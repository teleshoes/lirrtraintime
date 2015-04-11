import QtQuick 1.1

Rectangle {
  color: parent.color
  property variant fs: fileSystemController

  property string value: ""

  Row{
    id: buttonContainer
    height: 50
    width: parent.width
    anchors {top: parent.top; left: parent.left; right: parent.right}
    Btn {
      text: "home"
      width: parent.width * 1/buttonContainer.children.length
      height: 50
      onClicked: setFileSelectedByPath(fs.getHome())
    }
    Btn {
      text: "root"
      width: parent.width * 1/buttonContainer.children.length
      height: 50
      onClicked: setFileSelectedByPath("/")
    }
    Btn {
      text: "up"
      width: parent.width * 1/buttonContainer.children.length
      height: 50
      onClicked: up()
    }
    Btn {
      text: "clear"
      width: parent.width * 1/buttonContainer.children.length
      height: 50
      onClicked: clear()
    }
  }

  Rectangle {
    id: valueContainer
    height: 30
    width: parent.width
    anchors {top: buttonContainer.bottom; left: parent.left; right: parent.right}
    clip: true
    Text {
      text: "SELECTED: " + value
      anchors.centerIn: parent
    }
  }

  ListView {
    id: listView
    height: parent.height - valueContainer.height - buttonContainer.height
    width: parent.width
    anchors {top: valueContainer.bottom; left: parent.left; right: parent.right}
    model: treeModel
    focus: true
    clip: true
  }
  ScrollBar {
    flickable: listView
  }

  function setFileSelected(modelIndex){
    checkDirModel()
    if(modelIndex == null){
      value = ""
      treeModel.rootIndex = 0
      listView.currentIndex = -1
    }else{
      value = fs.getFilePath(modelIndex)
      if (fs.isDir(modelIndex)) {
        treeModel.rootIndex = modelIndex
        listView.currentIndex = -1;
      }
    }
  }
  function checkDirModel(){
    if(fs.checkDirModelFucked()){
      treeModel.model = fs.getDirModel()
      setFileSelectedByPath("/")
      clear()
    }
  }

  function clear(){
    checkDirModel()
    setFileSelected(null)
  }

  function up(){
    var modelIndex = treeModel.parentModelIndex()
    if(modelIndex){
      setFileSelected(modelIndex)
    }
  }

  function setFileSelectedByPath(path){
    var modelIndex = fs.getModelIndex(path)
    setFileSelected(modelIndex)
  }


  VisualDataModel {
    id: treeModel
    model: fs.getDirModel()

    Rectangle {
      id: fileContainer
      width: parent.width - 30
      height: 30
      color: listView.currentIndex == index ? "#DDDDDD" : "#FFFFFF"
      border.width: 1
      focus: true

      Text {
        width: parent.width - 10
        height: parent.height
        anchors.centerIn: parent

        property bool isDir: fs.isDir(treeModel.modelIndex(index))
        font.weight: isDir ? Font.DemiBold : Font.Normal
        text: fileName
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          select()
        }
      }

      function select(){
        moveCursor(index)
        setFileSelected(treeModel.modelIndex(index))
      }

      function moveCursor(targetIndex){
        if(targetIndex >= 0 && targetIndex < listView.count){
          listView.currentIndex = targetIndex
        }
      }

      Keys.onReturnPressed: {
        select();
      }
      Keys.onRightPressed: {
        select();
      }
      Keys.onLeftPressed: {
        up();
      }
      Keys.onUpPressed: {
        moveCursor(index-1)
      }
      Keys.onDownPressed: {
        moveCursor(index+1)
      }
    }
  }
}
