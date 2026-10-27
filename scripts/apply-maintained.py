"""Small, reviewed UI changes applied after the pinned G53 source patch."""
from pathlib import Path

nav = Path("Qt/qml/SideNavigation.qml")
source = nav.read_text(encoding="utf-8")

def replace_once(old: str, new: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one G53 anchor, found {count}: {old[:90]!r}")
    source = source.replace(old, new, 1)

replace_once(
    '                NavRow { label: navigation.createdOpen ? "创建的歌单  ﹀" : "创建的歌单  ›"; icon: "♫"; onInvoked: navigation.createdOpen = !navigation.createdOpen }',
    '''                Rectangle {
                    width: parent.width - 16 * navigation.unit
                    x: 8 * navigation.unit
                    height: 1 * navigation.unit
                    color: rhine.state.dark ? "#f0f1e8" : "#62695e"
                    opacity: 0.16
                }
                Item {
                    width: list.width
                    height: 43 * navigation.typeUnit
                    readonly property int count: (rhine.state.navigationCreated || []).length
                    NavRow {
                        width: parent.width - 39 * navigation.unit
                        label: navigation.createdOpen ? "创建的歌单  (" + parent.count + ") ﹀" : "创建的歌单  (" + parent.count + ") ›"
                        icon: "♫"
                        onInvoked: navigation.createdOpen = !navigation.createdOpen
                    }
                    Rectangle {
                        id: createPlaylistSurface
                        width: 30 * navigation.unit
                        height: 30 * navigation.unit
                        anchors.right: parent.right
                        anchors.rightMargin: 5 * navigation.unit
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 9 * navigation.unit
                        color: createPlaylistMouse.containsMouse ? (rhine.state.dark ? "#33cbd5b9" : "#24929f7e") : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 21 * navigation.typeUnit
                            color: rhine.state.dark ? "#eeeee8" : "#43473d"
                        }
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
                }''')

replace_once(
    '                NavRow { label: navigation.collectedOpen ? "收藏的歌单  ﹀" : "收藏的歌单  ›"; icon: "☆"; onInvoked: navigation.collectedOpen = !navigation.collectedOpen }',
    '''                Rectangle {
                    width: parent.width - 16 * navigation.unit
                    x: 8 * navigation.unit
                    height: 1 * navigation.unit
                    color: rhine.state.dark ? "#f0f1e8" : "#62695e"
                    opacity: 0.16
                }
                NavRow {
                    label: navigation.collectedOpen
                        ? "收藏的歌单  (" + (rhine.state.navigationCollected || []).length + ") ﹀"
                        : "收藏的歌单  (" + (rhine.state.navigationCollected || []).length + ") ›"
                    icon: "☆"
                    onInvoked: navigation.collectedOpen = !navigation.collectedOpen
                }''')

nav.write_text(source, encoding="utf-8")
print("Applied G53 maintained navigation: playlist counts, separators, create-playlist button.")
