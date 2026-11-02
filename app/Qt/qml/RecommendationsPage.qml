import QtQuick

Item {
    id: page
    objectName: "recommendationsPage"
    property var hudState: rhine.state
    property string session: hudState.recommendationsSession || ""
    property var playlists: hudState.recommendationPlaylists || []
    property var songs: hudState.recommendationSongs || []
    readonly property real unit: height / Math.max(1, hudState.recommendationsBounds ? hudState.recommendationsBounds.height : 224)
    readonly property color ink: hudState.dark ? "#eeede6" : "#25291f"
    readonly property color muted: hudState.dark ? "#a0a495" : "#75796b"
    readonly property color accent: hudState.dark ? "#bac39b" : "#707956"
    onSessionChanged: reading.contentY = 0
    function navigateKey(key) {
        var step = key === "ArrowDown" ? 1 : key === "ArrowUp" ? -1 : 0;
        if (step) { reading.cancelFlick(); reading.contentY = Math.max(0, Math.min(Math.max(0, reading.contentHeight - reading.height), reading.contentY + step * 60 * page.unit)); }
    }
    Flickable {
        id: reading
        objectName: "recommendationsReading"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        WheelHandler {
            target: null
            onWheel: function(event) {
                reading.cancelFlick();
                var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 58 * page.unit;
                reading.contentY = Math.max(0, Math.min(Math.max(0, reading.contentHeight - reading.height), reading.contentY - delta));
                event.accepted = true;
            }
        }
        Column {
            id: content
            width: reading.width - 8 * page.unit
            spacing: 18 * page.unit
            Column {
                width: parent.width
                spacing: 13 * page.unit
                visible: page.playlists.length > 0
                Text {
                    text: "相关歌单"
                    color: page.accent
                    font.family: rhineFontFamily
                    font.pixelSize: 16 * page.unit
                    font.weight: Font.DemiBold
                }
                Row {
                    width: parent.width
                    spacing: 24 * page.unit
                    Repeater {
                        model: page.playlists
                        delegate: Column {
                            id: card
                            required property var modelData
                            required property int index
                            width: (content.width - 48 * page.unit) / 3
                            spacing: 8 * page.unit
                            Rectangle {
                                width: Math.min(card.width, 72 * page.unit)
                                height: width
                                color: page.hudState.dark ? "#363c31" : "#dedfd4"
                                Image {
                                    anchors.fill: parent
                                    source: card.modelData.cover || ""
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 256
                                    sourceSize.height: 256
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !card.modelData.cover
                                    text: "歌单"
                                    font.family: rhineFontFamily
                                    font.pixelSize: 15 * page.unit
                                    color: page.muted
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rhine.action("music:recommend-playlist:" + card.index)
                                }
                            }
                            Text {
                                objectName: "recommendationPlaylistTitle"
                                width: parent.width
                                text: card.modelData.title || ""
                                textFormat: Text.PlainText
                                color: page.ink
                                font.family: rhineFontFamily
                                font.pixelSize: 16 * page.unit
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 20 * page.unit
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                height: 44 * page.unit
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rhine.action("music:recommend-playlist:" + card.index)
                                }
                            }
                        }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 8 * page.unit
                visible: page.songs.length > 0
                Text {
                    text: "相似歌曲"
                    color: page.accent
                    font.family: rhineFontFamily
                    font.pixelSize: 16 * page.unit
                    font.weight: Font.DemiBold
                    bottomPadding: 3 * page.unit
                }
                Repeater {
                    model: page.songs
                    delegate: Item {
                        id: song
                        required property var modelData
                        required property int index
                        width: content.width
                        height: 44 * page.unit
                        Text {
                            y: 2 * page.unit
                            width: parent.width * 0.62 - 16 * page.unit
                            text: song.modelData.title || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: rhineFontFamily
                            font.pixelSize: 16 * page.unit
                            color: page.ink
                        }
                        Text {
                            x: parent.width * 0.62
                            y: 5 * page.unit
                            width: Math.max(1, parent.width * 0.38 - 76 * page.unit)
                            text: song.modelData.artist || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: rhineFontFamily
                            font.pixelSize: 14 * page.unit
                            color: page.muted
                        }
                        Text {
                            anchors.right: parent.right
                            y: 4 * page.unit
                            text: song.modelData.timeLabel || ""
                            font.family: rhineFontFamily
                            font.pixelSize: 14 * page.unit
                            color: page.muted
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: page.hudState.dark ? "#41463b" : "#d8d8ca"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons:Qt.LeftButton|Qt.RightButton
                            onClicked:function(mouse){if(mouse.button===Qt.RightButton){var p=mapToItem(null,mouse.x,mouse.y);rhine.magazine.showSongMenu("recommendations",song.index,(song.modelData.provider||"netease")+":"+song.modelData.id,p.x,p.y);}else rhine.action("music:recommend-song:"+song.index);}
                        }
                    }
                }
            }
            Text {
                width: parent.width
                visible: page.hudState.recommendationsLoading || !!page.hudState.recommendationsError || (page.playlists.length === 0 && page.songs.length === 0)
                text: page.hudState.recommendationsLoading ? "正在读取推荐…" : page.hudState.recommendationsError || "这首歌暂时没有相关推荐"
                color: page.muted
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                wrapMode: Text.Wrap
            }
            Text {
                visible: !!page.hudState.recommendationsError && !page.hudState.recommendationsLoading
                text: "重新读取 ↗"
                color: page.accent
                font.family: rhineFontFamily
                font.pixelSize: 16 * page.unit
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rhine.action("music:recommend-retry") }
            }
            Item { width: 1; height: 10 * page.unit }
        }
    }
}
