import QtQuick
import QtQuick.Window

Window {
    id: lyricsWindow
    objectName: "desktopLyricsWindow"
    required property var backend
    readonly property var lyricState: backend ? backend.desktopLyrics : ({})
    readonly property bool locked: lyricState.locked === true
    readonly property color backingTint: lyricState.backgroundColor || "#f5f0e4"
    property real requestedX: -99999
    property real requestedY: -99999
    property bool ready: false
    transientParent: null
    title: "RHINE · 桌面歌词"
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | (locked ? Qt.WindowTransparentForInput : 0)
    visible: ready && lyricState.enabled === true
    width: lyricState.width || 800
    height: Math.max(132, lyricColumn.implicitHeight + 72)
    function positionFromSettings() {
        if (requestedX !== lyricState.x || requestedY !== lyricState.y) {
            requestedX = lyricState.x;
            requestedY = lyricState.y;
            x = lyricState.x || 0;
            y = lyricState.y || 0;
        }
    }
    Component.onCompleted: {
        backend.setDesktopWindow(lyricsWindow);
        positionFromSettings();
        ready = true;
    }
    onClosing: function(close) {
        close.accepted = false;
        backend.saveDesktopPosition(x, y);
        backend.action("desktop:close");
    }
    Connections {
        target: lyricsWindow.backend
        function onDesktopLyricsChanged() { lyricsWindow.positionFromSettings(); }
    }
    HoverHandler { id: hover; enabled: !lyricsWindow.locked }
    Rectangle {
        id: backing
        objectName: "desktopLyricsBacking"
        anchors.fill: parent
        anchors.margins: 6
        radius: 12
        color: Qt.rgba(lyricsWindow.backingTint.r, lyricsWindow.backingTint.g, lyricsWindow.backingTint.b,
            (lyricsWindow.lyricState.backgroundOpacity === undefined ? 65 : lyricsWindow.lyricState.backgroundOpacity) / 100)
        border.color: "#80fffdf4"
        opacity: hover.hovered && !lyricsWindow.locked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: lyricsWindow.lyricState.reduced ? 0 : 180 } }
    }
    MouseArea {
        id: dragArea
        objectName: "desktopLyricsDrag"
        anchors.fill: parent
        enabled: !lyricsWindow.locked
        cursorShape: Qt.SizeAllCursor
        property point pressPoint
        property point windowPoint
        onPressed: function(mouse) {
            pressPoint = Qt.point(mouse.x, mouse.y);
            windowPoint = Qt.point(lyricsWindow.x, lyricsWindow.y);
        }
        onPositionChanged: function(mouse) {
            if (pressed) {
                lyricsWindow.x += mouse.x - pressPoint.x;
                lyricsWindow.y += mouse.y - pressPoint.y;
            }
        }
        onReleased: lyricsWindow.backend.saveDesktopPosition(lyricsWindow.x, lyricsWindow.y)
        onCanceled: lyricsWindow.backend.saveDesktopPosition(lyricsWindow.x, lyricsWindow.y)
    }
    Row {
        id: toolbar
        objectName: "desktopLyricsToolbar"
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 20
        spacing: 10
        opacity: backing.opacity
        visible: opacity > 0
        enabled: !lyricsWindow.locked && hover.hovered
        Repeater {
            model: [{label: "锁定", action: "desktop:lock"}, {label: "Aa", action: "desktop:font"}, {label: "关闭", action: "desktop:close"}]
            delegate: Rectangle {
                required property var modelData
                width: 44
                height: 26
                radius: 5
                color: toolMouse.containsMouse ? "#18747857" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: "#60654f"
                    font.family: "Rhine MiSans"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: toolMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        lyricsWindow.backend.saveDesktopPosition(lyricsWindow.x, lyricsWindow.y);
                        lyricsWindow.backend.action(modelData.action);
                    }
                }
            }
        }
    }
    Column {
        id: lyricColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.top: parent.top
        anchors.topMargin: 46
        spacing: 9
        Text {
            id: currentLine
            objectName: "desktopLyricsPrimary"
            width: parent.width
            text: lyricsWindow.lyricState.primary || "选择歌曲开始播放"
            textFormat: Text.PlainText
            color: (backing.opacity > 0.5 ? (lyricsWindow.lyricState.hoverPrimaryColor || lyricsWindow.lyricState.primaryColor) : lyricsWindow.lyricState.primaryColor) || Qt.tint("#faf9ee", Qt.rgba(0.18, 0.20, 0.15, backing.opacity))
            font.family: !lyricsWindow.lyricState.font || lyricsWindow.lyricState.font === "MiSans" ? "Rhine MiSans" : lyricsWindow.lyricState.font
            font.pixelSize: lyricsWindow.lyricState.size || 26
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize * 1.35
            style: Text.Normal
            onTextChanged: if (!lyricsWindow.lyricState.reduced) { lineFade.restart(); }
            NumberAnimation { id: lineFade; target: currentLine; property: "opacity"; from: 0.45; to: 1; duration: 180 }
        }
        Text {
            objectName: "desktopLyricsSecondary"
            width: parent.width
            text: lyricsWindow.lyricState.secondary || ""
            textFormat: Text.PlainText
            color: (backing.opacity > 0.5 ? (lyricsWindow.lyricState.hoverSecondaryColor || lyricsWindow.lyricState.secondaryColor) : lyricsWindow.lyricState.secondaryColor) || Qt.tint("#dfdfcf", Qt.rgba(0.39, 0.42, 0.29, backing.opacity))
            font.family: !lyricsWindow.lyricState.font || lyricsWindow.lyricState.font === "MiSans" ? "Rhine MiSans" : lyricsWindow.lyricState.font
            font.pixelSize: (lyricsWindow.lyricState.size || 26) * 0.78
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize * 1.4
            elide: Text.ElideRight
            style: Text.Normal
        }
    }
}
