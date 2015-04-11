import QtQuick 1.1

Rectangle {
  height: isExpanded ? 500 : labelContainer.height
  width: parent.width

  property alias labelText: label.text
  property bool isDark: false

  property bool isExpanded: false

  color: isDark ? "#444444" : "#666666"

  function getFiles(){
    var files = []
    for(var i=0; i<fileListView.model.count; i++){
      files.push(fileListView.model.get(i)['file'])
    }
    return files
  }
  function setFiles(files){
    clearFiles()
    for(var i=0; i<files.length; i++){
      addFile(files[i])
    }
  }

  function addFile(file){
    fileListView.model.append({'file': file})
  }
  function clearFiles(){
    fileListView.model.clear()
  }


  Row {
    width: parent.width
    height: 40
    id: labelContainer
    Text {
      id: label
      height: parent.height
      font.pointSize: 20
      font.weight: Font.DemiBold
    }
    Btn {
      height: parent.height
      anchors.right: parent.right
      anchors.rightMargin: 20
      width: 100
      text: isExpanded ? "hide" : "show"
      onClicked: {
        isExpanded = !isExpanded
      }
    }
  }

  Column {
    id: leftColumn
    visible: isExpanded
    width: parent.width * 0.5
    height: parent.height - labelContainer.height
    anchors.top: labelContainer.bottom
    anchors.left: parent.left

    FileBrowser {
      id: fileBrowser
      height: parent.height
      width: parent.width
    }
  }
  Column {
    id: rightColumn
    visible: isExpanded
    width: parent.width * 0.5
    height: parent.height - labelContainer.height
    anchors.left: leftColumn.right
    anchors.top: labelContainer.bottom

    Rectangle {
      id: addContainer
      width: parent.width
      height: 50
      Btn {
        width: parent.width - 20
        height: parent.height
        anchors.centerIn: parent
        text: "attach selected file"
        onClicked: {
          if(fileBrowser.value){
            addFile(fileBrowser.value)
            fileBrowser.clear()
          }
        }
      }
    }
    Rectangle {
      width: parent.width
      height: 30
      Text {
        id: countDisplay
        text: fileListView.model.count + " file(s) attached"
        font.italic: true
      }
    }
    Rectangle {
      id: fileListContainer
      width: parent.width
      height: parent.height - countDisplay.height - addContainer.height

      clip: true
      anchors.margins: 2
      border.width: 1
      border.color: "white"

      ListView {
        id: fileListView
        anchors.fill: parent
        anchors.margins: 5
        model: ListModel {}
        clip: true

        spacing: 8
        delegate: Rectangle {
          height: fileListLabel.height
          width: parent.width
          color: "#E1D6A1"
          border.width: 2
          Text {
            id: fileListLabel
            width: parent.width * 0.90
            text: model['file']
            font.pointSize: 16
          }
          Btn {
            anchors {left: fileListLabel.right}
            height: fileListLabel.height
            width: parent.width * 0.10
            text: "x"
            onClicked: {
              fileListView.model.remove(index)
            }
          }
        }
      }
    }
  }
}
