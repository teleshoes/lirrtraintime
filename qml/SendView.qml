import QtQuick 1.1

Rectangle {
  id: sendView
  anchors.fill: parent

  function getForm(){
    return form
  }
  Item {
    id: form

    function getTo(){
      return to.getEmails()
    }
    function setTo(emails){
      return to.setEmails(emails)
    }

    function getCC(){
      return cc.getEmails()
    }
    function setCC(emails){
      return cc.setEmails(emails)
    }

    function getBCC(){
      return bcc.getEmails()
    }
    function setBCC(emails){
      return bcc.setEmails(emails)
    }

    function getAttachments(){
      return attachments.getFiles()
    }
    function setAttachments(files){
      return attachments.setFiles(files)
    }

    function getSubject(){
      return subject.getValue()
    }
    function setSubject(value){
      return subject.setValue(value)
    }

    function getBody(){
      return body.getValue()
    }
    function setBody(value){
      return body.setValue(value)
    }
  }

  Flickable {
    id: sendFlickable
    contentWidth: parent.width
    contentHeight: to.height + cc.height + bcc.height + subject.height + attachments.height + body.height
    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.DragOverBounds

    EmailListField {
      anchors {left: parent.left; right: parent.right; top: parent.top}
      id: to
      labelText: "TO"
      isDark: false
      height: 150
      width: parent.width
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: to.bottom}
      id: cc
      labelText: "CC"
      isDark: true
      height: 150
      width: parent.width
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: cc.bottom}
      id: bcc
      labelText: "BCC"
      isDark: false
      height: 150
      width: parent.width
    }
    FileSelectorField {
      id: attachments
      labelText: "ATTACHMENTS"
      anchors {left: parent.left; right: parent.right; top: bcc.bottom}
      isDark: true
    }
    LongField {
      anchors {left: parent.left; right: parent.right; top: attachments.bottom}
      id: subject
      labelText: "SUBJECT"
      isDark: false
      fontSize: 20
    }
    MultiLineField {
      anchors {left: parent.left; right: parent.right; top: subject.bottom}
      id: body
      labelText: "BODY"
      isDark: true
      cursorFollow: sendFlickable
      fontSize: 20
    }
  }

  ScrollBar{
    flickable: sendFlickable
    anchors.rightMargin: 0 - 30
  }
}
