import QtQuick 1.1

Rectangle {
  anchors.fill: parent

  function updateAllAccounts(){
    controller.updateAccount(null, messageBox, null)
  }

  function initAccountConfig(){
    var preferHtmlCfg = controller.getAccountConfigValue("preferHtml")
    var isHtml = preferHtmlCfg != "false"
    toolButtons.getButtonDefByName("toggleHtml").setIsHtml(isHtml)
    headerView.resetFilterButtons()
    controller.setHtmlMode(isHtml)
  }

  ListView {
    id: accountFlickable
    spacing: 15
    width: parent.width
    height: parent.height * 0.70
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: messageBox.top
    model: accountModel
    delegate: Component  {
      Rectangle {
        height: 100
        width: parent.width
        color: "gray"
        MouseArea{
          anchors.fill: parent
          onClicked: {
            controller.accountSelected(model.account)
            initAccountConfig()
            navToPage(headerPage)
          }
        }
        Rectangle {
          id: updateIndicator
          height: parent.height
          width: parent.width * 0.15
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          color: getColor()
          function getColor(){
            if(model.account.IsLoading){
              return "#FF0000";
            }else{
              return "#666666"
            }
          }
          function updateColor(){
            this.color = getColor()
          }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              controller.updateAccount(updateIndicator, messageBox, model.account)
            }
          }
        }
        Text {
          anchors.left: parent.left
          anchors.margins: 2
          text: model.account.Name + ": " + model.account.Unread
          font.pointSize: 32
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: parent.width * 0.15
          text: model.account.LastUpdatedRel
          font.pointSize: 24
        }
        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          text: model.account.Error
          font.pointSize: 24
        }
      }
    }
  }

  Rectangle{
    id: messageBox
    color: "#FFFFFF"
    border.color: "#000000"
    border.width: 2
    anchors.bottom: parent.bottom
    width: parent.width
    height: parent.height * 0.30
    clip: true

    function append(text) {
      messageBoxTextArea.text = messageBoxTextArea.text + text
    }
    function setText(text) {
       messageBoxTextArea.text = text
    }
    function scrollToBottom() {
      messageBoxFlickable.contentY = messageBoxTextArea.height - messageBoxFlickable.height
    }

    Flickable {
      id: messageBoxFlickable
      anchors.fill: parent
      contentWidth: messageBoxTextArea.paintedWidth
      contentHeight: messageBoxTextArea.paintedHeight
      flickableDirection: Flickable.HorizontalAndVerticalFlick
      boundsBehavior: Flickable.DragOverBounds
      Text {
        anchors.fill: parent
        id: messageBoxTextArea
        text: "CONSOLE OUTPUT\n"
      }
    }
  }

  ScrollBar {
    flickable: accountFlickable
    anchors.rightMargin: -30
  }
}
