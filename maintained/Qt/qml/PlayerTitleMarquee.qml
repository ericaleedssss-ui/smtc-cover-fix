import QtQuick

// Back-and-forth title pan with no wrap-around, plus a live edge blur/fade.
// Long titles pause at each endpoint and reverse along the same text.
Item {
    id: viewport
    objectName: "playerTitleViewport"
    property string value: ""
    property real unit: 1
    readonly property real panDistance: Math.max(0, songLabel.implicitWidth - width + 2 * unit)
    readonly property bool overflows: panDistance > 4 * unit
    property real shift: 0
    clip: true

    Item {
        id: textSurface
        anchors.fill: parent
        clip: true
        Text {
            id: songLabel
            objectName: "playerMarqueeText"
            x: viewport.shift
            anchors.verticalCenter: parent.verticalCenter
            text: viewport.value
            textFormat: Text.PlainText
            font.family: rhineFontFamily
            font.pixelSize: 19 * viewport.unit
            font.weight: Font.DemiBold
            color: rhine.state.dark ? "#ecede5" : "#222821"
            renderType: Text.QtRendering
        }
    }
    ShaderEffectSource {
        id: sourceTexture
        sourceItem: textSurface
        hideSource: true
        visible: false
        live: true
        smooth: true
    }
    ShaderEffect {
        objectName: "playerTitleEdgeFade"
        anchors.fill: parent
        property variant source: sourceTexture
        property size panelSize: Qt.size(width, height)
        property real horizontal: 1
        property real fadePx: 19 * viewport.unit
        property real fadeStart: viewport.shift < -1 ? 1 : 0
        property real fadeEnd: (songLabel.implicitWidth + viewport.shift) > viewport.width + 1 ? 1 : 0
        property real blurStrength: 1.15 * viewport.unit
        fragmentShader: "qrc:/shaders/softEdgeFade.frag.qsb"
    }
    SequentialAnimation {
        id: pan
        objectName: "titlePingPongAnimation"
        running: viewport.overflows && !rhine.state.reduced
        loops: Animation.Infinite
        onRunningChanged: {
            // Stopping the animation (for example when reduced motion is enabled)
            // must not leave the title stranded at an intermediate offset.
            if (!running) viewport.shift = 0
        }
        PauseAnimation { duration: 1300 }
        NumberAnimation {
            target: viewport
            property: "shift"
            from: 0
            to: -viewport.panDistance
            duration: Math.max(2300, viewport.panDistance * 20)
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 1450 }
        NumberAnimation {
            target: viewport
            property: "shift"
            from: -viewport.panDistance
            to: 0
            duration: Math.max(2300, viewport.panDistance * 20)
            easing.type: Easing.InOutSine
        }
    }
    onValueChanged: {
        shift = 0
        if (overflows && !rhine.state.reduced) pan.restart()
    }
    onOverflowsChanged: {
        if (!overflows) shift = 0
    }
}
