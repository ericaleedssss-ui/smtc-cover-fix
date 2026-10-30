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
    readonly property real discSize:Math.min(490*unit,width*.60)
    readonly property real vinylInset:discSize*.25
    readonly property real textWidth:width*.50-42*unit
    readonly property bool motion:visible&&playback.playing&&!rhine.state.reduced&&(!Window.window||Window.window.visibility!==Window.Minimized)
    function syncMotion(){
        for(var animation of [discSpin,ringPulse]){
            if(!animation)continue;
            if(motion){if(animation.paused)animation.resume();else if(!animation.running)animation.start();}
            else if(animation.running&&!animation.paused)animation.pause();
        }
    }
    onMotionChanged:syncMotion()
    Component.onCompleted:syncMotion()
    property bool following:true
    function dismissTopOverlay(){if(more.visible){more.close();return true;}return false;}
    function follow(){if(following&&playback.index>=0)lyrics.positionViewAtIndex(playback.index,ListView.Beginning);}
    function stamp(ms){var s=Math.max(0,Math.floor(ms/1000));return Math.floor(s/60)+":"+String(s%60).padStart(2,"0");}
    onInfoChanged:if(info.session!==session){session=info.session||"";following=true;lyrics.contentY=0;}
    property string session:""
    Connections {target:page.controller;function onPlaybackChanged(){page.follow();} function onLinesChanged(){Qt.callLater(page.follow);}}
    component Label:Text {textFormat:Text.PlainText;font.family:rhineFontFamily;color:page.ink;font.pixelSize:13*page.unit;elide:Text.ElideRight}
    component Action:Controls.Button {
        id:button
        property string symbol
        property string artwork:""
        property string subtitle:""
        focusPolicy:Qt.NoFocus;hoverEnabled:true
        implicitWidth:88*page.unit;implicitHeight:36*page.unit
        padding:4*page.unit
        HoverHandler {cursorShape:Qt.PointingHandCursor;enabled:button.enabled}
        contentItem:Item {
            Rectangle {x:0;anchors.verticalCenter:parent.verticalCenter;width:26*page.unit;height:width;radius:width/2;color:button.hovered?"#65fffdf3":"#40fffdf3"
                RhineIcon {anchors.centerIn:parent;width:15*page.unit;height:width;name:button.symbol;color:page.ink;visible:!!button.symbol&&!button.artwork}
                Image {anchors.centerIn:parent;width:18*page.unit;height:width;source:button.artwork;visible:!!source;fillMode:Image.PreserveAspectFit;sourceSize:Qt.size(24,24)}
            }
            Column {x:32*page.unit;anchors.verticalCenter:parent.verticalCenter;width:Math.max(0,parent.width-x);spacing:1*page.unit;visible:!!button.text
                Label {width:parent.width;text:button.text;font.pixelSize:11*page.unit}
                Label {width:parent.width;text:button.subtitle;font.pixelSize:8*page.unit;color:page.muted;visible:!!text}
            }
        }
        background:Rectangle {radius:height/2;color:button.hovered?"#42fffdf4":"#22fffdf4";border.width:.7*page.unit;border.color:"#55fffdf3";Behavior on color {ColorAnimation {duration:120}}}
        opacity:enabled?1:.45
    }
    MouseArea {anchors.fill:parent;onClicked:{} onWheel:e=>{var p=mapToItem(null,e.x,e.y);rhine.wheelInput(p.x/page.unit,p.y/page.unit,e.pixelDelta.y,e.angleDelta.y);e.accepted=true;}}
    Label {x:26*unit;y:25*unit;width:page.textWidth;text:"NOW PLAYING / 正在播放";font.pixelSize:11*unit;color:page.muted}
    Label {id:songTitle;objectName:"nowPlayingTitle";x:26*unit;y:55*unit;width:page.textWidth;height:implicitHeight;text:info.title||"正在播放";font.pixelSize:27*unit;font.weight:Font.Bold;wrapMode:Text.Wrap;maximumLineCount:2
        color:titleHit.containsMouse?page.muted:page.ink
        MouseArea {id:titleHit;objectName:"nowPlayingTitleHit";anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:page.controller.operate("details")}
    }
    Label {objectName:"nowAlbum";x:26*unit;y:songTitle.y+songTitle.height+7*unit;width:page.textWidth;text:info.album||"";font.pixelSize:12*unit;color:albumHit.containsMouse?page.ink:page.muted
        MouseArea {id:albumHit;objectName:"nowAlbumHit";anchors.fill:parent;enabled:!!page.info.albumID&&String(page.info.albumID)!=="0";hoverEnabled:true;cursorShape:enabled?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:page.controller.operate("album")}
    }
    ListView {
        id:lyrics;objectName:"nowPlayingLyrics";x:24*unit;y:146*unit;width:page.textWidth+4*unit;height:161*unit
        model:page.controller.lines;clip:true;boundsBehavior:Flickable.StopAtBounds;spacing:5*unit
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
            width:lyrics.width;height:Math.max(78*page.unit,words.implicitHeight+18*page.unit)
            opacity:GraphicsInfo.api===GraphicsInfo.Software?Math.min(1,Math.max(0,(y-lyrics.contentY+height/2)/(10*page.unit)),Math.max(0,(lyrics.height-y+lyrics.contentY-height/2)/(10*page.unit))):1
            Rectangle {anchors.fill:parent;radius:5*page.unit;color:hit.containsMouse?"#186f845e":"transparent";Behavior on color {ColorAnimation {duration:120}}}
            Label {x:2*page.unit;anchors.verticalCenter:parent.verticalCenter;width:34*page.unit;text:page.stamp(line.modelData.startMs||0);font.pixelSize:9*page.unit;color:page.muted;visible:hit.containsMouse&&page.playback.timed}
            Column {id:words;x:33*page.unit;y:9*page.unit;width:parent.width-x-5*page.unit;spacing:4*page.unit
                Label {width:parent.width;text:line.modelData.text||"";wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:22*page.unit;font.weight:line.current?Font.Medium:Font.Normal;maximumLineCount:2;color:line.current||hit.containsMouse?page.ink:page.muted;opacity:line.current||hit.containsMouse?.94:.82}
                Label {width:parent.width;text:line.modelData.translation||"";visible:!!text;wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:12*page.unit;color:page.muted;maximumLineCount:2}
            }
            MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;cursorShape:page.playback.timed&&page.playback.seekable?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:{page.controller.seekLine(line.index,page.info.session);page.following=true;}}
        }
        Label {anchors.centerIn:parent;visible:lyrics.count===0;text:page.playback.lyricStatus==="loading"?"正在读取歌词…":page.playback.lyricStatus==="error"?"歌词暂不可用":"暂无歌词";color:page.muted}
    }
    Label {objectName:"nowLyricsFollow";x:26*unit;y:307*unit;text:"回到当前歌词";font.pixelSize:10*unit;color:page.muted;visible:!page.following&&lyrics.count>0;MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{page.following=true;page.follow();}}}
    Row {x:26*unit;y:331*unit;spacing:7*unit;height:36*unit
        Action {objectName:"nowLike";width:82*page.unit;enabled:info.canLike&&info.likeKnown&&!info.likeBusy;text:info.likeKnown?(info.liked?"已喜欢":"喜欢"):"读取中";subtitle:info.liked?"留在喜欢里":"收藏这首歌";artwork:page.info.likeKnown?(page.info.liked?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png"):"";Accessible.name:info.liked?"取消喜欢":"喜欢";onClicked:controller.operate("like")}
        Action {objectName:"nowComments";symbol:"comment";width:92*page.unit;text:"评论";subtitle:rhine.state.socialSongID===page.info.id&&rhine.state.socialCommentCount>=0?String(rhine.state.socialCommentCount)+" 条评论":"查看评论";onClicked:controller.operate("comments")}
        Action {objectName:"nowShare";symbol:"share";width:82*page.unit;text:"分享";subtitle:"分享这首歌";Accessible.name:"分享";onClicked:controller.operate("share")}
        Controls.Button {objectName:"nowMore";width:36*page.unit;height:36*page.unit;padding:0;focusPolicy:Qt.NoFocus;hoverEnabled:true;Accessible.name:"更多操作"
            contentItem:Item {Row {anchors.centerIn:parent;spacing:3.5*page.unit;Repeater {model:3;Rectangle {width:2.6*page.unit;height:width;radius:width/2;color:page.ink}}}}
            background:Rectangle {objectName:"nowMoreSurface";radius:height/2;color:parent.hovered?"#42fffdf4":"#22fffdf4";border.width:.7*page.unit;border.color:"#55fffdf3"}
            HoverHandler {cursorShape:Qt.PointingHandCursor}
            Controls.ToolTip.visible:hovered;Controls.ToolTip.text:"更多操作";Controls.ToolTip.delay:500
            onClicked:{var p=mapToItem(page,0,height);more.x=Math.max(0,Math.min(page.width-more.implicitWidth,p.x));more.y=Math.min(page.height-more.implicitHeight,Math.max(0,p.y+6*page.unit));more.open();}
        }
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
        id:discField;objectName:"nowDiscField";anchors.fill:parent;clip:true;z:-1
        // One composite owns the record, all reflections and bounce.
        // It alone applies screen-space focal fade and the exact glass boundary.
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
        layer.effect:ShaderEffect {objectName:"nowRecordComposite";property variant artwork;property real phase:discField.width/Math.max(1,discField.height);property real shadowOnly:7;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
        Item {objectName:"nowRecordRings";anchors.fill:parent;opacity:page.motion?1:0;Behavior on opacity {NumberAnimation {duration:240}}
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
            layer.effect:ShaderEffect {property variant artwork;property real phase:0;property real shadowOnly:3;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            Item {id:haloPlane;x:record.x;y:record.y;width:record.width;height:record.height
                transform:[Rotation {origin.x:haloPlane.width/2;origin.y:haloPlane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:32},Rotation {origin.x:haloPlane.width/2;origin.y:haloPlane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
                ShaderEffect {objectName:"nowRippleShader";x:-parent.width*.45;y:x;width:parent.width*1.90;height:width
                    property variant artwork:shadowArt
                    property real phase:record.phase
                    property real shadowOnly:0
                    property real darkMode:rhine.state.dark?1:0
                    fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                }
            }
        }
    Item {
        id:record;objectName:"nowRecord";x:parent.width-width+38*page.unit;y:(parent.height-height)/2-6*page.unit;width:page.discSize;height:width
        property real phase:0
        NumberAnimation on phase {id:ringPulse;from:0;to:1;duration:6500;loops:Animation.Infinite;running:false}
        // The perspective belongs to the stationary platter. Only its inset print spins.
        Item {id:plane;objectName:"nowRecordBase";anchors.fill:parent;anchors.margins:-page.vinylInset
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
            layer.effect:ShaderEffect {property variant artwork;property real phase:0;property real shadowOnly:5;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            transform:[Rotation {objectName:"nowRecordTilt";origin.x:plane.width/2;origin.y:plane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:32},Rotation {origin.x:plane.width/2;origin.y:plane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
            ShaderEffect {
                objectName:"nowRecordShadow";opacity:.10;x:-parent.width*.32;y:-parent.height*.32+8*page.unit;width:parent.width*1.64;height:width
                property variant artwork:shadowArt
                property real phase:0
                property real shadowOnly:1
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                Image {id:shadowArt;visible:false;source:page.info.coverPixels||"";sourceSize:Qt.size(64,64);asynchronous:true;cache:true}
            }
            // A narrow lower sidewall, not a bright outline or a filled shadow disc.
            ShaderEffect {objectName:"nowRecordContactEdge";x:0;y:3*page.unit;width:parent.width;height:parent.height
                property variant artwork:printArt
                property real phase:0
                property real shadowOnly:10
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
            }
            ShaderEffect {objectName:"nowRecordPlatter";anchors.fill:parent
                property variant artwork:printArt
                property real phase:recordPrint.width/(plane.width*2)
                property real shadowOnly:9
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
            }
            Item {id:recordPrint;objectName:"nowRecordPrint";anchors.fill:parent;anchors.margins:page.vinylInset+4*page.unit;transformOrigin:Item.Center
                opacity:rhine.state.dark?.72:.64
                property real spinAngle:0
                NumberAnimation on spinAngle {id:discSpin;from:0;to:360;duration:40000;loops:Animation.Infinite;running:false}
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
            ShaderEffect {objectName:"nowRecordGloss";anchors.fill:parent
                property variant artwork:printArt
                property real phase:recordPrint.width/(plane.width*2)
                property real shadowOnly:4
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
            }
        }
    }

    }
    Row {anchors.right:parent.right;anchors.rightMargin:26*unit;y:412*unit;spacing:18*unit;height:18*unit
        Label {objectName:"nowDetails";height:18*unit;verticalAlignment:Text.AlignVCenter;text:"查看歌曲详情  →";font.pixelSize:10*unit;color:detailHit.containsMouse?page.ink:page.muted;MouseArea {id:detailHit;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:controller.operate("details")}}
    }
    Controls.Menu {id:more;parent:page;font.family:rhineFontFamily;palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.text:page.ink
        Controls.MenuItem {objectName:"nowCollect";text:"添加到歌单";onTriggered:controller.operate("collect")}
        Controls.MenuItem {text:"查看歌曲详情";onTriggered:controller.operate("details")}
        Controls.MenuItem {text:"重新读取歌词";onTriggered:controller.operate("retry-lyrics")}
        Controls.MenuItem {text:"在官方客户端打开";onTriggered:controller.operate("official")}
        Controls.MenuItem {text:"返回浏览信息";onTriggered:controller.operate("browse")}
    }
}
