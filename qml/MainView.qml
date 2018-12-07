import QtQuick 2.3

Rectangle {
  id: mainView
  anchors.fill: parent
  width: parent.width
  height: parent.height

  property string normalColor: "#aaaaaa"
  property string selectedColor: "#dddddd"

  Column{
    id: mainColumn
    height: parent.height
    width: parent.width
    Text{
      text: controller.formatLabelText()
      function updateText(){
        text = controller.formatLabelText()
      }
      id: displayLabel
      height: 60
      font.pointSize: 18
    }
    Btn {
      text: "SEARCH"
      width: parent.width
      height: 40
      onClicked: { controller.search() }
    }
    Row {
      width: parent.width
      height: 400
      spacing: 10
      Column {
        height: parent.height
        width: (parent.width - parent.spacing) * 0.50
        Text {
          id: fromLabel
          text: "FROM:"
          height: 30
          font.pointSize: 18
        }
        StationSelector{
          fieldName: "from"
          height: parent.height - fromLabel.height
          width: parent.width
        }
      }
      Column {
        height: parent.height
        width: (parent.width - parent.spacing) * 0.50
        Text {
          id: toLabel
          text: "TO:"
          height: 30
          font.pointSize: 18
        }
        StationSelector{
          fieldName: "to"
          height: parent.height - toLabel.height
          width: parent.width
        }
      }
    }
    Row{
      height: 250
      width: parent.width
      spacing: 10
      Column {
        height: parent.height
        width: (parent.width - parent.spacing) * 0.50
        Text {
          id: timeLabel
          text: "TIME:"
          height: 30
          font.pointSize: 18
        }
        TimeSelector{
          height: parent.height - timeLabel.height
          width: parent.width
        }
      }
      Column {
        height: parent.height
        width: (parent.width - parent.spacing) * 0.50
        Text {
          id: dateLabel
          text: "DATE:"
          height: 30
          font.pointSize: 18
        }
        DateSelector{
          height: parent.height - dateLabel.height
          width: parent.width
        }
      }
    }
  }
}
