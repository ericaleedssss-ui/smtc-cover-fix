import QtQuick
import QtQuick.Controls.Basic as Controls
Item {
    id:root
    required property var controller
    required property Item background
    readonly property var menu:controller.songMenu
    readonly property bool dark:rhine.state.dark===true
    readonly property color ink:dark?"#e5e9de":"#414b3c"
    Controls.Popup {
        id:popup
        objectName:"songContextMenu"
        parent:Controls.Overlay.overlay
        x:Math.max(10,Math.min(root.width-width-10,Number(root.menu.x)||0))
        y:Math.max(10,Math.min(root.height-height-12,Number(root.menu.y)||0))
        width:260;padding:9;modal:true;dim:false
        visible:root.menu.visible===true
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        onClosed:if(root.menu.visible)root.controller.closeMenu()
        background:Rectangle {color:root.dark?"#f02b3028":"#f5f3ed";radius:17;border.color:root.dark?"#42685454":"#d9ddd0";border.width:1}
        contentItem:Column {
            spacing:2
            Text {width:242;padding:9;text:root.menu.title||"";elide:Text.ElideRight;font.family:rhineFontFamily;font.pixelSize:12;color:root.dark?"#a4ad98":"#89917d"}
            Repeater {
                model:[{op:"play",icon:"play",text:"播放",permission:"playable"},
                    {op:"next",icon:"next",text:"下一首播放",permission:"playable"},
                    {op:"comments",icon:"comment",text:"查看评论",permission:"canComments"},
                    {op:"collect",icon:"collect",text:"收藏到歌单",permission:"canCollect",sep:true},
                    {op:"download",icon:"download",text:"下载",permission:"canDownload"},
                    {op:"share",icon:"share",text:"分享",permission:""},
                    {op:"copy",icon:"link",text:"复制链接",permission:""},
                    {op:"remove",icon:"remove",text:"从歌单中删除",permission:"canRemove",sep:true}]
                delegate:Item {
                    id:menuRow
                    required property var modelData
                    readonly property bool allowed:!modelData.permission || root.menu[modelData.permission]===true
                    objectName:"songMenu_"+modelData.op
                    width:242;height:42+(modelData.sep?10:0)
                    Rectangle {visible:parent.modelData.sep===true;x:10;width:parent.width-20;height:1;y:3;color:root.dark?"#24596550":"#16717f62"}
                    Rectangle {x:0;y:parent.modelData.sep?10:0;width:parent.width;height:40;radius:9;color:hit.containsMouse&&menuRow.allowed?(root.dark?"#354834":"#e4eada"):"transparent"
                        opacity:menuRow.allowed?1:.36
                        RhineIcon {x:12;y:10;width:20;height:20;name:modelData.icon;color:modelData.op==="remove"?"#9c6c60":root.ink}
                        Text {x:45;y:10;text:modelData.op==="comments"?modelData.text+(Number(root.menu.comments)>=0?"（"+root.menu.comments+"）":""):modelData.op==="remove"&&root.menu.isQueue?"从播放队列移除":modelData.text;font.family:rhineFontFamily;font.pixelSize:15;color:root.ink}
                        MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;cursorShape:menuRow.allowed?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:if(menuRow.allowed)root.controller.songAction(modelData.op)}
                    }
                }
            }
        }
    }
    Controls.Popup {
        id:removeDialog
        parent:Controls.Overlay.overlay
        anchors.centerIn:parent
        width:340;padding:24;modal:true
        visible:root.controller.removalCount>0
        closePolicy:Controls.Popup.CloseOnEscape
        onClosed:if(root.controller.removalCount>0)root.controller.cancelRemoval()
        background:Rectangle {color:root.dark?"#2a3026":"#f4f2e9";radius:18;border.color:"#d2d8c7"}
        contentItem:Column {spacing:20
            Text {width:292;wrapMode:Text.Wrap;text:"从这个歌单中移除 "+root.controller.removalCount+" 首歌曲？";font.family:rhineFontFamily;font.pixelSize:17;color:root.ink}
            Row {spacing:18
                Controls.Button {text:"取消";onClicked:root.controller.cancelRemoval()}
                Controls.Button {text:"确认移除";onClicked:root.controller.removeConfirmed()}
            }
        }
    }
}
