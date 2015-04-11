import QtQuick 1.1

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
      function setText(newText){
        text = newText
      }
      id: displayLabel
      height: 50
      text: "<select to/from>"
    }
    Text {
      text: "FROM:"
      height: 20
    }
    StationSelector{
      fieldName: "from"
      height: 100
      width: parent.width
    }
    Text {
      text: "TO:"
      height: 20
    }
    StationSelector{
      fieldName: "to"
      height: 100
      width: parent.width
    }
    Text {
      text: "TIME:"
      height: 20
    }
    TimeSelector{
      height: 100
      width: parent.width
    }
    Text {
      text: "DATE:"
      height: 20
    }
    DateSelector{
      height: 100
      width: parent.width
    }
    Btn {
      text: "SEARCH"
      onClicked: { controller.search() }
    }
  }
}
