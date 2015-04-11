#!/usr/bin/python
#qtbtn.py
#Copyright 2012,2015 Elliot Wolk
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

from PySide.QtGui import *
from PySide.QtCore import *
from PySide.QtDeclarative import *

import os
import os.path
import re
import signal
import sys
import subprocess

EMAIL_BIN = "/opt/qtemail/bin/email.pl"
QML_DIR = "/opt/qtemail/qml"

PLATFORM_OTHER = 0
PLATFORM_HARMATTAN = 1

signal.signal(signal.SIGINT, signal.SIG_DFL)

PAGE_INITIAL_SIZE = 200
PAGE_MORE_SIZE = 200

EMAIL_DIR = os.getenv("HOME") + "/.cache/email"

pages = ["account", "header", "config", "send", "folder", "body"]
okPages = "|".join(pages)

usage = """Usage:
  %(exec)s [OPTS]

  OPTS:
    --page=[%(okPages)s]
      start on the indicated page
    --account=ACCOUNT_NAME
      default the account to ACCOUNT_NAME {only useful with --page}
    --folder=FOLDER_NAME
      default the folder to ACCOUNT_NAME {only useful with --page}
    --uid=UID
      default the message to UID {only useful with --page}
""" % {"exec": sys.argv[0], "okPages": okPages}

def die(msg):
  print >> sys.stderr, msg
  sys.exit(1)

def main():
  args = sys.argv
  args.pop(0)

  opts = {}
  while len(args) > 0 and args[0].startswith("-"):
    arg = args.pop(0)
    pageMatch = re.match("^--page=(" + okPages + ")$", arg)
    accountMatch = re.match("^--account=(\\w+)$", arg)
    folderMatch = re.match("^--folder=(\\w+)$", arg)
    uidMatch = re.match("^--uid=(\\w+)$", arg)
    if pageMatch:
      opts['page'] = pageMatch.group(1)
    elif accountMatch:
      opts['account'] = accountMatch.group(1)
    elif folderMatch:
      opts['folder'] = folderMatch.group(1)
    elif uidMatch:
      opts['uid'] = uidMatch.group(1)
    else:
      die(usage)
  if len(args) > 0:
    die(usage)

  issue = open('/etc/issue').read().strip().lower()
  platform = None
  if "harmattan" in issue:
    platform = PLATFORM_HARMATTAN
  else:
    platform = PLATFORM_OTHER

  if platform == PLATFORM_HARMATTAN:
    qmlFile = QML_DIR + "/harmattan.qml"
  else:
    qmlFile = QML_DIR + "/desktop.qml"

  emailManager = EmailManager()
  accountModel = AccountModel()
  folderModel = FolderModel()
  headerModel = HeaderModel()
  configModel = ConfigModel()
  controller = Controller(emailManager, accountModel, folderModel, headerModel, configModel)

  if 'page' in opts:
    controller.setInitialPageName(opts['page'])
  if 'account' in opts:
    controller.setAccountName(opts['account'])
  if 'folder' in opts:
    controller.setFolderName(opts['folder'])
  if 'uid' in opts:
    hdr = emailManager.getHeader(opts['account'], opts['folder'], opts['uid'])
    controller.setHeader(hdr)

  app = QApplication([])
  widget = MainWindow(qmlFile, controller, accountModel, folderModel, headerModel, configModel)
  if platform == PLATFORM_HARMATTAN:
    widget.window().showFullScreen()
  else:
    widget.window().show()

  app.exec_()

