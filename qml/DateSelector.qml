import QtQuick 1.1

Rectangle {
  width: parent.width
  height: parent.height
  clip: true

  property variant curDate: "none"

  ListView {
    id: dateSelector
    flickableDirection: Flickable.VerticalFlick

    width: parent.width
    height: parent.height
    model: ListModel {
      ListElement { date: "none" }
      ListElement { date: "today" }
      ListElement { date: "tomorrow" }
      ListElement { date: "next" }
    }
    delegate: Component  {
      Rectangle {
        height: 40
        width: parent.width
        border.width: 2
        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          property bool selected: model.date == curDate
          color: selected ? mainView.selectedColor : mainView.normalColor
          Text {
            text: model.date
            height: parent.height
            width: parent.width
            font.pointSize: 24
          }
        }
        MouseArea{
          anchors.fill: parent
          onClicked: {
            curDate = model.date
            controller.dateSelected(model.date)
            displayLabel.updateText()
          }
        }
      }
    }
  }

  ScrollBar {
    flickable: dateSelector
  }
}
