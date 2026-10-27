import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Shapes

Item {
    id: navigation
    objectName: "sideNavigationRoot"
    required property Item background
    property real unit: 1
    property bool expanded: false
    readonly property bool home: rhine.state.mode === "archive" && !rhine.state.modal && !rhine.state.directoryOpen && !rhine.state.lyricsMode && !rhine.state.viewer
    readonly property real typeUnit: Math.max(.9, unit)
    readonly property real railWidth: 54 * typeUnit
    property bool musicOpen: true
    property bool createdOpen: true
    property bool collectedOpen: true
    property string selected: ""
    readonly property real drawerWidth: Math.max(208, 246 * unit)
    readonly property real drawerHeight: Math.max(250 * unit, Math.min(height - 340 * unit, 720 * unit))
    readonly property real drawerY: Math.max(210 * unit, (height - 100 * unit - drawerHeight) / 2)
    readonly property color ink: rhine.state.dark ? "#edeee7" : "#343a33"
    readonly property color muted: rhine.state.dark ? "#a6ae9f" : "#858d80"
    readonly property color line: rhine.state.dark ? "#ced7c7" : "#8b9384"

    // Monoline vector paths in a shared 24 x 24 space. No font glyphs or platform-dependent emoji.
    function iconPath(name) {
        const paths = {
            "home": "M3 10 L12 3 L21 10 M5 9 V20 H19 V9 M9 20 V14 H15 V20",
            "sparkles": "M12 2 L14.7 9.3 L22 12 L14.7 14.7 L12 22 L9.3 14.7 L2 12 L9.3 9.3 Z M19 2 V6 M17 4 H21",
            "podcast": "M12 13 A1.5 1.5 0 1 0 12 10 A1.5 1.5 0 1 0 12 13 M11 16 L10 21 M13 16 L14 21 M8 8 A5.5 5.5 0 0 0 7 16 M16 8 A5.5 5.5 0 0 1 17 16 M6 5 A9.5 9.5 0 0 0 4 18 M18 5 A9.5 9.5 0 0 1 20 18",
            "shuffle": "M4 7 H7 C12 7 12 17 18 17 H20 M17 14 L20 17 L17 20 M4 17 H7 C12 17 12 7 18 7 H20 M17 4 L20 7 L17 10",
            "users": "M15 19 V17 A4 4 0 0 0 11 13 H7 A4 4 0 0 0 3 17 V19 M9 10 A3.5 3.5 0 1 0 9 3 A3.5 3.5 0 1 0 9 10 M17 5 A3 3 0 0 1 17 11 M19 13 A4 4 0 0 1 22 17 V19",
            "chart": "M4 20 V13 M10 20 V9 M16 20 V5 M22 20 V3 M2 21 H23",
            "disc": "M12 21 A9 9 0 1 0 12 3 A9 9 0 1 0 12 21 M12 14.5 A2.5 2.5 0 1 0 12 9.5 A2.5 2.5 0 1 0 12 14.5",
            "heart": "M20.3 5.7 C18.6 3.6 15.4 3.6 13.5 5.5 L12 7 L10.5 5.5 C8.6 3.6 5.4 3.6 3.7 5.7 C1.7 8.2 2.5 11 4.7 13.3 L12 20.5 L19.3 13.3 C21.5 11 22.3 8.2 20.3 5.7 Z",
            "clock": "M12 21 A9 9 0 1 0 12 3 A9 9 0 1 0 12 21 M12 7 V12 L16 14",
            "star": "M12 2.8 L14.9 8.7 L21.4 9.6 L16.7 14.2 L17.8 20.8 L12 17.7 L6.2 20.8 L7.3 14.2 L2.6 9.6 L9.1 8.7 Z",
            "music": "M9 18 V5 L20 3 V16 M9 9 L20 7 M9 18 A3 3 0 1 1 3 18 A3 3 0 1 1 9 18 M20 16 A3 3 0 1 1 14 16 A3 3 0 1 1 20 16",
            "list": "M4 6 H20 M4 12 H20 M4 18 H20",
            "user": "M12 11 A4 4 0 1 0 12 3 A4 4 0 1 0 12 11 M4 21 V19 A8 8 0 0 1 20 19 V21",
            "folder": "M3 7 V19 H21 V9 H12 L10 6 H3 Z",
            "download": "M12 3 V16 M7 11 L12 16 L17 11 M4 19 V21 H20 V19",
            "cloud": "M7 18 H18 A4 4 0 0 0 18 10 A6 6 0 0 0 6 10 A4 4 0 0 0 7 18 M12 12 V21 M9 15 L12 12 L15 15",
            "chevron-down": "M6.5 9.5 L12 15 L17.5 9.5",
            "chevron-right": "M9.5 6.5 L15 12 L9.5 17.5",
            "plus": "M12 5 V19 M5 12 H19"
        };
        return paths[name] || paths["disc"];
    }
    function open() {
        closeTimer.stop();
        if (!expanded) rhine.action("navigation:load-playlists");
        expanded = true;
    }
    function scheduleClose() { closeTimer.restart(); }
    function discover(tab) {
        rhine.action("discover");
        rhine.action("discover:tab:" + tab);
        selected = tab;
        scheduleClose();
    }
    function profile(filter) {
        var uid = rhine.state.accountUID || "";
        if (!uid) { rhine.action("saved"); scheduleClose(); return; }
        rhine.action("profile:open:" + uid);
        if (filter) rhine.action("profile:filter:" + filter);
        selected = "profile:" + filter;
        scheduleClose();
    }

    Timer {
        id: closeTimer
        interval: 280
        onTriggered: {
            if (!edgeHover.hovered && !panelHover.hovered && !railHover.hovered)
                navigation.expanded = false
        }
    }
    // Hover edge stays fixed in place; the expanded surface never changes its Y or size.
    Item {
        x: 0
        y: navigation.drawerY
        width: Math.max(18, 26 * navigation.unit)
        height: navigation.drawerHeight
        HoverHandler {
            id: edgeHover
            onHoveredChanged: hovered ? navigation.open() : navigation.scheduleClose()
        }
    }
    // The collapsed rail is a different surface, not the closing drawer being resized.
    Item {
        id: rail
        objectName: "sideNavigationRail"
        x: 18 * navigation.unit
        y: (navigation.height - 100 * navigation.unit - height) / 2
        width: navigation.railWidth
        height: 164 * navigation.typeUnit
        visible: navigation.home && !navigation.expanded
        LiquidGlass {
            anchors.fill: parent
            background: navigation.background
            sampleX: rail.x; sampleY: rail.y
            uiScale: navigation.unit; dark: rhine.state.dark === true
        }
        HoverHandler {
            id: railHover
            onHoveredChanged: hovered ? navigation.open() : navigation.scheduleClose()
        }
        Column {
            anchors.centerIn: parent
            spacing: 4 * navigation.typeUnit
            Repeater {
                model: [
                    {icon:"sparkles", label:"精选", action:"discover"},
                    {icon:"heart", label:"我喜欢的音乐", action:"navigation:likes"},
                    {icon:"user", label:"我的主页", action:"profile"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 42 * navigation.typeUnit
                    height: width
                    radius: 12 * navigation.typeUnit
                    color: railMouse.containsMouse ? (rhine.state.dark ? "#29bfc7b4" : "#27929c82") : "transparent"
                    VectorIcon { anchors.centerIn: parent; name: modelData.icon; tint: navigation.ink; size: 22 }
                    Controls.ToolTip.visible: railMouse.containsMouse
                    Controls.ToolTip.text: modelData.label
                    Controls.ToolTip.delay: 500
                    MouseArea {
                        id: railMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.action === "profile") navigation.profile("")
                            else if (modelData.action === "discover") navigation.discover("playlists")
                            else { rhine.action(modelData.action); navigation.scheduleClose() }
                        }
                    }
                }
            }
        }
    }
    Item {
        id: drawer
        objectName: "sideNavigation"
        x: navigation.expanded ? 18 * navigation.unit : -navigation.drawerWidth - 16 * navigation.unit
        y: navigation.drawerY
        width: navigation.drawerWidth
        height: navigation.drawerHeight
        Behavior on x { NumberAnimation { duration: 245; easing.type: Easing.OutCubic } }
        HoverHandler {
            id: panelHover
            onHoveredChanged: hovered ? navigation.open() : navigation.scheduleClose()
        }
        LiquidGlass {
            anchors.fill: parent
            background: navigation.background
            sampleX: drawer.x; sampleY: drawer.y
            uiScale: navigation.unit; dark: rhine.state.dark === true
        }
        Flickable {
            id: list
            anchors.fill: parent
            anchors.margins: 12 * navigation.unit
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: content
                width: list.width
                spacing: 2 * navigation.unit

                Text {
                    text: "发现音乐"
                    height: 34 * navigation.typeUnit
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14 * navigation.typeUnit
                    font.bold: true
                    color: navigation.muted
                    opacity: .9
                }
                Repeater {
                    model: [
                        {label:"推荐", icon:"home", tab:"daily"},
                        {label:"精选", icon:"sparkles", tab:"playlists"},
                        {label:"播客", icon:"podcast", tab:"podcasts"},
                        {label:"漫游", icon:"shuffle", tab:"roam"},
                        {label:"关注", icon:"users", tab:"following"}
                    ]
                    delegate: NavRow {
                        required property var modelData
                        label: modelData.label
                        icon: modelData.icon
                        selected: navigation.selected === modelData.tab
                        onInvoked: navigation.discover(modelData.tab)
                    }
                }
                DividerLine {}
                Text {
                    text: "我的"
                    height: 43 * navigation.typeUnit
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14 * navigation.typeUnit
                    font.bold: true
                    color: navigation.muted
                    opacity: .76
                    leftPadding: 8 * navigation.unit
                }
                NavRow {
                    label: "我喜欢的音乐"
                    icon: "heart"
                    visible: navigation.musicOpen
                    selected: navigation.selected === "likes"
                    onInvoked: { navigation.selected = "likes"; rhine.action("navigation:likes"); navigation.scheduleClose() }
                }
                NavRow {
                    label: "最近播放"
                    icon: "clock"
                    visible: navigation.musicOpen
                    selected: navigation.selected === "profile:recent"
                    onInvoked: navigation.profile("recent")
                }
                NavRow {
                    label: "我的主页"
                    icon: "user"
                    visible: navigation.musicOpen
                    selected: navigation.selected === "profile:"
                    onInvoked: navigation.profile("")
                }
                NavRow {
                    label: "我的收藏"
                    icon: "star"
                    visible: navigation.musicOpen
                    selected: navigation.selected === "profile:collected"
                    onInvoked: navigation.profile("collected")
                }
                NavRow {
                    label: "排行榜"
                    icon: "chart"
                    visible: navigation.musicOpen
                    selected: navigation.selected === "charts"
                    onInvoked: navigation.discover("charts")
                }
                NavRow {
                    label: "新专辑"
                    icon: "disc"
                    visible: navigation.musicOpen
                    selected: navigation.selected === "albums"
                    onInvoked: navigation.discover("albums")
                }
                NavRow {
                    label: navigation.musicOpen ? "收起" : "展开"
                    icon: ""
                    heading: true
                    chevron: true
                    opened: navigation.musicOpen
                    onInvoked: navigation.musicOpen = !navigation.musicOpen
                }
                DividerLine {}
                Item {
                    width: list.width
                    height: 43 * navigation.typeUnit
                    readonly property int count: (rhine.state.navigationCreated || []).length
                    NavRow {
                        width: parent.width - 33 * navigation.unit
                        label: "创建的歌单  " + parent.count
                        icon: "music"
                        chevron: true
                        opened: navigation.createdOpen
                        onInvoked: navigation.createdOpen = !navigation.createdOpen
                    }
                    Rectangle {
                        id: createPlaylistSurface
                        width: 29 * navigation.unit
                        height: 29 * navigation.unit
                        anchors.right: parent.right
                        anchors.rightMargin: 3 * navigation.unit
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 11 * navigation.unit
                        color: createPlaylistMouse.containsMouse ? (rhine.state.dark ? "#31bdc6b3" : "#3198a589") : "transparent"
                        VectorIcon { anchors.centerIn: parent; name: "plus"; tint: navigation.ink; size: 19 }
                        Controls.ToolTip.visible: createPlaylistMouse.containsMouse
                        Controls.ToolTip.text: "创建歌单"
                        MouseArea {
                            id: createPlaylistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                rhine.action("music:create-playlist")
                                navigation.scheduleClose()
                            }
                        }
                    }
                }
                Repeater {
                    model: navigation.createdOpen ? (rhine.state.navigationCreated || []) : []
                    delegate: PlaylistRow {
                        required property var modelData
                        required property int index
                        entry: modelData
                        lane: 2
                        itemIndex: index
                    }
                }
                DividerLine {}
                NavRow {
                    label: "收藏的歌单  " + (rhine.state.navigationCollected || []).length
                    icon: "star"
                    chevron: true
                    opened: navigation.collectedOpen
                    onInvoked: navigation.collectedOpen = !navigation.collectedOpen
                }
                Repeater {
                    model: navigation.collectedOpen ? (rhine.state.navigationCollected || []) : []
                    delegate: PlaylistRow {
                        required property var modelData
                        required property int index
                        entry: modelData
                        lane: 3
                        itemIndex: index
                    }
                }
            }
        }
    }

    component DividerLine: Rectangle {
        width: list.width - 16 * navigation.unit
        x: 8 * navigation.unit
        height: 1 * navigation.unit
        color: navigation.line
        opacity: .24
    }
    component VectorIcon: Item {
        id: glyph
        property string name: "disc"
        property color tint: navigation.ink
        property real size: 22
        width: size * navigation.typeUnit
        height: width
        Shape {
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: (glyph.size * navigation.typeUnit) / 24
            ShapePath {
                strokeColor: glyph.tint
                strokeWidth: 1.85
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: navigation.iconPath(glyph.name) }
            }
        }
    }
    component PlaylistRow: Item {
        id: playlist
        property var entry: ({})
        property int lane: 2
        property int itemIndex: 0
        width: list.width
        height: 59 * navigation.typeUnit
        opacity: Math.max(0, Math.min(1, (y - list.contentY + height) / (24 * navigation.unit), (list.height - (y - list.contentY)) / (24 * navigation.unit)))
        Rectangle {
            anchors.fill: parent
            radius: 8 * navigation.unit
            color: rhine.state.dark ? "#929b83" : "#a2aa8d"
            opacity: playlistMouse.containsMouse ? .18 : 0
            Behavior on opacity { NumberAnimation { duration: 110 } }
        }
        Image {
            x: 8 * navigation.unit
            anchors.verticalCenter: parent.verticalCenter
            width: 36 * navigation.typeUnit
            height: width
            source: String(playlist.entry.cover || "").replace(/^http:/, "https:")
            sourceSize.width: 100
            sourceSize.height: 100
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Text {
            x: 49 * navigation.typeUnit
            width: parent.width - x - 8 * navigation.unit
            anchors.verticalCenter: parent.verticalCenter
            text: playlist.entry.title || "歌单"
            font.pixelSize: 15 * navigation.typeUnit
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: navigation.ink
        }
        Controls.ToolTip.visible: playlistMouse.containsMouse
        Controls.ToolTip.text: playlist.entry.title || "歌单"
        Controls.ToolTip.delay: 650
        MouseArea {
            id: playlistMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                rhine.action("navigation:playlist:" + playlist.lane + ":" + playlist.itemIndex)
                navigation.scheduleClose()
            }
        }
    }
    component NavRow: Item {
        id: row
        property string label: ""
        property string icon: ""
        property bool selected: false
        property bool chevron: false
        property bool opened: false
        property bool heading: false
        signal invoked()
        width: list.width
        height: visible ? 43 * navigation.typeUnit : 0
        opacity: Math.max(0, Math.min(1, (y - list.contentY + height) / (24 * navigation.unit), (list.height - (y - list.contentY)) / (24 * navigation.unit)))
        Rectangle {
            anchors.fill: parent
            radius: 8 * navigation.unit
            color: rhine.state.dark ? "#929b83" : "#a2aa8d"
            opacity: row.selected ? .24 : pointer.containsMouse ? .14 : 0
            Behavior on opacity { NumberAnimation { duration: 110 } }
        }
        VectorIcon {
            visible: row.icon.length > 0
            x: 8 * navigation.unit
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            tint: navigation.ink
            size: 21
        }
        Text {
            x: row.heading ? 38 * navigation.typeUnit : 38 * navigation.typeUnit
            width: parent.width - x - (row.chevron ? 27 : 7) * navigation.unit
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.pixelSize: row.heading ? 13 * navigation.typeUnit : 15.5 * navigation.typeUnit
            font.bold: row.chevron && !row.heading
            elide: Text.ElideRight
            color: row.heading ? navigation.muted : navigation.ink
        }
        VectorIcon {
            visible: row.chevron
            anchors.right: parent.right
            anchors.rightMargin: 8 * navigation.unit
            anchors.verticalCenter: parent.verticalCenter
            name: row.opened ? "chevron-down" : "chevron-right"
            tint: navigation.muted
            size: 18
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.invoked()
        }
    }
}