class EmailManager():
  def __init__(self):
    self.emailRegex = self.compileEmailRegex()

  def compileEmailRegex(self):
    c = "[a-zA-Z0-9!#$%&'*+\\-/=?^_`{|}~]"
    start = c + "+"
    middleDot = "(?:" + "\\." + c + ")*"
    end = c + "*"
    user = start + middleDot + end

    sub = "[a-zA-Z0-9\\-.]+"
    top = "[a-zA-Z]{2,}"
    host = sub + "\\." + top

    return re.compile(user + "@" + host)

  def parseEmails(self, string):
    if string == None:
      return []
    return self.emailRegex.findall(string)

  def readConfig(self, configMode, accName=None):
    configValues = {}
    cmd = [EMAIL_BIN]
    if configMode == "account":
      cmd.append("--read-config")
      if accName != None:
        cmd.append(accName)
    elif configMode == "options":
      cmd.append("--read-options")
    else:
      die("invalid config mode: " + configMode)

    if cmd != None:
      configOut = self.readProc(cmd)
      for line in configOut.splitlines():
        m = re.match("(\w+)=(.*)", line)
        if m:
          fieldName = m.group(1)
          value = m.group(2)
          configValues[m.group(1)] = m.group(2)
    return configValues
  def writeConfig(self, configValues, configMode, accName=None):
    cmd = [EMAIL_BIN]
    if configMode == "account":
      cmd.append("--write-config")
      cmd.append(accName)
    elif configMode == "options":
      cmd.append("--write-options")
    else:
      die("invalid config mode: " + str(configMode))

    for key in configValues.keys():
      cmd.append(key + "=" + configValues[key])

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = process.communicate()
    print >> sys.stdout, out
    print >> sys.stderr, err
    return {'exitCode': process.returncode, 'stdout': out, 'stderr': err}

  def getConfigFields(self, schema, configValues):
    fieldNames = schema[0::2]
    fieldDescriptions = dict(zip(schema[0::2], schema[1::2]))

    fields = []
    for fieldName in fieldNames:
      if fieldName in configValues:
        value = configValues[fieldName]
      else:
        value = ""
      pwRegex = re.compile('password|pword|^pw$', re.IGNORECASE)
      isPass = pwRegex.search(fieldName) != None
      fields.append(Field(fieldName, isPass, value, fieldDescriptions[fieldName]))
    return fields
  def getAccountConfigFields(self, accName):
    schema = [ "name",           "single-word account ID, e.g.: \"Work\""
             , "user",           "IMAP user, usually the full email address"
             , "password",       "password, stored with optional encrypt_cmd"
             , "server",         "IMAP server, e.g.: \"imap.gmail.com\""
             , "port",           "IMAP port"
             , "sent",           "[OPT] sent folder, e.g: \"Sent\""
             , "ssl",            "[OPT] set to false if necessary"
             , "smtp_server",    "[OPT] SMTP server. e.g.: \"smtp.gmail.com\""
             , "smtp_port",      "[OPT] SMTP port"
             , "new_unread_cmd", "[OPT] custom alert command"
             , "skip",           "[OPT] set to true to skip during --update"
             , "preferHtml",     "[OPT] set to false to prefer plaintext"
             ]
    if accName == None:
      configValues = []
    else:
      configValues = self.readConfig("account", accName)
    return self.getConfigFields(schema, configValues)
  def getOptionsConfigFields(self):
    schema = [ "update_cmd",     "[OPT] command to run after all updates"
             , "encrypt_cmd",    "[OPT] command to encrypt passwords on disk"
             , "decrypt_cmd",    "[OPT] command to decrypt saved passwords"
             ]
    configValues = self.readConfig("options")
    return self.getConfigFields(schema, configValues)

  def saveAccountConfigFields(self, fields):
    configValues = {}
    accName = None
    for field in fields:
      if field.FieldName == "name":
        accName = field.Value
      else:
        configValues[field.FieldName] = field.Value
    return self.writeConfig(configValues, "account", accName)
  def saveOptionsConfigFields(self, fields):
    configValues = {}
    for field in fields:
      configValues[field.FieldName] = field.Value
    return self.writeConfig(configValues, "options")

  def getAccounts(self):
    accountOut = self.readProc([EMAIL_BIN, "--accounts"])
    accounts = []
    for line in accountOut.splitlines():
      m = re.match("(\w+):(\d+):([a-z0-9_\- ]+):(\d+)/(\d+):(.*)", line)
      if m:
        accName = m.group(1)
        lastUpdated = int(m.group(2))
        lastUpdatedRel = m.group(3)
        unreadCount = int(m.group(4))
        totalCount = int(m.group(5))
        error = m.group(6)
        accounts.append(Account(
          accName, lastUpdated, lastUpdatedRel, unreadCount, totalCount, error, False))
    return accounts
  def getFolders(self, accountName):
    folderOut = self.readProc([EMAIL_BIN, "--folders", accountName])
    folders = []
    for line in folderOut.splitlines():
      m = re.match("([a-z]+):(\d+)/(\d+)", line)
      if m:
        folderName = m.group(1)
        unreadCount = int(m.group(2))
        totalCount = int(m.group(3))
        folders.append(Folder(
          folderName, unreadCount, totalCount))
    return folders
  def getUids(self, accName, folderName, fileName):
    filePath = EMAIL_DIR + "/" + accName + "/" + folderName + "/" + fileName
    if not os.path.isfile(filePath):
      return []
    f = open(filePath, 'r')
    uids = f.read()
    f.close()
    return map(int, uids.splitlines())
  def fetchHeaders(self, accName, folderName, limit=None, exclude=[]):
    uids = self.getUids(accName, folderName, "all")
    uids.sort()
    uids.reverse()
    total = len(uids)
    if len(exclude) > 0:
      exUids = set(map(lambda header: header.uid_, exclude))
      uids = filter(lambda uid: uid not in exUids, uids)
    if limit != None:
      uids = uids[0:limit]
    unread = set(self.getUids(accName, folderName, "unread"))
    headers = []
    for uid in uids:
      header = self.getHeader(accName, folderName, uid)
      header.isSent_ = folderName == "sent"
      header.read_ = not uid in unread
      headers.append(header)
    return (total, headers)
  def getHeader(self, accName, folderName, uid):
    filePath = EMAIL_DIR + "/" + accName + "/" + folderName + "/" + "headers/" + str(uid)
    if not os.path.isfile(filePath):
      return None
    f = open(filePath, 'r')
    header = f.read()
    f.close()
    hdrDate = ""
    hdrFrom = ""
    hdrSubject = ""
    for line in header.splitlines():
      m = re.match('(\w+): (.*)', line)
      if not m:
        return None
      field = m.group(1)
      val = m.group(2)
      try:
        val = val.encode('utf-8')
      except:
        val = val.decode('utf-8')

      if field == "Date":
        hdrDate = val
      elif field == "From":
        hdrFrom = val
      elif field == "To":
        hdrTo = val
      elif field == "Subject":
        hdrSubject = val
    return Header(uid, hdrDate, hdrFrom, hdrTo, hdrSubject, False, False, False)
  def readProc(self, cmdArr):
    process = subprocess.Popen(cmdArr, stdout=subprocess.PIPE)
    (stdout, _) = process.communicate()
    return stdout

