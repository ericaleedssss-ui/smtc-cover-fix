import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls

Item {
    id:tools
    required property Item background
    property Item drawerBackground:background
    property real unit:1
    property real topRightReserved:0
    readonly property real u:Math.max(.9,unit)
    readonly property real occupiedWidth:accountRow.width+24*u
    readonly property bool messageDrawerVisible:inbox.visible
    readonly property bool personalDrawerVisible:library.visible
    readonly property bool membershipVisible:membership.visible
    readonly property bool signedIn:!!rhine.state.accountUID
    readonly property bool dark:rhine.state.dark===true
    readonly property bool reduced:rhine.state.reduced===true||rhine.visualPreferences.motion!=="full"
    readonly property color ink:dark?"#eceee4":"#30382d"
    readonly property color muted:dark?"#c5ccbd":"#5b6654"
    readonly property color accent:dark?"#d8e7bb":"#405a35"
    readonly property var person:(rhine.personal.state.identity||{}).data||({})
    readonly property var level:(rhine.personal.state.level||{}).data||({})
    readonly property var vip:(rhine.personal.state.vip||{}).data||({})
    property string hoverKey:""
    property string previewKey:""
    property bool accountPinned:false
    property string section:"created"
    readonly property bool collectionMode:section==="created"||section==="collected"||section==="albums"
    readonly property var currentPage:rhine.personal.state[section]||({})
    readonly property var previewPage:rhine.personal.state[previewKey==="history"?"songs":"collected"]||({})
    visible:rhine.state.mode!=="boot"&&rhine.state.viewer!==true
    function cover(url){return String(url||"").replace(/^http:/,"https:")}
    function prepare(key){
        if(key==="account"){rhine.personal.load("identity");rhine.personal.load("level");rhine.personal.load("vip")}
        if(key==="messages")rhine.messages.previewCounts()
        if(key==="history")rhine.personal.load("songs")
        if(key==="favorites")rhine.personal.load("collected")
    }
    function hover(key){
        if(key!=="account"&&(identity.visualFocus||vipBadge.visualFocus))tools.forceActiveFocus(Qt.MouseFocusReason)
        leaveTimer.stop();hoverKey=key
        if(library.visible||inbox.visible||accountPinned)return
        if(previewKey&&previewKey!==key){preview.close();accountMenu.close();previewKey=""}
        revealTimer.restart()
    }
    function leave(){revealTimer.stop();leaveTimer.restart()}
    function clearPreview(){if(accountPinned)return;preview.close();accountMenu.close();previewKey="";hoverKey=""}
    function pinAccount(){preview.close();previewKey="account";accountPinned=true;leaveTimer.stop();prepare("account");accountMenu.open()}
    function openVip(){dismiss();rhine.personal.load("vip");membership.open()}
    function openProfile(section){dismiss();if(!signedIn)rhine.action("music:login");else if(rhine.state.accountProvider==="netease"){rhine.action("profile:open:"+rhine.state.accountUID);if(["notes","follows","followers"].indexOf(section)>=0)rhine.action("profile:section:"+section);}else rhine.action("saved")}
    function openLibrary(key){
        leaveTimer.stop();revealTimer.stop()
        clearPreview();accountPinned=false;accountMenu.close();preview.close();inbox.close()
        if(rhine.state.queueOpen)rhine.action("queue-close")
        section=key;rhine.personal.load(key);library.open()
    }
    function openInbox(tab){leaveTimer.stop();revealTimer.stop();clearPreview();accountPinned=false;accountMenu.close();library.close();if(rhine.state.queueOpen)rhine.action("queue-close");rhine.messages.selectTab(tab);inbox.open()}
    function openConversation(uid,name){openInbox(0);rhine.messages.startConversation(uid,name)}
    function selectSection(key){section=key;rhine.personal.load(key);libraryScroll.contentY=0}
    function dismiss(){
        revealTimer.stop();leaveTimer.stop();hoverKey="";previewKey="";accountPinned=false
        if(inbox.dismiss())return true
        if(membership.visible){membership.close();return true}
        if(library.visible){library.close();return true}
        if(switchConfirm.visible){switchConfirm.close();return true}
        if(accountMenu.visible){accountMenu.close();return true}
        if(preview.visible){preview.close();return true}
        return false
    }
    Timer {id:revealTimer;interval:260;onTriggered:{if(!tools.hoverKey||library.visible||inbox.visible||tools.accountPinned)return;tools.previewKey=tools.hoverKey;tools.prepare(tools.previewKey);if(tools.previewKey==="account")accountMenu.open();else if(tools.previewKey!=="settings")preview.open()}}
    Timer {id:leaveTimer;interval:230;onTriggered:tools.clearPreview()}
    Connections {target:rhine.personal;function onChanged(){if(!tools.signedIn){tools.dismiss()}}}
    onSignedInChanged:if(signedIn)vipWarm.restart()
    Component.onCompleted:if(signedIn)vipWarm.start()
    Timer {id:vipWarm;interval:700;onTriggered:rhine.personal.load("vip")}
    // Wait for the Grid to position new rows before deciding which folders are visible.
    Timer {id:prepareFolders;interval:0;onTriggered:{
        if(!library.visible||!libraryGrid.positioned)return
        for(var i=0;i<libraryRows.count;++i){
            var row=libraryRows.itemAt(i)
            if(row&&row.folder&&row.inViewport)row.folderPrepared=true
        }
    }}
    component Label:Text {color:tools.ink;textFormat:Text.PlainText;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*tools.u;elide:Text.ElideRight}
    component Action:Controls.Button {
        property string iconName:"chevron"
        implicitHeight:43*tools.u
        width:parent.width
        contentItem:Item {
            RhineIcon {x:10*tools.u;anchors.verticalCenter:parent.verticalCenter;width:19*tools.u;height:width;name:parent.parent.iconName;color:tools.muted}
            Label {x:40*tools.u;width:parent.width-x-12*tools.u;height:parent.height;verticalAlignment:Text.AlignVCenter;text:parent.parent.text;font.pixelSize:15*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});opacity:parent.parent.enabled?1:.4}
        }
        background:Rectangle {radius:11*tools.u;color:parent.hovered?(tools.dark?"#234e6444":"#126b8050"):"transparent"}
    }
    component Tool:Controls.Control {
        id:tool
        property string keyName
        property string iconName
        property string label
        readonly property bool expanded:tools.hoverKey===keyName||tools.previewKey===keyName||visualFocus
        focusPolicy:Qt.TabFocus
        onVisualFocusChanged:if(visualFocus)tools.hover(keyName);else tools.leave()
        Keys.onReturnPressed:invoked()
        Keys.onSpacePressed:invoked()
        signal invoked()
        width:36*tools.u+(expanded?(caption.implicitWidth+8*tools.u):0);height:34*tools.u
        Behavior on width {NumberAnimation {duration:tools.reduced?0:230;easing.type:Easing.OutCubic}}
        Rectangle {anchors.fill:parent;radius:height/2;color:tools.dark?"#d02b3327":"#60ffffff";border.width:tools.u*.7;border.color:tools.dark?"#50ffffff":"#bbffffff";opacity:tool.expanded?1:0;Behavior on opacity{NumberAnimation{duration:RhineTheme.noMotion?0:150}}}
        RhineIcon {x:8*tools.u;anchors.verticalCenter:parent.verticalCenter;width:20*tools.u;height:width;name:tool.iconName;color:tool.expanded?tools.accent:tools.ink}
        Item {x:33*tools.u;height:parent.height;width:Math.max(0,parent.width-x-10*tools.u);clip:true
            Label {id:caption;objectName:"personalToolCaption";height:parent.height;verticalAlignment:Text.AlignVCenter;text:tool.label;font.pixelSize:15*tools.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:tools.accent;x:tool.expanded?0:-8*tools.u;opacity:tool.expanded?1:0;Behavior on x{NumberAnimation{duration:tools.reduced?0:230;easing.type:Easing.OutCubic}} Behavior on opacity{NumberAnimation{duration:RhineTheme.noMotion?0:160}}}
        }
        Accessible.role:Accessible.Button;Accessible.name:label;Accessible.onPressAction:invoked()
        MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onEntered:tools.hover(tool.keyName);onExited:tools.leave();onClicked:tool.invoked()}
    }
    Item {objectName:"globalBack";x:28*tools.unit;y:75*tools.unit-height/2;width:Math.max(28,42*tools.unit);height:width;visible:rhine.state.mode==="detail"||rhine.state.directoryOpen===true||!!rhine.state.modal
        Rectangle {anchors.fill:parent;radius:width/2;color:tools.dark?"#343b30":"#f5f4ef"}
        RhineIcon {anchors.centerIn:parent;name:"back";width:22*tools.u;height:width;color:tools.ink}
        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action("back")}
    }
    // Search has a dedicated entry instead of competing with personal tools.
    Rectangle {objectName:"globalSearch";x:300*tools.unit;y:60*tools.unit;width:rhine.state.mode==="archive"?148*tools.u:36*tools.u;height:34*tools.u;radius:height/2;color:searchMouse.containsMouse?(tools.dark?"#28ffffff":"#80ffffff"):"transparent"
        RhineIcon {x:8*tools.u;anchors.verticalCenter:parent.verticalCenter;name:"search";width:19*tools.u;height:width;color:tools.muted}
        Label {x:34*tools.u;height:parent.height;verticalAlignment:Text.AlignVCenter;text:"搜索音乐";color:tools.muted;visible:parent.width>100*tools.u;font.pixelSize:12*tools.u}
        MouseArea {id:searchMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action("search")}
    }
    Row {id:accountRow;objectName:"globalAccountBar";x:tools.width-width-tools.topRightReserved-12*tools.u;y:3*tools.u;spacing:5*tools.u;height:34*tools.u
        Controls.Control {id:identity;objectName:"globalProfile";width:avatar.width+nickname.width+(vipBadge.visible?vipBadge.width+10*tools.u:0)+43*tools.u;height:parent.height
            readonly property bool engaged:tools.hoverKey==="account"||visualFocus||vipBadge.visualFocus||accountMenu.visible||membership.visible
            focusPolicy:Qt.TabFocus
            Accessible.role:Accessible.Button;Accessible.name:rhine.state.accountName||"登录账户";Accessible.onPressAction:tools.pinAccount()
            Keys.onReturnPressed:tools.pinAccount()
            Keys.onSpacePressed:tools.pinAccount()
            HoverHandler {id:accountHover;onHoveredChanged:if(hovered)tools.hover("account");else tools.leave()}
            Loader {
                objectName:"globalAccountGlass";anchors.fill:parent
                opacity:identity.engaged?1:0;active:identity.engaged||opacity>0
                Behavior on opacity {NumberAnimation{duration:RhineTheme.noMotion?0:160}}
                sourceComponent:LiquidGlass {anchors.fill:parent;background:tools.background;readonly property point origin:{identity.x;identity.width;accountRow.x;return identity.mapToItem(tools.background,0,0)} sampleX:origin.x;sampleY:origin.y;uiScale:tools.u;radius:height/2;dark:tools.dark;refractive:rhineRefractiveGlass;refraction:.78;frosting:.30;tint:.09;rimStrength:.28;shadowStrength:0}
            }
            Rectangle {id:avatar;x:3*tools.u;anchors.verticalCenter:parent.verticalCenter;width:28*tools.u;height:width;radius:width/2;color:tools.dark?"#48523e":"#dce1d2";clip:true
                Image {anchors.fill:parent;source:tools.cover(rhine.state.accountAvatar);sourceSize:Qt.size(96,96);asynchronous:true;fillMode:Image.PreserveAspectCrop;layer.enabled:true;layer.effect:MultiEffect{maskEnabled:true;maskSource:smallAvatarMask}}
                Rectangle {id:smallAvatarMask;anchors.fill:parent;radius:width/2;visible:false;layer.enabled:true}
                RhineIcon {anchors.centerIn:parent;visible:!rhine.state.accountAvatar;name:"user";width:18*tools.u;height:width;color:tools.ink}
            }
            Label {id:nickname;x:avatar.width+10*tools.u;height:parent.height;width:Math.min(implicitWidth,90*tools.u);verticalAlignment:Text.AlignVCenter;text:rhine.state.accountName||"登录";font.pixelSize:13*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
            RhineIcon {objectName:"globalAccountArrow";anchors.right:parent.right;anchors.rightMargin:10*tools.u;anchors.verticalCenter:parent.verticalCenter;width:15*tools.u;height:width;name:"chevron";color:tools.ink;opacity:identity.engaged?1:0;visible:opacity>0;Behavior on opacity{NumberAnimation{duration:RhineTheme.noMotion?0:160}}}
            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:tools.pinAccount()}
            Controls.Control {id:vipBadge;objectName:"globalVipBadge";x:nickname.x+nickname.width+8*tools.u;anchors.verticalCenter:parent.verticalCenter;visible:tools.signedIn&&!!(tools.vip.label||rhine.state.accountMember)&&tools.vip.label!=="普通账户";width:badge.implicitWidth+16*tools.u;height:22*tools.u
                focusPolicy:Qt.TabFocus
                Accessible.role:Accessible.Button;Accessible.name:"会员资料";Accessible.onPressAction:tools.openVip()
                Keys.onReturnPressed:tools.openVip()
                Keys.onSpacePressed:tools.openVip()
                Label {id:badge;anchors.centerIn:parent;text:tools.vip.label||rhine.state.accountMember||"";font.pixelSize:10*tools.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:tools.dark?"#f0e2c6":"#594a30";font.letterSpacing:.6*tools.u}
                MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:tools.openVip()}
            }
        }
        Rectangle {width:tools.u;height:18*tools.u;anchors.verticalCenter:parent.verticalCenter;color:tools.dark?"#40ffffff":"#303e4e32"}
        Tool {objectName:"globalInbox";keyName:"messages";iconName:"comment";label:"消息";onInvoked:tools.openInbox(0)
            Rectangle {x:25*tools.u;y:4*tools.u;width:5*tools.u;height:width;radius:width/2;color:"#bc6960";visible:(rhine.messages.state.counts||[]).some(n=>Number(n)>0)}
        }
        Tool {objectName:"globalHistory";keyName:"history";iconName:"history";label:"历史";onInvoked:tools.openLibrary("songs")}
        Tool {objectName:"globalFavorites";keyName:"favorites";iconName:"folder";label:"收藏";onInvoked:tools.openLibrary("created")}
        Tool {objectName:"globalSettings";keyName:"settings";iconName:"settings";label:"设置";onInvoked:{tools.dismiss();rhine.action("settings")}}
    }
    RhinePopup {
        id:accountMenu;objectName:"globalAccountMenu";parent:Controls.Overlay.overlay;popupType:Controls.Popup.Item
        modal:tools.accountPinned;dim:false;focus:tools.accountPinned
        width:Math.min(380*tools.u,tools.width-32);height:Math.min(accountContent.implicitHeight+36*tools.u,tools.height-120*tools.u)
        x:Math.max(16,tools.width-tools.topRightReserved-width-14*tools.u);y:48*tools.u;padding:18*tools.u
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        onClosed:{tools.accountPinned=false;if(tools.previewKey==="account")tools.previewKey=""}
        background:Rectangle {radius:22*tools.u;color:RhineTheme.surface(tools.dark);PopupGlass {anchors.fill:parent;opacity:.42;objectName:"accountMenuGlass";popup:accountMenu;unit:tools.u;dark:tools.dark;radius:22*tools.u;frosting:1;tint:.38}}
        enter:Transition {NumberAnimation{property:"opacity";from:0;to:1;duration:RhineTheme.noMotion?0:150}}
        contentItem:Flickable {clip:true;contentHeight:accountContent.implicitHeight;boundsBehavior:Flickable.StopAtBounds
            HoverHandler {onHoveredChanged:if(hovered)leaveTimer.stop();else tools.leave()}
            Column {id:accountContent;width:parent.width;spacing:8*tools.u
                Row {width:parent.width;height:22*tools.u
                    Label {width:parent.width/2;text:"RHINE / 个人音乐档案";font.pixelSize:10*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});color:tools.muted;font.letterSpacing:.6*tools.u}
                    Label {width:parent.width/2;text:tools.level.level!==undefined?"LV "+tools.level.level:"NETEASE";horizontalAlignment:Text.AlignRight;font.pixelSize:11*tools.u;color:tools.muted}
                }
                Rectangle {width:parent.width;height:110*tools.u;radius:14*tools.u;color:tools.dark?"#464e3c":"#d7decb";clip:true
                    Image {id:identityBackdrop;objectName:"identityAvatarBackdrop";anchors.fill:parent;anchors.margins:-18*tools.u;source:tools.cover(rhine.state.accountAvatar);sourceSize:Qt.size(48,48);fillMode:Image.PreserveAspectCrop;asynchronous:true;visible:false}
                    MultiEffect {anchors.fill:parent;source:identityBackdrop;blurEnabled:true;blurMax:48;blur:.8;autoPaddingEnabled:false;saturation:-.12;opacity:.78;maskEnabled:true;maskSource:identityBackdropMask}
                    Rectangle {id:identityBackdropMask;anchors.fill:parent;radius:14*tools.u;visible:false;layer.enabled:true}
                    Rectangle {anchors.fill:parent;radius:14*tools.u;color:tools.dark?"#30202430":"#20ffffff"}
                    Rectangle {anchors.centerIn:parent;width:78*tools.u;height:width;radius:width/2;color:"#e9ece3";border.width:4*tools.u;border.color:"#f4f6ed";clip:true
                        Image {
                            objectName:"accountMenuAvatarImage"
                            anchors.fill:parent;anchors.margins:4*tools.u
                            source:tools.cover(rhine.state.accountAvatar)
                            // Decode for the physical display size, keeping one stable size per scale bucket.
                            readonly property int decodeSide:Math.pow(2,Math.ceil(Math.log2(Math.max(128,Math.max(width,height)*Screen.devicePixelRatio))))
                            sourceSize:Qt.size(decodeSide,decodeSide)
                            fillMode:Image.PreserveAspectCrop;asynchronous:true
                            layer.enabled:true;layer.effect:MultiEffect{maskEnabled:true;maskSource:largeAvatarMask}
                        }
                        Rectangle {id:largeAvatarMask;anchors.fill:parent;anchors.margins:4*tools.u;radius:width/2;visible:false;layer.enabled:true}
                        RhineIcon {anchors.centerIn:parent;visible:!rhine.state.accountAvatar;width:34*tools.u;height:width;name:"user";color:tools.muted}
                    }
                }
                Label {width:parent.width;text:rhine.state.accountName||"欢迎来到 Rhine";font.pixelSize:25*tools.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
                Label {width:parent.width;text:tools.person.signature||"让喜欢的音乐，留下自己的痕迹。";font.pixelSize:12*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});color:tools.muted;maximumLineCount:2;wrapMode:Text.Wrap;elide:Text.ElideRight}
                Row {width:parent.width;height:24*tools.u
                    Label {width:parent.width*.6;text:tools.vip.label||rhine.state.accountMember||rhine.state.accountProviderName||"Rhine";font.pixelSize:12*tools.u;color:tools.accent}
                    Label {width:parent.width*.4;horizontalAlignment:Text.AlignRight;text:tools.level.full?"MAX / 满级":tools.level.level!==undefined?"Lv."+tools.level.level:"";font.pixelSize:11*tools.u;color:tools.muted}
                }
                Rectangle {width:parent.width;height:4*tools.u;radius:height/2;color:tools.dark?"#36412e":"#dce2d4"
                    Rectangle {width:parent.width*Math.max(0,Math.min(1,Number(tools.level.progress||0)));height:parent.height;radius:height/2;color:tools.accent}
                }
                Row {width:parent.width;height:66*tools.u
                    Repeater {model:[{label:"笔记",field:"eventCount",section:"notes"},{label:"关注",field:"follows",section:"follows"},{label:"粉丝",field:"followeds",section:"followers"}]
                        Controls.AbstractButton {id:stat;required property var modelData;objectName:"accountStat_"+modelData.section;width:parent.width/3;height:parent.height;hoverEnabled:true;enabled:tools.signedIn&&rhine.state.accountProvider==="netease";Accessible.name:modelData.label;onClicked:tools.openProfile(modelData.section)
                            background:Rectangle {radius:12*tools.u;color:stat.hovered||stat.visualFocus?(tools.dark?"#12ffffff":"#0c405a35"):"transparent"}
                            contentItem:Item {
                            Label {anchors.horizontalCenter:parent.horizontalCenter;y:11*tools.u;text:tools.person[stat.modelData.field]!==undefined?String(tools.person[stat.modelData.field]):"—";font.pixelSize:22*tools.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:stat.hovered?tools.accent:tools.ink}
                            Label {anchors.horizontalCenter:parent.horizontalCenter;y:40*tools.u;text:stat.modelData.label;font.pixelSize:12*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});color:stat.hovered?tools.accent:tools.muted}
                            }
                            HoverHandler {cursorShape:Qt.PointingHandCursor}
                        }
                    }
                }
                Rectangle {width:parent.width;height:tools.u;color:tools.dark?"#20ffffff":"#1837472e"}
        Action {objectName:"accountMenuProfile";text:tools.signedIn?"个人主页":"登录账户";iconName:"user";onClicked:tools.openProfile()}
                Action {objectName:"accountMenuPlaylists";text:"我的歌单与收藏";iconName:"folder";enabled:tools.signedIn;onClicked:tools.openLibrary("created")}
                Label {width:parent.width;height:30*tools.u;text:tools.vip.expires?"会员有效期 · "+tools.vip.expires:"会员身份 · "+(tools.vip.label||"暂未读取");font.pixelSize:12*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});color:tools.muted;verticalAlignment:Text.AlignVCenter}
                Rectangle {width:parent.width;height:tools.u;color:tools.dark?"#20ffffff":"#1837472e"}
                Action {objectName:"accountMenuSwitch";text:"切换账号";iconName:"switchAccount";enabled:tools.signedIn;onClicked:{tools.dismiss();switchConfirm.open()}}
                Action {objectName:"accountMenuLogout";text:"退出登录";iconName:"logout";enabled:tools.signedIn;onClicked:{tools.dismiss();rhine.action("music:logout")}}
            }
            Controls.ScrollBar.vertical:Controls.ScrollBar {}
        }
    }
    RhinePopup {
        id:preview;objectName:"personalHoverPreview";parent:Controls.Overlay.overlay;popupType:Controls.Popup.Item
        width:Math.min(330*tools.u,tools.width-32);height:Math.min(tools.height-80*tools.u,previewContent.implicitHeight+36*tools.u)
        x:Math.max(16,tools.width-tools.topRightReserved-width-14*tools.u);y:48*tools.u;padding:18*tools.u;modal:false;focus:false
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        background:Rectangle {radius:20*tools.u;color:RhineTheme.surface(tools.dark);PopupGlass {anchors.fill:parent;opacity:.42;popup:preview;unit:tools.u;dark:tools.dark;radius:20*tools.u;frosting:1;tint:.4}}
        enter:Transition {NumberAnimation{property:"opacity";from:0;to:1;duration:RhineTheme.noMotion?0:140}}
        contentItem:Column {id:previewContent;spacing:10*tools.u
            HoverHandler {onHoveredChanged:if(hovered)leaveTimer.stop();else tools.leave()}
            Row {width:parent.width;height:32*tools.u
                Label {width:parent.width-90*tools.u;anchors.verticalCenter:parent.verticalCenter;text:tools.previewKey==="messages"?"消息":tools.previewKey==="history"?"最近听过":"收藏速览";font.pixelSize:17*tools.u;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
                Controls.Button {width:90*tools.u;height:parent.height;flat:true;contentItem:Label{text:"查看全部 →";font.pixelSize:11*tools.u;color:tools.accent;horizontalAlignment:Text.AlignRight;verticalAlignment:Text.AlignVCenter} onClicked:tools.previewKey==="messages"?tools.openInbox(0):tools.openLibrary(tools.previewKey==="history"?"songs":"collected")}
            }
            Repeater {model:tools.previewKey==="messages"?["私信","评论","@我","通知"]:[]
                Action {required property string modelData;required property int index;iconName:index===0?"comment":"message";text:modelData;onClicked:tools.openInbox(index)
                    Label {anchors.right:parent.right;anchors.rightMargin:12*tools.u;anchors.verticalCenter:parent.verticalCenter;text:String((rhine.messages.state.counts||[])[parent.index]??"—");color:tools.muted;font.pixelSize:12*tools.u}
                }
            }
            Repeater {model:tools.previewKey==="messages"?[]:(tools.previewPage.rows||[]).slice(0,4)
                Item {required property var modelData;required property int index;width:parent.width;height:54*tools.u
                    Rectangle {anchors.fill:parent;radius:9*tools.u;color:rowMouse.containsMouse?(tools.dark?"#20ffffff":"#60ffffff"):"transparent"}
                    Image {x:3*tools.u;y:5*tools.u;width:44*tools.u;height:width;source:tools.cover(modelData.cover);sourceSize:Qt.size(96,96);fillMode:Image.PreserveAspectCrop;asynchronous:true}
                    Label {x:58*tools.u;y:7*tools.u;width:parent.width-x;text:modelData.title||"";font.pixelSize:13*tools.u}
                    Label {x:58*tools.u;y:29*tools.u;width:parent.width-x;text:modelData.artist||"";font.pixelSize:10*tools.u;color:tools.muted}
                    MouseArea {id:rowMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{rhine.personal.activate(tools.previewKey==="history"?"songs":"collected",index);tools.clearPreview()}}
                }
            }
            Label {visible:tools.previewKey!=="messages"&&!(tools.previewPage.rows||[]).length;width:parent.width;text:!tools.signedIn?"登录后查看你的音乐":tools.previewPage.loading?"正在读取…":tools.previewPage.error||"这里还没有记录";color:tools.muted;font.pixelSize:12*tools.u}
        }
    }
    Rectangle {
        anchors.left:parent.left;anchors.right:parent.right;y:40*tools.u;height:Math.max(0,tools.height-y-100*tools.unit)
        visible:library.visible;color:tools.dark?"#30000000":"#18000000"
        MouseArea {anchors.fill:parent;hoverEnabled:true;onClicked:library.close();onWheel:event=>event.accepted=true}
    }
    RhinePopup {
        id:library;objectName:"personalLibraryDrawer";parent:Controls.Overlay.overlay;popupType:Controls.Popup.Item
        onVisibleChanged:if(visible)prepareFolders.restart()
        width:Math.min(tools.width-32*tools.u,850*tools.u);height:Math.max(180,tools.height-140*tools.u)
        x:tools.width-width-16*tools.u;y:48*tools.u;padding:24*tools.u;modal:false;dim:false;focus:true
        closePolicy:Controls.Popup.CloseOnEscape
        background:Rectangle {radius:24*tools.u;color:RhineTheme.surface(tools.dark);PopupGlass {anchors.fill:parent;opacity:.42;popup:library;unit:tools.u;dark:tools.dark;radius:24*tools.u;refraction:.72;frosting:.72;tint:.22;rimStrength:.28}}
        enter:Transition {NumberAnimation{property:"x";from:tools.width;duration:tools.reduced?0:280;easing.type:Easing.OutCubic} NumberAnimation{property:"opacity";from:0;to:1;duration:RhineTheme.noMotion?0:180}}
        exit:Transition {NumberAnimation{property:"opacity";to:0;duration:RhineTheme.noMotion?0:130}}
        contentItem:Column {
            spacing:14*tools.u
            Row {width:parent.width;height:48*tools.u
                Column {width:parent.width-40*tools.u;spacing:3*tools.u
                    Label {text:tools.collectionMode?"COLLECTION / 私人音乐架":"HISTORY / 聆听记录";font.pixelSize:10*tools.u;color:tools.muted;font.letterSpacing:1.4*tools.u}
                    Label {text:tools.collectionMode?"喜欢的，都在这里。":"再听一次。";font.pixelSize:24*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
                }
                Controls.Button {objectName:"personalLibraryClose";width:36*tools.u;height:width;flat:true;onClicked:library.close();contentItem:RhineIcon{name:"close";color:tools.muted}}
            }
            Row {width:parent.width;spacing:8*tools.u
                Repeater {model:tools.collectionMode?[{key:"created",label:"我的歌单"},{key:"collected",label:"收藏歌单"},{key:"albums",label:"收藏专辑"}]:[{key:"songs",label:"歌曲"},{key:"recentAlbums",label:"专辑"},{key:"recentPlaylists",label:"歌单"}]
                    Controls.Button {required property var modelData;text:modelData.label;checked:tools.section===modelData.key;checkable:true;onClicked:tools.selectSection(modelData.key);font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12*tools.u;leftPadding:16*tools.u;rightPadding:16*tools.u
                        implicitWidth:tabCaption.implicitWidth+32*tools.u
                        contentItem:Label {id:tabCaption;text:parent.text;font.pixelSize:12*tools.u;color:parent.checked?tools.ink:tools.muted;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                        background:Rectangle {radius:height/2;color:parent.checked?(tools.dark?"#46533a":"#dfe6d4"):"transparent"}
                    }
                }
            }
            Rectangle {width:parent.width;height:tools.u;color:tools.dark?"#20ffffff":"#1837472e"}
            Flickable {id:libraryScroll;objectName:"personalLibraryScroll";width:parent.width;height:library.availableHeight-115*tools.u;contentHeight:libraryGrid.height+50*tools.u;clip:true;boundsBehavior:Flickable.StopAtBounds
                onHeightChanged:prepareFolders.restart()
                WheelHandler {target:null;onWheel:event=>{libraryScroll.contentY=Math.max(0,Math.min(Math.max(0,libraryScroll.contentHeight-libraryScroll.height),libraryScroll.contentY-event.angleDelta.y*.65*tools.u));event.accepted=true}}
                Grid {id:libraryGrid;anchors.horizontalCenter:parent.horizontalCenter;readonly property bool folders:tools.section==="created"||tools.section==="collected";columns:tools.section==="songs"?1:Math.max(2,Math.floor((libraryScroll.width+24*tools.u)/(220*tools.u+24*tools.u)));width:folders?Math.min(libraryScroll.width,columns*220*tools.u+(columns-1)*24*tools.u):libraryScroll.width;spacing:24*tools.u
                    property bool positioned:false
                    onPositioningComplete:{positioned=true;prepareFolders.restart()}
                    Repeater {id:libraryRows;model:tools.currentPage.rows||[]
                        onItemAdded:libraryGrid.positioned=false
                        onItemRemoved:libraryGrid.positioned=false
                        Item {id:card;required property var modelData;required property int index;width:(libraryGrid.width-(libraryGrid.columns-1)*libraryGrid.spacing)/libraryGrid.columns;height:folder?width*350/340:tools.section==="songs"?64*tools.u:220*tools.u
                            readonly property bool song:tools.section==="songs"
                            readonly property bool folder:tools.section==="created"||tools.section==="collected"
                            readonly property bool hovering:cardMouse.containsMouse
                            readonly property bool inViewport:library.visible&&card.y+card.height>libraryScroll.contentY&&card.y<libraryScroll.contentY+libraryScroll.height
                            property bool folderPrepared:false
                            onInViewportChanged:if(inViewport&&folder)prepareFolders.restart()
                            Loader {
                              id:folderLoader;objectName:"musicFolderLoader_"+card.index
                              anchors.fill:parent;active:card.folder&&card.folderPrepared;asynchronous:true
                              sourceComponent:MusicFolder {
                                id:musicFolder;objectName:"musicFolder_"+card.index;visible:card.folder;anchors.fill:parent
                                entry:card.modelData;unit:tools.u;dark:tools.dark;reduced:tools.reduced;fontFamily:rhineFontFamily
                                materialActive:card.inViewport
                                entranceActive:card.folder&&library.visible
                                inViewport:materialActive
                                entranceDelay:Math.min(5,Math.max(0,Math.floor((card.y-libraryScroll.contentY)/(card.height+libraryGrid.spacing)))*libraryGrid.columns+card.index%libraryGrid.columns)*140
                                readonly property string snapshotKey:"folder:"+card.modelData.key
                                readonly property var snapshot:rhine.personal.state[snapshotKey]||({})
                                files:snapshot.rows||[];loading:snapshot.loading===true;loaded:snapshot.loaded===true;error:snapshot.error||""
                                onRequested:rhine.personal.loadFolder(tools.section,card.index)
                                onSelected:index=>{rhine.personal.activate(snapshotKey,index);library.close()}
                                onViewAll:{rhine.personal.activate(tools.section,card.index);library.close()}
                                onViewOriginal:rhine.personal.openOriginal(tools.section,card.index)
                              }
                            }
                            Rectangle {visible:card.song;anchors.fill:parent;radius:12*tools.u;color:card.hovering?(tools.dark?"#20ffffff":"#65ffffff"):"transparent"}
                            Rectangle {id:art;visible:!card.folder;x:card.song?4*tools.u:8*tools.u;y:card.song?4*tools.u:card.hovering?5*tools.u:16*tools.u;width:card.song?54*tools.u:parent.width-16*tools.u;height:card.song?width:150*tools.u;radius:10*tools.u;color:tools.dark?"#49533d":"#d7decb";clip:true
                                Behavior on y{NumberAnimation{duration:tools.reduced?0:230;easing.type:Easing.OutCubic}} Behavior on rotation{NumberAnimation{duration:tools.reduced?0:260;easing.type:Easing.OutCubic}}
                                Image {objectName:"libraryPlainCover";anchors.fill:parent;source:card.folder?"":tools.cover(card.modelData.cover);sourceSize:Qt.size(320,320);fillMode:Image.PreserveAspectCrop;asynchronous:true}
                            }
                            Label {visible:!card.folder;x:card.song?72*tools.u:3*tools.u;y:card.song?10*tools.u:182*tools.u;width:parent.width-x-8*tools.u;text:card.modelData.title||"";font.pixelSize:card.song?14*tools.u:13*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
                            Label {visible:!card.folder;x:card.song?72*tools.u:3*tools.u;y:card.song?36*tools.u:204*tools.u;width:parent.width-x-8*tools.u;text:card.modelData.heardAt||card.modelData.artist||"";font.pixelSize:10*tools.u;color:tools.muted}
                            MouseArea {id:cardMouse;enabled:!card.folder;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{rhine.personal.activate(tools.section,index);library.close()}}
                        }
                    }
                }
                Label {anchors.top:parent.top;anchors.topMargin:35*tools.u;width:parent.width;horizontalAlignment:Text.AlignHCenter;visible:!(tools.currentPage.rows||[]).length;text:!rhine.personal.state.supported?"登录网易云音乐后查看收藏与历史":tools.currentPage.loading?"正在整理你的音乐…":tools.currentPage.error||"这里暂时没有内容";color:tools.muted}
                Controls.Button {visible:tools.currentPage.more===true||!!tools.currentPage.error;y:libraryGrid.height+10*tools.u;anchors.horizontalCenter:parent.horizontalCenter;text:tools.currentPage.error?"重试":"加载更多";enabled:!tools.currentPage.loading;onClicked:rhine.personal.load(tools.section,!tools.currentPage.error)}
                Controls.ScrollBar.vertical:Controls.ScrollBar {}
            }
        }
    }
    MessageDrawer {id:inbox;controller:rhine.messages;sceneBackground:tools.drawerBackground;panelBounds:rhine.state.drawerBounds||({});dark:tools.dark;unit:tools.unit}
    RhinePopup {
        id:membership;objectName:"personalMembership";parent:Controls.Overlay.overlay;popupType:Controls.Popup.Item
        width:Math.min(360*tools.u,tools.width-32);height:Math.min(tools.height-80*tools.u,memberContent.implicitHeight+40*tools.u)
        x:Math.max(16,tools.width-tools.topRightReserved-width-14*tools.u);y:48*tools.u;padding:20*tools.u;focus:true
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        background:Rectangle {radius:22*tools.u;color:RhineTheme.surface(tools.dark);PopupGlass{anchors.fill:parent;opacity:.42;popup:membership;unit:tools.u;dark:tools.dark;radius:22*tools.u;refraction:.78;frosting:.57;tint:.15;rimStrength:.28}}
        contentItem:Column {id:memberContent;spacing:15*tools.u
            Label{text:"MEMBERSHIP / 会员";font.pixelSize:10*tools.u;color:tools.muted;font.letterSpacing:1.4*tools.u}
            Label{text:tools.vip.label||"正在读取会员信息…";font.pixelSize:30*tools.u;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
            Label{text:tools.vip.level!==undefined?"黑胶等级 · "+tools.vip.level:"";color:tools.muted}
            Label{text:tools.vip.expires?"有效期至 "+tools.vip.expires:"";color:tools.muted}
            Action{text:"前往网易云会员中心";iconName:"link";onClicked:{membership.close();rhine.personal.openMembership()}}
        }
    }
    RhineDialog {
        id:switchConfirm;objectName:"accountSwitchDialog";unit:tools.u;dark:tools.dark
        title:"切换账号";confirmText:"退出并切换"
        message:"将退出当前账号并打开登录页面。当前播放会停止。"
        onAccepted:{rhine.action("music:logout");rhine.action("music:login")}
    }
}
