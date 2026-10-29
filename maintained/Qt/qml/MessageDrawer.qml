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
    property var panelBounds: ({})
    readonly property real typeUnit: Math.max(.9,unit)
    readonly property var info: controller.state
    readonly property color ink: dark ? "#eeece4" : "#343c32"
    readonly property color muted: dark ? "#b5b8ab" : "#7b8075"
    readonly property color accent: dark ? "#b4c6a5" : "#6f8562"
    readonly property bool chatting: !!info.peer
    readonly property real destination: panelBounds.width!==undefined ? Number(panelBounds.x)*unit : parent.width-width-18*unit
    parent: Controls.Overlay.overlay
    x: destination
    y: panelBounds.y!==undefined ? Number(panelBounds.y)*unit : 116*unit
    width: Math.min(parent.width-16, (panelBounds.width!==undefined ? Number(panelBounds.width) : Math.min(430,Math.max(320,parent.width/unit*.29)))*unit)
    height: Math.min((panelBounds.height!==undefined ? Number(panelBounds.height) : 842)*unit,parent.height-y-12*unit)
    padding: 0
    modal: true
    dim: false
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onAboutToShow: { emojiPicker.close(); controller.setOpen(true); }
    onOpened: { x=Qt.binding(()=>drawer.destination); messageFrost.refresh(); }
    onClosed: { emojiPicker.close(); controller.setOpen(false); }
    enter: Transition { NumberAnimation { property: "x"; from: drawer.parent.width; to: drawer.destination; duration: 200; easing.type: Easing.OutCubic } NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
    exit: Transition { NumberAnimation { property: "x"; to: drawer.parent.width; duration: 160; easing.type: Easing.InCubic } NumberAnimation { property: "opacity"; to: 0; duration: 130 } }
    function dismiss() { if(!visible)return false; if(emojiPicker.visible){emojiPicker.close();return true;} if(chatting){controller.leaveConversation();return true;}close();return true; }
    Connections {target:drawer.controller;function onChanged(){if(!drawer.info.open&&drawer.opened)drawer.close();}}
    component Label: Text {
        color: drawer.ink; textFormat: Text.PlainText
        font.family: rhineFontFamily; font.pixelSize: 14*drawer.typeUnit
        elide: Text.ElideRight
    }
    component Button: Controls.Button {
        font.family: rhineFontFamily; font.pixelSize: 12*drawer.typeUnit
        implicitHeight: 32*drawer.unit; leftPadding: 6*drawer.unit;rightPadding:6*drawer.unit
        contentItem: Label {text: parent.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;opacity:parent.enabled?1:.45;font.pixelSize:12*drawer.typeUnit}
        background: Rectangle {radius:7*drawer.unit;color:parent.hovered?(drawer.dark?"#454f3e":"#dce2d4"):"transparent"}
    }
    component Badge: Rectangle {
        property var count
        visible: count !== undefined && count !== null && Number(count)>0
        width: Math.max(17*drawer.unit, badgeText.implicitWidth+9*drawer.unit); height:17*drawer.unit;radius:height/2;color:"#c95454"
        Label {id:badgeText;anchors.centerIn:parent;text:Number(parent.count)>999?"999+":String(parent.count);color:"#fffaf5";font.pixelSize:10*drawer.typeUnit}
    }
    component Avatar: Item {
        property string url: ""
        property string name: ""
        property string badge: ""
        width:48*drawer.unit;height:width
        Rectangle {anchors.fill:parent;radius:width/2;color:drawer.dark?"#4b5444":"#d6dccf"
            Label {anchors.centerIn:parent;text:parent.parent.name.slice(0,1)||"人";color:drawer.accent;font.pixelSize:19*drawer.typeUnit}
        }
        Image {id:avatarImage;anchors.fill:parent;source:parent.url;asynchronous:true;cache:true;sourceSize:Qt.size(96,96);fillMode:Image.PreserveAspectCrop;visible:status===Image.Ready
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
            layer.effect:MultiEffect {maskEnabled:true;maskSource:avatarMask}
        }
        Rectangle {id:avatarMask;anchors.fill:parent;radius:width/2;visible:false;layer.enabled:true}
        Rectangle {anchors.right:parent.right;anchors.bottom:parent.bottom;width:18*drawer.unit;height:width;radius:width/2;visible:parent.badge!=="";color:parent.badge==="VIP"?"#a69058":"#c45b54"
            Label {anchors.centerIn:parent;text:parent.parent.badge==="VIP"?"VIP":"V";color:"#fffaf2";font.pixelSize:9*drawer.typeUnit}
        }
    }
    background: DrawerFrost {
        id:messageFrost;background:drawer.sceneBackground
        sampleX:drawer.destination;sampleY:drawer.y;unit:drawer.unit;dark:drawer.dark
    }
    contentItem: Item {
        MouseArea {anchors.fill:parent;onWheel:event=>event.accepted=true}
        Item {
            id:heading;x:18*drawer.unit;y:12*drawer.unit;width:parent.width-36*drawer.unit;height:34*drawer.unit
            Button {id:backButton;objectName:"messageBack";visible:drawer.chatting;text:"‹";width:28*drawer.unit;onClicked:drawer.controller.leaveConversation()}
            Label {objectName:"messageHeadingTitle";anchors.left:parent.left;anchors.leftMargin:drawer.chatting?backButton.width+5*drawer.unit:0;anchors.right:headingActions.left;anchors.rightMargin:10*drawer.unit;text:drawer.chatting?drawer.info.peerName:"消息";font.pixelSize:18*drawer.typeUnit;font.weight:Font.DemiBold;height:parent.height;verticalAlignment:Text.AlignVCenter}
            Row {id:headingActions;anchors.right:parent.right;spacing:3*drawer.unit
                Button {objectName:"messageRefresh";text:"刷新";width:48*drawer.unit;enabled:drawer.info.supported&&!drawer.info.loading;onClicked:drawer.controller.refresh()}
                Button {objectName:"messageClose";text:"×";width:28*drawer.unit;onClicked:drawer.close()}
            }
        }
        Row {
            id:tabs;x:18*drawer.unit;y:55*drawer.unit;height:39*drawer.unit;visible:!drawer.chatting;spacing:4*drawer.unit
            Repeater {model:["私信","评论","@我","通知"]
                delegate:Item {required property int index;required property string modelData;width:(drawer.width-145*drawer.unit)/4;height:39*drawer.unit
                    Label {anchors.centerIn:parent;text:parent.modelData;color:drawer.info.tab===parent.index?drawer.ink:drawer.muted;font.pixelSize:15*drawer.typeUnit}
                    Badge {x:parent.width-18*drawer.unit;y:0;count:drawer.info.counts[parent.index]}
                    Rectangle {anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:22*drawer.unit;height:2*drawer.unit;radius:1;color:drawer.accent;visible:drawer.info.tab===parent.index}
                    MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:drawer.controller.selectTab(parent.index)}
                }
            }
            Button {objectName:"messageAllRead";width:86*drawer.unit;text:drawer.width<380*drawer.typeUnit?"全读":"◎ 一键全读";onClicked:drawer.controller.allRead();Controls.ToolTip.visible:hovered;Controls.ToolTip.text:"当前接口未提供批量已读，点击查看说明"}
        }
        Row {id:newChat;x:20*drawer.unit;y:101*drawer.unit;spacing:5*drawer.unit;visible:!drawer.chatting&&drawer.info.tab===0&&drawer.info.supported
            Controls.TextField {id:recipient;objectName:"messageRecipient";width:drawer.width-128*drawer.unit;height:32*drawer.unit;placeholderText:"输入对方用户 ID";font.family:rhineFontFamily;font.pixelSize:12*drawer.typeUnit;color:drawer.ink;selectByMouse:true;validator:RegularExpressionValidator {regularExpression:/[0-9]{0,20}/} background:Rectangle {radius:7;color:drawer.dark?"#40483a":"#80ffffff";border.color:drawer.dark?"#66705d":"#d4d8cd"}}
            Button {text:"新私信";onClicked:drawer.controller.startConversation(recipient.text,"")}
        }
        Label {id:feedback;x:22*drawer.unit;width:parent.width-44*drawer.unit;y:drawer.chatting?56*drawer.unit:(newChat.visible?140:100)*drawer.unit;visible:text!=="";text:!drawer.info.supported?drawer.info.permission:(drawer.info.error||drawer.info.feedback||"");font.pixelSize:12*drawer.typeUnit;color:drawer.info.error?"#b3544d":drawer.muted;wrapMode:Text.Wrap;elide:Text.ElideNone}
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
                Label {x:rowName.x;y:43*drawer.unit;width:parent.width-x-48*drawer.unit;text:drawer.displayMessage(message.text).replace(/\n/g," ");color:drawer.muted;font.pixelSize:12*drawer.typeUnit}
                Label {anchors.right:parent.right;anchors.rightMargin:10*drawer.unit;y:18*drawer.unit;text:drawer.timeLabel(message.time);color:drawer.muted;font.pixelSize:10*drawer.typeUnit}
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
                Label {id:stamp;anchors.horizontalCenter:parent.horizontalCenter;text:drawer.historyTimeLabel(modelData.time);font.pixelSize:10*drawer.typeUnit;color:drawer.muted;visible:index===0||Number(modelData.time)-Number((drawer.controller.history[index-1]||{}).time)>=300000;height:visible?28*drawer.unit:0}
                Avatar {y:stamp.height;x:modelData.mine?parent.width-width:0;width:34*drawer.unit;height:width;url:modelData.avatar||"";name:modelData.name||""}
                Rectangle {id:bubble;y:stamp.height;x:modelData.mine?parent.width-width-44*drawer.unit:44*drawer.unit;width:Math.min(parent.width-44*drawer.unit,Math.max(42*drawer.unit,bubbleText.implicitWidth+28*drawer.unit));height:body.implicitHeight+24*drawer.unit;radius:13*drawer.unit;color:modelData.mine?(drawer.dark?"#596a4c":"#d9e2ce"):(drawer.dark?"#454d3f":"#b8f8f7f0")
                    Column {id:body;x:14*drawer.unit;y:12*drawer.unit;width:parent.width-28*drawer.unit;spacing:8*drawer.unit
                        Text {id:bubbleText;width:Math.min(implicitWidth,chat.width-72*drawer.unit);text:drawer.displayMessage(modelData.text);color:drawer.ink;wrapMode:Text.Wrap;textFormat:Text.PlainText;font.family:rhineFontFamily;font.pixelSize:14*drawer.typeUnit}
                        Image {visible:!!modelData.image;source:modelData.image||"";width:Math.min(240*drawer.unit,body.width);height:visible?width:0;fillMode:Image.PreserveAspectFit;asynchronous:true;cache:true}
                        Image {visible:!!modelData.cover;source:modelData.cover||"";width:48*drawer.unit;height:visible?width:0;fillMode:Image.PreserveAspectCrop;asynchronous:true;cache:true}
                        Label {visible:!!modelData.target;width:body.width;text:"打开分享的"+(modelData.kind==="song"?"歌曲":modelData.kind==="album"?"专辑":"歌单");font.pixelSize:12*drawer.typeUnit;color:drawer.accent
                            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:drawer.controller.openResource(index)}
                        }
                    }
                }
            }
            Label {anchors.centerIn:parent;visible:chat.count===0&&!drawer.info.loading;text:"暂无会话记录";color:drawer.muted}
        }
        Rectangle {id:composer;objectName:"messageComposer";visible:drawer.chatting;x:18*drawer.unit;anchors.bottom:parent.bottom;anchors.bottomMargin:18*drawer.unit;width:parent.width-36*drawer.unit;height:106*drawer.unit;radius:12*drawer.unit;color:drawer.dark?"#454d3f":"#80fffef8";border.color:drawer.dark?"#606c54":"#cbd1c3"
            Controls.TextArea {id:editor;objectName:"messageEditor";x:8*drawer.unit;y:6*drawer.unit;width:parent.width-16*drawer.unit;height:60*drawer.unit;placeholderText:"说点什么吧";text:drawer.controller.draft;color:drawer.ink;font.family:rhineFontFamily;font.pixelSize:14*drawer.typeUnit;wrapMode:TextEdit.Wrap;selectByMouse:true;background:null;enabled:!drawer.info.sending
                onTextChanged:if(activeFocus)drawer.controller.setDraft(text)
                Keys.onPressed:event=>{if((event.modifiers&Qt.ControlModifier)&&event.key===Qt.Key_Return){drawer.controller.send();event.accepted=true;}}
            }
            Label {x:12*drawer.unit;anchors.bottom:parent.bottom;anchors.bottomMargin:13*drawer.unit;text:editor.text.length+(" / 1000");font.pixelSize:10*drawer.typeUnit;color:drawer.muted}
            Button {id:emojiButton;objectName:"messageEmoji";anchors.right:sendButton.left;anchors.bottom:parent.bottom;anchors.margins:6*drawer.unit;width:30*drawer.unit;text:"☺";enabled:!drawer.info.sending;onClicked:emojiPicker.visible?emojiPicker.close():emojiPicker.open();Controls.ToolTip.visible:hovered;Controls.ToolTip.text:"插入表情"}
            Button {id:sendButton;objectName:"messageSend";anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:6*drawer.unit;text:drawer.info.sending?"正在发送…":"发送";enabled:!drawer.info.sending&&editor.text.trim().length>0&&editor.text.length<=1000;onClicked:drawer.controller.send()}
        }
    }
    Controls.Popup {
        id:emojiPicker;objectName:"messageEmojiPicker"
        parent:drawer.contentItem
        x:Math.max(8*drawer.unit,drawer.width-width-18*drawer.unit)
        y:Math.max(8*drawer.unit,drawer.contentItem.height-(106+18)*drawer.unit-height-6*drawer.unit)
        width:Math.min(drawer.width-36*drawer.unit,250*drawer.typeUnit);padding:10*drawer.unit
        height:emojiGrid.implicitHeight+20*drawer.unit
        closePolicy:Controls.Popup.CloseOnEscape
        background:Rectangle {radius:10*drawer.unit;color:drawer.dark?"#363e30":"#f0f0e6";border.color:drawer.dark?"#66725c":"#cdd4c3"}
        contentItem:Grid {
            id:emojiGrid;columns:6;spacing:3*drawer.unit
            Repeater {model:["😊","🥰","😂","😭","🤔","😠","😍","🥺","😅","😴","😎","😳","👍","👏","🙏","💪","❤️","💔","🎵","🎉","🌹","☀️","✨","🤝"]
                delegate:Controls.Button {
                    required property string modelData
                    required property int index
                    objectName:"messageEmojiChoice_"+index
                    width:(emojiPicker.availableWidth-15*drawer.unit)/6;height:30*drawer.typeUnit
                    contentItem:Text {text:parent.modelData;font.pixelSize:20*drawer.typeUnit;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                    background:Rectangle {radius:5;color:parent.hovered?"#44778761":"transparent"}
                    onClicked:{editor.forceActiveFocus();editor.insert(editor.cursorPosition,modelData);drawer.controller.setDraft(editor.text);emojiPicker.close();}
                }
            }
        }
    }
    function displayMessage(text) {
        var faces={"生气":"😠","大笑":"😄","可爱":"😊","憨笑":"😁","色":"😍","惊恐":"😱","流泪":"😢","大哭":"😭","亲亲":"😘","哀伤":"😞","呲牙":"😁","眨眼":"😉","汗":"😅","微笑":"🙂","爱心":"❤️","心碎":"💔","鼓掌":"👏","强":"👍","握手":"🤝","拜":"👋","睡":"😴","思考":"🤔"};
        return String(text||"").replace(/\[([^\]]+)\]/g,(all,name)=>faces[name]||all);
    }
    function historyTimeLabel(t) {
        if(!t)return "";var d=new Date(Number(t));var now=new Date();return Qt.formatDateTime(d,d.getFullYear()===now.getFullYear()?"MM-dd hh:mm":"yyyy-MM-dd hh:mm");
    }
    function timeLabel(t) {
        if(!t)return "";var date=new Date(Number(t));var now=new Date();var diff=now.getTime()-date.getTime();
        if(diff>=0&&diff<60000)return "刚刚";
        if(date.toDateString()===now.toDateString())return Qt.formatDateTime(date,"hh:mm");
        var yesterday=new Date(now.getTime()-86400000);if(date.toDateString()===yesterday.toDateString())return "昨天 "+Qt.formatDateTime(date,"hh:mm");
        return Qt.formatDateTime(date,date.getFullYear()===now.getFullYear()?"MM-dd":"yyyy-MM-dd");
    }
}