class Controller(QObject):
  def __init__(self, emailManager, accountModel, folderModel, headerModel, configModel):
    QObject.__init__(self)
    self.emailManager = emailManager
    self.accountModel = accountModel
    self.folderModel = folderModel
    self.headerModel = headerModel
    self.configModel = configModel
    self.initialPageName = "account"
    self.htmlMode = False
    self.configMode = None
    self.accountName = None
    self.accountConfig = None
    self.folderName = None
    self.header = None
    self.currentBodyText = None
    self.threads = []
    self.currentHeaders = []
    self.headerFilters = []
    self.fileSystemController = FileSystemController()

  @Slot('QVariantList')
  def runCommand(self, cmdArr):
    subprocess.Popen(cmdArr)
  @Slot(str)
  def shellCommand(self, cmdStr):
    subprocess.Popen(['sh', '-c', cmdStr])

  @Slot(QObject, str, result=QObject)
  def findChild(self, obj, name):
    return obj.findChild(QObject, name)

  @Slot(str, QObject, QObject)
  def initSend(self, sendType, sendForm, notifier):
    if self.accountName == None or self.folderName == None or self.header == None:
      notifier.notify("Missing source email for " + sendType)
      return

    header = self.emailManager.getHeader(self.accountName, self.folderName, self.header.Uid)
    if header == None:
      notifier.notify("Could not parse headers for message")
      return

    toEmails = self.emailManager.parseEmails(header.To)
    fromEmails = self.emailManager.parseEmails(header.From)

    if sendType == "reply":
      if self.folderName == "sent":
        recipEmails = toEmails
      else:
        recipEmails = fromEmails
    else:
      recipEmails = []

    subjectPrefix = ""
    if sendType == "reply":
      subjectPrefix = "Re: "
    elif sendType == "forward":
      subjectPrefix = "Fwd: "
    subject = header.Subject
    if not subject.startswith(subjectPrefix):
      subject = subjectPrefix + subject

    if len(fromEmails) > 0:
      firstFrom = fromEmails[0]
    else:
      firstFrom = "[unknown]"

    date = header.Date

    sendForm.setTo(recipEmails)
    sendForm.setCC([])
    sendForm.setBCC([])
    sendForm.setSubject(subject)

    self.fetchCurrentBodyText(notifier, sendForm, None,
      lambda body: self.wrapBody(body, date, firstFrom))

  def wrapBody(self, body, date, author):
    bodyPrefix = "\n\nOn " + date + ", " + author + " wrote:\n"
    lines = [""] + body.splitlines()
    indentedBody = "\n".join(map(lambda line: "> " + line, lines)) + "\n"
    return bodyPrefix + indentedBody

  @Slot(QObject, QObject)
  def sendEmail(self, sendForm, notifier):
    to = sendForm.getTo()
    cc = sendForm.getCC()
    bcc = sendForm.getBCC()
    subject = sendForm.getSubject()
    body = sendForm.getBody()
    attachments = sendForm.getAttachments()
    if len(to) == 0:
      notifier.notify("TO is empty\n")
      return
    if self.accountName == None:
      notifier.notify("no FROM account selected\n")
      return
    firstTo = to.pop(0)

    notifier.notify("sending...")
    cmd = [EMAIL_BIN, "--smtp", self.accountName, subject, body, firstTo]
    for email in to:
      cmd += ["--to", email]
    for email in cc:
      cmd += ["--cc", email]
    for email in bcc:
      cmd += ["--bcc", email]
    for att in attachments:
      cmd += ["--attach", att]

    self.startEmailCommandThread(cmd, None,
      self.onSendEmailFinished, {'notifier': notifier})
  def onSendEmailFinished(self, isSuccess, output, extraArgs):
    notifier = extraArgs['notifier']
    if not isSuccess:
      notifier.notify("\nFAILED\n\n" + output)
    else:
      notifier.notify("\nSUCCESS\n\n" + output)

  @Slot()
  def setupAccounts(self):
    self.accountModel.setItems(self.emailManager.getAccounts())
  @Slot()
  def setupFolders(self):
    self.folderModel.setItems(self.emailManager.getFolders(self.accountName))
  @Slot(QObject)
  def setupHeaders(self, counterBox):
    self.headerFilters = []
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=PAGE_INITIAL_SIZE, exclude=[])
    self.totalSize = total
    self.curSize = len(headers)
    self.updateCounterBox(counterBox)
    self.setHeaders(headers)
  @Slot(str)
  def setConfigMode(self, mode):
    self.configMode = mode
  @Slot()
  def setupConfig(self):
    if self.configMode == "account":
      self.setupAccountConfig()
    elif self.configMode == "options":
      self.setupOptionsConfig()
  def setupAccountConfig(self):
    fields = self.emailManager.getAccountConfigFields(self.accountName)
    self.configModel.setItems(fields)
  def setupOptionsConfig(self):
    fields = self.emailManager.getOptionsConfigFields()
    self.configModel.setItems(fields)

  @Slot(QObject, str)
  def updateConfigFieldValue(self, field, value):
    field.value_ = value
  @Slot(QObject, result=bool)
  def saveConfig(self, notifier):
    fields = self.configModel.getItems()
    if self.configMode == "account":
      res = self.emailManager.saveAccountConfigFields(fields)
    elif self.configMode == "options":
      res = self.emailManager.saveOptionsConfigFields(fields)

    if res['exitCode'] == 0:
      notifier.notify("saved config\n" + res['stdout'] + res['stderr'])
      return True
    else:
      notifier.notify("FAILURE\n" + res['stdout'] + res['stderr'])
      return False

  @Slot(QObject)
  def accountSelected(self, account):
    self.setAccountName(account.Name)
    self.setFolderName("inbox")
    self.setAccountConfig(self.emailManager.readConfig("account", account.Name))
  @Slot(QObject)
  def folderSelected(self, folder):
    self.setFolderName(folder.Name)
  @Slot(QObject)
  def headerSelected(self, header):
    self.setHeader(header)
  @Slot()
  def clearAccount(self):
    self.reset()

  @Slot(str, result=str)
  def getAccountConfigValue(self, configKey):
    if self.accountConfig != None and configKey in self.accountConfig:
      return self.accountConfig[configKey]
    return ''

  @Slot(result=str)
  def getInitialPageName(self):
    return self.initialPageName
  def setInitialPageName(self, pageName):
    self.initialPageName = pageName

  def setAccountName(self, accName):
    self.accountName = accName
  def setFolderName(self, folderName):
    self.folderName = folderName
  def setHeader(self, header):
    self.header = header
  def setAccountConfig(self, accountConfig):
    self.accountConfig = accountConfig
  def reset(self):
    self.setAccountName(None)
    self.setAccountConfig(None)
    self.setFolderName(None)
    self.setHeader(None)
    self.currentBodyText = None

  def filterHeader(self, header):
    for f in self.headerFilters:
      if not f.filterHeader(header):
        return False
    return True
  def setQuickFilterRegex(self, regex):
    name = "quickFilter"
    self.headerFilters = filter(lambda f: f.name != name, self.headerFilters)
    self.headerFilters.append(HeaderFilterRegex(name, regex))
    self.setHeaders(self.currentHeaders)
  @Slot(str)
  def setUnreadFilter(self, unreadFilter):
    name = "unreadFilter"
    self.headerFilters = filter(lambda f: f.name != name, self.headerFilters)
    if unreadFilter == "unread-only":
      self.headerFilters.append(HeaderFilterUnread(name))
    self.setHeaders(self.currentHeaders)
  def setHeaders(self, headers):
    self.currentHeaders = headers
    filteredHeaders = filter(self.filterHeader, headers)
    if len(filteredHeaders) == 0:
      self.headerModel.clear()
    else:
      self.headerModel.setItems(filteredHeaders)
  def appendHeaders(self, headers):
    self.currentHeaders += headers
    filteredHeaders = filter(self.filterHeader, headers)
    if len(filteredHeaders) > 0:
      self.headerModel.appendItems(filteredHeaders)

  @Slot(str)
  def onSearchTextChanged(self, searchText):
    self.setQuickFilterRegex(re.compile(searchText.strip(), re.IGNORECASE))

  @Slot(QObject, QObject, QObject)
  def updateAccount(self, indicator, messageBox, account):
    if account == None:
      accMsg = "ALL ACCOUNTS WITHOUT SKIP"
    else:
      accMsg = account.Name
    self.onAppendMessage(messageBox, "STARTING UPDATE FOR " + accMsg + "\n")

    if account != None:
      account.isLoading_ = True
    if indicator != None:
      indicator.updateColor()

    cmd = [EMAIL_BIN, "--update"]
    if account != None:
      cmd.append(account.Name)

    self.startEmailCommandThread(cmd, messageBox,
      self.onUpdateAccountFinished, {})
  def onUpdateAccountFinished(self, isSuccess, output, extraArgs):
    self.setupAccounts()

  @Slot(QObject, QObject)
  def toggleRead(self, indicator, header):
    header.isLoading_ = True
    indicator.updateColor()

    if header.read_:
      arg = "--mark-unread"
    else:
      arg = "--mark-read"
    cmd = [EMAIL_BIN, arg,
      "--folder=" + self.folderName, self.accountName, str(header.uid_)]

    self.startEmailCommandThread(cmd, None,
      self.onToggleReadFinished, {'indicator': indicator, 'header': header})
  def onToggleReadFinished(self, isSuccess, output, extraArgs):
    indicator = extraArgs['indicator']
    header = extraArgs['header']
    header.isLoading_ = False
    if isSuccess:
      header.read_ = not header.read_
    indicator.updateColor()

  @Slot(result=bool)
  def getHtmlMode(self):
    return self.htmlMode
  @Slot(bool)
  def setHtmlMode(self, htmlMode):
    self.htmlMode = htmlMode

  @Slot(QObject, QObject, QObject, object)
  def fetchCurrentBodyText(self, notifier, bodyBox, headerBox, transform):
    self.currentBodyText = None
    bodyBox.setBody("...loading body")
    if self.header == None:
      notifier.notify("CURRENT MESSAGE NOT SET")
      return
    if headerBox != None:
      headerBox.setHeader(""
        + "From: " + self.header.From + "\n"
        + "Subject: " + self.header.Subject + "\n"
        + "To: " + self.header.To + "\n"
        + "Date: " + self.header.Date + "\n"
      );

    if self.htmlMode:
      arg = "--body-html"
    else:
      arg = "--body-plain"

    cmd = [EMAIL_BIN, arg,
      "--folder=" + self.folderName, self.accountName, str(self.header.Uid)]

    self.startEmailCommandThread(cmd, None,
      self.onFetchCurrentBodyTextFinished, {'bodyBox': bodyBox, 'transform': transform})
  def onFetchCurrentBodyTextFinished(self, isSuccess, output, extraArgs):
    bodyBox = extraArgs['bodyBox']
    transform = extraArgs['transform']
    if transform:
      body = transform(output)
    else:
      body = output

    if isSuccess:
      self.currentBodyText = body
      bodyBox.setBody(body)
    else:
      self.currentBodyText = None
      bodyBox.setBody("ERROR FETCHING BODY\n")

  @Slot(QObject)
  def copyBodyToClipboard(self, notifier):
    if self.currentBodyText != None:
      QClipboard().setText(self.currentBodyText)
    notifier.notify("Copied text to clipboard: " + self.currentBodyText)

  @Slot(QObject)
  def saveCurrentAttachments(self, notifier):
    if self.header == None:
      notifier.notify("MISSING CURRENT MESSAGE")
      return

    destDir = os.getenv("HOME")
    cmd = [EMAIL_BIN, "--attachments",
      "--folder=" + self.folderName, self.accountName, destDir, str(self.header.Uid)]

    self.startEmailCommandThread(cmd, None,
      self.onSaveCurrentAttachmentsFinished, {'notifier': notifier})
  def onSaveCurrentAttachmentsFinished(self, isSuccess, output, extraArgs):
    notifier = extraArgs['notifier']
    if output.strip() == "":
      output = "{no attachments}"
    if isSuccess:
      notifier.notify("success:\n" + output)
    else:
      notifier.notify("ERROR: saving attachments failed\n")

  def startEmailCommandThread(self, command, messageBox, finishedAction, extraArgs):
    thread = EmailCommandThread(
      command=command,
      messageBox=messageBox,
      finishedAction=finishedAction,
      extraArgs=extraArgs)
    thread.finished.connect(lambda: self.onThreadFinished(thread))
    thread.commandFinished.connect(self.onCommandFinished)
    thread.setMessage.connect(self.onSetMessage)
    thread.appendMessage.connect(self.onAppendMessage)
    self.threads.append(thread)
    thread.start()
  def onThreadFinished(self, thread):
    self.threads.remove(thread)
  def onCommandFinished(self, isSuccess, output, finishedAction, extraArgs):
    if finishedAction != None:
      finishedAction(isSuccess, output, extraArgs)
  def onSetMessage(self, messageBox, message):
    if messageBox != None:
      messageBox.setText(message)
  def onAppendMessage(self, messageBox, message):
    if messageBox != None:
      messageBox.append(message)
      messageBox.scrollToBottom()

  @Slot(QObject, int)
  def moreHeaders(self, counterBox, percentage):
    if percentage != None:
      limit = int(self.totalSize * percentage / 100)
    else:
      limit = 0
    if limit < PAGE_MORE_SIZE:
      limit = PAGE_MORE_SIZE
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=limit, exclude=self.currentHeaders)
    self.curSize = len(self.currentHeaders) + len(headers)
    self.totalSize = total
    self.updateCounterBox(counterBox)
    self.appendHeaders(headers)
  def updateCounterBox(self, counterBox):
    counterBox.setCounterText(str(self.curSize) + " / " + str(self.totalSize))

