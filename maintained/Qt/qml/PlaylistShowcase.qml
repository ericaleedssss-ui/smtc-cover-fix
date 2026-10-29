import QtQuick
import QtQuick.Window
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
    function scrollSongs(e){var dy=e.pixelDelta.y||e.angleDelta.y/120*96*unit;songList.contentY=Math.max(songList.originY,Math.min(songList.originY+songList.contentHeight-songList.height,songList.contentY-dy));}
    function wheelRecord(e){var dy=e.pixelDelta.y||e.angleDelta.y;if(dy)moveRecord(dy<0?1:-1);}
    function moveSong(step){showSongs=true;songIndex=Math.max(0,Math.min(controller.songs.length-1,songIndex+step));controller.preview(songIndex);songList.positionViewAtIndex(songIndex,ListView.Contain);}
    function moveRecord(step){var target=controller.recordNeighbour(step);if(target.key)recordStack.choose(Object.assign({},target,{side:step}));else controller.prepareRecords();}
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
    onInfoChanged:if(info.key!==session){session=info.key||"";songIndex=-1;showSongs=false;}
    property string session:""
    component Label:Text {textFormat:Text.PlainText;color:page.ink;font.family:rhineFontFamily;font.pixelSize:16*page.unit;elide:Text.ElideRight}
    component Button:Controls.Button {
        property bool primary:false
        focusPolicy:Qt.NoFocus
        implicitHeight:40*page.unit;leftPadding:12*page.unit;rightPadding:12*page.unit
        contentItem:Label {text:parent.text;color:parent.primary?"#f7f7ed":page.ink;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;font.pixelSize:13*page.unit}
        background:Rectangle {radius:height/2;color:parent.primary?(parent.hovered?"#7e916c":"#70845e"):(parent.hovered?"#55ffffff":"#28ffffff");border.width:1;border.color:parent.primary?"transparent":"#bafffff5";opacity:parent.enabled?1:.45}
    }
    // Content only: the shared ArchiveReading owns the original glass.
    // Own only this panel's input; navigation and the player remain outside it.
    MouseArea {anchors.fill:parent;onClicked:{} onWheel:e=>{if(page.showSongs)page.scrollSongs(e);else page.wheelRecord(e);e.accepted=true;}}
    Label {x:26*unit;y:26*unit;width:page.textWidth;text:"MUSIC DATABASE / "+(info.sourceLabel||"收藏歌单");font.pixelSize:10*unit;color:page.muted}
    Label {objectName:"showcaseTitle";x:26*unit;y:62*unit;width:page.textWidth;height:64*unit;text:info.title||(info.kind==="album"?"专辑":"歌单");font.pixelSize:25*unit;font.weight:Font.DemiBold;wrapMode:Text.Wrap;maximumLineCount:2}
    Rectangle {x:26*unit;y:139*unit;width:page.textWidth;height:unit;color:page.muted;opacity:.5}
    Rectangle {x:26*unit;y:136*unit;width:6*unit;height:6*unit;color:page.ink}
    Flickable {x:26*unit;y:160*unit;width:page.textWidth;height:100*unit;visible:!page.showSongs;clip:true;contentHeight:description.implicitHeight;boundsBehavior:Flickable.StopAtBounds
        Label {id:description;width:parent.width;text:info.description|| (info.loading?"正在读取歌单资料…":(info.kind==="album"?"这张专辑还没有简介。":"这张歌单还没有简介。"));color:page.muted;font.pixelSize:14*unit;wrapMode:Text.Wrap;elide:Text.ElideNone;lineHeight:1.65}
        WheelHandler {target:null;onWheel:e=>{page.wheelRecord(e);e.accepted=true;}}
        Controls.ScrollBar.vertical:Controls.ScrollBar {}
    }
    ListView {id:songList;objectName:"showcaseSongPreview";x:26*unit;y:158*unit;width:page.textWidth;height:160*unit;visible:page.showSongs;clip:true;model:controller.songs;boundsBehavior:Flickable.StopAtBounds
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
        onContentYChanged:{var row=indexAt(1,contentY+height*.5);if(row>=0)controller.preview(row);}
        delegate:Rectangle {required property var modelData;required property int index;width:songList.width;height:32*page.unit;opacity:GraphicsInfo.api===GraphicsInfo.Software?Math.min(1,Math.max(0,(y-songList.contentY+height/2)/(14*page.unit)),Math.max(0,(songList.height-y+songList.contentY-height/2)/(12*page.unit))):1;radius:5*page.unit;color:page.songIndex===index?"#286f845e":"transparent"
            Label {x:9*page.unit;width:parent.width-18*page.unit;anchors.verticalCenter:parent.verticalCenter;text:(index+1)+"  "+modelData.title+(modelData.artist?" · "+modelData.artist:"");font.pixelSize:16*page.unit}
            MouseArea {anchors.fill:parent;onClicked:{page.songIndex=index;page.controller.preview(index);}onDoubleClicked:page.controller.playSong(index)}
        }
        Controls.ScrollBar.vertical:Controls.ScrollBar {}
        Label {visible:songList.count===0;anchors.centerIn:parent;text:info.loading?"读取曲目中…":"暂无可用曲目";color:page.muted}
    }
    Row {visible:!page.showSongs;x:26*unit;y:278*unit;spacing:12*unit
        Label {width:Math.min(150*unit,page.textWidth*.32);text:(info.kind==="album"?"艺人  ":"创建者  @")+(info.artist||"未知");font.pixelSize:12*unit;MouseArea {anchors.fill:parent;enabled:!!info.creatorID;cursorShape:Qt.PointingHandCursor;onClicked:controller.operate("creator")}}
        Label {text:"│  "+(info.total||0)+" 首歌曲";font.pixelSize:12*unit}
        Label {text:"│  "+(info.durationLabel||"");font.pixelSize:10*unit;color:page.muted}
    }
    Row {x:26*unit;y:337*unit;spacing:9*unit
        Button {objectName:"showcasePlay";text:"▶  播放全部";primary:true;width:Math.min(150*unit,page.textWidth*.29);enabled:!controller.busy;onClicked:controller.operate("play")}
        Button {objectName:"showcaseShuffle";text:"⇄  随机播放";width:Math.min(120*unit,page.textWidth*.26);enabled:!controller.busy;onClicked:controller.operate("shuffle")}
        Button {objectName:"showcaseCollect";text:info.editable?"我的歌单":info.subscribed?"♡  已收藏":"♡  收藏";width:Math.min(105*unit,page.textWidth*.25);enabled:info.canSubscribe&&!controller.busy;onClicked:page.collect()}
        Button {objectName:"showcaseMore";text:"•••";leftPadding:10*unit;rightPadding:10*unit;onClicked:more.popup()}
    }
    Label {x:26*unit;y:382*unit;width:page.textWidth;text:controller.status||"";color:page.muted;font.pixelSize:10*unit}
    RecordStack {id:recordStack;objectName:"showcaseRecordStack";x:page.width-width-24*unit;y:66*unit;width:page.coverWidth;height:232*unit;unit:page.unit;controller:page.controller;background:page.background;reduced:rhine.state.reduced;editorial:true}
    Label {anchors.right:parent.right;anchors.rightMargin:38*unit;y:322*unit;text:(info.recordPosition||1)+" / "+(info.recordCount||1)+"    ←  →";font.pixelSize:10*unit;color:page.muted}
    Rectangle {x:20*unit;y:400*unit;width:parent.width-40*unit;height:unit;color:page.muted;opacity:.2}
    Label {x:26*unit;y:412*unit;width:parent.width-52*unit;text:(page.showSongs?"ENTER  播放所选歌曲":"ENTER  播放全部")+"    ·    SPACE  随机播放    ·    F  收藏/取消收藏    ·    TAB  简介/歌曲    ·    ← →  切换歌单/专辑    ·    ↑ ↓  浏览歌曲"+(page.showSongs?"    ·    滚轮  滚动列表":"    ·    滚轮  切换歌单/专辑");font.pixelSize:10*unit;color:page.muted}
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
