import QtQuick

Item {
    id: page
    required property Item background
    property real unit: 1
    property var hud: rhine.state
    property int keyboardIndex: -1
    property var scrollMemory: ({})
    readonly property real typeUnit: Math.max(.9, unit)
    function remember() { scrollMemory[page.hud.discoverTab || "playlists"] = { y: scrolling.contentY, index: page.keyboardIndex }; }
    readonly property var tabTitles: ({podcasts:"播客", roam:"漫游", following:"关注"})
    readonly property bool customCategory: tabTitles[page.hud.discoverTab] !== undefined
    function availableTabs() {
        var existing = [{label:"推荐歌单", key:"playlists"}, {label:"每日推荐", key:"daily"}, {label:"排行榜", key:"charts"}, {label:"新专辑", key:"albums"}, {label:"分类歌单", key:"categories"}];
        if (customCategory) return [{label:tabTitles[page.hud.discoverTab], key:page.hud.discoverTab}].concat(existing);
        return existing;
    }
    function restore() {
        var old = scrollMemory[page.hud.discoverTab || "playlists"];
        scrolling.contentY = old ? Math.max(0, Math.min(old.y, Math.max(0, scrolling.contentHeight - scrolling.height))) : 0;
        page.keyboardIndex = old ? old.index : -1;
    }
    focus: true
    Keys.onEscapePressed: function(event) { rhine.action("back"); event.accepted = true }
    Keys.onPressed: function(event) {
        var total = (page.hud.discoverItems || []).length;
        var step = event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Down ? grid.columns : event.key === Qt.Key_Up ? -grid.columns : 0;
        if (step && total) {
            page.keyboardIndex = page.keyboardIndex < 0 ? 0 : Math.max(0, Math.min(total - 1, page.keyboardIndex + step));
            var rowTop = Math.floor(page.keyboardIndex / grid.columns) * ((grid.width - (grid.columns - 1) * grid.columnSpacing) / grid.columns + 58 * page.typeUnit + grid.rowSpacing);
            scrolling.contentY = Math.max(0, Math.min(scrolling.contentHeight - scrolling.height, rowTop - 30 * page.unit));
            event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && page.keyboardIndex >= 0 && page.keyboardIndex < total) {
            page.remember(); rhine.action("discover:item:" + page.keyboardIndex); event.accepted = true;
        }
    }
    MouseArea { width: parent.width; height: Math.max(0, parent.height - 100 * page.unit); onClicked: {} }
    Item {
        id: panel
        x: Math.max(90 * page.unit, page.width * .10)
        y: 125 * page.unit
        width: page.width - x - 55 * page.unit
        height: page.height - y - 125 * page.unit
        LiquidGlass {
            anchors.fill: parent; background: page.background
            sampleX: panel.x; sampleY: panel.y
            uiScale: page.unit; dark: page.hud.dark === true
        }
        MouseArea { anchors.fill: parent; onClicked: {} }
        Text {
            x: 35 * page.unit; y: 24 * page.unit
            text: "精选"; font.pixelSize: 34 * page.unit; font.bold: true
            color: page.hud.dark ? "#f4f1e9" : "#252820"
        }
        Rectangle {
            id: back
            x: panel.width - width - 24 * page.unit; y: 22 * page.unit
            width: 65 * page.unit; height: 35 * page.unit; radius: 8 * page.unit
            color: backMouse.containsMouse ? "#28a2aa8d" : "transparent"
            Text { anchors.centerIn: parent; text: "返回"; font.pixelSize: 16 * page.typeUnit; color: page.hud.dark ? "#f4f1e9" : "#252820" }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action("back") }
        }
        Row {
            id: tabs
            x: 35 * page.unit; y: 82 * page.unit; spacing: 13 * page.unit
            Repeater {
                model: page.availableTabs()
                delegate: Item {
                    required property var modelData
                    width: 112 * page.typeUnit; height: 38 * page.typeUnit
                    Rectangle { anchors.fill: parent; radius: 7 * page.unit; color: page.hud.dark ? "#a1a893" : "#9da688"; opacity: page.hud.discoverTab === modelData.key ? .25 : tabMouse.containsMouse ? .13 : 0; Behavior on opacity { NumberAnimation { duration: 110 } } }
                    Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 16 * page.typeUnit; color: page.hud.dark ? "#f4f1e9" : "#252820" }
                    MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { page.remember(); page.keyboardIndex = -1; scrolling.contentY = 0; rhine.action("discover:tab:" + modelData.key); page.forceActiveFocus(); Qt.callLater(page.restore); } }
                }
            }
        }
        Flickable {
            id: scrolling
            x: 35 * page.unit; y: 92 * page.unit + 44 * page.typeUnit
            width: panel.width - 70 * page.unit; height: panel.height - y - 18 * page.unit
            clip: true; contentWidth: width; contentHeight: grid.implicitHeight + status.height + 50 * page.unit
            boundsBehavior: Flickable.StopAtBounds
            Grid {
                id: grid
                width: scrolling.width
                columns: Math.max(2, Math.floor(width / Math.max(172, 236 * page.unit)))
                columnSpacing: 18 * page.unit; rowSpacing: 14 * page.unit
                Repeater {
                    model: page.hud.discoverItems || []
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: (grid.width - (grid.columns - 1) * grid.columnSpacing) / grid.columns
                        height: width + 58 * page.typeUnit
                        Rectangle { anchors.fill: parent; radius: 9 * page.unit; color: page.hud.dark ? "#b7c0a7" : "#aab398"; opacity: cardMouse.containsMouse || page.keyboardIndex === index ? .18 : 0; Behavior on opacity { NumberAnimation { duration: 110 } } }
                        Rectangle {
                            x: 5 * page.unit; y: 5 * page.unit; width: parent.width - 10 * page.unit; height: width
                            radius: 7 * page.unit; color: page.hud.dark ? "#41473c" : "#d4d3c8"; clip: true
                            Image { objectName: "discoverCardImage"; anchors.fill: parent; source: String(modelData.cover || "").replace(/^http:/,"https:"); asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize.width: 360; sourceSize.height: 360 }
                        }
                        Text { x: 8 * page.unit; y: parent.width + 2 * page.unit; width: parent.width - 16 * page.unit; text: modelData.title || ""; font.pixelSize: 16 * page.typeUnit; font.bold: true; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight; color: page.hud.dark ? "#f4f1e9" : "#252820" }
                        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPositionChanged: page.keyboardIndex = -1; onClicked: { page.remember(); rhine.action("discover:item:" + index); } }
                    }
                }
            }
            Text { id: status; y: grid.implicitHeight + 12 * page.unit; width: parent.width; text: page.hud.discoverStatus || ""; font.pixelSize: 14 * page.typeUnit; color: page.hud.dark ? "#c9cec3" : "#666b5f" }
            Text {
                y: status.y + 28 * page.unit; text: "加载更多"; visible: page.hud.discoverMore === true
                font.pixelSize: 16 * page.typeUnit; color: page.hud.dark ? "#f4f1e9" : "#4b5942"
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action("discover:more") }
            }
        }
    }
    Component.onCompleted: { forceActiveFocus(); Qt.callLater(page.restore); }
}
