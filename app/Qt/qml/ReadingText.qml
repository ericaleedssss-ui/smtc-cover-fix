import QtQuick

Flickable {
    id: reading
    objectName: "detailReadingText"
    property var hudState: rhine.state
    property int wheelEvents: 0
    property real lastWheelY: 0
    property string session: hudState.readerSession || ""
    readonly property real unit: height / Math.max(1, hudState.readerBounds ? hudState.readerBounds.height : 100)
    onSessionChanged: contentY = 0
    function navigateKey(key) {
        var step = key === "ArrowDown" ? 1 : key === "ArrowUp" ? -1 : 0;
        if (step) { reading.cancelFlick(); reading.contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), contentY + step * reading.hudState.readerLeading * reading.unit * 2)); }
    }
    clip: true
    contentWidth: width
    contentHeight: copy.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    // 显式接收当前阅读区的滚轮，避免跨页面复用 Flickable 时沿用旧滚动目标。
    WheelHandler {
        target: null
        onWheel: function(event) {
            reading.cancelFlick();
            var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * reading.hudState.readerLeading * reading.unit * 3;
            reading.contentY = Math.max(0, Math.min(Math.max(0, reading.contentHeight - reading.height), reading.contentY - delta));
            reading.wheelEvents += 1;
            reading.lastWheelY = reading.contentY;
            event.accepted = true;
        }
    }
    Text {
        id: copy
        width: reading.width
        text: reading.hudState.readerText || ""
        textFormat: Text.PlainText
        color: reading.hudState.dark ? "#eeeeE6" : "#181c17"
        font.family: rhineFontFamily
        font.pixelSize: reading.hudState.readerFont * reading.unit
        lineHeightMode: Text.FixedHeight
        lineHeight: reading.hudState.readerLeading * reading.unit
        wrapMode: Text.Wrap
    }
}
