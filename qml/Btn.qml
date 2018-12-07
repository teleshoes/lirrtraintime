import QtQuick 2.3

Rectangle {
  id: button
  width: 100
  height: 120
  signal clicked()
  property string imgSource: ""
  property string text: ""

  border.color: "black"
  border.width: 5
  property variant hover: false
  property variant buttonColorDefault: "gray"
  property variant buttonColorGradient: "white"
  property variant buttonColor: buttonColorDefault
  MouseArea {
    hoverEnabled: true
    anchors.fill: parent
    onClicked: button.clicked()
    function setColor(){
      if(this.pressed){
        parent.buttonColor = Qt.lighter(parent.buttonColorDefault)
      }else if(this.containsMouse){
        parent.buttonColor = Qt.darker(parent.buttonColorDefault)
      }else{
        parent.buttonColor = parent.buttonColorDefault
      }
    }
    onEntered: setColor()
    onExited: setColor()
    onPressed: setColor()
    onReleased: setColor()
  }
  gradient: Gradient {
    GradientStop { position: 0.0; color: buttonColor }
    GradientStop { position: 1.0; color: buttonColorGradient }
  }

  Text {
    text: button.text
    font.pointSize: 16
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
  }
  Image {
    source: button.imgSource
    anchors.fill: parent
    anchors.topMargin: 10
    anchors.bottomMargin: 30
    anchors.leftMargin: 10
    anchors.rightMargin: 10
  }
}