class HeaderFilter():
  def __init__(self, name):
    self.name = name
  def filterHeader(self, header):
    return True

class HeaderFilterRegex(HeaderFilter):
  def __init__(self, name, regex, fields=["subject", "from", "to"]):
    HeaderFilter.__init__(self, name)
    self.regex = regex
    self.fields = fields
  def filterHeader(self, header):
    for field in self.fields:
      if field == "subject" and self.regex.search(header.subject_):
        return True
      elif field == "from" and self.regex.search(header.from_):
        return True
      elif field == "to" and self.regex.search(header.to_):
        return True
    return False
class HeaderFilterUnread(HeaderFilter):
  def __init__(self, name):
    HeaderFilter.__init__(self, name)
  def filterHeader(self, header):
    return not header.read_

class FileSystemController(QObject):
  def __init__(self):
    QObject.__init__(self)
    self.dirModel = None

  def ensureDirModel(self):
    if self.dirModel == None:
      self.dirModel = QDirModel()
      self.dirModel.setSorting(QDir.DirsFirst)
      self.dirModel.setFilter(QDir.AllEntries | QDir.NoDot | QDir.NoDotDot)

  @Slot(result=str)
  def getHome(self):
    return os.getenv("HOME")

  @Slot(result=QObject)
  def getDirModel(self):
    self.ensureDirModel()
    return self.dirModel
  @Slot(str, result=QModelIndex)
  def getModelIndex(self, path):
    self.ensureDirModel()
    return self.dirModel.index(path)
  @Slot(QModelIndex, result=str)
  def getFilePath(self, index):
    self.ensureDirModel()
    return self.dirModel.filePath(index)
  @Slot(QModelIndex, result=bool)
  def isDir(self, index):
    self.ensureDirModel()
    p = self.getFilePath(index)
    if p:
      return self.dirModel.isDir(index)
    else:
      return False
  @Slot(str, result=QObject)
  def setDirModelPath(self, path):
    index = self.dirModel.index(path)
    self.dirModel.refresh(parent=index)

  @Slot(result=bool)
  def checkDirModelFucked(self):
    try:
      if self.dirModel:
        self.dirModel.isReadOnly()
    except:
      print "\n\n\n\n\n\nQDirModel is FUUUUUUCKED\n\n"
      self.dirModel = None
      self.ensureDirModel()
      return True
    return False


