import QtQuick 1.1

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    clip: true

    Rectangle {
      id: mainPage
      objectName: "mainPage"
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      Text{ text: "bananas" }
    }
  }
}
