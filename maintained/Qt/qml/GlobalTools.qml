import QtQuick
import QtQuick.Controls.Basic as Controls
Item {
    id:tools
    required property Item background
    property real unit:1
    property real topRightReserved:0
    readonly property real occupiedWidth:accountRow.width+24
    readonly property real u:Math.max(.9,unit)
    readonly property bool signedIn:!!rhine.state.accountUID
    readonly property bool profileSupported:rhine.state.accountProvider==="netease"
    readonly property color ink:rhine.state.dark?"#e8eadd":"#384333"
    visible:rhine.state.mode!=="boot"&&rhine.state.viewer!==true
    function openProfile(){if(rhine.state.accountProvider==="local"){rhine.action("saved");return;}if(!signedIn)rhine.action("music:login");else if(profileSupported)rhine.action("profile:open:"+rhine.state.accountUID);else accountInfo.open();}
    function openCollection(filter,lane){if(profileSupported){rhine.action("profile:open:"+rhine.state.accountUID);rhine.action("profile:filter:"+filter);}else{rhine.action("saved");rhine.action("music:collection:"+lane);}}
    function dismiss(){if(switchConfirm.visible){switchConfirm.close();return true;}if(accountInfo.visible){accountInfo.close();return true;}if(accountMenu.visible){accountMenu.close();return true;}return false;}
    component Tool:Rectangle {
        property string iconName
        property string label
        property string action:""
        property bool available:true
        signal invoked()
        width:32*tools.u;height:32*tools.u;radius:8*tools.u
        color:mouse.containsMouse&&available?(rhine.state.dark?"#284f6344":"#16677c58"):"transparent"
        opacity:available?1:.42
        RhineIcon {anchors.centerIn:parent;width:20*tools.u;height:width;name:parent.iconName;color:tools.ink}
        Controls.ToolTip.visible:mouse.containsMouse
        Controls.ToolTip.delay:450
        Controls.ToolTip.text:label
        MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;acceptedButtons:parent.available?Qt.LeftButton:Qt.NoButton;cursorShape:parent.available?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:{if(parent.action)rhine.action(parent.action);parent.invoked();}}
    }
    Item {objectName:"globalBack";x:28*tools.u;y:25*tools.u;width:42*tools.u;height:width
        visible:rhine.state.mode==="detail"||rhine.state.directoryOpen===true||!!rhine.state.modal
        LiquidGlass {anchors.fill:parent;background:tools.background;sampleX:parent.x;sampleY:parent.y;uiScale:tools.u;radius:height/2;dark:rhine.state.dark===true}
        Tool {anchors.centerIn:parent;iconName:"back";label:"返回";action:"back"}
    }
    Row {
        id:accountRow;objectName:"globalAccountBar"
        x:tools.width-width-tools.topRightReserved-12;y:3;spacing:7*tools.u;height:34*tools.u
        Item {objectName:"globalProfile";width:avatar.width+8*tools.u+nickname.width;height:parent.height
            Rectangle {id:avatar;anchors.verticalCenter:parent.verticalCenter;width:28*tools.u;height:width;radius:height/2;color:rhine.state.dark?"#384431":"#dbe0d2";clip:true
                Image {anchors.fill:parent;source:rhine.state.accountAvatar||"";fillMode:Image.PreserveAspectCrop;sourceSize.width:80;sourceSize.height:80;asynchronous:true}
                RhineIcon {anchors.centerIn:parent;width:18*tools.u;height:width;name:"user";color:tools.ink;visible:!rhine.state.accountAvatar}
            }
            Text {id:nickname;x:avatar.width+8*tools.u;width:Math.min(implicitWidth,110*tools.u);height:parent.height;verticalAlignment:Text.AlignVCenter;textFormat:Text.PlainText;text:rhine.state.accountName||(tools.signedIn?"我的账户":"登录");elide:Text.ElideRight;color:tools.ink;font.family:rhineFontFamily;font.pixelSize:13*tools.u}
            MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:tools.openProfile();Controls.ToolTip.visible:containsMouse;Controls.ToolTip.text:tools.signedIn?(tools.profileSupported?"我的主页":"账户信息"):"登录账户"}
        }
        Rectangle {visible:tools.signedIn&&!!rhine.state.accountMember;width:membership.implicitWidth+12*tools.u;height:18*tools.u;radius:4*tools.u;anchors.verticalCenter:parent.verticalCenter;color:rhine.state.dark?"#68755c":"#d6dccb"
            Text {id:membership;anchors.centerIn:parent;text:rhine.state.accountMember||"";textFormat:Text.PlainText;color:tools.ink;font.family:rhineFontFamily;font.pixelSize:10*tools.u;font.weight:Font.Medium}
        }
        Tool {objectName:"globalAccountArrow";iconName:"chevron";label:"账户菜单";onInvoked:accountMenu.popup()}
        Item {width:3*tools.u;height:parent.height}
        Tool {objectName:"globalInbox";iconName:"message";label:"私信 · 尚未启用";available:false}
        Tool {objectName:"globalSearch";iconName:"search";label:"搜索";action:"search"}
        Tool {objectName:"globalSettings";iconName:"settings";label:"设置";action:"settings"}
    }
    Controls.Menu {
        id:accountMenu;objectName:"globalAccountMenu"
        parent:Controls.Overlay.overlay;x:Math.max(12,tools.width-tools.topRightReserved-width-12);y:42*tools.u
        font.family:rhineFontFamily;font.pixelSize:13*tools.u
        palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.text:tools.ink;palette.highlight:rhine.state.dark?"#48573b":"#e0e7d5";palette.highlightedText:tools.ink
        Controls.MenuItem {objectName:"accountMenuProfile";text:rhine.state.accountProvider==="local"?"本地音乐资料库":tools.signedIn?(tools.profileSupported?"个人主页":"个人主页（当前平台暂不支持）"):"登录账户";enabled:!tools.signedIn||tools.profileSupported;onTriggered:tools.openProfile()}
        Controls.MenuItem {objectName:"accountMenuInfo";text:"账户基本信息";onTriggered:accountInfo.open()}
        Controls.MenuSeparator {}
        Controls.MenuItem {objectName:"accountMenuPlaylists";text:"我的歌单";enabled:tools.signedIn;onTriggered:tools.openCollection("created",2)}
        Controls.MenuItem {objectName:"accountMenuCollections";text:"我的收藏";enabled:tools.signedIn;onTriggered:tools.openCollection("collected",3)}
        Controls.MenuItem {objectName:"accountMenuMembership";text:"会员信息";enabled:tools.signedIn;onTriggered:accountInfo.open()}
        Controls.MenuSeparator {}
        Controls.MenuItem {objectName:"accountMenuSettings";text:"账户与平台设置";onTriggered:rhine.action("settings")}
        Controls.MenuItem {objectName:"accountMenuSwitch";text:"切换账号…";enabled:tools.signedIn;onTriggered:switchConfirm.open()}
        Controls.MenuItem {objectName:"accountMenuLogout";text:"退出登录";enabled:tools.signedIn;onTriggered:rhine.action("music:logout")}
    }
    Controls.Popup {
        id:accountInfo;objectName:"accountInfoPopup"
        parent:Controls.Overlay.overlay;width:Math.min(350*tools.u,tools.width-32);height:infoText.implicitHeight+48*tools.u
        x:Math.max(16,tools.width-tools.topRightReserved-width-16);y:46*tools.u;padding:20*tools.u
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        background:Rectangle {radius:12*tools.u;color:rhine.state.dark?"#30382a":"#f3f1e8";border.width:1;border.color:"#70ffffff"}
        contentItem:Text {id:infoText;width:parent.width;textFormat:Text.PlainText;wrapMode:Text.Wrap;lineHeight:1.7;color:tools.ink;font.family:rhineFontFamily;font.pixelSize:13*tools.u
            text:(rhine.state.accountName||"未登录")+"\n"+(tools.signedIn?"账号 ID："+rhine.state.accountUID:"尚未登录账户")+"\n平台："+(rhine.state.accountProviderName||"—")+"\n会员："+(rhine.state.accountMember||"未确认会员权益")+"\n\n会员有效期及详细权益暂未提供。"}
    }
    Controls.Dialog {
        id:switchConfirm;objectName:"accountSwitchDialog";parent:Controls.Overlay.overlay
        title:"切换账号";modal:true;x:(tools.width-width)/2;y:80*tools.u;width:Math.min(380*tools.u,tools.width-32)
        standardButtons:Controls.Dialog.Ok|Controls.Dialog.Cancel
        palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.windowText:tools.ink;palette.text:tools.ink;palette.buttonText:tools.ink;palette.button:rhine.state.dark?"#48573b":"#e0e7d5"
        background:Rectangle {radius:12*tools.u;color:rhine.state.dark?"#30382a":"#f3f1e8";border.width:1;border.color:"#70ffffff"}
        Text {width:parent.width;wrapMode:Text.Wrap;text:"将退出当前账号并打开登录页面。当前播放会停止。";color:tools.ink;font.family:rhineFontFamily;font.pixelSize:13*tools.u}
        onAccepted:{rhine.action("music:logout");rhine.action("music:login");}
    }
}
