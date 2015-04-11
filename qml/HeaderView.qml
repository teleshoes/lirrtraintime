import QtQuick 1.1

Rectangle {
  anchors.fill: parent

  function setCounterText(text){
    counterTextArea.text = text
  }

  function resetFilterButtons(){
    unreadFilterButton.checked = false
  }

  Rectangle {
    id: counterBox
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: 30
    y: 0 - 30
    z: 10

    Text {
      id: counterTextArea
      anchors.margins: 5
      anchors.right: parent.right
      font.pointSize: 12
    }
  }

  Rectangle {
    id: filterBox
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: headerFlickable.top
    width: parent.width
    height: searchBox.height + filterToggleBox.height
    z: 10

    Column {
      anchors.fill: parent
      Row {
        id: filterToggleBox
        width: parent.width
        height: 30
        Btn {
          id: unreadFilterButton
          height: parent.height
          width: parent.width * 0.20

          property bool checked: false
          text: checked ? "=>read+unread" : "=>unread only"

          onCheckedChanged: {
            controller.setUnreadFilter(checked ? "unread-only" : "all")
          }
          onClicked: {
            checked = !checked
          }
        }
      }
      Rectangle {
        id: searchBox
        width: parent.width
        height: 30
        border.width: 2

        TextInput {
          anchors.margins: 2
          id: searchTextBox
          anchors.fill: parent
          font.pointSize: 18
          onTextChanged: {
            controller.onSearchTextChanged(searchTextBox.text)
          }
        }
      }
    }
  }

  ListView {
    id: headerFlickable
    anchors.bottom: parent.bottom
    anchors.top: filterBox.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: parent.height - filterBox.height

    spacing: 10
    model: headerModel
    delegate: Component  {
      Rectangle {
        color: "#AAAAAA"
        height: 125
        width: parent.width
        MouseArea {
          anchors.fill: parent
          onClicked: {
            controller.headerSelected(model.header)
            navToPage(bodyPage)
          }
        }
        Rectangle {
          id: readIndicator
          height: parent.height
          width: parent.width * 0.15
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          color: getColor()
          function getColor(){
            if(model.header.IsLoading){
              return "#FF0000";
            }else{
              return model.header.Read ? "#E1D6A1" : "#666666"
            }
          }
          function updateColor(){
            this.color = getColor()
          }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              controller.toggleRead(readIndicator, model.header)
            }
          }
        }
        Column {
          id: col
          anchors.fill: parent
          Text {
            text: model.header.IsSent ? "=>" + model.header.To : model.header.From
            font.pointSize: 24
          }
          Text {
            text: model.header.Date
            font.pointSize: 20
          }
          Text {
            text: model.header.Subject
            font.pointSize: 16
          }
        }
      }
    }
    clip: true
  }

  ScrollBar{
    flickable: headerFlickable
    anchors.rightMargin: -30
  }
}
