import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls

Controls.Popup {
    id: drawer
    objectName: "messageDrawer"
    required property var controller
    required property Item sceneBackground
    property bool dark: false
    property real unit: 1
    readonly property var info: controller.state
    readonly property color ink: dark ? "#eeece4" : "#343c32"
    readonly property color muted: dark ? "#b5b8ab" : "#7b8075"
    readonly property color accent: dark ? "#b4c6a5" : "#6f8562"
    readonly property bool chatting: !!info.peer
    readonly property real destination: Math.max(8, parent.width-width-12)
    parent: Controls.Overlay.overlay
    x: destination
    y: 56*unit
    width: Math.min(490*unit, parent.width-16)
    height: Math.max(180,parent.height-y-24*unit)
    padding: 0
    modal: true
    dim: false
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onAboutToShow: controller.setOpen(true)
    onOpened: { x=Qt.binding(()=>drawer.destination); sample.scheduleUpdate(); }
    onClosed: controller.setOpen(false)
    enter: Transition { NumberAnimation { property: "x"; from: drawer.parent.width; to: drawer.destination; duration: 200; easing.type: Easing.OutCubic } NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
    exit: Transition { NumberAnimation { property: "x"; to: drawer.parent.width; duration: 160; easing.type: Easing.InCubic } NumberAnimation { property: "opacity"; to: 0; duration: 130 } }
    function dismiss() { if(!visible)return false; if(chatting){controller.leaveConversation();return true;}close();return true; }
    Connections {target:drawer.controller;function onChanged(){if(!drawer.info.open&&drawer.opened)drawer.close();}}
    component Label: Text {
        color: drawer.ink; textFormat: Text.PlainText
        font.family: rhineFontFamily; font.pixelSize: 14*drawer.unit
        elide: Text.ElideRight
    }
    component Button: Controls.Button {
        font.family: rhineFontFamily; font.pixelSize: 12*drawer.unit
        implicitHeight: 32*drawer.unit; leftPadding: 10*drawer.unit;rightPadding:10*drawer.unit
        contentItem: Label {text: parent.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;opacity:parent.enabled?1:.45;font.pixelSize:12*drawer.unit}
        background: Rectangle {radius:7*drawer.unit;color:parent.hovered?(drawer.dark?"#454f3e":"#dce2d4"):"transparent"}
    }
    component Badge: Rectangle {
        property var count
        visible: count !== undefined && count !== null && Number(count)>0
        width: Math.max(17*drawer.unit, badgeText.implicitWidth+9*drawer.unit); height:17*drawer.unit;radius:height/2;color:"#c95454"
        Label {id:badgeText;anchors.centerIn:parent;text:Number(parent.count)>999?"999+":String(parent.count);color:"#fffaf5";font.pixelSize:10*drawer.unit}
    }
    component Avatar: Item {
        property string url: ""
        property string name: ""
        property string badge: ""
        width:48*drawer.unit;height:width
        Rectangle {anchors.fill:parent;radius:width/2;color:drawer.dark?"#4b5444":"#d6dccf"
            Label {anchors.centerIn:parent;text:parent.parent.name.slice(0,1)||"人";color:drawer.accent;font.pixelSize:19*drawer.unit}
        }
        Image {id:avatarImage;anchors.fill:parent;source:parent.url;asynchronous:true;cache:true;sourceSize:Qt.size(96,96);fillMode:Image.PreserveAspectCrop;visible:status===Image.Ready
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
            layer.effect:MultiEffect {maskEnabled:true;maskSource:avatarMask}
        }
        Rectangle {id:avatarMask;anchors.fill:parent;radius:width/2;visible:false;layer.enabled:true}
        Rectangle {anchors.right:parent.right;anchors.bottom:parent.bottom;width:18*drawer.unit;height:width;radius:width/2;visible:parent.badge!=="";color:parent.badge==="VIP"?"#a69058":"#c45b54"
            Label {anchors.centerIn:parent;text:parent.parent.badge==="VIP"?"VIP":"V";color:"#fffaf2";font.pixelSize:9*drawer.unit}
        }
    }
    background: Item {
        // A single bounded snapshot and high-opacity warm tint: no full-window live blur.
        ShaderEffectSource {id:sample;sourceItem:drawer.sceneBackground;sourceRect:Qt.rect(drawer.destination,drawer.y,drawer.width,drawer.height);textureSize:Qt.size(Math.max(1,drawer.width/2),Math.max(1,drawer.height/2));live:false;hideSource:false;visible:false
            onSourceRectChanged:if(drawer.visible)scheduleUpdate()
        }
        Rectangle {id:panelMask;anchors.fill:parent;radius:20*drawer.unit;visible:false;layer.enabled:true}
        MultiEffect {anchors.fill:parent;source:sample;blurEnabled:true;blurMax:32;blur:1;autoPaddingEnabled:false;maskEnabled:true;maskSource:panelMask;visible:GraphicsInfo.api!==GraphicsInfo.Software}
        Rectangle {anchors.fill:parent;radius:20*drawer.unit;color:drawer.dark?"#ef30352d":"#ebece8de";border.width:1;border.color:drawer.dark?"#507f8676":"#80fffef5"
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
            layer.effect:MultiEffect {shadowEnabled:true;shadowOpacity:.12;shadowBlur:.65;shadowVerticalOffset:4;shadowColor:"#252b20"}
        }
    }
    contentItem: Item {
        MouseArea {anchors.fill:parent;onWheel:event=>event.accepted=true}
        Row {
            id:heading;x:18*drawer.unit;y:12*drawer.unit;spacing:5*drawer.unit
            Button {objectName:"messageBack";visible:drawer.chatting;text:"‹";onClicked:drawer.controller.leaveConversation()}
            Label {text:drawer.chatting?drawer.info.peerName:"消息";font.pixelSize:18*drawer.unit;font.weight:Font.DemiBold;width:Math.max(70,drawer.width-190*drawer.unit);height:32*drawer.unit;verticalAlignment:Text.AlignVCenter}
            Button {objectName:"messageRefresh";text:"刷新";enabled:drawer.info.supported&&!drawer.info.loading;onClicked:drawer.controller.refresh()}
            Button {objectName:"messageClose";text:"×";onClicked:drawer.close()}
        }
        Row {
            id:tabs;x:18*drawer.unit;y:55*drawer.unit;height:39*drawer.unit;visible:!drawer.chatting;spacing:4*drawer.unit
            Repeater {model:["私信","评论","@我","通知"]
                delegate:Item {required property int index;required property string modelData;width:(drawer.width-145*drawer.unit)/4;height:39*drawer.unit
                    Label {anchors.centerIn:parent;text:parent.modelData;color:drawer.info.tab===parent.index?drawer.ink:drawer.muted;font.pixelSize:15*drawer.unit}
                    Badge {x:parent.width-18*drawer.unit;y:0;count:drawer.info.counts[parent.index]}
                    Rectangle {anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:22*drawer.unit;height:2*drawer.unit;radius:1;color:drawer.accent;visible:drawer.info.tab===parent.index}
                    MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:drawer.controller.selectTab(parent.index)}
                }
            }
            Button {objectName:"messageAllRead";text:"◎ 一键全读";onClicked:drawer.controller.allRead();Controls.ToolTip.visible:hovered;Controls.ToolTip.text:"当前接口未提供批量已读，点击查看说明"}
        }
        Row {id:newChat;x:20*drawer.unit;y:101*drawer.unit;spacing:5*drawer.unit;visible:!drawer.chatting&&drawer.info.tab===0&&drawer.info.supported
            Controls.TextField {id:recipient;objectName:"messageRecipient";width:drawer.width-128*drawer.unit;height:32*drawer.unit;placeholderText:"输入对方用户 ID";font.family:rhineFontFamily;font.pixelSize:12*drawer.unit;color:drawer.ink;selectByMouse:true;validator:RegularExpressionValidator {regularExpression:/[0-9]{0,20}/} background:Rectangle {radius:7;color:drawer.dark?"#40483a":"#80ffffff";border.color:drawer.dark?"#66705d":"#d4d8cd"}}
            Button {text:"新私信";onClicked:drawer.controller.startConversation(recipient.text,"")}
        }
        Label {id:feedback;x:22*drawer.unit;width:parent.width-44*drawer.unit;y:drawer.chatting?56*drawer.unit:(newChat.visible?140:100)*drawer.unit;visible:text!=="";text:!drawer.info.supported?drawer.info.permission:(drawer.info.error||drawer.info.feedback||"");font.pixelSize:12*drawer.unit;color:drawer.info.error?"#b3544d":drawer.muted;wrapMode:Text.Wrap;elide:Text.ElideNone}
        ListView {
            id:messages;objectName:"messageList";visible:!drawer.chatting&&drawer.info.supported
            x:12*drawer.unit;width:parent.width-24*drawer.unit;y:Math.max((newChat.visible?140:100)*drawer.unit,feedback.y+(feedback.visible?feedback.implicitHeight+10*drawer.unit:0));height:parent.height-y-16*drawer.unit
            clip:true;model:drawer.controller;boundsBehavior:Flickable.StopAtBounds;reuseItems:true;spacing:2*drawer.unit
            Controls.ScrollBar.vertical:Controls.ScrollBar {}
            delegate:Rectangle {
                required property var message;required property int index
                width:messages.width;height:82*drawer.unit;radius:10*drawer.unit;color:rowMouse.containsMouse?(drawer.dark?"#304f5c42":"#406c8653"):"transparent"
                Avatar {id:rowAvatar;x:9*drawer.unit;anchors.verticalCenter:parent.verticalCenter;url:message.avatar||"";name:message.name||"";badge:message.badge||""}
                Label {id:rowName;x:rowAvatar.x+rowAvatar.width+12*drawer.unit;y:17*drawer.unit;width:parent.width-x-95*drawer.unit;text:message.name||"平台通知";font.weight:Font.Medium}
                Label {x:rowName.x;y:43*drawer.unit;width:parent.width-x-48*drawer.unit;text:message.text.replace(/\n/g," ");color:drawer.muted;font.pixelSize:12*drawer.unit}
                Label {anchors.right:parent.right;anchors.rightMargin:10*drawer.unit;y:18*drawer.unit;text:drawer.timeLabel(message.time);color:drawer.muted;font.pixelSize:10*drawer.unit}
                Badge {anchors.right:parent.right;anchors.rightMargin:10*drawer.unit;y:45*drawer.unit;count:message.unread}
                MouseArea {id:rowMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:drawer.controller.activate(parent.index)}
            }
            footer:Button {width:messages.width;visible:drawer.info.more||drawer.info.loading;text:drawer.info.loading?"正在加载…":"加载更多";enabled:!drawer.info.loading;onClicked:drawer.controller.more()}
            Label {anchors.centerIn:parent;visible:messages.count===0;text:drawer.info.loading?"正在读取消息…":drawer.info.error?"读取失败，点击顶部刷新重试":"暂无消息";color:drawer.muted}
        }
        ListView {
            id:chat;objectName:"messageHistory";visible:drawer.chatting
            x:18*drawer.unit;width:parent.width-36*drawer.unit;y:Math.max(64*drawer.unit,feedback.y+(feedback.visible?feedback.implicitHeight+10*drawer.unit:0));height:Math.max(0,composer.y-y-12*drawer.unit)
            clip:true;model:drawer.controller.history;spacing:16*drawer.unit;boundsBehavior:Flickable.StopAtBounds
            property string peer:drawer.info.peer||""
            property bool wasAtEnd:true
            onMovementStarted:wasAtEnd=atYEnd
            onPeerChanged: {wasAtEnd=true;Qt.callLater(()=>chat.positionViewAtEnd())}
            onCountChanged:if(wasAtEnd)Qt.callLater(()=>chat.positionViewAtEnd())
            Controls.ScrollBar.vertical:Controls.ScrollBar {}
            header:Button {width:chat.width;visible:drawer.info.more||drawer.info.loading;text:drawer.info.loading?"正在读取…":"加载更早的消息";enabled:!drawer.info.loading;onClicked:{chat.wasAtEnd=false;drawer.controller.older();}}
            delegate:Item {required property var modelData;required property int index;width:chat.width;height:stamp.height+bubble.height+8*drawer.unit
                Label {id:stamp;anchors.horizontalCenter:parent.horizontalCenter;text:drawer.timeLabel(modelData.time);font.pixelSize:10*drawer.unit;color:drawer.muted;height:24*drawer.unit}
                Avatar {y:stamp.height;width:32*drawer.unit;height:width;visible:!modelData.mine;url:modelData.avatar||"";name:modelData.name||""}
                Rectangle {id:bubble;y:stamp.height;x:modelData.mine?parent.width-width:42*drawer.unit;width:Math.min(parent.width-44*drawer.unit,Math.max(100*drawer.unit,bubbleText.implicitWidth+28*drawer.unit));height:body.implicitHeight+24*drawer.unit;radius:13*drawer.unit;color:modelData.mine?(drawer.dark?"#596a4c":"#d9e2ce"):(drawer.dark?"#454d3f":"#b8f8f7f0")
                    Column {id:body;x:14*drawer.unit;y:12*drawer.unit;width:parent.width-28*drawer.unit;spacing:8*drawer.unit
                        Text {id:bubbleText;width:Math.min(implicitWidth,chat.width-72*drawer.unit);text:modelData.text;color:drawer.ink;wrapMode:Text.Wrap;textFormat:Text.PlainText;font.family:rhineFontFamily;font.pixelSize:14*drawer.unit}
                        Image {visible:!!modelData.image;source:modelData.image||"";width:Math.min(240*drawer.unit,body.width);height:visible?width:0;fillMode:Image.PreserveAspectFit;asynchronous:true;cache:true}
                        Image {visible:!!modelData.cover;source:modelData.cover||"";width:48*drawer.unit;height:visible?width:0;fillMode:Image.PreserveAspectCrop;asynchronous:true;cache:true}
                        Label {visible:!!modelData.target;width:body.width;text:"打开分享的"+(modelData.kind==="song"?"歌曲":modelData.kind==="album"?"专辑":"歌单");font.pixelSize:12*drawer.unit;color:drawer.accent
                            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:drawer.controller.openResource(index)}
                        }
                    }
                }
            }
            Label {anchors.centerIn:parent;visible:chat.count===0&&!drawer.info.loading;text:"暂无会话记录";color:drawer.muted}
        }
        Rectangle {id:composer;objectName:"messageComposer";visible:drawer.chatting;x:18*drawer.unit;anchors.bottom:parent.bottom;anchors.bottomMargin:18*drawer.unit;width:parent.width-36*drawer.unit;height:140*drawer.unit;radius:12*drawer.unit;color:drawer.dark?"#454d3f":"#80fffef8";border.color:drawer.dark?"#606c54":"#cbd1c3"
            Controls.TextArea {id:editor;objectName:"messageEditor";x:8*drawer.unit;y:6*drawer.unit;width:parent.width-16*drawer.unit;height:90*drawer.unit;placeholderText:"说点什么吧";text:drawer.controller.draft;color:drawer.ink;font.family:rhineFontFamily;font.pixelSize:14*drawer.unit;wrapMode:TextEdit.Wrap;selectByMouse:true;background:null;enabled:!drawer.info.sending
                onTextChanged:if(activeFocus)drawer.controller.setDraft(text)
                Keys.onPressed:event=>{if((event.modifiers&Qt.ControlModifier)&&event.key===Qt.Key_Return){drawer.controller.send();event.accepted=true;}}
            }
            Label {x:12*drawer.unit;anchors.bottom:parent.bottom;anchors.bottomMargin:13*drawer.unit;text:editor.text.length+" / 1000 · Ctrl+Enter 发送";font.pixelSize:10*drawer.unit;color:drawer.muted}
            Button {objectName:"messageSend";anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:6*drawer.unit;text:drawer.info.sending?"正在发送…":"发送";enabled:!drawer.info.sending&&editor.text.trim().length>0&&editor.text.length<=1000;onClicked:drawer.controller.send()}
        }
    }
    function timeLabel(t) {
        if(!t)return "";var date=new Date(Number(t));var now=new Date();var diff=now.getTime()-date.getTime();
        if(diff>=0&&diff<60000)return "刚刚";
        if(date.toDateString()===now.toDateString())return Qt.formatDateTime(date,"hh:mm");
        var yesterday=new Date(now.getTime()-86400000);if(date.toDateString()===yesterday.toDateString())return "昨天 "+Qt.formatDateTime(date,"hh:mm");
        return Qt.formatDateTime(date,date.getFullYear()===now.getFullYear()?"MM-dd":"yyyy-MM-dd");
    }
}
