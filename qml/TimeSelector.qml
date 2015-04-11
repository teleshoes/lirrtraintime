import QtQuick 1.1

Rectangle {
  width: parent.width
  height: parent.height
  clip: true

  property variant curTime: "none"

  ListView {
    id: timeSelector
    flickableDirection: Flickable.VerticalFlick

    width: parent.width
    height: parent.height
    model: ListModel {
      ListElement { time: "none" }
      ListElement { time: "00:00" }
      ListElement { time: "01:00" }
      ListElement { time: "02:00" }
      ListElement { time: "03:00" }
      ListElement { time: "04:00" }
      ListElement { time: "05:00" }
      ListElement { time: "06:00" }
      ListElement { time: "07:00" }
      ListElement { time: "08:00" }
      ListElement { time: "09:00" }
      ListElement { time: "10:00" }
      ListElement { time: "11:00" }
      ListElement { time: "12:00" }
      ListElement { time: "13:00" }
      ListElement { time: "14:00" }
      ListElement { time: "15:00" }
      ListElement { time: "16:00" }
      ListElement { time: "17:00" }
      ListElement { time: "18:00" }
      ListElement { time: "19:00" }
      ListElement { time: "20:00" }
      ListElement { time: "21:00" }
      ListElement { time: "22:00" }
      ListElement { time: "23:00" }
    }
    delegate: Component  {
      Rectangle {
        height: 40
        width: parent.width
        border.width: 2
        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          property bool selected: model.time == curTime
          color: selected ? mainView.selectedColor : mainView.normalColor
          Text {
            text: model.time
            height: parent.height
            width: parent.width
            font.pointSize: 24
          }
        }
        MouseArea{
          anchors.fill: parent
          onClicked: {
            curTime = model.time
            controller.timeSelected(model.time, displayLabel)
          }
        }
      }
    }
  }

  ScrollBar {
    flickable: timeSelector
    anchors.rightMargin: -30
  }
}
