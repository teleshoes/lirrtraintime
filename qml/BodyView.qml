import QtQuick 1.1

Rectangle {
  anchors.fill: parent
  id: bodyView
  function setHeader(header){
    headerText.text = header
  }
  function setBody(body){
    bodyText.text = body
  }

  property variant scales: [0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 5, 10]

  function zoomIn(){
    setZoom(getNextScale("in"))
  }
  function zoomOut(){
    setZoom(getNextScale("out"))
  }
  function getNextScale(dir){
    var curScale = bodyFlickable.scale
    for(var i=0; i<scales.length; ++i){
      var scale
      if(dir == "in"){
        scale = scales[i]
      }else if(dir == "out"){
        scale = scales[scales.length - i]
      }
      console.log(scale)
      if(dir == "in" && curScale < scale){
        return scale
      }else if(dir == "out" && curScale > scale){
        return scale
      }
    }
    if(dir == "in"){
      return scales[scales.length - 1]
    }else if(dir == "out"){
      return scales[0]
    }
  }
  function setZoom(scale){
    zoomDisplay.text = parseInt(scale*100) + "%"
    zoomDisplay.visible = scale != 1
    bodyFlickable.scale = scale
  }

  PinchFlick{
    anchors.fill: parent
    pinch.minimumScale: 0.1
    pinch.maximumScale: 10
    pinch.target: bodyFlickable
  }

  Flickable {
    id: bodyFlickable
    contentWidth: parent.width
    contentHeight: headerText.paintedHeight + bodyText.paintedHeight
    anchors.fill: parent
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    boundsBehavior: Flickable.DragOverBounds
    Rectangle{
      width: parent.width
      height: parent.height
      color: "#FFFFFF"
      Text {
        id: headerText
        color: "#0000FF"
        width: parent.width
        wrapMode: Text.Wrap
        font.pointSize: 18
      }
      Text {
        id: bodyText
        anchors.top: headerText.bottom
        height: parent.height
        width: parent.width
        wrapMode: Text.Wrap
        font.pointSize: 24
        onLinkActivated: main.onLinkActivated(link)
      }
    }
  }

  Text {
    id: zoomDisplay
    visible: false
    anchors.top: parent.top
    anchors.right: parent.right
  }

  ScrollBar{
    flickable: bodyFlickable
    anchors.rightMargin: 0 - 30
  }
}
