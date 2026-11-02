import QtQuick
import QtQuick.Window
import QtQuick.Effects

Item {
    id: glass
    required property Item background
    property real sampleX: 0
    property real sampleY: 0
    property real uiScale: 1
    property bool dark: false
    property real radius: 22 * uiScale
    readonly property real padding: 22 * uiScale
    readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software
    ShaderEffectSource {
        id: raw
        x: -glass.padding; y: -glass.padding
        width: glass.width+2*glass.padding; height: glass.height+2*glass.padding
        sourceItem: glass.background
        sourceRect: Qt.rect(glass.sampleX+x,glass.sampleY+y,width,height)
        textureSize: Qt.size(Math.max(1,Math.ceil(width*Screen.devicePixelRatio/2)),Math.max(1,Math.ceil(height*Screen.devicePixelRatio/2)))
        visible: false; live: true; smooth: true; hideSource: false
    }
    MultiEffect {
        id: blur
        objectName: "textFrostedEffect"
        source: raw; width: raw.width; height: raw.height
        visible: false; autoPaddingEnabled: false
        blurEnabled: true; blurMax: 48; blur: 0.9
    }
    ShaderEffectSource {
        id: blurTexture
        sourceItem: blur; visible: false; live: true; smooth: true
        textureSize: raw.textureSize
    }
    ShaderEffect {
        objectName: "liquidGlassMaterial"
        visible: !glass.software
        x: -glass.padding; y: -glass.padding
        width: raw.width; height: raw.height
        property variant blurred: blurTexture
        property variant scene: raw
        property size panelSize: Qt.size(glass.width,glass.height)
        property real paddingWidth: glass.padding
        property real cornerRadius: glass.radius
        property real darkMode: glass.dark ? 1 : 0
        fragmentShader: "qrc:/shaders/liquidGlass.frag.qsb"
    }
    Rectangle {
        anchors.fill: parent; radius: glass.radius; visible: glass.software
        color: glass.dark ? "#df252923" : "#dfefede5"
        border.color: glass.dark ? "#407e8476" : "#aafffdf5"
    }
}
