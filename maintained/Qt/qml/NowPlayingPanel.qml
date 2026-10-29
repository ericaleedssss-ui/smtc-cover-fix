import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

Item {
    id:page
    objectName:"nowPlayingPanel"
    required property var controller
    property real unit:1
    readonly property var info:controller.info
    readonly property var playback:controller.playback
    readonly property color ink:rhine.state.dark?"#eceee3":"#30372e"
    readonly property color muted:rhine.state.dark?"#b1b9a5":"#77806e"
    readonly property real discSize:Math.min(286*unit,width*.34)
    readonly property real textWidth:width-discSize-82*unit
    readonly property bool motion:visible&&playback.playing&&!rhine.state.reduced
    property bool following:true
    function dismissTopOverlay(){if(more.visible){more.close();return true;}return false;}
    function follow(){if(following&&playback.index>=0)lyrics.positionViewAtIndex(playback.index,ListView.Center);}
    function stamp(ms){var s=Math.max(0,Math.floor(ms/1000));return Math.floor(s/60)+":"+String(s%60).padStart(2,"0");}
    onInfoChanged:if(info.session!==session){session=info.session||"";following=true;lyrics.contentY=0;}
    property string session:""
    Connections {target:page.controller;function onPlaybackChanged(){page.follow();} function onLinesChanged(){Qt.callLater(page.follow);}}
    component Label:Text {textFormat:Text.PlainText;font.family:rhineFontFamily;color:page.ink;font.pixelSize:13*page.unit;elide:Text.ElideRight}
    component Action:Controls.Button {
        id:button
        property string symbol
        property bool primary:false
        focusPolicy:Qt.NoFocus;hoverEnabled:true
        implicitWidth:34*page.unit;implicitHeight:34*page.unit
        leftPadding:primary?12*page.unit:8*page.unit;rightPadding:leftPadding
        HoverHandler {cursorShape:Qt.PointingHandCursor;enabled:button.enabled}
        contentItem:Row {spacing:6*page.unit
            RhineIcon {anchors.verticalCenter:parent.verticalCenter;width:16*page.unit;height:width;name:button.symbol;color:button.primary?"#f4f5ee":page.ink;visible:!!button.symbol}
            Label {anchors.verticalCenter:parent.verticalCenter;text:button.text;color:button.primary?"#f4f5ee":page.ink;visible:!!text;font.pixelSize:12*page.unit}
        }
        background:Rectangle {radius:height/2;color:button.primary?(button.hovered?"#7b9068":"#70845e"):(button.hovered?"#386f845e":"#18ffffff");border.width:page.unit;border.color:button.primary?"transparent":"#70fffff3";Behavior on color {ColorAnimation {duration:120}}}
        opacity:enabled?1:.42
    }
    MouseArea {anchors.fill:parent;onClicked:{} onWheel:e=>{var p=mapToItem(null,e.x,e.y);rhine.wheelInput(p.x/page.unit,p.y/page.unit,e.pixelDelta.y,e.angleDelta.y);e.accepted=true;}}
    Label {x:26*unit;y:25*unit;width:page.textWidth;text:"NOW PLAYING / 正在播放";font.pixelSize:11*unit;color:page.muted}
    Label {objectName:"nowPlayingTitle";x:26*unit;y:55*unit;width:page.textWidth;height:56*unit;text:info.title||"正在播放";font.pixelSize:27*unit;font.weight:Font.Bold;wrapMode:Text.Wrap;maximumLineCount:2
        color:titleHit.containsMouse?page.muted:page.ink
        MouseArea {id:titleHit;objectName:"nowPlayingTitleHit";anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:page.controller.operate("details")}
    }
    Label {x:26*unit;y:118*unit;width:page.textWidth;text:info.album||"";font.pixelSize:12*unit;color:page.muted}
    ListView {
        id:lyrics;objectName:"nowPlayingLyrics";x:24*unit;y:146*unit;width:page.textWidth+4*unit;height:161*unit
        model:page.controller.lines;clip:true;boundsBehavior:Flickable.StopAtBounds;spacing:4*unit
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
        layer.effect:ShaderEffect {property variant source;property size panelSize:Qt.size(lyrics.width,lyrics.height);property real topInset:0;property real fadePx:10*page.unit;property real fadeTop:1;property real bottomFadePx:10*page.unit;fragmentShader:"qrc:/shaders/magazineEdgeFade.frag.qsb"}
        WheelHandler {target:null;onWheel:e=>{page.following=false;var dy=e.pixelDelta.y||e.angleDelta.y/120*55*page.unit;lyrics.contentY=Math.max(lyrics.originY,Math.min(lyrics.originY+Math.max(0,lyrics.contentHeight-lyrics.height),lyrics.contentY-dy));e.accepted=true;}}
        Behavior on contentY {enabled:page.following&&!rhine.state.reduced&&!lyrics.dragging;NumberAnimation {duration:240;easing.type:Easing.OutCubic}}
        onDraggingChanged:if(dragging)page.following=false
        delegate:Item {
            id:line
            required property var modelData
            required property int index
            objectName:"nowLyric_"+index
            property bool current:index===page.playback.index
            width:lyrics.width;height:Math.max(39*page.unit,words.implicitHeight+10*page.unit)
            opacity:GraphicsInfo.api===GraphicsInfo.Software?Math.min(1,Math.max(0,(y-lyrics.contentY+height/2)/(10*page.unit)),Math.max(0,(lyrics.height-y+lyrics.contentY-height/2)/(10*page.unit))):1
            Rectangle {anchors.fill:parent;radius:5*page.unit;color:hit.containsMouse?"#186f845e":"transparent";Behavior on color {ColorAnimation {duration:120}}}
            Label {x:2*page.unit;anchors.verticalCenter:parent.verticalCenter;width:34*page.unit;text:page.stamp(line.modelData.startMs||0);font.pixelSize:9*page.unit;color:page.muted;visible:hit.containsMouse&&page.playback.timed}
            Column {id:words;x:39*page.unit;y:5*page.unit;width:parent.width-x-5*page.unit;spacing:4*page.unit
                Label {width:parent.width;text:line.modelData.text||"";wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:17*page.unit;font.weight:line.current?Font.DemiBold:Font.Normal;color:line.current||hit.containsMouse?page.ink:page.muted;opacity:line.current||hit.containsMouse?1:.6}
                Label {width:parent.width;text:line.modelData.translation||"";visible:!!text;wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:11*page.unit;color:page.muted}
            }
            MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;cursorShape:page.playback.timed&&page.playback.seekable?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:{page.controller.seekLine(line.index,page.info.session);page.following=true;}}
        }
        Label {anchors.centerIn:parent;visible:lyrics.count===0;text:page.playback.lyricStatus==="loading"?"正在读取歌词…":page.playback.lyricStatus==="error"?"歌词暂不可用":"暂无歌词";color:page.muted}
    }
    Label {objectName:"nowLyricsFollow";x:26*unit;y:307*unit;text:"回到当前歌词";font.pixelSize:10*unit;color:page.muted;visible:!page.following&&lyrics.count>0;MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{page.following=true;page.follow();}}}
    Row {x:26*unit;y:331*unit;spacing:9*unit;height:34*unit
        Action {objectName:"nowComments";primary:true;symbol:"comment";width:104*page.unit;text:"评论"+(rhine.state.socialSongID===page.info.id&&rhine.state.socialCommentCount>=0?" "+rhine.state.socialCommentCount:"");onClicked:controller.operate("comments")}
        Action {objectName:"nowLike";width:34*page.unit;enabled:info.canLike&&info.likeKnown&&!info.likeBusy;Accessible.name:info.liked?"取消喜欢":"喜欢";onClicked:controller.operate("like")
            contentItem:Item {
                Image {anchors.fill:parent;visible:page.info.likeKnown;source:page.info.liked?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png";fillMode:Image.PreserveAspectFit;sourceSize:Qt.size(24,24)}
                Label {anchors.centerIn:parent;visible:!page.info.likeKnown;text:"…";color:page.muted}
            }
        }
        Action {objectName:"nowShare";symbol:"share";width:34*page.unit;Accessible.name:"分享";onClicked:controller.operate("share")}
        Action {objectName:"nowMore";symbol:"more";width:34*page.unit;Accessible.name:"更多";onClicked:more.popup()}
    }
    Label {x:26*unit;y:369*unit;width:page.textWidth;text:controller.status||"";font.pixelSize:10*unit;color:page.muted}
    Row {id:metadata;x:26*unit;y:392*unit;width:page.textWidth;spacing:8*unit;height:26*unit
        Rectangle {width:24*page.unit;height:width;radius:width/2;color:rhine.state.dark?"#59614f":"#cdd2c5"
            RhineIcon {anchors.centerIn:parent;width:16*page.unit;height:width;name:"user";color:page.muted}
            Image {anchors.fill:parent;source:page.info.artistAvatar||"";fillMode:Image.PreserveAspectFit}
        }
        ArtistMarquee {people:page.info.artists||[];fallback:page.info.artist||"未知艺人";unit:page.unit;height:26*page.unit;width:Math.min(implicitWidth,Math.max(45*page.unit,metadata.width*.34));onPersonClicked:id=>page.controller.openArtist(id)}
        Label {height:26*page.unit;verticalAlignment:Text.AlignVCenter;text:"│";color:page.muted}
        Label {id:date;objectName:"nowReleaseDate";height:26*page.unit;verticalAlignment:Text.AlignVCenter;text:info.date||"发行日期暂无";font.pixelSize:12*page.unit;color:page.muted}
        Label {height:26*page.unit;verticalAlignment:Text.AlignVCenter;text:"│";color:page.muted}
        Label {objectName:"nowGenres";height:26*page.unit;verticalAlignment:Text.AlignVCenter;width:Math.max(28*page.unit,metadata.width-x);text:(page.info.tags||[]).length?page.info.tags.join(" / "):"曲风暂无";font.pixelSize:12*page.unit;color:page.muted}
    }
    Item {
        id:record;objectName:"nowRecord";x:parent.width-width-22*unit;y:65*unit;width:page.discSize;height:width
        property real phase:0
        NumberAnimation on phase {from:0;to:1;duration:6500;loops:Animation.Infinite;running:!rhine.state.reduced;paused:!page.motion}
        // The perspective belongs to the stationary platter. Only its inset print spins.
        Item {id:plane;objectName:"nowRecordBase";anchors.fill:parent
            transform:[Rotation {objectName:"nowRecordTilt";origin.x:plane.width/2;origin.y:plane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:32},Rotation {origin.x:plane.width/2;origin.y:plane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
            ShaderEffect {
                objectName:"nowRecordShadow";x:-parent.width*.32;y:-parent.height*.32+8*page.unit;width:parent.width*1.64;height:width
                property variant artwork:shadowArt
                property real phase:0
                property real shadowOnly:1
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                Image {id:shadowArt;visible:false;source:page.info.coverPixels||"";sourceSize:Qt.size(64,64);asynchronous:true;cache:true}
            }
            Item {objectName:"nowRecordRings";anchors.fill:parent;opacity:page.motion?1:0;Behavior on opacity {NumberAnimation {duration:240}}
                ShaderEffect {
                    x:-parent.width*.32;y:x;width:parent.width*1.64;height:width
                    property variant artwork:shadowArt
                    property real phase:record.phase
                    property real shadowOnly:0
                    property real darkMode:rhine.state.dark?1:0
                    fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                }
            }
            // Thin fixed ivory lip and contact edge, with no offset opaque cylinder.
            Rectangle {objectName:"nowRecordContactEdge";x:0;y:3*page.unit;width:parent.width;height:parent.height;radius:width/2;color:rhine.state.dark?"#666759":"#bfb09b"}
            Rectangle {objectName:"nowRecordPlatter";anchors.fill:parent;radius:width/2
                gradient:Gradient {GradientStop {position:0;color:rhine.state.dark?"#d0cbb6":"#fff9ed"} GradientStop {position:.6;color:rhine.state.dark?"#777a68":"#eae1d0"} GradientStop {position:1;color:rhine.state.dark?"#a7a48e":"#d5c5ae"}}
                border.width:page.unit;border.color:"#c0fffdf5"
            }
            Item {id:recordPrint;objectName:"nowRecordPrint";anchors.fill:parent;anchors.margins:4*page.unit;transformOrigin:Item.Center
                property real spinAngle:0
                NumberAnimation on spinAngle {from:0;to:360;duration:40000;loops:Animation.Infinite;running:!rhine.state.reduced;paused:!page.motion}
                Image {id:printArt;objectName:"nowRecordArtwork";anchors.fill:parent;source:page.info.coverPixels||"";fillMode:Image.PreserveAspectFit;asynchronous:true;cache:true
                    visible:GraphicsInfo.api===GraphicsInfo.Software
                    rotation:visible?recordPrint.spinAngle:0
                }
                ShaderEffect {anchors.fill:parent;visible:GraphicsInfo.api!==GraphicsInfo.Software
                    property variant artwork:printArt
                    property real phase:recordPrint.spinAngle/360
                    property real shadowOnly:2
                    property real darkMode:0
                    fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                }
            }
            // Highlight remains on the fixed rim, never follows the cover's rotation.
            Rectangle {anchors.fill:parent;radius:width/2;color:"transparent";border.width:1.4*page.unit;border.color:"#a0fffdf3"}
        }
    }
    Label {objectName:"nowDetails";anchors.right:parent.right;anchors.rightMargin:26*unit;y:412*unit;text:"查看歌曲详情  →";font.pixelSize:10*unit;color:detailHit.containsMouse?page.ink:page.muted;MouseArea {id:detailHit;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:controller.operate("details")}}
    Controls.Menu {id:more;font.family:rhineFontFamily;palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.text:page.ink
        Controls.MenuItem {objectName:"nowCollect";text:"添加到歌单";onTriggered:controller.operate("collect")}
        Controls.MenuItem {text:"查看歌曲详情";onTriggered:controller.operate("details")}
        Controls.MenuItem {text:"重新读取歌词";onTriggered:controller.operate("retry-lyrics")}
        Controls.MenuItem {text:"在官方客户端打开";onTriggered:controller.operate("official")}
        Controls.MenuItem {text:"返回浏览信息";onTriggered:controller.operate("browse")}
    }
}