class EmailCommandThread(QThread):
  commandFinished = Signal(bool, str, object, list)
  setMessage = Signal(QObject, str)
  appendMessage = Signal(QObject, str)
  def __init__(self, command, messageBox=None, finishedAction=None, extraArgs=None):
    QThread.__init__(self)
    self.command = command
    self.messageBox = messageBox
    self.finishedAction = finishedAction
    self.extraArgs = extraArgs
  def run(self):
    proc = subprocess.Popen(self.command, stdout=subprocess.PIPE)
    output = ""
    for line in iter(proc.stdout.readline,''):
      self.appendMessage.emit(self.messageBox, line)
      output += line
    proc.wait()

    if proc.returncode == 0:
      success = True
      status = "SUCCESS\n"
    else:
      success = False
      status = "FAILURE\n"

    self.appendMessage.emit(self.messageBox, status)

    self.commandFinished.emit(success, output, self.finishedAction, self.extraArgs)

class BaseListModel(QAbstractListModel):
  def __init__(self):
    QAbstractListModel.__init__(self)
    self.items = []
  def getItems(self):
    return self.items
  def setItems(self, items):
    self.clear()
    if len(items) > 0:
      self.beginInsertRows(QModelIndex(), 0, 0)
      self.items = items
      self.endInsertRows()
    else:
      self.items = []
  def appendItems(self, items):
    self.beginInsertRows(QModelIndex(), len(self.items), len(self.items))
    self.items.extend(items)
    self.endInsertRows()
  def rowCount(self, parent=QModelIndex()):
    return len(self.items)
  def data(self, index, role):
    if role == Qt.DisplayRole:
      return self.items[index.row()]
  def clear(self):
    self.removeRows(0, len(self.items))
  def removeRows(self, firstRow, rowCount, parent = QModelIndex()):
    self.beginRemoveRows(parent, firstRow, firstRow+rowCount-1)
    while rowCount > 0:
      del self.items[firstRow]
      rowCount -= 1
    self.endRemoveRows()

