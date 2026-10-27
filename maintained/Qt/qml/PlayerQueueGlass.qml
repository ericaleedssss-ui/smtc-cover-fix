import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Item {
    id: queue
    objectName: "playerQueueGlass"
    required property Item background
    property real sampleX: 0
    property real sampleY: 0
    property real unit: 1
    readonly property real typeUnit: Math.max(.9, unit)
    readonly property var hud: rhine.state
    property var incomingRows: hud.queueRows || []
    property string syncedRows: ""
    property int syncedPage: -1
    readonly property int pageStart: Number(hud.queueOffset || 0)
    readonly property int pageSize: Number(hud.queuePageSize || 40)
    readonly property color ink: hud.dark ? "#eef2e9" : "#343a33"
    readonly property color muted: hud.dark ? "#a6ae9f" : "#858d80"
    readonly property color accent: hud.dark ? "#b7ceab" : "#6f8968"
    ListModel { id: stableQueueRows }
    function syncRows() {
        var rows = incomingRows || [];
        var signature = JSON.stringify(rows);
        if (signature === syncedRows) return;
        syncedRows = signature;
        var pageChanged = syncedPage !== pageStart;
        syncedPage = pageStart;
        // Update in place: artwork arriving or a removed song must not jump
        // the viewport to the top or destroy a hovered delegate every frame.
        while (stableQueueRows.count > rows.length) stableQueueRows.remove(stableQueueRows.count - 1);
        for (var i = 0; i < rows.length; ++i) {
            var song = rows[i] || {};
            var entry = {trackTitle: String(song.title || "未知歌曲"),
                trackArtist: String(song.artist || "未知歌手"),
                trackIndex: Number(song.index), trackId: String(song.id || ""),
                trackKey: String(song.key || ""), trackCover: String(song.cover || ""),
                trackDuration: String(song.durationLabel || "—"),
                trackSource: String(song.sourceTitle || ""),
                sourceLink: song.sourceLink === true};
            if (i < stableQueueRows.count) stableQueueRows.set(i, entry);
            else stableQueueRows.append(entry);
        }
        if (pageChanged && songList) songList.positionViewAtBeginning();
    }
    function rowAction(operation, index, key) {
        rhine.action("player:" + operation + ":" + index + ":" + encodeURIComponent(key));
    }
    onIncomingRowsChanged: syncRows()
    Component.onCompleted: syncRows()

    component QueueIcon: Item {
        id: glyph
        property string kind: "close"
        property color tint: queue.ink
        width: 20 * queue.typeUnit; height: width
        Shape {
            anchors.centerIn: parent; width: 24; height: 24
            scale: glyph.width / 24
        ShapePath {
            strokeColor: glyph.tint; strokeWidth: 1.6
            fillColor: glyph.kind === "play" ? glyph.tint : "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: {
                switch (glyph.kind) {
                case "play": return "M9 5 L19 12 L9 19 Z";
                case "link": return "M9 15 L15 9 M8 12 L5 15 C1 19 5 23 9 19 L12 16 M12 8 L15 5 C19 1 23 5 19 9 L16 12";
                case "add": return "M4 4 H20 V20 H4 Z M12 8 V16 M8 12 H16";
                case "trash": return "M4 6 H20 M9 6 V3 H15 V6 M6 6 L7 21 H17 L18 6 M10 10 V17 M14 10 V17";
                case "prev": return "M15 5 L8 12 L15 19";
                case "next": return "M9 5 L16 12 L9 19";
                default: return "M6 6 L18 18 M18 6 L6 18";
                }
            } }
        }
        }
    }
    component QueueButton: Rectangle {
        id: button
        property string icon: "close"
        property string label: ""
        property string actionName: ""
        property bool actionable: true
        signal activated()
        width: 31 * queue.typeUnit; height: width; radius: 9 * queue.unit
        color: buttonMouse.containsMouse ? (queue.hud.dark ? "#328ca07c" : "#21919c81") : "transparent"
        opacity: enabled && actionable ? 1 : .3
        QueueIcon { anchors.centerIn: parent; kind: button.icon }
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: button.activate()
        function activate() {
            if (!enabled || !actionable) return;
            if (actionName) rhine.action(actionName);
            activated();
        }
        ToolTip.visible: buttonMouse.containsMouse
        ToolTip.text: label; ToolTip.delay: 550
        MouseArea {
            id: buttonMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: button.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onWheel: function(wheel) { wheel.accepted = false }
            onClicked: button.activate()
        }
    }

    LiquidGlass {
        anchors.fill: parent; background: queue.background
        sampleX: queue.sampleX; sampleY: queue.sampleY
        uiScale: queue.unit; radius: 27 * queue.unit; dark: queue.hud.dark === true
    }
    // This component is a root-level input surface, above the page input
    // layer. Decorative materials never own a MouseArea.
    MouseArea { anchors.fill: parent; onWheel: function(wheel) { wheel.accepted = true } }
    Text {
        id: heading
        x: 25 * queue.unit; y: 24 * queue.unit
        text: "播放列表"; color: queue.ink
        font.family: rhineFontFamily; font.pixelSize: 21 * queue.typeUnit; font.weight: Font.DemiBold
    }
    Text {
        x: heading.x + heading.implicitWidth + 7 * queue.unit; y: heading.y + 3 * queue.unit
        text: Number(queue.hud.queueCount || 0).toLocaleString()
        color: queue.muted; font.family: rhineFontFamily; font.pixelSize: 12 * queue.typeUnit
    }
    QueueButton {
        objectName: "queueClose"
        x: parent.width - width - 18 * queue.unit; y: 18 * queue.unit
        label: "关闭播放列表"; actionName: "queue-close"
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 22 * queue.unit
        y: 65 * queue.unit; spacing: 8 * queue.unit
        QueueButton {
            objectName: "queueCollectAll"; icon: "add"; label: "收藏全部到歌单"
            enabled: queue.hud.queueCanCollect === true && Number(queue.hud.queueCount || 0) > 0
            actionName: "player:queue-collect-all"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "收藏全部"; color: queue.muted
            font.family: rhineFontFamily; font.pixelSize: 12 * queue.typeUnit
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                enabled: queue.hud.queueCanCollect === true && Number(queue.hud.queueCount || 0) > 0
                onClicked: rhine.action("player:queue-collect-all")
            }
        }
        QueueButton {
            objectName: "queueClear"; icon: "trash"
            label: queue.hud.queueRoaming ? "退出漫游" : "清空待播，保留当前播放"
            actionName: queue.hud.queueRoaming ? "roam:exit" : "player:clear"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: queue.hud.queueRoaming ? "退出漫游" : "清空待播"; color: queue.muted
            font.family: rhineFontFamily; font.pixelSize: 12 * queue.typeUnit
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: rhine.action(queue.hud.queueRoaming ? "roam:exit" : "player:clear") }
        }
    }
    Rectangle {
        x: 25 * queue.unit; y: 109 * queue.unit; width: parent.width - 50 * queue.unit
        height: Math.max(.6, queue.unit); color: queue.muted; opacity: .18
    }
    ListView {
        id: songList
        objectName: "playerQueueList"
        x: 15 * queue.unit; y: 122 * queue.unit
        width: parent.width - 30 * queue.unit
        height: Math.max(50, parent.height - 188 * queue.unit)
        clip: true; model: stableQueueRows; reuseItems: true
        cacheBuffer: 180 * queue.unit; boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1400
        WheelHandler {
            target: null
            onWheel: function(event) {
                var delta = event.pixelDelta.y || event.angleDelta.y / 120 * 64 * queue.unit;
                var maximum = Math.max(0, songList.contentHeight - songList.height);
                songList.contentY = Math.max(0, Math.min(maximum, songList.contentY - delta));
                event.accepted = true;
            }
        }
        // Fade the list's own layer. It remains the event source; there is
        // no duplicate texture surface or invisible input proxy over it.
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: ShaderEffect {
            objectName: "playerQueueEdgeFade"
            property variant source
            property size panelSize: Qt.size(songList.width, songList.height)
            property real horizontal: 0
            property real fadePx: 40 * queue.unit
            property real fadeStart: songList.contentY > 4 * queue.unit ? 1 : 0
            property real fadeEnd: songList.contentY + songList.height < songList.contentHeight - 4 * queue.unit ? 1 : 0
            property real blurStrength: 1.7 * queue.unit
            fragmentShader: "qrc:/shaders/softEdgeFade.frag.qsb"
        }
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded; width: 3 * queue.unit
            contentItem: Rectangle { radius: width / 2; color: queue.accent; opacity: .35 }
        }
        delegate: Item {
            id: track
            required property int index
            required property string trackTitle
            required property string trackArtist
            required property int trackIndex
            required property string trackKey
            required property string trackCover
            required property string trackDuration
            required property string trackSource
            required property bool sourceLink
            objectName: "queueRow_" + trackIndex
            readonly property bool selected: trackIndex === Number(queue.hud.queueIndex)
            readonly property bool hovered: rowHover.hovered
            width: songList.width; height: Math.max(74 * queue.unit, 64 * queue.typeUnit)
            HoverHandler { id: rowHover }
            Rectangle {
                objectName: "queueRowHighlight"
                anchors.fill: parent; anchors.margins: 2 * queue.unit
                radius: 12 * queue.unit
                color: track.hovered ? (queue.hud.dark ? "#329db18d" : "#21919c81")
                       : track.selected ? (queue.hud.dark ? "#268caa85" : "#18829477") : "transparent"
                Behavior on color { ColorAnimation { duration: queue.hud.reduced ? 0 : 100 } }
            }
            MouseArea {
                objectName: "queueRowPlay_" + track.trackIndex
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onWheel: function(wheel) { wheel.accepted = false }
                onClicked: queue.rowAction("queue-play", track.trackIndex, track.trackKey)
            }
            Rectangle {
                id: artwork
                x: 12 * queue.unit; y: (parent.height - height) / 2
                width: 50 * queue.unit; height: width
                color: queue.hud.dark ? "#3e483b" : "#d8dcce"
                Text { anchors.centerIn: parent; text: "♪"; color: queue.muted; font.pixelSize: 24 * queue.unit }
                Image {
                    anchors.fill: parent; source: track.trackCover
                    sourceSize: Qt.size(100, 100); asynchronous: true; cache: true
                    fillMode: Image.PreserveAspectCrop
                }
                Rectangle {
                    anchors.fill: parent
                    visible: track.hovered || track.selected
                    color: track.hovered ? "#66000000" : "#33000000"
                    QueueIcon { anchors.centerIn: parent; kind: "play"; tint: "#ffffff" }
                }
                MouseArea {
                    objectName: "queueCoverPlay_" + track.trackIndex
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onWheel: function(wheel) { wheel.accepted = false }
                    onClicked: queue.rowAction("queue-play", track.trackIndex, track.trackKey)
                }
            }
            Column {
                x: 76 * queue.unit; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (track.hovered ? 110 * queue.typeUnit : 60 * queue.unit)
                spacing: 3 * queue.unit
                Text {
                    width: parent.width; text: track.trackTitle; elide: Text.ElideRight
                    color: track.selected ? queue.accent : queue.ink
                    font.family: rhineFontFamily; font.pixelSize: 15.5 * queue.typeUnit
                    font.weight: track.selected ? Font.DemiBold : Font.Normal
                }
                Text {
                    width: parent.width; text: track.trackArtist; elide: Text.ElideRight
                    color: queue.muted; font.family: rhineFontFamily; font.pixelSize: 12 * queue.typeUnit
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 15 * queue.unit
                anchors.verticalCenter: parent.verticalCenter
                visible: !track.hovered
                text: track.trackDuration; color: queue.muted
                font.family: rhineFontFamily; font.pixelSize: 12 * queue.typeUnit
            }
            Row {
                visible: track.hovered
                anchors.right: parent.right; anchors.rightMargin: 9 * queue.unit
                anchors.verticalCenter: parent.verticalCenter; spacing: 3 * queue.unit
                QueueButton {
                    objectName: "queueSource_" + track.trackIndex
                    icon: "link"
                    label: track.sourceLink ? "来源：" + track.trackSource : "暂无可追溯来源"
                    actionable: track.sourceLink
                    onActivated: queue.rowAction("queue-source", track.trackIndex, track.trackKey)
                }
                QueueButton {
                    objectName: "queueCollect_" + track.trackIndex
                    icon: "add"; label: "收藏到歌单"; enabled: queue.hud.queueCanCollect === true
                    onActivated: queue.rowAction("queue-collect", track.trackIndex, track.trackKey)
                }
                QueueButton {
                    objectName: "queueRemove_" + track.trackIndex
                    label: track.selected ? "当前播放歌曲保留在队列" : "从播放队列移除"
                    enabled: !track.selected && !queue.hud.queueRoaming
                    onActivated: queue.rowAction("remove", track.trackIndex, track.trackKey)
                }
            }
            Rectangle {
                x: 76 * queue.unit; y: parent.height - height
                width: parent.width - x - 14 * queue.unit
                height: Math.max(.6, queue.unit * .6); color: queue.muted; opacity: .13
                visible: index < stableQueueRows.count - 1 && !track.hovered
            }
        }
    }
    Text {
        anchors.centerIn: songList; visible: stableQueueRows.count === 0
        text: "播放列表是空的"; color: queue.muted
        font.family: rhineFontFamily; font.pixelSize: 15 * queue.typeUnit
    }
    Rectangle {
        x: 25 * queue.unit; y: parent.height - 57 * queue.unit
        width: parent.width - 50 * queue.unit; height: Math.max(.6, queue.unit)
        color: queue.muted; opacity: .18
    }
    Text {
        x: 27 * queue.unit; y: parent.height - 39 * queue.unit
        text: Number(queue.hud.queueCount || 0) > 0
            ? (queue.pageStart + 1) + "–" + Math.min(Number(queue.hud.queueCount), queue.pageStart + stableQueueRows.count)
              + " / " + Number(queue.hud.queueCount).toLocaleString() : "0 首"
        color: queue.muted; font.family: rhineFontFamily; font.pixelSize: 12 * queue.typeUnit
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 22 * queue.unit
        y: parent.height - 47 * queue.unit; spacing: 9 * queue.unit
        QueueButton {
            objectName: "queuePrevious"; icon: "prev"; label: "上一页"
            enabled: queue.pageStart > 0; actionName: "player:queue-page-prev"
        }
        QueueButton {
            objectName: "queueNext"; icon: "next"; label: "下一页"
            enabled: queue.pageStart + queue.pageSize < Number(queue.hud.queueCount || 0)
            actionName: "player:queue-page-next"
        }
    }
}
