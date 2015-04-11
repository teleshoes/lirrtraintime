import QtQuick 1.1

Rectangle {
  signal enterPressed

  property alias labelText: label.text
  property alias value: edit.text

  property int fontSize: 16
  property bool isDark: false

  property string bgColor: isDark ? "#444444" : "#666666"
  color: bgColor

  width: parent.width
  height: labelContainer.height + editContainer.height

  function getValue(){
    return value
  }
  function setValue(value){
    this.value = value
    edit.cursorPosition = 0
  }

  Rectangle {
    id: labelContainer
    width: parent.width
    height: fontSize * 2
    color: bgColor
    anchors.margins: 2

    Text {
      id: label
      anchors.fill: parent
      font.pointSize: fontSize
      font.capitalization: Font.AllUppercase
      font.weight: Font.DemiBold
    }
  }

  Rectangle {
    id: editContainer
    anchors.top: labelContainer.bottom
    width: parent.width
    height: fontSize * 2 + 4
    color: bgColor
    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 8
      height: parent.height - 4
      color: "#FFFFFF"
      border.color: "#000000"
      border.width: 2

      TextInput {
        anchors.margins: 3
        id: edit
        anchors.fill: parent
        font.pointSize: fontSize
        Keys.onReturnPressed: {
          enterPressed()
        }
      }
    }
  }
}
