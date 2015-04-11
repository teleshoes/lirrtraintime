import QtQuick 1.1

Rectangle {
  width: parent.width
  height: parent.height
  clip: true

  property variant fieldName
  property variant curStationId

  ListView {
    id: stationSelector
    flickableDirection: Flickable.VerticalFlick

    width: parent.width
    height: parent.height
    model: stationModel
    delegate: Component  {
      Rectangle {
        height: 40
        width: parent.width
        border.width: 2
        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          property bool selected: model.station.StationId == curStationId
          color: selected ? mainView.selectedColor : mainView.normalColor
          Text {
            text: model.station.Name + " (" + model.station.StationId + ")"
            height: parent.height
            width: parent.width
            font.pointSize: 24
          }
        }
        MouseArea{
          anchors.fill: parent
          onClicked: {
            curStationId = model.station.StationId
            controller.stationSelected(fieldName, model.station.StationId)
            displayLabel.updateText()
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
