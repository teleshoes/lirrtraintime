import QtQuick 1.1

Rectangle {
  width: parent.width
  height: parent.height
  clip: true

  ListView {
    id: dateSelector
    flickableDirection: Flickable.VerticalFlick

    width: parent.width
    height: parent.height
    model: ListModel {
      ListElement { date: "today" }
      ListElement { date: "tomorrow" }
      ListElement { date: "next" }
    }
    delegate: Component  {
      Rectangle {
        height: 30
        width: parent.width
        border.width: 2
        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          color: "gray"
          Text {
            text: model.date
            height: parent.height
            width: parent.width
          }
        }
        MouseArea{
          anchors.fill: parent
          onClicked: {
            controller.dateSelected(model.date, displayLabel)
          }
        }
      }
    }
  }

  ScrollBar {
    flickable: dateSelector
    anchors.rightMargin: -30
  }
}
