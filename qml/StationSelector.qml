import QtQuick 1.1

Rectangle {
  width: parent.width
  height: parent.height
  clip: true

  property variant fieldName

  ListView {
    id: stationSelector
    flickableDirection: Flickable.VerticalFlick

    width: parent.width
    height: parent.height
    model: stationModel
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
            text: model.station.Name + " (" + model.station.StationId + ")"
            height: parent.height
            width: parent.width
          }
        }
        MouseArea{
          anchors.fill: parent
          onClicked: {
            controller.stationSelected(fieldName, model.station, displayLabel)
          }
        }
      }
    }
  }

  ScrollBar {
    flickable: stationSelector
    anchors.rightMargin: -30
  }
}
