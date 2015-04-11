import QtQuick 1.1

Rectangle {
  id: fieldContainer

  property int minHeight: 500

  property Flickable cursorFollow: null

  property alias labelText: label.text
  property alias value: edit.text

  property int fontSize: 16
  property bool isDark: false

  property string bgColor: isDark ? "#444444" : "#666666"
  color: bgColor

  height: labelContainer.height + editContainer.height
  width: parent.width

  function getValue(){
    return value
  }
  function setValue(value){
    this.value = value
  }

  function updateCursorFollow(cursorY){
    if(cursorFollow != null){
      var scrollY = cursorFollow.contentY
      var cY = cursorY + fieldContainer.y + editContainer.y
      var offset = fontSize*2 * 2
      if (scrollY >= cY - offset){
        cursorFollow.contentY = cY - offset
      }else if (scrollY+cursorFollow.height <= cY + offset){
        cursorFollow.contentY = cY-cursorFollow.height + offset
      }
    }
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
    property int margin: 4
    property int border: 2

    height: edit.height + margin*2 + margin*2 + border*2
    width: parent.width

    color: bgColor
    Rectangle {
      id: editBorder
      color: "#FFFFFF"
      anchors.fill: parent
      border.color: "#000000"
      border.width: parent.border
      anchors.margins: editContainer.margin

      Rectangle {
        id: editMargin
        anchors.fill: parent
        anchors.margins: editContainer.margin
        TextEdit {
          id: edit
          wrapMode: TextEdit.Wrap
          width: parent.width
          height: paintedHeight < minHeight ? minHeight : paintedHeight
          font.pointSize: fontSize
          onCursorRectangleChanged: updateCursorFollow(cursorRectangle.y)
        }
      }
    }
  }
}
