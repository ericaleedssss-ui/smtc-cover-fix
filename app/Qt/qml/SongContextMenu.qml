// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_pane.go and ui_songmenu.go, adapted to Qt popup coordinates.
import QtQuick
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls
Item {
    id:root
    required property var controller
    required property Item background
    property real unit:1
    readonly property real u:Math.min(Math.max(.9,unit),Math.max(.65,(height-16)/500))
    readonly property var menu:controller.songMenu
    readonly property bool dark:rhine.state.dark===true||["detail","playing"].indexOf(menu.scope)>=0
    readonly property color ink:dark?"white":"#1d1d1f"
    readonly property color muted:dark?"#99ffffff":"#9e1d1d1f"
    readonly property color faint:dark?"#6bffffff":"#6b1d1d1f"
    property string submenu:""
    function rows(){
        var result=[];
        if(["detail","playing"].indexOf(menu.scope)>=0)result.push({op:"effects",icon:"cloudyWave",text:"音效",note:rhine.soundEffects.info.menuNote});
        result.push({op:"next",icon:"cloudyNext",text:"下一首播放",permission:"playable",sep:result.length>0});
        result.push({op:"copy-title",icon:"cloudyCopy",text:"复制歌名",sep:true});
        result.push({op:"copy-title-artist",icon:"cloudyCopy",text:"复制歌名和歌手"});
        result.push({op:"copy",icon:"link",text:"复制链接"});
        result.push({op:"download",icon:"download",text:"下载到本机",permission:"canDownload",sep:true});
        var people=(menu.artists||[]).filter(function(p){return p.id&&String(p.id)!=="0";});
        people.forEach(function(p,i){result.push({op:"artist:"+p.id,icon:"user",text:p.name,note:"歌手",sep:i===0});});
        if(menu.albumID&&String(menu.albumID)!=="0")result.push({op:"album",icon:"disc",text:menu.album||"专辑",note:"专辑",sep:!people.length});
        result.push({op:"collect",icon:"collect",text:"添加到歌单",permission:"canCollect",child:true,sep:true});
        if(menu.canRemove)result.push({op:"remove",icon:"remove",text:menu.isQueue?"从待播清单移除":"从歌单中删除",sep:true});
        return result;
    }
    function submenuEntries(){
        return (menu.playlists||[]).map(function(p){return {op:"playlist:"+p.id,text:p.title,icon:"disc"};}).concat([{op:"collect",text:"选择其他歌单",icon:"collect"}]);
    }
    Connections {target:root.controller;function onMenuChanged(){if(!root.menu.visible)root.submenu="";}}
    component MenuRow:Controls.AbstractButton {
        id:row
        required property var entry
        readonly property bool allowed:!entry.permission||root.menu[entry.permission]===true
        objectName:"songMenu_"+entry.op
        width:256*root.u;height:38*root.u;padding:0;hoverEnabled:true;enabled:allowed
        Accessible.name:entry.text;Accessible.role:Accessible.MenuItem
        opacity:allowed?1:.36
        background:Rectangle {objectName:"songMenuRowSurface";radius:14*root.u;color:row.down?(root.dark?"#29ffffff":"#1f1d1d1f"):row.hovered||row.visualFocus?(root.dark?"#1affffff":"#121d1d1f"):"transparent";Behavior on color {ColorAnimation {duration:RhineTheme.noMotion?0:100}}}
        contentItem:Item {
            RhineIcon {x:10*root.u;anchors.verticalCenter:parent.verticalCenter;width:16*root.u;height:width;name:({user:"cloudyUser",disc:"cloudyAlbum",download:"cloudyDownload",link:"cloudyLink",back:"cloudyBack",collect:"cloudyAdd"})[row.entry.icon]||row.entry.icon||"disc";color:root.muted}
            Text {x:37*root.u;anchors.verticalCenter:parent.verticalCenter;width:parent.width-x-(note.visible?note.implicitWidth+20*root.u:row.entry.child?30*root.u:10*root.u);text:row.entry.text;elide:Text.ElideRight;font.family:rhineFontFamily;font.pixelSize:13.5*root.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});color:root.ink}
            Text {id:note;anchors.right:parent.right;anchors.rightMargin:10*root.u;anchors.verticalCenter:parent.verticalCenter;visible:!!text;text:row.entry.note||"";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12*root.u;color:root.faint}
            RhineIcon {visible:row.entry.child===true;anchors.right:parent.right;anchors.rightMargin:10*root.u;anchors.verticalCenter:parent.verticalCenter;width:14*root.u;height:width;name:"chevron";rotation:-90;color:root.faint}
        }
        HoverHandler {cursorShape:Qt.PointingHandCursor}
        onClicked:if(entry.op==="back")root.submenu="";else if(entry.child)root.submenu=entry.op;else root.controller.songAction(entry.op)
    }
    component MenuLine:Item {width:256*root.u;height:9*root.u;Rectangle {x:10*root.u;y:4*root.u;width:parent.width-20*root.u;height:.5*root.u;color:root.dark?"#1affffff":"#1a1d1d1f"}}
    Controls.Popup {
        id:popup;objectName:"songContextMenu";parent:Controls.Overlay.overlay
        x:Math.max(8,Math.min(root.width-width-8,Number(root.menu.x)||0))
        y:Math.max(8,Math.min(root.height-height-8,Number(root.menu.y)||0))
        width:268*root.u;padding:6*root.u;modal:true;dim:false;focus:true
        visible:root.menu.visible===true
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        onClosed:if(root.menu.visible)root.controller.closeMenu()
        popupType:Controls.Popup.Item
        enter:Transition {ParallelAnimation {NumberAnimation {property:"opacity";from:0;to:1;duration:RhineTheme.noMotion?0:280;easing.type:Easing.BezierSpline;easing.bezierCurve:[.22,.8,.24,1,1,1]} NumberAnimation {property:"scale";from:rhine.visualPreferences.motion==="full"?.86:1;to:1;duration:RhineTheme.noMotion?0:280;easing.type:Easing.BezierSpline;easing.bezierCurve:[.22,.8,.24,1,1,1]}}}
        exit:Transition {ParallelAnimation {NumberAnimation {property:"opacity";to:0;duration:RhineTheme.noMotion?0:280} NumberAnimation {property:"scale";to:RhineTheme.fullMotion?.97:1;duration:RhineTheme.noMotion?0:280}}}
        background:Item {
            Rectangle {anchors.fill:parent;radius:20*root.u;color:root.dark?"#383837":"#f6f6f8";border.width:.5;border.color:root.dark?"#24ffffff":"#1a000000"}
            PopupGlass {objectName:"songContextGlass";anchors.fill:parent;popup:popup;unit:root.u;radius:20*root.u;dark:root.dark;frosting:.8;tint:.86;refraction:0;rimStrength:0;opacity:.5}
            Rectangle {anchors.fill:parent;radius:20*root.u;color:"transparent";border.width:.5;border.color:root.dark?"#24ffffff":"#1a000000"}
        }
        contentItem:Column {
            spacing:1*root.u
            Column {visible:!root.submenu;width:256*root.u
                Item {width:parent.width;height:58*root.u
                    Rectangle {x:8*root.u;anchors.verticalCenter:parent.verticalCenter;width:40*root.u;height:width;radius:8*root.u;clip:true;color:"#1affffff"
                        ProfileArtwork {anchors.fill:parent;url:root.menu.cover||"";sourceSize:Qt.size(96,96);layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:headMask}}
                        Item {id:headMask;anchors.fill:parent;visible:false;layer.enabled:true;Rectangle {anchors.fill:parent;radius:8*root.u;color:"white"}}
                    }
                    Column {x:59*root.u;anchors.verticalCenter:parent.verticalCenter;width:parent.width-x-8*root.u;spacing:2*root.u
                        Text {width:parent.width;text:root.menu.title||"";elide:Text.ElideRight;font.family:rhineFontFamily;font.pixelSize:13.5*root.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:root.ink}
                        Text {width:parent.width;text:root.menu.artist||"";elide:Text.ElideRight;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12*root.u;color:root.muted}
                    }
                }
                MenuLine {}
                Repeater {model:root.rows();delegate:Column {required property var modelData;spacing:1*root.u;MenuLine {visible:parent.modelData.sep===true}MenuRow {entry:parent.modelData}}}
            }
            Column {visible:!!root.submenu;width:256*root.u;spacing:1*root.u
                MenuRow {entry:({op:"back",text:"添加到歌单",icon:"back"})}
                MenuLine {}
                Controls.ScrollView {width:parent.width;height:Math.min(300*root.u,playlistRows.implicitHeight);clip:true
                    Column {id:playlistRows;spacing:1*root.u;Repeater {model:root.submenuEntries();delegate:MenuRow {required property var modelData;entry:modelData}}}
                }
            }
        }
    }
    RhineDialog {
        id:removeDialog;unit:root.u;dark:root.dark
        title:"移除歌曲";confirmText:"确认移除";destructive:true
        message:"从这个歌单中移除 "+root.controller.removalCount+" 首歌曲？"
        visible:root.controller.removalCount>0
        closePolicy:Controls.Popup.CloseOnEscape
        onClosed:if(root.controller.removalCount>0)root.controller.cancelRemoval()
        onAccepted:root.controller.removeConfirmed()
        onRejected:root.controller.cancelRemoval()
    }
}
