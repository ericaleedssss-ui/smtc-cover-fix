import QtQuick
import QtQuick.Window
import QtQuick.Effects

// Shared right-drawer material. Only the bounded background is sampled.
Item {
    id: frost
    required property Item background
    property real sampleX: 0
    property real sampleY: 0
    property real unit: 1
    property real radius: 20*unit
    property bool dark: false
    readonly property bool software: GraphicsInfo.api===GraphicsInfo.Software
    function refresh() { sample.scheduleUpdate(); }
    Component.onCompleted: refresh()
    onSampleXChanged: refresh()
    onSampleYChanged: refresh()
    onWidthChanged: refresh()
    onHeightChanged: refresh()
    ShaderEffectSource {
        id: sample
        sourceItem: frost.background
        sourceRect: Qt.rect(frost.sampleX,frost.sampleY,frost.width,frost.height)
        textureSize: Qt.size(Math.max(1,Math.ceil(frost.width/2)),Math.max(1,Math.ceil(frost.height/2)))
        live: false; hideSource: false; visible: false
    }
    Rectangle {id:mask;anchors.fill:parent;radius:frost.radius;visible:false;layer.enabled:!frost.software}
    MultiEffect {anchors.fill:parent;source:sample;blurEnabled:true;blurMax:32;blur:1;autoPaddingEnabled:false;maskEnabled:true;maskSource:mask;visible:!frost.software}
    Rectangle {
        objectName:"drawerFrostTint"
        anchors.fill:parent;radius:frost.radius
        color:frost.dark?"#ef30352d":"#ebece8de"
        border.width:1;border.color:frost.dark?"#507f8676":"#80fffef5"
        layer.enabled:!frost.software
        layer.effect:MultiEffect {shadowEnabled:true;shadowOpacity:.12;shadowBlur:.65;shadowVerticalOffset:4;shadowColor:"#252b20"}
    }
}