class AccountModel(BaseListModel):
  COLUMNS = ('account',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(AccountModel.COLUMNS)))

class FolderModel(BaseListModel):
  COLUMNS = ('folder',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(FolderModel.COLUMNS)))

class HeaderModel(BaseListModel):
  COLUMNS = ('header',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(HeaderModel.COLUMNS)))

class ConfigModel(BaseListModel):
  COLUMNS = ('config',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(ConfigModel.COLUMNS)))

class Account(QObject):
  def __init__(self, name_, lastUpdated_, lastUpdatedRel_, unread_, total_, error_, isLoading_):
    QObject.__init__(self)
    self.name_ = name_
    self.lastUpdated_ = lastUpdated_
    self.lastUpdatedRel_ = lastUpdatedRel_
    self.unread_ = unread_
    self.total_ = total_
    self.error_ = error_
    self.isLoading_ = isLoading_
  def Name(self):
    return self.name_
  def LastUpdated(self):
    return self.lastUpdated_
  def LastUpdatedRel(self):
    return self.lastUpdatedRel_
  def Unread(self):
    return self.unread_
  def Total(self):
    return self.total_
  def Error(self):
    return self.error_
  def IsLoading(self):
    return self.isLoading_
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  LastUpdated = Property(int, LastUpdated, notify=changed)
  LastUpdatedRel = Property(unicode, LastUpdatedRel, notify=changed)
  Unread = Property(int, Unread, notify=changed)
  Total = Property(int, Total, notify=changed)
  Error = Property(unicode, Error, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)

