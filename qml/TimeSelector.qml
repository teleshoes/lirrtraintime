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
      ListElement { time: "none"; display: "" }
      ListElement { time: "00:00"; display: " (midnight)"}
      ListElement { time: "01:00"; display: " (1am)"}
      ListElement { time: "02:00"; display: " (2am)"}
      ListElement { time: "03:00"; display: " (3am)"}
      ListElement { time: "04:00"; display: " (4am)"}
      ListElement { time: "05:00"; display: " (5am)"}
      ListElement { time: "06:00"; display: " (6am)"}
      ListElement { time: "07:00"; display: " (7am)"}
      ListElement { time: "08:00"; display: " (8am)"}
      ListElement { time: "09:00"; display: " (9am)"}
      ListElement { time: "10:00"; display: " (10am)"}
      ListElement { time: "11:00"; display: " (11am)"}
      ListElement { time: "12:00"; display: " (noon)"}
      ListElement { time: "13:00"; display: " (1pm)"}
      ListElement { time: "14:00"; display: " (2pm)"}
      ListElement { time: "15:00"; display: " (3pm)"}
      ListElement { time: "16:00"; display: " (4pm)"}
      ListElement { time: "17:00"; display: " (5pm)"}
      ListElement { time: "18:00"; display: " (6pm)"}
      ListElement { time: "19:00"; display: " (7pm)"}
      ListElement { time: "20:00"; display: " (8pm)"}
      ListElement { time: "21:00"; display: " (9pm)"}
      ListElement { time: "22:00"; display: " (10pm)"}
      ListElement { time: "23:00"; display: " (11pm)"}
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
            text: model.time + model.display
            height: parent.height
            width: parent.width
            font.pointSize: 24
          }
        }
        MouseArea{
          anchors.fill: parent
          onClicked: {
            curTime = model.time
            controller.timeSelected(model.time)
            displayLabel.updateText()
          }
        }
      }
    }
  }

  ScrollBar {
    flickable: timeSelector
  }
}
