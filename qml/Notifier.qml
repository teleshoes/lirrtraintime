import QtQuick 1.1

Rectangle {
  property int hideTimeout: 5000

  id: notificationArea
  x: parent.width * 0.10
  y: parent.height * 0.10
  width: parent.width * 0.80
  height: notificationBox.height
  clip: true
  opacity: 0.9
  visible: false
  z: 100
  color: "#dddddd"

  function notify(text){
    notificationBox.text = text
    notificationArea.visible = true
    hideTimer.start()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: notificationArea.visible = false
  }

  Timer {
    id: hideTimer
    interval: hideTimeout
    repeat: false
    onTriggered: {notificationArea.visible = false}
  }

  Text {
    id: notificationBox
    width: parent.width
    wrapMode: Text.Wrap
    font.pointSize: 32
  }
}

