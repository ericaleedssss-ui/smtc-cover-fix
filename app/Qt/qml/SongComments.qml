// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_comments.go commentsPane/commentRow, Qt playback API adapter.
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects

Item {
    id:page
    objectName:"songComments"
    readonly property var state:rhine.state
    readonly property var hot:state.commentsFeatured||[]
    readonly property var latest:state.commentsRows||[]
    readonly property bool empty:!hot.length&&!latest.length
    property bool requested:false
    onLatestChanged:requested=false
    onHotChanged:Qt.callLater(loadNearEnd)
    function loadNearEnd(){if(visible&&!empty&&!requested&&state.commentsMore&&!state.commentsLoading&&!state.commentsError&&reading.contentHeight-reading.contentY<reading.height*2){requested=true;rhine.action("comments:more");}}
    Component.onCompleted:Qt.callLater(loadNearEnd)
    Connections {target:rhine;function onStateChanged(){Qt.callLater(page.loadNearEnd);}}
    component Heading:Text {property string label;text:label;font.family:rhineFontFamily;font.pixelSize:13;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});color:"#8cffffff";topPadding:18;leftPadding:12;bottomPadding:6}
    component Comment:Item {
        id:comment
        required property var entry
        objectName:"detailComment_"+entry.id
        width:reading.width-8;height:Math.max(34,body.implicitHeight)+24
        Rectangle {id:avatar;x:12;y:12;width:34;height:34;radius:17;color:"#1affffff"
            Text {anchors.centerIn:parent;text:String(comment.entry.author||"").slice(0,1);font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;color:"#99ffffff"}
            ProfileArtwork {anchors.fill:parent;url:comment.entry.avatar||"";sourceSize:Qt.size(96,96);layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:avatarMask}}
            Item {id:avatarMask;anchors.fill:parent;visible:false;layer.enabled:true;Rectangle {anchors.fill:parent;radius:17;color:"white"}}
            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;enabled:!!comment.entry.userID;onClicked:rhine.action("profile:open:"+comment.entry.userID)}
        }
        Column {id:body;x:58;y:12;width:parent.width-x-12;spacing:6
            Item {width:parent.width;height:20
                Text {width:parent.width-like.width-8;text:comment.entry.author||"匿名用户";elide:Text.ElideRight;font.family:rhineFontFamily;font.pixelSize:13;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:authorHit.containsMouse?"white":"#99ffffff"
                    MouseArea {id:authorHit;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;enabled:!!comment.entry.userID;onClicked:rhine.action("profile:open:"+comment.entry.userID)}
                }
                Controls.AbstractButton {id:like;objectName:"detailCommentLike_"+comment.entry.id;anchors.right:parent.right;y:-3;width:count.implicitWidth+29;height:26;hoverEnabled:true;enabled:!page.state.commentsPending;opacity:enabled?1:.5;Accessible.name:comment.entry.liked?"取消赞":"赞";onClicked:rhine.action("comments:like:"+comment.entry.id)
                    background:Rectangle {radius:13;color:like.hovered?"#0fffffff":"transparent"}
                    contentItem:Row {spacing:4;RhineIcon {width:13;height:13;anchors.verticalCenter:parent.verticalCenter;name:"cloudyThumb";color:comment.entry.liked?"#ef6575":like.hovered?"#bfffffff":"#6bffffff"} Text {id:count;anchors.verticalCenter:parent.verticalCenter;text:comment.entry.likes>0?String(Math.floor(comment.entry.likes)):"";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:comment.entry.liked?"#ef6575":"#6bffffff"}}
                }
            }
            Text {objectName:"detailCommentBody";width:parent.width;text:comment.entry.content||"";textFormat:Text.PlainText;wrapMode:Text.Wrap;lineHeight:1.55;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:15;color:"#ebffffff"}
            Rectangle {width:parent.width;height:quote.implicitHeight+16;radius:14;color:"#12ffffff";visible:!!comment.entry.quote&&!!comment.entry.quote.content
                Text {id:quote;x:12;y:8;width:parent.width-24;text:comment.entry.quote?"@"+(comment.entry.quote.author||"")+"："+(comment.entry.quote.content||""):"";textFormat:Text.PlainText;wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;lineHeight:1.5;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;color:"#99ffffff"}
            }
            Text {text:(comment.entry.date||"")+(comment.entry.location?" · "+comment.entry.location:"");font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:Math.round(11.5);color:"#61ffffff"}
        }
    }
    Flickable {id:reading;objectName:"detailCommentsReading";anchors.fill:parent;visible:!page.empty;clip:true;contentWidth:width;contentHeight:content.implicitHeight+48;boundsBehavior:Flickable.StopAtBounds
        onContentYChanged:page.loadNearEnd()
        onHeightChanged:Qt.callLater(page.loadNearEnd)
        Column {id:content;width:reading.width-8;y:4;spacing:2
            Text {objectName:"commentActionError";width:parent.width;visible:!!text;text:page.state.commentsActionError||"";wrapMode:Text.Wrap;color:"#ffadb6";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;bottomPadding:visible?14:0}
            Heading {visible:page.hot.length>0;label:"精彩评论"}
            Repeater {model:page.hot;delegate:Comment {required property var modelData;entry:modelData}}
            Heading {label:"最新评论 "+Math.floor(page.state.commentsTotal||0)}
            Repeater {model:page.latest;delegate:Comment {required property var modelData;entry:modelData}}
            Item {width:parent.width;height:56
                Text {anchors.centerIn:parent;text:page.state.commentsLoading?"正在读取评论…":page.state.commentsError?"加载失败，点按重试":!page.state.commentsMore?"没有更多评论了":"";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12;color:"#59ffffff"}
                MouseArea {anchors.fill:parent;enabled:!!page.state.commentsError;cursorShape:Qt.PointingHandCursor;onClicked:{page.requested=false;rhine.action("comments:retry");}}
            }
        }
    }
    Column {anchors.centerIn:parent;visible:page.empty;spacing:14;width:parent.width
        RhineIcon {anchors.horizontalCenter:parent.horizontalCenter;width:40;height:40;name:"comment";color:"#4dffffff";visible:!page.state.commentsLoading&&!page.state.commentsError}
        Text {width:parent.width;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;text:page.state.commentsLoading?"正在读取评论…":page.state.commentsError||"还没有评论，快来抢沙发";font.family:rhineFontFamily;font.pixelSize:page.state.commentsError?15:17;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:"#73ffffff"}
        Controls.AbstractButton {anchors.horizontalCenter:parent.horizontalCenter;width:72;height:32;visible:!!page.state.commentsError;onClicked:rhine.action("comments:retry");background:Rectangle {radius:16;color:"#24ffffff"}contentItem:Text {text:"重试";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;color:"white";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}}
    }
}
