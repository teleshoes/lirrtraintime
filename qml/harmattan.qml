import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
  id: main
  initialPage: mainPage

  // ACCOUNT PAGE
  Page {
    id: mainPage
    objectName: "mainPage"
    anchors.margins: 30

    MainView{}
  }

  // HACK TO HIDE KEYBOARD
  function hideKb(){
    hideKbDummyEdit.closeSoftwareInputPanel()
  }
  TextEdit {
    id: hideKbDummyEdit
    width: 0
    height: 0
  }
  // HACK TO HIDE KEYBOARD
}
