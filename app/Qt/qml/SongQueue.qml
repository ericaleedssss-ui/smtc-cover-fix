// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_nowplaying.go queuePane; existing RHINE queue actions adapter.
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects

Item {
    id:pane
    objectName:"songQueue"
    readonly property var rows:rhinePipelineLegacy?rhine.nowPlaying.queue:[]
    readonly property var queueRevision:rhine.nowPlaying.queueRevision
    readonly property int entryCount:rhinePipelineLegacy?rows.length:rhine.nowPlaying.queueCount
    readonly property int current:Number(rhine.state.queueIndex)
    property int shownIndex:-1
    function sync(){if(current>=0&&current!==shownIndex){list.positionViewAtIndex(current,shownIndex<0?ListView.Beginning:ListView.Contain);shownIndex=current;}}
    onCurrentChanged:Qt.callLater(sync)
    Component.onCompleted:Qt.callLater(sync)
    Item {id:header;width:parent.width;height:visible?36:0;visible:pane.entryCount>1
        Text {x:10;anchors.verticalCenter:parent.verticalCenter;width:parent.width-clear.width-30;text:"共 "+pane.entryCount+" 首 · 接下来 "+Math.max(0,pane.entryCount-pane.current-1)+" 首";elide:Text.ElideRight;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:"#80ffffff"}
        Controls.AbstractButton {id:clear;objectName:"detailQueueClear";anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;width:96;height:28;visible:pane.current<pane.entryCount-1;enabled:!rhine.state.roamActive;hoverEnabled:true;Accessible.name:"清空待播";onClicked:rhine.action("player:clear")
            background:Rectangle {radius:14;color:clear.hovered?"#24ffffff":"#1affffff"}
            contentItem:Item {Row {anchors.centerIn:parent;spacing:5;RhineIcon {width:12;height:12;anchors.verticalCenter:parent.verticalCenter;name:"cloudyTrash";color:"white"}Text {text:"清空待播";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:"white"}}}
        }
    }
    ListView {id:list;objectName:"detailQueueList";anchors.top:header.bottom;anchors.bottom:parent.bottom;width:parent.width;model:rhinePipelineLegacy?pane.rows:pane.entryCount;clip:true;spacing:2;topMargin:8;bottomMargin:40;boundsBehavior:Flickable.StopAtBounds
        delegate:Controls.AbstractButton {
            id:row
            required property int index
            readonly property var modelData:rhinePipelineLegacy?pane.rows[index]:(pane.queueRevision,rhine.nowPlaying.queueRow(index))
            objectName:"detailQueueRow_"+modelData.index
            readonly property bool current:Number(modelData.index)===pane.current
            width:list.width;height:58;padding:0;hoverEnabled:true;enabled:!modelData.unavailable;opacity:enabled?1:.4;Accessible.name:modelData.title||"歌曲"
            onClicked:if(!current)rhine.action("player:queue-play:"+modelData.index+":"+encodeURIComponent(modelData.key))
            background:Rectangle {radius:14;color:row.current?"#1fffffff":row.hovered?"#14ffffff":"transparent";Behavior on color {ColorAnimation {duration:RhineTheme.noMotion?0:120}}}
            contentItem:Item {
                ProfileArtwork {id:art;x:10;y:8;width:42;height:42;url:row.modelData.cover||"";sourceSize:Qt.size(96,96);layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:mask}}
                Item {id:mask;width:42;height:42;visible:false;layer.enabled:true;Rectangle {anchors.fill:parent;radius:8;color:"white"}}
                PlayingBars {x:66;anchors.verticalCenter:parent.verticalCenter;visible:row.current;color:"#ef6575"}
                Column {x:row.current?92:66;anchors.verticalCenter:parent.verticalCenter;width:Math.max(1,parent.width-x-clock.width-54);spacing:3
                    Text {width:parent.width;text:row.modelData.title||"";elide:Text.ElideRight;font.family:rhineFontFamily;font.pixelSize:14;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:"white"}
                    RhineCreditLine {width:parent.width;pixelSize:12.5;song:row.modelData;includeAlbum:false;idleColor:"#8cffffff";onActivated:function(target){rhine.magazine.openSongCredit(row.modelData.key,target);}}
                }
                Text {id:clock;anchors.right:remove.left;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;text:{var n=Math.floor(Number(row.modelData.duration||0)/1000);return Math.floor(n/60)+":"+String(n%60).padStart(2,"0");}font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:"#66ffffff"}
                Controls.AbstractButton {id:remove;objectName:"detailQueueRemove_"+row.modelData.index;anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;width:26;height:26;hoverEnabled:true;enabled:!row.current&&!rhine.state.roamActive;opacity:enabled&&(row.hovered||hovered||visualFocus)?1:0;Accessible.name:"从待播清单移除";onClicked:rhine.action("player:remove:"+row.modelData.index+":"+encodeURIComponent(row.modelData.key))
                    background:Rectangle {radius:13;color:remove.hovered?"#18ffffff":"transparent"}
                    contentItem:Item {RhineIcon {anchors.centerIn:parent;name:"cloudyClose";color:"#99ffffff";width:12;height:12}}
                }
            }
            TapHandler {acceptedButtons:Qt.RightButton;onTapped:{var p=row.mapToItem(null,row.width,0);rhine.magazine.showSongMenu("queue",row.modelData.index,row.modelData.key,p.x,p.y);}}
        }
    }
}
