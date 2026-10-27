import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// G62: A real, scrollable queue rather than native text/lines/button positions.
// The same row owns its title, artist, divider, hover focus and actions.
Item {
    id: queue
    objectName: "playerQueueGlass"
    required property Item background
    property real sampleX: 0
    property real sampleY: 0
    property real unit: 1
    readonly property var hud: rhine.state
    // The HUD may refresh every frame. Never rebind ListView to that fresh
    // JSON array: keep a stable, capped ListModel until content really changes.
    property var incomingRows: hud.queueRows || []
    property string syncedRows: ""
    readonly property int pageStart: Number(hud.queueOffset || 0)
    readonly property int pageSize: Number(hud.queuePageSize || 40)
    ListModel { id: stableQueueRows }
    function syncRows() {
        var rows = incomingRows || [];
        var signature = JSON.stringify(rows);
        if (signature === syncedRows) return;
        syncedRows = signature;
        stableQueueRows.clear();
        for (var i = 0; i < rows.length; ++i) {
            var song = rows[i] || {};
            stableQueueRows.append({
                trackTitle: String(song.title || "未知歌曲"),
                trackArtist: String(song.artist || ""),
                trackIndex: Number(song.index),
                trackId: String(song.id || "")
            });
        }
        if (songList) songList.positionViewAtBeginning();
    }
    onIncomingRowsChanged: syncRows()
    Component.onCompleted: syncRows()
    readonly property color ink: hud.dark ? "#eef2e9" : "#282d27"
    readonly property color muted: hud.dark ? "#a4ada1" : "#747d72"
    readonly property color accent: hud.dark ? "#b7ceab" : "#6f8968"
    readonly property color stroke: hud.dark ? "#447d8776" : "#70828c7c"

    LiquidGlass {
        anchors.fill: parent
        background: queue.background
        sampleX: queue.sampleX
        sampleY: queue.sampleY
        uiScale: queue.unit
        radius: 27 * queue.unit
        dark: queue.hud.dark === true
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    Text {
        x: 25 * queue.unit; y: 23 * queue.unit
        text: "播放队列"
        font.family: rhineFontFamily
        font.pixelSize: 24 * queue.unit
        font.weight: Font.DemiBold
        color: queue.ink
    }

    Rectangle {
        x: parent.width - 57 * queue.unit
        y: 18 * queue.unit; width: 38 * queue.unit; height: 38 * queue.unit
        radius: height / 2
        color: closeMouse.containsMouse
            ? (queue.hud.dark ? "#4267775e" : "#5ba4ad91")
            : "transparent"
        Text {
            anchors.centerIn: parent
            text: "×"; color: queue.ink
            font.pixelSize: 27 * queue.unit
        }
        MouseArea {
            id: closeMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rhine.action("close-modal")
        }
    }

    Text {
        x: 27 * queue.unit; y: 97 * queue.unit
        width: parent.width - 54 * queue.unit
        text: String(queue.hud.queueCurrentTitle || "尚未播放")
        elide: Text.ElideRight
        color: queue.ink
        font.family: rhineFontFamily
        font.pixelSize: 18 * queue.unit; font.weight: Font.DemiBold
    }
    Text {
        x: 27 * queue.unit; y: 127 * queue.unit
        width: parent.width - 54 * queue.unit
        text: String(queue.hud.queueCurrentArtist || "")
        elide: Text.ElideRight
        color: queue.muted
        font.family: rhineFontFamily
        font.pixelSize: 13 * queue.unit
    }
    Rectangle {
        x: 26 * queue.unit; y: 166 * queue.unit
        width: parent.width - 52 * queue.unit
        height: Math.max(1, queue.unit)
        color: queue.stroke; opacity: .38
    }
    Text {
        x: 27 * queue.unit; y: 190 * queue.unit
        text: "QUEUE  /  " + Number(queue.hud.queueCount || 0).toLocaleString() + " 首"
        color: queue.muted; font.family: rhineFontFamily
        font.pixelSize: 12 * queue.unit; font.letterSpacing: .5 * queue.unit
    }
    Rectangle {
        x: parent.width - 132 * queue.unit; y: 180 * queue.unit
        width: 110 * queue.unit; height: 35 * queue.unit; radius: 12 * queue.unit
        color: clearMouse.containsMouse ? (queue.hud.dark ? "#2f8a947f" : "#4d9aa78f") : "transparent"
        Text {
            anchors.centerIn: parent
            text: queue.hud.queueRoaming ? "退出漫游" : "清空待播"
            color: queue.ink; font.pixelSize: 13 * queue.unit
            font.family: rhineFontFamily
        }
        MouseArea {
            id: clearMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rhine.action(queue.hud.queueRoaming ? "roam:exit" : "player:clear")
        }
    }

    ListView {
        id: songList
        objectName: "playerQueueList"
        x: 19 * queue.unit
        y: 238 * queue.unit
        width: parent.width - 38 * queue.unit
        height: Math.max(80, parent.height - 313 * queue.unit)
        clip: true
        spacing: 3 * queue.unit
        model: stableQueueRows
        cacheBuffer: 250
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1400
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 3 * queue.unit
            contentItem: Rectangle {
                radius: width / 2; color: queue.accent; opacity: .36
            }
        }
        delegate: Item {
            id: track
            required property int index
            required property string trackTitle
            required property string trackArtist
            required property int trackIndex
            readonly property bool selected: trackIndex === Number(queue.hud.queueIndex)
            width: songList.width
            height: 62 * queue.unit

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 1 * queue.unit
                anchors.rightMargin: 1 * queue.unit
                radius: 13 * queue.unit
                color: rowMouse.containsMouse
                    ? (queue.hud.dark ? "#4a9db18d" : "#6899a58d")
                    : track.selected
                      ? (queue.hud.dark ? "#338caa85" : "#3b829477")
                      : "transparent"
                Behavior on color { ColorAnimation { duration: queue.hud.reduced ? 0 : 140 } }
            }
            Rectangle {
                x: 14 * queue.unit; y: parent.height - 1.5 * queue.unit
                height: Math.max(.65, queue.unit * .65)
                width: parent.width - 29 * queue.unit
                color: queue.stroke
                opacity: .20
                visible: index < stableQueueRows.count - 1
            }
            Text {
                x: 18 * queue.unit; y: 9 * queue.unit
                width: parent.width - 132 * queue.unit
                text: track.trackTitle
                color: queue.ink; elide: Text.ElideRight
                font.family: rhineFontFamily; font.pixelSize: 15 * queue.unit
                font.weight: track.selected ? Font.DemiBold : Font.Normal
            }
            Text {
                x: 18 * queue.unit; y: 34 * queue.unit
                width: parent.width - 132 * queue.unit
                text: track.trackArtist
                color: queue.muted; elide: Text.ElideRight
                font.family: rhineFontFamily
                font.pixelSize: 11.5 * queue.unit
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rhine.action("player:queue-play:" + track.trackIndex)
            }
            Rectangle {
                x: parent.width - 92 * queue.unit; y: 12 * queue.unit
                width: 33 * queue.unit; height: 35 * queue.unit
                radius: 11 * queue.unit
                color: playMouse.containsMouse
                    ? (queue.hud.dark ? "#559ab487" : "#5990a582")
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: track.selected ? "♫" : "▶"
                    color: track.selected ? queue.accent : queue.ink
                    font.pixelSize: track.selected ? 20 * queue.unit : 16 * queue.unit
                }
                MouseArea {
                    id: playMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rhine.action("player:queue-play:" + track.trackIndex)
                }
            }
            Rectangle {
                x: parent.width - 50 * queue.unit; y: 12 * queue.unit
                width: 33 * queue.unit; height: 35 * queue.unit
                radius: 11 * queue.unit
                visible: !track.selected && !queue.hud.queueRoaming
                color: removeMouse.containsMouse
                    ? (queue.hud.dark ? "#5ea17870" : "#4eb4b09a")
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "×"; color: queue.ink
                    font.pixelSize: 20 * queue.unit
                }
                MouseArea {
                    id: removeMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rhine.action("player:remove:" + track.trackIndex)
                }
            }
        }
    }

    // Use the same soft-edge shader as the left navigation. Only the
    // visual texture is faded/softened: ListView stays the interactive source.
    ShaderEffectSource {
        id: listTexture
        sourceItem: songList
        hideSource: true
        visible: false
        live: true
        smooth: true
    }
    ShaderEffect {
        id: edgeFeather
        objectName: "playerQueueEdgeFade"
        x: songList.x; y: songList.y
        width: songList.width; height: songList.height
        property variant source: listTexture
        property size panelSize: Qt.size(width, height)
        property real horizontal: 0
        property real fadePx: 78 * queue.unit
        property real fadeStart: songList.contentY > 4 * queue.unit ? 1 : 0
        property real fadeEnd: songList.contentY + songList.height < songList.contentHeight - 4 * queue.unit ? 1 : 0
        property real blurStrength: 1.7 * queue.unit
        fragmentShader: "qrc:/shaders/softEdgeFade.frag.qsb"
    }

    Rectangle {
        x: 26 * queue.unit; y: parent.height - 63 * queue.unit
        width: parent.width - 52 * queue.unit; height: Math.max(.7, queue.unit)
        color: queue.stroke; opacity: .25
    }
    Text {
        x: 28 * queue.unit; y: parent.height - 45 * queue.unit
        text: Number(queue.hud.queueCount || 0) > 0
            ? (queue.pageStart + 1) + "–" + Math.min(Number(queue.hud.queueCount), queue.pageStart + stableQueueRows.count)
            : "0"
        color: queue.muted; font.pixelSize: 12 * queue.unit
        font.family: rhineFontFamily
    }
    // Fixed-size pages keep a 4,000+ song queue cheap even during playback.
    // Scrolling within a page remains smooth, the arrows browse the full queue.
    Rectangle {
        x: 100 * queue.unit; y: parent.height - 53 * queue.unit
        width: 34 * queue.unit; height: 31 * queue.unit
        radius: 11 * queue.unit
        color: previousMouse.containsMouse && queue.pageStart > 0
            ? (queue.hud.dark ? "#448d9b8c" : "#508c9977") : "transparent"
        opacity: queue.pageStart > 0 ? 1 : .26
        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 24 * queue.unit; color: queue.ink }
        MouseArea { id: previousMouse; anchors.fill: parent; hoverEnabled: true
            enabled: queue.pageStart > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: rhine.action("player:queue-page-prev") }
    }
    Rectangle {
        x: 144 * queue.unit; y: parent.height - 53 * queue.unit
        width: 34 * queue.unit; height: 31 * queue.unit
        radius: 11 * queue.unit
        color: nextMouse.containsMouse && queue.pageStart + queue.pageSize < Number(queue.hud.queueCount || 0)
            ? (queue.hud.dark ? "#448d9b8c" : "#508c9977") : "transparent"
        opacity: queue.pageStart + queue.pageSize < Number(queue.hud.queueCount || 0) ? 1 : .26
        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 24 * queue.unit; color: queue.ink }
        MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true
            enabled: queue.pageStart + queue.pageSize < Number(queue.hud.queueCount || 0)
            cursorShape: Qt.PointingHandCursor
            onClicked: rhine.action("player:queue-page-next") }
    }
    Text {
        x: parent.width - 160 * queue.unit
        y: parent.height - 45 * queue.unit
        text: "SCROLL  /  QUEUE"
        color: queue.muted; opacity: .76
        font.pixelSize: 10 * queue.unit; font.letterSpacing: 1 * queue.unit
    }
}