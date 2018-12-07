import QtQuick 2.3

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  Rectangle {
    id: mainPage
    objectName: "mainPage"
    anchors.fill: parent
    anchors.margins: 30

    MainView{}
  }
}
