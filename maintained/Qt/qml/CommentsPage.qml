import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: page
    objectName: "commentsPage"
    property var hudState: rhine.state
    property var rows: hudState.commentsRows || []
    property string session: hudState.commentsSession || ""
    readonly property color ink: hudState.dark ? "#eeeDE6" : "#25291f"
    readonly property color muted: hudState.dark ? "#a0a495" : "#75796b"
    readonly property color accent: hudState.dark ? "#bac39b" : "#707956"
    readonly property color line: hudState.dark ? "#41463b" : "#d8d8ca"
    readonly property real unit: Math.max(0.58, height / Math.max(1, hudState.commentsBounds ? hudState.commentsBounds.height : 260))
    property string modelSession: ""
    property var scrollMemory: ({})
    property bool restoringScroll: false
    function navigateKey(key) {
        var step = key === "ArrowDown" ? 1 : key === "ArrowUp" ? -1 : 0;
        if (step) { reading.cancelFlick(); reading.contentY = Math.max(0, Math.min(Math.max(0, reading.contentHeight - reading.height), reading.contentY + step * 60 * page.unit)); }
    }
    onRowsChanged: modelSync.restart()
    onSessionChanged: modelSync.restart()
    onHudStateChanged: modelSync.restart()
    Timer { id: modelSync; interval: 0; onTriggered: page.syncRows() }
    Timer {
        id: restoreScroll; interval: 0
        property real savedY: 0
        onTriggered: {
            if (page.hudState.commentsOpen === false) return;
            reading.contentY = Math.max(0, Math.min(savedY, reading.contentHeight - reading.height));
            page.restoringScroll = false;
        }
    }
    property string featuredSignature: ""
    ListModel { id: featuredItems; dynamicRoles: true }
    Component.onCompleted: syncRows()
    function syncRows() {
        // A closing Loader must not reset models while their delegates tear down.
        if (hudState.commentsOpen === false) return;
        var featured = hudState.commentsFeatured || [];
        var signature = JSON.stringify(featured);
        if (signature !== featuredSignature) {
            featuredSignature = signature;
            featuredItems.clear();
            for (var f = 0; f < featured.length; ++f) featuredItems.append({entry: featured[f]});
        }
        var reset = modelSession !== session || rows.length < items.count;
        for (var i = 0; !reset && i < items.count; ++i) {
            reset = items.get(i).entry.id !== rows[i].id;
        }
        var savedY = Number(scrollMemory[session] || 0);
        if (reset) { restoringScroll = true; items.clear(); modelSession = session; reading.contentY = 0; }
        for (var j = items.count; j < rows.length; ++j) items.append({entry: rows[j]});
        if (reset) { restoreScroll.savedY = savedY; restoreScroll.restart(); }
    }
    ListModel { id: items; dynamicRoles: true }
    component Avatar: Item {
        id: avatar
        property string url: ""
        property string userID: ""
        property string name: ""
        Rectangle { anchors.fill: parent; radius: width / 2; color: page.hudState.dark ? "#394032" : "#dfe2d5" }
        Text {
            anchors.centerIn: parent
            visible: portrait.status !== Image.Ready
            text: avatar.name.slice(0, 1)
            color: page.muted; font.family: rhineFontFamily; font.pixelSize: avatar.width * .4
        }
        Rectangle { id: circle; width: avatar.width; height: avatar.height; radius: width / 2; color: "white"; visible: false }
        ShaderEffectSource { id: circleTexture; sourceItem: circle; hideSource: true; visible: false; live: true }
        Image {
            id: portrait
            objectName: "commentAvatarImage"
            anchors.fill: parent
            source: avatar.url.replace("http://", "https://")
            sourceSize: Qt.size(96, 96)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: circleTexture }
        }
        MouseArea {
            anchors.fill: parent
            enabled: Number(avatar.userID) > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: rhine.action("profile:open:" + avatar.userID)
        }
    }
    component CommentCard: Column {
        id: comment
        required property var entry
        property bool expanded: false
        spacing: 7 * page.unit
        Item {
            width: parent.width
            height: 32 * page.unit
            Avatar {
                width: 32 * page.unit; height: width
                url: comment.entry.avatar || ""
                userID: String(comment.entry.userID || "")
                name: comment.entry.author || "匿名用户"
            }
            Text {
                id: authorLabel
                objectName: "commentAuthor"
                x: 44 * page.unit; y: 7 * page.unit
                width: Math.min(implicitWidth, Math.max(1, parent.width - 172 * page.unit))
                text: comment.entry.author || "匿名用户"
                textFormat: Text.PlainText
                color: page.accent
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                MouseArea {
                    anchors.fill: parent
                    enabled: Number(comment.entry.userID || 0) > 0
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: rhine.action("profile:open:" + comment.entry.userID)
                }
            }
            Text {
                objectName: "commentDate"
                x: authorLabel.x + authorLabel.width + 16 * page.unit
                y: 9 * page.unit
                text: comment.entry.date || ""
                color: page.muted
                font.family: rhineFontFamily
                font.pixelSize: 14 * page.unit
            }
        }
        Text {
            id: body
            x: 44 * page.unit
            width: parent.width - x
            text: comment.entry.content || ""
            textFormat: Text.PlainText
            color: page.ink
            font.family: rhineFontFamily
            font.pixelSize: 17 * page.unit
            lineHeight: 1.5
            wrapMode: Text.Wrap
            maximumLineCount: comment.expanded ? 10000 : 2
            elide: Text.ElideRight
        }
        Rectangle {
            x: 44 * page.unit
            width: parent.width - x
            height: quote.implicitHeight + 16 * page.unit
            visible: !!comment.entry.quote && !!comment.entry.quote.content
            color: page.hudState.dark ? "#30362b" : "#e1e4d7"
            Avatar {
                x: 10 * page.unit; y: 8 * page.unit
                width: 20 * page.unit; height: width
                url: comment.entry.quote ? comment.entry.quote.avatar || "" : ""
                userID: comment.entry.quote ? String(comment.entry.quote.userID || "") : ""
                name: comment.entry.quote ? comment.entry.quote.author || "" : ""
            }
            Text {
                id: quote
                x: 38 * page.unit
                y: 8 * page.unit
                width: parent.width - x - 10 * page.unit
                text: comment.entry.quote && comment.entry.quote.content ? (comment.entry.quote.author || "原评论") + "：" + comment.entry.quote.content : ""
                textFormat: Text.PlainText
                color: page.muted
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                wrapMode: Text.Wrap
                maximumLineCount: comment.expanded ? 10000 : 2
                elide: Text.ElideRight
            }
        }
        Item {
            x: 44 * page.unit
            width: parent.width - x
            height: 18 * page.unit
            Text {
                text: Number(comment.entry.likes || 0).toLocaleString(Qt.locale("zh_CN"), "f", 0) + " 赞"
                color: page.muted
                font.family: rhineFontFamily
                font.pixelSize: 14 * page.unit
            }
            Text {
                id: expand
                anchors.right: parent.right
                visible: body.truncated || quote.truncated || comment.expanded
                text: comment.expanded ? "收起 ↑" : "展开全文 ↓"
                color: page.accent
                font.family: rhineFontFamily
                font.pixelSize: 15 * page.unit
                Accessible.role: Accessible.Button
                Accessible.name: text
                Accessible.onPressAction: comment.expanded = !comment.expanded
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: comment.expanded = !comment.expanded
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: page.line }
        Item { width: 1; height: 7 * page.unit }
    }
    Flickable {
        id: reading
        onContentYChanged: if (!page.restoringScroll && page.modelSession === page.session) page.scrollMemory[page.session] = contentY
        objectName: "commentsReading"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: content
            width: reading.width
            spacing: 10 * page.unit
            Text {
                visible: (page.hudState.commentsFeatured || []).length > 0
                text: "精选评论"
                color: page.accent
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                font.weight: Font.DemiBold
            }
            Repeater {
                model: featuredItems
                delegate: CommentCard {
                    required property var model
                    width: content.width
                    entry: model.entry
                }
            }
            Item {
                width: parent.width
                height: 20 * page.unit
                Text { text: "最新评论"; color: page.accent; font.family: rhineFontFamily; font.pixelSize: 16 * page.unit; font.weight: Font.DemiBold }
                Text { anchors.right: parent.right; text: page.hudState.commentsTotal > 0 ? Number(page.hudState.commentsTotal).toLocaleString(Qt.locale("zh_CN"), "f", 0) + " 条" : ""; color: page.muted; font.family: rhineFontFamily; font.pixelSize: 14 * page.unit }
            }
            Repeater {
                model: items
                delegate: CommentCard {
                    required property var model
                    width: content.width
                    entry: model.entry
                }
            }
            Text {
                width: parent.width
                visible: items.count === 0 && !page.hudState.commentsLoading && !page.hudState.commentsError
                text: "这里还没有评论"
                color: page.muted
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                topPadding: 12 * page.unit
                bottomPadding: 12 * page.unit
            }
            Text {
                width: parent.width
                visible: !!page.hudState.commentsError
                text: page.hudState.commentsError || ""
                textFormat: Text.PlainText
                color: page.muted
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                wrapMode: Text.Wrap
            }
            Item {
                width: parent.width
                height: 48 * page.unit
                Rectangle {
                    id: more
                    objectName: "commentsLoadMore"
                    width: 196 * page.unit
                    height: 36 * page.unit
                    anchors.centerIn: parent
                    visible: page.hudState.commentsMore || page.hudState.commentsLoading || !!page.hudState.commentsError
                    color: page.hudState.dark ? "#39422f" : "#e0e3d3"
                    Text {
                        anchors.centerIn: parent
                        text: page.hudState.commentsLoading ? "正在读取评论…" : page.hudState.commentsError ? "重新读取" : "加载更多 ↓"
                        color: page.ink
                        font.family: rhineFontFamily
                        font.pixelSize: 16 * page.unit
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: page.hudState.commentsError ? "重新读取评论" : "加载更多评论"
                    Accessible.onPressAction: if (!page.hudState.commentsLoading) rhine.action(page.hudState.commentsError ? "comments:retry" : "comments:more")
                    MouseArea { anchors.fill: parent; enabled: !page.hudState.commentsLoading; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action(page.hudState.commentsError ? "comments:retry" : "comments:more") }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !more.visible && items.count > 0
                    text: "已经读到最后一条了"
                    color: page.muted
                    font.family: rhineFontFamily
                    font.pixelSize: 15 * page.unit
                }
            }
        }
    }
}
