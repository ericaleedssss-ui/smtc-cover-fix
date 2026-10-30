import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls

Item {
    id:page
    objectName:"playlistShowcase"
    required property var controller
    required property Item background
    property real unit:1
    property bool showSongs:false
    property int songIndex:-1
    readonly property var info:controller.info
    readonly property color ink:rhine.state.dark?"#eceee3":"#30372e"
    readonly property color muted:rhine.state.dark?"#aeb6a1":"#737b6d"
    readonly property real coverWidth:Math.min(280*unit,width*.32)
    readonly property real textWidth:width-coverWidth-80*unit
    function dismissTopOverlay(){if(cancelCollect.visible){cancelCollect.close();return true;}if(more.visible){more.close();return true;}return false;}
    function scrollContent(view,e){var dy=e.pixelDelta.y||e.angleDelta.y/120*72*unit;var origin=view.originY||0;view.contentY=Math.max(origin,Math.min(origin+Math.max(0,view.contentHeight-view.height),view.contentY-dy));}
    function scrollSongs(e){scrollContent(songList,e);}
    property real wheelCarry:0
    property int pendingMoves:0
    property double pendingUntil:0
    property double lastWheelTime:0
    function wheelRecord(e){
        var now=Date.now();if(now-lastWheelTime>220)wheelCarry=0;lastWheelTime=now;
        var dy=e.pixelDelta.y?e.pixelDelta.y/60:e.angleDelta.y/120;wheelCarry+=dy;
        var whole=wheelCarry<0?Math.ceil(wheelCarry):Math.floor(wheelCarry);
        if(whole!==0){wheelCarry-=whole;moveRecord(-whole);}
    }
    function drainMoves(){
        if(pendingMoves&&Date.now()>pendingUntil)pendingMoves=0;
        if(!pendingMoves||recordStack.busy)return;
        var step=pendingMoves>0?1:-1;var target=controller.recordNeighbour(step);
        if(target.key){if(recordStack.choose(Object.assign({},target,{side:step}))!==false)pendingMoves-=step;}
        else {controller.prepareRecords();pendingMoves=0;}
    }
    function moveSong(step){
        if(!controller.songs.length)return;
        showSongs=true;songIndex=Math.max(0,Math.min(controller.songs.length-1,songIndex+step));
        controller.preview(songIndex);songList.positionViewAtIndex(songIndex,ListView.Contain);
    }
    function moveRecord(step){
        pendingMoves=Math.max(-6,Math.min(6,pendingMoves+step));
        pendingUntil=Date.now()+5000;drainMoves();
    }
    readonly property bool keysEnabled:visible&&enabled&&!more.visible&&!cancelCollect.visible&&!rhine.state.queueOpen&&!rhine.messages.state.open&&!Controls.Overlay.overlay.visible
    function playSelection(){if(showSongs&&songIndex>=0)controller.playSong(songIndex);else controller.operate("play");}
    Shortcut {sequences:["Return","Enter"];enabled:page.keysEnabled;autoRepeat:false;onActivated:page.playSelection()}
    Shortcut {sequence:"Space";enabled:page.keysEnabled;autoRepeat:false;onActivated:controller.operate("shuffle")}
    Shortcut {sequence:"F";enabled:page.keysEnabled;autoRepeat:false;onActivated:page.collect()}
    Shortcut {sequence:"Tab";enabled:page.keysEnabled;autoRepeat:false;onActivated:page.showSongs=!page.showSongs}
    Shortcut {sequence:"Right";enabled:page.keysEnabled;onActivated:page.moveRecord(1)}
    Shortcut {sequence:"Left";enabled:page.keysEnabled;onActivated:page.moveRecord(-1)}
    Shortcut {sequence:"Down";enabled:page.keysEnabled;onActivated:page.moveSong(1)}
    Shortcut {sequence:"Up";enabled:page.keysEnabled;onActivated:page.moveSong(-1)}
    function collect(){if(controller.busy)return;if(info.canSubscribe){if(info.subscribed){controller.operate("subscribe");cancelCollect.open();}else controller.operate("subscribe");}}
    onInfoChanged:if(info.key!==session){session=info.key||"";songIndex=-1;showSongs=false;descriptionView.contentY=0;}
    property string session:""
    component Label:Text {textFormat:Text.PlainText;color:page.ink;font.family:rhineFontFamily;font.pixelSize:16*page.unit;elide:Text.ElideRight}
    component Button:Controls.Button {
        id:button
        property bool primary:false
        property url artwork
        property bool heart:false
        readonly property color foreground:primary?"#fafaf2":page.ink
        focusPolicy:Qt.NoFocus
        opacity:enabled?1:.48
        Accessible.name:text||"更多"
        HoverHandler {cursorShape:Qt.PointingHandCursor;enabled:button.enabled}
        implicitHeight:42*page.unit
        implicitWidth:42*page.unit
        leftPadding:12*page.unit;rightPadding:12*page.unit
        contentItem:Item {
            implicitWidth:buttonContent.width;implicitHeight:24*page.unit
            Row {
                id:buttonContent;anchors.centerIn:parent;spacing:8*page.unit
                Item {
                    width:20*page.unit;height:24*page.unit
                    ArchiveActionIcon {anchors.centerIn:parent;width:(button.primary?18:22)*page.unit;height:width;source:button.artwork;tint:button.foreground;visible:!button.heart}
                    Image {objectName:"showcaseCollectArtwork";anchors.centerIn:parent;width:23*page.unit;height:width;source:button.heart?(info.subscribed?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png"):"";fillMode:Image.PreserveAspectFit;visible:button.heart;cache:true}
                }
                Label {visible:button.text!=="";text:button.text;color:button.foreground;height:24*page.unit;verticalAlignment:Text.AlignVCenter;font.pixelSize:14*page.unit}
            }
        }
        background:Rectangle {radius:height/2;color:button.primary?(button.hovered?"#7c9069":"#70845e"):(button.hovered?"#55ffffff":"#20ffffff");border.width:1;border.color:button.primary?"transparent":(rhine.state.dark?"#557b8470":"#bafffff5")}
    }
    // Content only: the shared ArchiveReading owns the original glass.
    // Own only this panel's input; navigation and the player remain outside it.
    MouseArea {anchors.fill:parent;onClicked:{} onWheel:e=>{page.wheelRecord(e);e.accepted=true;}}
    Label {x:26*unit;y:26*unit;width:page.textWidth;text:"MUSIC DATABASE / "+(info.sourceLabel||"收藏歌单");font.pixelSize:12*unit;color:page.muted}
    Label {
        objectName:"showcaseTitle";x:26*unit;y:59*unit;width:page.textWidth;height:68*unit
        color:titleHit.containsMouse?(rhine.state.dark?"#cedbbf":"#647b52"):page.ink
        Behavior on color {ColorAnimation {duration:120}}
        text:info.title||(info.kind==="album"?"专辑":"歌单");font.pixelSize:28*unit;font.weight:Font.Bold
        wrapMode:Text.Wrap;maximumLineCount:2
        MouseArea {id:titleHit;hoverEnabled:true;anchors.fill:parent;enabled:!!info.key;cursorShape:Qt.PointingHandCursor;onClicked:controller.operate("details")}
    }
    Rectangle {x:26*unit;y:137*unit;width:page.textWidth;height:unit;color:page.muted;opacity:.5}
    Rectangle {x:26*unit;y:134*unit;width:6*unit;height:6*unit;color:page.ink}
    Flickable {id:descriptionView;objectName:"showcaseDescription";x:26*unit;y:154*unit;width:page.textWidth;height:96*unit;visible:!page.showSongs;clip:true;contentHeight:description.implicitHeight;boundsBehavior:Flickable.StopAtBounds
        Label {id:description;width:parent.width;text:info.description|| (info.loading?"正在读取歌单资料…":(info.kind==="album"?"这张专辑还没有简介。":"这张歌单还没有简介。"));color:page.muted;font.pixelSize:15*unit;wrapMode:Text.Wrap;elide:Text.ElideNone;lineHeight:1.6}
        WheelHandler {target:null;onWheel:e=>{page.scrollContent(descriptionView,e);e.accepted=true;}}
    }
    ListView {id:songList;objectName:"showcaseSongPreview";x:26*unit;y:158*unit;width:page.textWidth;height:160*unit;visible:page.showSongs;clip:true;model:page.showSongs?controller.songs:[];boundsBehavior:Flickable.StopAtBounds
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
        layer.effect:ShaderEffect {
            objectName:"showcaseSongFade"
            property variant source
            property size panelSize:Qt.size(songList.width,songList.height)
            property real topInset:0
            property real fadePx:14*page.unit
            property real fadeTop:songList.contentY>1?1:0
            property real bottomFadePx:12*page.unit
            fragmentShader:"qrc:/shaders/magazineEdgeFade.frag.qsb"
        }
        WheelHandler {target:null;onWheel:e=>{page.scrollSongs(e);e.accepted=true;}}
        onContentYChanged:{var row=indexAt(1,contentY+height*.5);if(row>=0)controller.preview(row);}
        delegate:Rectangle {required property var modelData;required property int index;width:songList.width;height:32*page.unit;opacity:GraphicsInfo.api===GraphicsInfo.Software?Math.min(1,Math.max(0,(y-songList.contentY+height/2)/(14*page.unit)),Math.max(0,(songList.height-y+songList.contentY-height/2)/(12*page.unit))):1;radius:5*page.unit;color:page.songIndex===index?"#286f845e":songHit.containsMouse?"#126f845e":"transparent"
            Behavior on color {ColorAnimation {duration:100}}
            Label {x:9*page.unit;width:parent.width-18*page.unit;anchors.verticalCenter:parent.verticalCenter;text:(index+1)+"  "+modelData.title+(modelData.artist?" · "+modelData.artist:"");font.pixelSize:16*page.unit}
            MouseArea {id:songHit;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;anchors.fill:parent;onClicked:{page.songIndex=index;page.controller.preview(index);}onDoubleClicked:page.controller.playSong(index)}
        }
        Label {visible:songList.count===0;anchors.centerIn:parent;text:info.loading?"读取曲目中…":info.loadFailed?"曲目读取失败，请在更多中重试":info.loaded?"暂无曲目":"等待曲目信息…";color:page.muted}
    }
    Row {
        id:metadataRow;objectName:"showcaseMetadata";visible:!page.showSongs;x:26*unit;y:269*unit;width:page.textWidth;spacing:8*unit;height:32*unit
        Item {
            id:identityInfo;objectName:"showcaseIdentity";width:40*unit+Math.min(identityNames.implicitWidth,Math.max(48*unit,(metadataRow.width-trackCountInfo.implicitWidth-dateInfo.implicitWidth-40*unit-6*metadataRow.spacing-3*unit)*.48));height:32*unit
            Rectangle {width:30*unit;height:width;radius:width/2;color:avatarHit.containsMouse?"#90a080":(rhine.state.dark?"#59614f":"#cdd2c5")
                RhineIcon {anchors.centerIn:parent;width:18*unit;height:width;name:"user";color:page.muted}
                Image {id:identityAvatar;onStatusChanged:if(status===Image.Error&&page.controller.retryIdentityAvatar)page.controller.retryIdentityAvatar();objectName:"showcaseIdentityAvatar";anchors.fill:parent;source:info.identityAvatar||"";asynchronous:true;cache:true;sourceSize:Qt.size(96,96);fillMode:Image.PreserveAspectCrop;visible:status===Image.Ready
                    layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
                    layer.effect:MultiEffect {maskEnabled:true;maskSource:identityMask}
                }
                Rectangle {id:identityMask;anchors.fill:parent;radius:width/2;visible:false;layer.enabled:true}
                Rectangle {anchors.fill:parent;radius:width/2;color:avatarHit.containsMouse?"#246f845e":"transparent";Behavior on color {ColorAnimation {duration:120}}}
                MouseArea {id:avatarHit;anchors.fill:parent;enabled:!!info.identityCanOpen;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:controller.operate("creator")}
            }
            ArtistMarquee {id:identityNames;x:40*unit;width:Math.max(0,parent.width-x);height:32*unit;unit:page.unit;people:info.identities||[];fallback:info.artist||"未知";onPersonClicked:id=>controller.openIdentity(id)}

        }
        Rectangle {width:unit;height:13*unit;y:9*unit;color:page.muted;opacity:.4}
        Label {id:tagInfo;objectName:"showcaseTags";height:32*unit;verticalAlignment:Text.AlignVCenter;font.pixelSize:13*unit;color:page.muted
            text:(info.tags||[]).length?info.tags.join(" / "):"暂无标签"
            width:Math.min(implicitWidth,Math.max(24*unit,metadataRow.width-identityInfo.width-trackCountInfo.implicitWidth-dateInfo.implicitWidth-6*metadataRow.spacing-3*unit))
            HoverHandler {id:tagHover}
            Controls.ToolTip.visible:tagHover.hovered&&tagInfo.truncated
            Controls.ToolTip.text:tagInfo.text
        }
        Rectangle {width:unit;height:13*unit;y:9*unit;color:page.muted;opacity:.4}
        Label {id:trackCountInfo;objectName:"showcaseTrackCount";height:32*unit;verticalAlignment:Text.AlignVCenter;text:(info.total||0)+" 首歌曲";font.pixelSize:13*unit}
        Rectangle {width:unit;height:13*unit;y:9*unit;color:page.muted;opacity:.4}
        Label {id:dateInfo;objectName:"showcaseDate";height:32*unit;verticalAlignment:Text.AlignVCenter;text:info.createdDate||info.date||"日期暂无";font.pixelSize:13*unit;color:page.muted
            HoverHandler {id:dateHover}
            Controls.ToolTip.visible:dateHover.hovered
            Controls.ToolTip.text:info.kind==="album"?"发行日期":"创建日期"
        }
    }
    Row {x:26*unit;y:332*unit;spacing:9*unit
        Button {objectName:"showcasePlay";text:"播放全部";artwork:"qrc:/icons/archive-play.png";primary:true;width:Math.min(144*unit,(page.textWidth-69*unit)*.36);enabled:!controller.busy;onClicked:controller.operate("play")}
        Button {objectName:"showcaseShuffle";text:"随机播放";artwork:"qrc:/icons/archive-shuffle.png";width:Math.min(132*unit,(page.textWidth-69*unit)*.33);enabled:!controller.busy;onClicked:controller.operate("shuffle")}
        Button {objectName:"showcaseCollect";text:info.editable?"我的歌单":info.subscribed?"已收藏":"收藏";heart:true;width:Math.min(116*unit,(page.textWidth-69*unit)*.31);enabled:info.canSubscribe&&!controller.busy;onClicked:page.collect()}
        Button {objectName:"showcaseMore";artwork:"qrc:/icons/archive-more.png";width:42*unit;onClicked:more.popup();Controls.ToolTip.visible:hovered;Controls.ToolTip.text:"更多"}
    }
    Label {x:26*unit;y:382*unit;width:page.textWidth;text:controller.status||"";color:page.muted;font.pixelSize:10*unit}
    RecordStack {id:recordStack;objectName:"showcaseRecordStack";x:page.width-width-24*unit;y:66*unit;width:page.coverWidth;height:232*unit;unit:page.unit;controller:page.controller;background:page.background;reduced:rhine.state.reduced;editorial:true;groupTransitions:true}
    Connections {target:recordStack;function onBusyChanged(){if(!recordStack.busy)Qt.callLater(page.drainMoves);}}
    Label {anchors.right:parent.right;anchors.rightMargin:38*unit;y:322*unit;text:(info.recordPosition||1)+" / "+(info.recordCount||1)+"    ←  →";font.pixelSize:10*unit;color:page.muted}
    Rectangle {x:20*unit;y:400*unit;width:parent.width-40*unit;height:unit;color:page.muted;opacity:.2}
    Row {
        x:26*unit;y:412*unit;spacing:17*unit
        Label {text:page.showSongs?"ENTER  播放所选":"ENTER  播放全部";font.pixelSize:10.5*unit;color:page.muted}
        Label {text:"SPACE  随机播放";font.pixelSize:10.5*unit;color:page.muted}
        Label {visible:info.canSubscribe;text:"F  收藏/取消收藏";font.pixelSize:10.5*unit;color:page.muted}
    }
    Label {objectName:"showcaseTabHint";anchors.right:parent.right;anchors.rightMargin:26*unit;y:412*unit;text:"TAB  简介 / 歌曲";font.pixelSize:10.5*unit;color:page.muted}

    Controls.Menu {id:more;font.family:rhineFontFamily;palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.text:page.ink;palette.highlight:rhine.state.dark?"#48573b":"#dfe6d5";palette.highlightedText:page.ink
        Controls.MenuItem {objectName:"showcaseDetails";text:info.kind==="album"?"专辑详情":"歌单详情";onTriggered:controller.operate("details")}
        Controls.MenuItem {objectName:"showcaseAppend";text:"添加到播放列表";enabled:!controller.busy;onTriggered:controller.operate("append")}
        Controls.MenuItem {objectName:"showcaseCopy";text:info.kind==="album"?"复制专辑链接":"复制歌单链接";onTriggered:controller.operate("copy")}
        Controls.MenuItem {objectName:"showcaseRetry";text:"重新读取资料";enabled:!controller.busy;onTriggered:controller.refresh()}
    }
    Controls.Dialog {id:cancelCollect;parent:Controls.Overlay.overlay;modal:true;title:"取消收藏";width:Math.min(parent.width-32,360*page.unit);standardButtons:Controls.Dialog.Ok|Controls.Dialog.Cancel;x:(parent.width-width)/2;y:(parent.height-height)/2
        Label {text:info.kind==="album"?"确定取消收藏这张专辑吗？":"确定取消收藏这张歌单吗？";font.pixelSize:16*page.unit}
        background:Rectangle {radius:14*page.unit;color:rhine.state.dark?"#30382a":"#f3f1e8";border.color:"#80ffffff"}
        onAccepted:controller.confirmUnsubscribe()
    }
}
