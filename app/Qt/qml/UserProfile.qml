import QtQuick

Rectangle {
    id: page
    objectName: "userProfilePage"
    property real unit: 1
    property var hudState: rhine.state
    property var person: hudState.profile || ({})
    readonly property color ink: hudState.dark ? "#eeeee6" : "#25291f"
    readonly property color muted: hudState.dark ? "#a0a495" : "#75796b"
    readonly property color accent: hudState.dark ? "#bac39b" : "#777b60"
    readonly property color shade: hudState.dark ? "#30362b" : "#e1e1d7"
    color: hudState.dark ? "#22261f" : "#eeece4"
    clip: true
    MouseArea {
        anchors.fill: parent; hoverEnabled: true
        onPositionChanged: function(mouse) { var p = mapToItem(null, mouse.x, mouse.y); rhine.hoverItem("", p.x / page.unit, p.y / page.unit); }
        onWheel: function(event) { event.accepted = true; }
    }
    function cover(url) { return String(url || "").replace(/^http:/, "https:"); }
    function hoverCard(index, item, mouse) {
        var p = item.mapToItem(null, mouse.x, mouse.y);
        rhine.hoverItem("profile:item:" + index, p.x / page.unit, p.y / page.unit);
    }
    function navigateKey(key) {
        var rows = page.hudState.profileRows || [];
        if (!rows.length) { return; }
        var action = String(page.hudState.focusAction || "");
        var index = action.indexOf("profile:item:") === 0 ? Number(action.split(":")[2]) : -1;
        if (key === "Enter") { if (index >= 0) rhine.action("profile:item:" + index); return; }
        var columns = cards.columns;
        var movement = key === "ArrowDown" ? columns : key === "ArrowUp" ? -columns : key === "ArrowRight" ? 1 : key === "ArrowLeft" ? -1 : 0;
        if (!movement) { return; }
        index = index < 0 ? 0 : Math.max(0, Math.min(rows.length - 1, index + movement));
        rhine.action("profile:focus:" + index);
        var card = cardRepeater.itemAt(index);
        if (card) {
            var y = card.mapToItem(content, 0, 0).y;
            if (y < reading.contentY) reading.contentY = y;
            else if (y + card.height > reading.contentY + reading.height) reading.contentY = y + card.height - reading.height;
            reading.contentY = Math.max(0, Math.min(reading.contentY, Math.max(0, reading.contentHeight - reading.height)));
        }
    }
    component Label: Text {
        color: page.ink; textFormat: Text.PlainText; font.family: rhineFontFamily
        font.pixelSize: 16 * page.unit; elide: Text.ElideRight
    }
    component Control: Rectangle {
        property string label
        property string action
        property bool selected: false
        width: caption.implicitWidth + 30 * page.unit; height: 38 * page.unit
        color: mouse.containsMouse ? page.shade : "transparent"
        Label { id: caption; anchors.centerIn: parent; text: parent.label; font.pixelSize: 16 * page.unit; font.weight: parent.selected ? Font.DemiBold : Font.Normal }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width - 20 * page.unit; anchors.horizontalCenter: parent.horizontalCenter; height: page.unit; color: page.accent; visible: parent.selected }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action(parent.action) }
    }

    Column {
        x: 26 * page.unit; y: 48 * page.unit; width: 270 * page.unit; spacing: 18 * page.unit
        Label { text: "PERSONAL / 个人主页"; font.pixelSize: 11 * page.unit; color: page.muted }
        Rectangle {
            width: 210 * page.unit; height: width; radius: 4 * page.unit; color: page.shade
            Image { anchors.fill: parent; source: page.cover(page.person.avatarUrl); sourceSize.width: 320; sourceSize.height: 320; asynchronous: true; fillMode: Image.PreserveAspectCrop }
        }
        Label { objectName: "profileNickname"; width: parent.width; text: page.person.nickname || "正在读取用户资料…"; font.pixelSize: 27 * page.unit; font.weight: Font.DemiBold }
        Label { text: page.person.level !== undefined ? "LEVEL / " + page.person.level : "网易云音乐"; color: page.muted; font.pixelSize: 14 * page.unit }
        Row {
            spacing: 20 * page.unit
            Label { text: "关注 " + (page.person.follows || 0); font.pixelSize: 16 * page.unit }
            Label { text: "粉丝 " + (page.person.followeds || 0); font.pixelSize: 16 * page.unit }
        }
        Label { width: parent.width - 14 * page.unit; text: page.person.signature || "暂无简介"; wrapMode: Text.Wrap; elide: Text.ElideNone; maximumLineCount: 7; lineHeight: 1.5; color: page.muted; font.pixelSize: 16 * page.unit }
        Control { visible: Number(page.person.artistId || 0) > 0; label: "歌手页 ↗"; action: "profile:artist" }
    }
    Item {
        id: right
        x: 340 * page.unit; y: 58 * page.unit; width: parent.width - x - 28 * page.unit; height: parent.height - y - 20 * page.unit
        Row {
            id: tabs; spacing: 24 * page.unit
            Repeater {
                model: [{key:"music",name:"音乐"},{key:"notes",name:"笔记"},{key:"podcasts",name:"播客"}]
                delegate: Control { required property var modelData; label: modelData.name; selected: page.hudState.profileSection === modelData.key || (modelData.key === "podcasts" && page.hudState.profileSection === "programs"); action: "profile:section:" + modelData.key }
            }
        }
        Rectangle { y: 46 * page.unit; width: parent.width; height: page.unit; color: page.shade }
        Row {
            id: filters; y: 61 * page.unit; spacing: 12 * page.unit
            visible: page.hudState.profileSection === "music"
            Repeater {
                model: page.hudState.profileOwn ? [{key:"recent",name:"近期"},{key:"created",name:"创建"},{key:"collected",name:"收藏"},{key:"albums",name:"收藏专辑"}] : [{key:"created",name:"创建"},{key:"collected",name:"收藏"}]
                delegate: Control { required property var modelData; label: modelData.name; selected: page.hudState.profileFilter === modelData.key; action: "profile:filter:" + modelData.key }
            }
        }
        Row {
            y: 108 * page.unit; spacing: 12 * page.unit
            visible: page.hudState.profileSection === "music" && page.hudState.profileFilter === "recent"
            Repeater {
                model: [{key:"playlist",name:"概览"},{key:"song",name:"歌曲历史"},{key:"album",name:"专辑历史"},{key:"ranking",name:"听歌排行"}]
                delegate: Control { required property var modelData; label: modelData.name; selected: page.hudState.profileRecentKind === modelData.key; action: "profile:recent-kind:" + modelData.key }
            }
        }
        Row {
            y: 155 * page.unit; spacing: 12 * page.unit
            visible: page.hudState.profileSection === "music" && page.hudState.profileFilter === "recent" && page.hudState.profileRecentKind === "ranking"
            Control { label: "所有时间"; selected: page.hudState.profileRankPeriod === "all"; action: "profile:rank-period:all" }
            Control { label: "最近一周"; selected: page.hudState.profileRankPeriod === "week"; action: "profile:rank-period:week" }
        }
        Flickable {
            id: reading
            objectName: "profileReading"
            y: page.hudState.profileSection === "music" ? (page.hudState.profileFilter === "recent" ? (page.hudState.profileRecentKind === "ranking" ? 205 : 165) : 120) * page.unit : 65 * page.unit
            width: parent.width; height: parent.height - y
            clip: true; contentWidth: width; contentHeight: content.height
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler { target: null; onWheel: function(event) { reading.contentY = Math.max(0, Math.min(Math.max(0, reading.contentHeight - reading.height), reading.contentY - event.angleDelta.y * page.unit * 0.6)); event.accepted = true; } }
            Column {
                id: content; width: parent.width; spacing: 20 * page.unit
                property bool list: page.hudState.profileSection === "notes" || page.hudState.profileSection === "programs" || (page.hudState.profileFilter === "recent" && (page.hudState.profileRecentKind === "song" || page.hudState.profileRecentKind === "ranking"))
                Grid {
                    id: cards
                    width: parent.width
                    columns: content.list ? 1 : Math.max(2, Math.floor(width / (195 * page.unit)))
                    spacing: 22 * page.unit
                    Repeater {
                        id: cardRepeater
                        model: page.hudState.profileRows || []
                        delegate: Item {
                            id: card
                            required property var modelData
                            required property int index
                            width: (cards.width - (cards.columns - 1) * cards.spacing) / cards.columns
                            height: content.list ? (page.hudState.profileSection === "notes" ? Math.max(90 * page.unit, note.implicitHeight + 40 * page.unit) : 82 * page.unit) : width + 66 * page.unit
                            property bool noteCard: page.hudState.profileSection === "notes"
                            property bool focused: page.hudState.focusAction === "profile:item:" + index
                            property bool playable: modelData.kind === "song" || modelData.kind === "album" || modelData.kind === "playlist"
                            Rectangle { anchors.fill: parent; visible: content.list && card.focused; color: page.hudState.dark ? "#203e4731" : "#16777b60" }
                            Rectangle {
                                id: art
                                width: content.list ? 64 * page.unit : parent.width; height: width
                                color: page.shade; visible: !card.noteCard || !!card.modelData.cover || !!(card.modelData.resource && card.modelData.resource.cover)
                                Image { anchors.fill: parent; source: page.cover(card.modelData.cover || (card.modelData.resource ? card.modelData.resource.cover : "")); sourceSize.width: 300; sourceSize.height: 300; asynchronous: true; fillMode: Image.PreserveAspectCrop }
                                Rectangle {
                                    anchors.fill: parent; visible: card.modelData.kind === "ranking"
                                    gradient: Gradient { GradientStop { position: 0; color: "#c8c8b0" } GradientStop { position: 1; color: "#7b8970" } }
                                    Row {
                                        anchors.centerIn: parent; spacing: 10 * page.unit
                                        Repeater {
                                            model: [40, 78, 56]
                                            delegate: Rectangle { required property var modelData; y: (78 - modelData) * page.unit; width: 14 * page.unit; height: modelData * page.unit; radius: 7 * page.unit; color: "#eeeDE4" }
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent; color: "black"
                                    opacity: card.focused && !content.list ? 0.13 : 0
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                }
                            }
                            Label {
                                id: note
                                x: content.list ? (art.visible ? 82 * page.unit : 0) : 0
                                y: content.list ? 5 * page.unit : art.height + 10 * page.unit
                                width: parent.width - x
                                text: (card.modelData.rank ? String(card.modelData.rank).padStart(2, "0") + "  " : "") + (card.modelData.title || "未命名")
                                wrapMode: card.noteCard ? Text.Wrap : Text.NoWrap
                                maximumLineCount: card.noteCard ? 1000 : 1
                                font.pixelSize: 16 * page.unit; lineHeight: 1.5
                            }
                            Label {
                                x: note.x; y: note.y + note.height + 7 * page.unit; width: note.width
                                text: card.modelData.kind === "ranking" ? (page.person.listenSongs !== undefined ? "累计听歌 " + page.person.listenSongs + " 首" : "最近一周 / 所有时间") :
                                    (card.modelData.artist || "") + (card.modelData.listeningCount !== undefined ? " · " + card.modelData.listeningCount + " 次" : card.modelData.date ? " · " + card.modelData.date : card.modelData.kind !== "song" && card.modelData.kind !== "note" ? " · " + (card.modelData.trackCount || 0) + " 首" : "")
                                color: page.muted; font.pixelSize: 14 * page.unit
                            }
                            Rectangle { visible: content.list; anchors.bottom: parent.bottom; width: parent.width; height: page.unit; color: page.shade }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: if (!page.hudState.keyboardNavigation) page.hoverCard(card.index, this, {x:mouseX,y:mouseY})
                                onPositionChanged: function(mouse) { page.hoverCard(card.index, this, mouse); }
                                acceptedButtons:Qt.LeftButton|Qt.RightButton
                                onClicked:function(mouse){if(mouse.button===Qt.RightButton){var p=mapToItem(null,mouse.x,mouse.y);rhine.magazine.showSongMenu("profile",card.index,(card.modelData.provider||"netease")+":"+card.modelData.id,p.x,p.y);}else rhine.action("profile:item:"+card.index);}
                            }
                            Rectangle {
                                objectName: "profileCardPlay"
                                x: art.width - width - 9 * page.unit; y: art.height - height - 9 * page.unit
                                width: (content.list ? 27 : 36) * page.unit; height: width; radius: width / 2
                                color: "#eeeDE4"; visible: card.playable
                                opacity: card.focused ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Label { anchors.centerIn: parent; text: page.hudState.profilePlayKey === card.modelData.key ? "…" : "▶"; color: "#666f50"; font.pixelSize: 16 * page.unit }
                                MouseArea { anchors.fill: parent; enabled: card.focused && !page.hudState.profilePlayKey; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action("profile:play:" + card.index) }
                            }
                        }
                    }
                    Rectangle {
                        visible: page.hudState.profileOwn && page.hudState.profileSection === "music" && page.hudState.profileFilter === "created" && !page.hudState.profileMore
                        width: (cards.width - (cards.columns - 1) * cards.spacing) / cards.columns
                        height: width + 66 * page.unit; color: "transparent"
                        Rectangle { width: parent.width; height: width; color: page.shade; Label { anchors.centerIn: parent; text: "+"; color: page.muted; font.pixelSize: 55 * page.unit; font.weight: Font.Light } }
                        Label { y: parent.width + 10 * page.unit; text: "创建歌单" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action("profile:create") }
                    }
                }
                Label { visible: !!page.hudState.profileError; width: parent.width; text: page.hudState.profileError || ""; wrapMode: Text.Wrap; color: page.muted; font.pixelSize: 16 * page.unit }
                Label { visible: !page.hudState.profileLoading && !page.hudState.profileError && (page.hudState.profileRows || []).length === 0; text: "暂无可展示的内容"; color: page.muted }
                Control { visible: !!page.hudState.profileError; label: "重新加载 ↗"; action: "profile:retry" }
                Control { visible: page.hudState.profileMore; label: "加载更多 ↓"; action: "profile:more" }
                Label { visible: page.hudState.profileLoading; text: "正在读取…"; color: page.muted }
            }
            Connections { target: rhine; function onStateChanged() { var key = page.hudState.profileID + ":" + page.hudState.profileSection + ":" + page.hudState.profileFilter; if (reading.session !== key) { reading.session = key; reading.contentY = 0; } } }
            property string session: ""
        }
    }
}