class Folder(QObject):
  def __init__(self, name_, unread_, total_):
    QObject.__init__(self)
    self.name_ = name_
    self.unread_ = unread_
    self.total_ = total_
  def Name(self):
    return self.name_
  def Unread(self):
    return self.unread_
  def Total(self):
    return self.total_
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  Unread = Property(int, Unread, notify=changed)
  Total = Property(int, Total, notify=changed)

class Header(QObject):
  def __init__(self, uid_, date_, from_, to_, subject_, isSent_, read_, isLoading_):
    QObject.__init__(self)
    self.uid_ = uid_
    self.date_ = date_
    self.from_ = from_
    self.to_ = to_
    self.subject_ = subject_
    self.isSent_ = isSent_
    self.read_ = read_
    self.isLoading_ = isLoading_
  def Uid(self):
    return self.uid_
  def Date(self):
    return self.date_
  def From(self):
    return self.from_
  def To(self):
    return self.to_
  def Subject(self):
    return self.subject_
  def IsSent(self):
    return self.isSent_
  def Read(self):
    return self.read_
  def IsLoading(self):
    return self.isLoading_
  changed = Signal()
  Uid = Property(int, Uid, notify=changed)
  Date = Property(unicode, Date, notify=changed)
  From = Property(unicode, From, notify=changed)
  To = Property(unicode, To, notify=changed)
  Subject = Property(unicode, Subject, notify=changed)
  IsSent = Property(bool, IsSent, notify=changed)
  Read = Property(bool, Read, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)

class Field(QObject):
  def __init__(self, fieldName_, isPassword_, value_, description_):
    QObject.__init__(self)
    self.fieldName_ = fieldName_
    self.isPassword_ = isPassword_
    self.value_ = value_
    self.description_ = description_
  def FieldName(self):
    return self.fieldName_
  def IsPassword(self):
    return self.isPassword_
  def Value(self):
    return self.value_
  def Description(self):
    return self.description_
  changed = Signal()
  FieldName = Property(unicode, FieldName, notify=changed)
  IsPassword = Property(bool, IsPassword, notify=changed)
  Value = Property(unicode, Value, notify=changed)
  Description = Property(unicode, Description, notify=changed)

class MainWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller, accountModel, folderModel, headerModel, configModel):
    super(MainWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('accountModel', accountModel)
    context.setContextProperty('folderModel', folderModel)
    context.setContextProperty('headerModel', headerModel)
    context.setContextProperty('configModel', configModel)
    context.setContextProperty('controller', controller)
    context.setContextProperty('fileSystemController', controller.fileSystemController)

    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

if __name__ == "__main__":
  sys.exit(main())
