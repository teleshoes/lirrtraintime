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

LIRRTRAINTIME_BIN = "/opt/lirrtraintime/bin/lirrtraintime.pl"
QML_DIR = "/opt/lirrtraintime/qml"

PLATFORM_OTHER = 0
PLATFORM_HARMATTAN = 1

signal.signal(signal.SIGINT, signal.SIG_DFL)

PAGE_INITIAL_SIZE = 200
PAGE_MORE_SIZE = 200

usage = """Usage:
  %(exec)s
""" % {"exec": sys.argv[0]}

def die(msg):
  print >> sys.stderr, msg
  sys.exit(1)

def main():
  args = sys.argv
  args.pop(0)

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

  stationManager = StationManager()
  stationModel = StationModel()
  controller = Controller(stationManager, stationModel)

  app = QApplication([])
  widget = MainWindow(qmlFile, controller, stationModel)
  if platform == PLATFORM_HARMATTAN:
    widget.window().showFullScreen()
  else:
    widget.window().show()

  app.exec_()

class StationManager(QObject):
  def __init__(self):
    self.stations = {'CPG': 'Copiague'}
  def getStations():
    for name in self.stations.keys():
      return Station(name, self.stations[name])

class Controller(QObject):
  def __init__(self, stationManager, stationModel):
    QObject.__init__(self)
    self.stationManager = stationManager
    self.stationModel = stationModel

  @Slot('QVariantList')
  def runCommand(self, cmdArr):
    subprocess.Popen(cmdArr)
  @Slot(str)
  def shellCommand(self, cmdStr):
    subprocess.Popen(['sh', '-c', cmdStr])

  @Slot(QObject, str, result=QObject)
  def findChild(self, obj, name):
    return obj.findChild(QObject, name)

  @Slot()
  def setupStations(self):
    self.stationModel.setItems(self.stationManager.getStations())

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

class StationModel(BaseListModel):
  COLUMNS = ('station',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(StationModel.COLUMNS)))

class Account(QObject):
  def __init__(self, stationId_, name_):
    QObject.__init__(self)
    self.stationId_ = stationId_
    self.name_ = name_
  def StationId(self):
    return self.stationId_
  def Name(self):
    return self.name_
  changed = Signal()
  StationId = Property(unicode, StationId, notify=changed)
  Name = Property(unicode, Name, notify=changed)

class MainWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller, stationModel):
    super(MainWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('stationModel', stationModel)
    context.setContextProperty('controller', controller)

    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

if __name__ == "__main__":
  sys.exit(main())
