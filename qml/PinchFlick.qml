import QtQuick 1.1

PinchArea {
    property variant flick: ""
    Component.onCompleted: {
        flick = pinch.target
        flick.transformOrigin = Item.TopLeft
        flick.contentWidth = Qt.binding(function() { return flick.implicitWidth })
        flick.contentHeight = Qt.binding(function() { return flick.implicitHeight })
        width = Qt.binding(function() { return flick.contentWidth })
        height = Qt.binding(function() { return flick.contentHeight })
    }

    onPinchFinished: flick.interactive = true
    onPinchStarted: flick.interactive = false

    onPinchUpdated: {
        if (pinch.pointCount < 2)
            return
        var maxScale = pinch.maximumScale
        var minScale = pinch.minimumScale
        var scale = Math.max(minScale, Math.min(pinch.scale * flick.scale, maxScale))
        var pinch_scale = scale / flick.scale
        flick.resizeContent(flick.implicitWidth * scale,
                                  flick.implicitHeight * scale, Qt.point(0,0))

        flick.scale = scale
    }
}
