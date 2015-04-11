import QtQuick 1.1

Rectangle {
  id: configView
  anchors.fill: parent

  ListView {
    id: configFlickable
    spacing: 3
    anchors.fill: parent

    model: configModel

    delegate: Field {
      labelText: model.config.FieldName
      descriptionText: model.config.Description
      value: model.config.Value
      isDark: index % 2 == 0
      isPassword: model.config.IsPassword

      onValueChanged: {
        controller.updateConfigFieldValue(model.config, value)
      }
    }
  }

  ScrollBar{
    flickable: configFlickable
    anchors.rightMargin: 0 - 30
  }
}
