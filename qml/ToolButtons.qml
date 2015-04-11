import QtQuick 1.1

QtObject {
  property variant pages: {
    "accountPage": ["newAccount", "update", "options"],
    "folderPage": ["back"],
    "headerPage": ["back", "more", "wayMore", "all", "config", "send", "folder"],
    "bodyPage": ["back", "attachments", "toggleHtml", "reply", "forward", "copy", "zoomIn", "zoomOut"],
    "configPage": ["back", "submit"],
    "sendPage": ["back", "sendEmail"],
  }

  function getButtonDefs(){
    return buttonDefs
  }
  function getButtonDefByName(name){
    for (var i = 0; i < buttonDefs.length; ++i){
      var buttonDef = buttonDefs[i]
      var btnName = buttonDef.name
      if(name == btnName){
        return buttonDef
      }
    }
    return null
  }
  function getButtonElemByName(name){
    return controller.findChild(toolBar, "toolbarButton-" + name)
  }

  property list<QtObject> buttonDefs: [
    QtObject {
      signal clicked
      property variant name: "back"
      property variant text: "back"
      onClicked: main.backPage()
    },
    QtObject {
      signal clicked
      property variant name: "config"
      property variant text: "config"
      onClicked: {
        controller.setConfigMode("account")
        navToPage(configPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "newAccount"
      property variant text: "new acc"
      onClicked: {
        controller.setConfigMode("account")
        navToPage(configPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "options"
      property variant text: "options"
      onClicked: {
        controller.setConfigMode("options")
        navToPage(configPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "send"
      property variant text: "write"
      onClicked: navToPage(sendPage)
    },
    QtObject {
      signal clicked
      property variant name: "reply"
      property variant text: "reply"
      onClicked: {
        controller.initSend("reply", sendView.getForm(), notifier)
        navToPage(sendPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "forward"
      property variant text: "forward"
      onClicked: {
        controller.initSend("forward", sendView.getForm(), notifier)
        navToPage(sendPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "sendEmail"
      property variant text: "send"
      onClicked: controller.sendEmail(sendView.getForm(), notifier)
    },
    QtObject {
      signal clicked
      property variant name: "update"
      property variant text: "update"
      onClicked: accountView.updateAllAccounts()
    },
    QtObject {
      signal clicked
      property variant name: "submit"
      property variant text: "submit"
      onClicked: {
        if(controller.saveConfig(notifier)){
          main.backPage()
        }
      }
    },
    QtObject {
      signal clicked
      property variant name: "more"
      property variant text: "more"
      onClicked: controller.moreHeaders(headerView, 0)
    },
    QtObject {
      signal clicked
      property variant name: "wayMore"
      property variant text: "+30%"
      onClicked: controller.moreHeaders(headerView, 30)
    },
    QtObject {
      signal clicked
      property variant name: "all"
      property variant text: "all"
      onClicked: controller.moreHeaders(headerView, 100)
    },
    QtObject {
      signal clicked
      property variant name: "folder"
      property variant text: "folders"
      onClicked: navToPage(folderPage)
    },
    QtObject {
      signal clicked
      property variant name: "toggleHtml"
      property variant text: "html"
      function setIsHtml(isHtml){
        var btnElem = getButtonElemByName(name)
        btnElem.setText(isHtml ? "text" : "html")
      }
      onClicked: {
        var wasHtml = controller.getHtmlMode()
        controller.setHtmlMode(!wasHtml)
        setIsHtml(!wasHtml)
        controller.fetchCurrentBodyText(notifier, bodyView, bodyView, null)
      }
    },
    QtObject {
      signal clicked
      property variant name: "copy"
      property variant text: "copy"
      onClicked: controller.copyBodyToClipboard(notifier)
    },
    QtObject {
      signal clicked
      property variant name: "zoomIn"
      property variant text: "zoom in"
      onClicked: bodyView.zoomIn()
    },
    QtObject {
      signal clicked
      property variant name: "zoomOut"
      property variant text: "zoom out"
      onClicked: bodyView.zoomOut()
    },
    QtObject {
      signal clicked
      property variant name: "attachments"
      property variant text: "attach"
      onClicked: controller.saveCurrentAttachments(notifier)
    }
  ]
}

