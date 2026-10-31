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
    readonly property real vinylInset:discSize*.31
    readonly property real textWidth:width*.50-42*unit
    readonly property bool motion:visible&&playback.playing&&!rhine.state.reduced&&(!Window.window||Window.window.visibility!==Window.Minimized)
    property real spinPhase:0
    property real platterPhase:0
    property bool armPlaybackStateInitialized:false
    property bool armObservedPlaying:false
    property bool armOutReady:false
    property bool recordCoverReady:false
    property string armMotionMode:"idle"
    readonly property bool armTransitionRunning:armMotionAnimation.running||armMotionMode==="changeOut"
    readonly property bool recordVisualTransitionRunning:recordChangeAnimation.running
    function stopArmAnimations(){
        armMotionAnimation.stop();
        armMotionMode="idle";
    }
    function animateArmToPlaybackState(){
        if(!armPlane)return;
        armMotionAnimation.stop();
        armMotionMode="playback";
        armMotionAnimation.to=armPlane.normalPose;
        armMotionAnimation.duration=rhine.state.reduced?0:260;
        armMotionAnimation.start();
    }
    function startArmChangeOut(){
        if(!recordTransitioning||!playback.playing)return;
        armMotionAnimation.stop();
        armMotionMode="changeOut";
        armMotionAnimation.to=1;
        armMotionAnimation.duration=rhine.state.reduced?0:360;
        armMotionAnimation.start();
    }
    function startArmReturn(){
        if(!armPlane)return;
        armMotionAnimation.stop();
        armMotionMode="changeReturn";
        armMotionAnimation.to=armPlane.normalPose;
        armMotionAnimation.duration=rhine.state.reduced?0:360;
        armMotionAnimation.start();
    }
    function handleArmMotionFinished(){
        var mode=armMotionMode;
        armMotionMode="idle";
        if(mode==="changeOut"){
            armOutReady=true;
            startRecordVisualTransition();
        }else if(mode==="changeReturn"&&recordTransitioning){
            armMotionMode="idle";
        }else if(mode==="playback"&&recordTransitioning&&armPlane.pose>0.5){
            armOutReady=true;
            startRecordVisualTransition();
        }
    }
    function syncArmPlayback(){
        var playing=!!playback.playing;
        if(!armPlaybackStateInitialized){
            armObservedPlaying=playing;
            armPlaybackStateInitialized=true;
            if(armPlane)armPlane.pose=armPlane.normalPose;
            return;
        }
        if(playing===armObservedPlaying)return;
        armObservedPlaying=playing;
        if(!armPlane)return;
        // One animation object owns pose. Playback changes interrupt the
        // current song gesture and move to the actual playback state.
        animateArmToPlaybackState();
        if(recordTransitioning&&playing){
            armOutReady=true;
            Qt.callLater(page.startRecordVisualTransition);
        }
    }
    function syncMotion(){
        for(var animation of [recordSpin,platterPulse]){
            if(!animation)continue;
            if(motion){if(animation.paused)animation.resume();else if(!animation.running)animation.start();}
            else if(animation.running&&!animation.paused)animation.pause();
        }
    }
    onMotionChanged:syncMotion()
    Component.onCompleted:{armObservedPlaying=!!playback.playing;armPlaybackStateInitialized=true;syncMotion();}
    NumberAnimation on spinPhase {id:recordSpin;from:0;to:1;duration:40000;loops:Animation.Infinite;running:false}
    NumberAnimation on platterPhase {id:platterPulse;from:0;to:1;duration:6500;loops:Animation.Infinite;running:false}
    property bool following:true
    // The text panel follows the real player immediately, while the record
    // keeps its own old/new visual identities until a platter change settles.
    property var displayedInfo: ({})
    property var transitionInfo: null
    property bool visualInitialized:false
    property bool recordTransitioning:false
    property string visualFallbackCover:""
    property string displayedFallbackCover:""
    // Title etched in the clear seat ring. Rebuilt only when the song changes.
    readonly property string etchText:(info.title||"")+"  ·  "+(info.artist||"")+"  ·  SIDE A  ·  33⅓  ·  RHINE MUSIC DATABASE  ·  "
    function etchGlyphs(text,radius,px){
        var out=[],a=-Math.PI*.5,r=Math.max(1,radius);
        for(var i=0;i<text.length&&a<Math.PI*1.45;++i){var ch=text[i];var w=(ch.charCodeAt(0)>0x2e80?1.0:.6)*px;a+=w/2/r;out.push({c:ch,a:a});a+=w/2/r+.7/r;}
        return out;
    }
    function dismissTopOverlay(){if(more.visible){more.close();return true;}return false;}
    property bool lyricFollowRetryScheduled:false
    function follow(){
        if(!following||playback.index<0||playback.index>=lyrics.count||!lyrics.count)return;
        var item=lyrics.itemAtIndex(playback.index);
        if(!item){
            // Ask the virtualized ListView to instantiate the target delegate.
            // Retry once after layout; never spin an unbounded callLater loop.
            if(!lyricFollowRetryScheduled){
                lyricFollowRetryScheduled=true;
                lyrics.positionViewAtIndex(playback.index,ListView.Contain);
                Qt.callLater(function(){
                    page.lyricFollowRetryScheduled=false;
                    // If layout still has not produced the delegate, stop here.
                    // A later playback/lyrics notification can request another attempt.
                    if(lyrics.itemAtIndex(page.playback.index))page.follow();
                });
            }
            return;
        }
        var target=Math.max(lyrics.originY,Math.min(lyrics.originY+Math.max(0,lyrics.contentHeight-lyrics.height),item.y-(lyrics.height-item.height)/2));
        lyricFollowAnimation.stop();lyricFollowAnimation.to=target;lyricFollowAnimation.duration=rhine.state.reduced?0:280;lyricFollowAnimation.start();
    }
    function stamp(ms){var s=Math.max(0,Math.floor(ms/1000));return Math.floor(s/60)+":"+String(s%60).padStart(2,"0");}
    function mergeInfo(base,next){
        var merged=Object.assign({},base||{});if(next)for(var key in next)merged[key]=next[key];return merged;
    }
    function beginRecordChange(next){
        if(!next||!next.session)return;
        displayedFallbackCover=displayedInfo.coverPixels||displayedFallbackCover||visualFallbackCover;
        transitionInfo=mergeInfo({},next);recordTransitioning=true;
        record.transitionY=0;record.visualOpacity=1;
        incomingRecord.transitionY=16*unit;incomingRecord.visualOpacity=0;incomingRecord.visible=true;
        stopArmAnimations();recordChangeAnimation.stop();recordCoverWait.stop();
        recordCoverReady=false;
        if(playback.playing){armOutReady=false;startArmChangeOut();}
        else {armPlane.pose=1;armOutReady=true;}
        if(incomingRecord.artworkReady){recordCoverReady=true;startRecordVisualTransition();}
        else recordCoverWait.restart();
    }
    function finishRecordChange(){
        if(!recordTransitioning)return;
        recordCoverWait.stop();
        displayedInfo=mergeInfo({},transitionInfo||info);record.transitionY=0;record.visualOpacity=1;
        displayedFallbackCover=displayedInfo.coverPixels||visualFallbackCover||displayedFallbackCover;
        incomingRecord.visible=false;incomingRecord.transitionY=16*unit;incomingRecord.visualOpacity=0;
        transitionInfo=null;recordTransitioning=false;recordCoverReady=false;armOutReady=false;
        if(playback.playing)startArmReturn();
        else {stopArmAnimations();armPlane.pose=1;}
    }
    onInfoChanged:{
        var next=info||({});
        if(!visualInitialized){displayedInfo=mergeInfo({},next);visualFallbackCover=next.coverPixels||"";displayedFallbackCover=visualFallbackCover;visualInitialized=true;}
        else if(recordTransitioning){
            if(next.session&&next.session!==((transitionInfo&&transitionInfo.session)||""))beginRecordChange(next);
            else transitionInfo=mergeInfo(transitionInfo,next);
        }else if(next.session!==displayedInfo.session){beginRecordChange(next);
        }
        else displayedInfo=mergeInfo(displayedInfo,next);
        if(next.coverPixels){visualFallbackCover=next.coverPixels;if(!recordTransitioning)displayedFallbackCover=next.coverPixels;}
        if(next.session!==session){session=next.session||"";following=true;Qt.callLater(page.follow);}
    }
    property string session:""
    Connections {target:page.controller;function onPlaybackChanged(){
            page.follow();
            page.syncArmPlayback();
        } function onLinesChanged(){Qt.callLater(page.follow);}}
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
            Rectangle {objectName:"nowActionIcon";x:0;anchors.verticalCenter:parent.verticalCenter;width:28*page.unit;height:width;radius:width/2;color:button.hovered?(rhine.state.dark?"#50fffdf3":"#c8fffdf6"):(rhine.state.dark?"#30fffdf3":"#8cfffdf6");border.width:.8*page.unit;border.color:rhine.state.dark?"#70fffdf3":"#e6fffdf3"
                RhineIcon {anchors.centerIn:parent;width:14*page.unit;height:width;name:button.symbol;color:page.ink;visible:!!button.symbol&&!button.artwork}
                Image {anchors.centerIn:parent;width:18*page.unit;height:width;source:button.artwork;visible:!!source;fillMode:Image.PreserveAspectFit;sourceSize:Qt.size(24,24)}
            }
            Column {id:actionText;x:36*page.unit;anchors.verticalCenter:parent.verticalCenter;spacing:2*page.unit;visible:!!button.text
                Label {text:button.text;font.pixelSize:12*page.unit;font.weight:Font.Medium}
                Label {text:button.subtitle;font.pixelSize:9*page.unit;color:page.muted;visible:!!text}
            }
        }
        width:button.text?36*page.unit+actionText.implicitWidth+8*page.unit:implicitWidth
        background:Item {}
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
        onDraggingChanged:if(dragging){page.following=false;page.lyricFollowAnimation.stop();}
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
                Label {width:parent.width;text:line.modelData.text||"";wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:22*page.unit;font.weight:line.current?Font.DemiBold:Font.Medium;maximumLineCount:2;color:line.current||hit.containsMouse?page.ink:(rhine.state.dark?Qt.lighter(page.muted,1.12):Qt.darker(page.muted,1.18));opacity:line.current||hit.containsMouse?1:.92}
                Label {width:parent.width;text:line.modelData.translation||"";visible:!!text;wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:12.5*page.unit;color:page.ink;opacity:.64;maximumLineCount:2}
            }
            MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;cursorShape:page.playback.timed&&page.playback.seekable?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:{page.controller.seekLine(line.index,page.info.session);page.following=true;}}
        }
        Label {anchors.centerIn:parent;visible:lyrics.count===0;text:page.playback.lyricStatus==="loading"?"正在读取歌词…":(page.playback.lyricStatus==="error"?"歌词暂不可用":"暂无歌词");color:page.muted}
    }
    Label {objectName:"nowLyricsFollow";x:26*unit;y:421*unit;text:"回到当前歌词";font.pixelSize:10*unit;color:page.muted;visible:!page.following&&lyrics.count>0;MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{page.following=true;page.follow();}}}
    Row {x:26*unit;y:331*unit;spacing:14*unit;height:36*unit
        Action {objectName:"nowLike";enabled:info.canLike&&info.likeKnown&&!info.likeBusy;text:info.likeKnown?(info.liked?"已喜欢":"喜欢"):"读取中";subtitle:info.liked?"留在喜欢里":"收藏这首歌";artwork:page.info.likeKnown?(page.info.liked?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png"):"";Accessible.name:info.liked?"取消喜欢":"喜欢";onClicked:controller.operate("like")}
        Action {objectName:"nowComments";symbol:"comment";text:"评论";subtitle:rhine.state.socialSongID===page.info.id&&rhine.state.socialCommentCount>=0?String(rhine.state.socialCommentCount)+" 条评论":"查看评论";onClicked:controller.operate("comments")}
        Action {objectName:"nowShare";symbol:"share";text:"分享";subtitle:"分享这首歌";Accessible.name:"分享";onClicked:controller.operate("share")}
        Controls.Button {objectName:"nowMore";width:36*page.unit;height:36*page.unit;padding:0;focusPolicy:Qt.NoFocus;hoverEnabled:true;Accessible.name:"更多操作"
            contentItem:Item {Row {anchors.centerIn:parent;spacing:3.5*page.unit;Repeater {model:3;Rectangle {width:2.6*page.unit;height:width;radius:width/2;color:page.ink}}}}
            background:Item {Rectangle {objectName:"nowMoreSurface";anchors.centerIn:parent;width:28*page.unit;height:width;radius:width/2;color:parent.parent.hovered?(rhine.state.dark?"#50fffdf3":"#c8fffdf6"):(rhine.state.dark?"#30fffdf3":"#8cfffdf6");border.width:.8*page.unit;border.color:rhine.state.dark?"#70fffdf3":"#e6fffdf3"}}
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
    component RecordVisual: Item {
        required property var visualInfo
        property string nameSuffix:""
        property string fallbackCover:""
        property real transitionY:0
        property real visualOpacity:1
        property real phase:page.platterPhase
        readonly property string visualSession:(visualInfo&&visualInfo.session)||""
        readonly property bool artworkReady:!(visualInfo&&visualInfo.coverLoading)&&(!(visualInfo&&visualInfo.coverPixels)||printArt.status===Image.Ready||printArt.status===Image.Error)
        width:page.discSize;height:width
        x:parent.width-width+38*page.unit
        y:(parent.height-height)/2-6*page.unit+transitionY
        opacity:visualOpacity
        Item {id:plane;objectName:"nowRecordBase"+nameSuffix;anchors.fill:parent;anchors.margins:-page.vinylInset
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
            layer.effect:ShaderEffect {property variant artwork;property real phase:0;property real shadowOnly:5;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            transform:[Rotation {objectName:"nowRecordTilt"+nameSuffix;origin.x:plane.width/2;origin.y:plane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:38},Rotation {origin.x:plane.width/2;origin.y:plane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
            ShaderEffect {objectName:"nowRecordShadow"+nameSuffix;opacity:.40;x:-parent.width*.32-12*page.unit;y:-parent.height*.32+20*page.unit;width:parent.width*1.64;height:width
                property variant artwork:shadowArt;property real phase:0;property real shadowOnly:1;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                Image {id:shadowArt;visible:false;source:visualInfo.coverPixels||fallbackCover||"";sourceSize:Qt.size(64,64);asynchronous:true;cache:true}
            }
            ShaderEffect {objectName:"nowRecordContactEdge"+nameSuffix;x:-2*page.unit;y:6*page.unit;width:parent.width;height:parent.height
                property variant artwork:printArt;property real phase:0;property real shadowOnly:10;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            ShaderEffect {objectName:"nowRecordPlatter"+nameSuffix;anchors.fill:parent
                property variant artwork:printArt;property real phase:recordPrint.width/(plane.width*2);property real shadowOnly:9;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            Item {id:recordPrint;objectName:"nowRecordPrint"+nameSuffix;anchors.fill:parent;anchors.margins:page.vinylInset+4*page.unit;transformOrigin:Item.Center
                opacity:rhine.state.dark?.82:.90;property real spinAngle:page.spinPhase*360
                Image {id:printArt;objectName:"nowRecordArtwork"+nameSuffix;anchors.fill:parent;source:visualInfo.coverPixels||fallbackCover||"";fillMode:Image.PreserveAspectFit;asynchronous:true;cache:true;retainWhileLoading:true
                    visible:GraphicsInfo.api===GraphicsInfo.Software;rotation:visible?recordPrint.spinAngle:0}
                ShaderEffect {anchors.fill:parent;visible:GraphicsInfo.api!==GraphicsInfo.Software
                    property variant artwork:printArt;property real phase:recordPrint.spinAngle/360;property real shadowOnly:2;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            }
            Item {id:etch;objectName:"nowRecordEtch"+nameSuffix;anchors.centerIn:parent;width:recordPrint.width+plane.width*.10;height:width;rotation:recordPrint.spinAngle
                readonly property real radius:recordPrint.width/2+plane.width*.022;layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true
                Repeater {model:page.etchGlyphs((visualInfo.title||"")+"  \u8def  "+(visualInfo.artist||"")+"  \u8def  SIDE A  \u8def  33 1/3  \u8def  RHINE MUSIC DATABASE  \u8def  ",etch.radius,11*page.unit)
                    Text {required property var modelData;text:modelData.c;textFormat:Text.PlainText;font.family:rhineFontFamily;font.pixelSize:11*page.unit;font.weight:Font.DemiBold;font.letterSpacing:0;color:rhine.state.dark?"#e6e8de":"#4a4034";opacity:.90
                        x:etch.width/2+Math.cos(modelData.a)*etch.radius-width/2;y:etch.height/2+Math.sin(modelData.a)*etch.radius-height/2;rotation:modelData.a*180/Math.PI+90}
                }
            }
            ShaderEffect {objectName:"nowRecordGloss"+nameSuffix;anchors.fill:parent
                property variant artwork:printArt;property real phase:recordPrint.width/(plane.width*2);property real shadowOnly:4;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
        }
    }
    Item {id:discField;objectName:"nowDiscField";anchors.fill:parent;clip:true;z:-1
        // One composite owns both temporary decks, all reflections and bounce.
        // It alone applies screen-space focal fade and the exact glass boundary.
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
        layer.effect:ShaderEffect {objectName:"nowRecordComposite";property variant artwork;property real phase:discField.width/Math.max(1,discField.height);property real shadowOnly:7;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
        Item {objectName:"nowRecordRings";anchors.fill:parent;opacity:page.motion?1:0;Behavior on opacity {NumberAnimation {duration:240}}
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
            layer.effect:ShaderEffect {property variant artwork;property real phase:0;property real shadowOnly:3;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            Item {id:haloPlane;x:record.x;y:record.y;width:record.width;height:record.height
                transform:[Rotation {origin.x:haloPlane.width/2;origin.y:haloPlane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:38},Rotation {origin.x:haloPlane.width/2;origin.y:haloPlane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
                ShaderEffect {objectName:"nowRippleShader";x:-parent.width*.45;y:x;width:parent.width*1.90;height:width;property variant artwork:armShadowArt;property real phase:record.phase;property real shadowOnly:0;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            }
        }
        RecordVisual {id:incomingRecord;objectName:"nowRecordIncoming";nameSuffix:"Incoming";visualInfo:transitionInfo||displayedInfo;fallbackCover:displayedFallbackCover;visible:false;visualOpacity:0;transitionY:16*page.unit;z:1;onArtworkReadyChanged:if(artworkReady){page.recordCoverReady=true;page.startRecordVisualTransition()}}
        RecordVisual {id:record;objectName:"nowRecord";nameSuffix:"";visualInfo:displayedInfo;fallbackCover:displayedFallbackCover;z:2}
        Image {id:armShadowArt;visible:false;source:displayedInfo.coverPixels||displayedFallbackCover;sourceSize:Qt.size(64,64);asynchronous:true;cache:true}
        // Tonearm in the same inclined plane as the platter. Everything outside
        // the glass is clipped by discField and its composite, like the record.
        Item {id:armPlane;objectName:"nowTonearmPlane";x:record.x;y:(parent.height-record.height)/2-6*page.unit;width:record.width;height:record.height;z:3
            visible:true
            transform:[Rotation {origin.x:armPlane.width/2;origin.y:armPlane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:38},Rotation {origin.x:armPlane.width/2;origin.y:armPlane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
            readonly property real armLength:width*.46
            // Keep the bearing outside the record while leaving a readable
            // section of shaft and headshell over the white outer groove.
            readonly property real pivotX:width*.98
            readonly property real pivotY:height*.72
            readonly property real normalPose:page.playback.playing?0:1
            // 0 = stylus in the lead-out ring, 1 = lifted and swung clear of the record.
            property real pose:normalPose
            readonly property real lift:Math.min(1,pose*2.4)
            readonly property real swing:-116+8*pose
            Item {objectName:"nowTonearmShadow";x:-.642*(5+8*armPlane.lift)*page.unit;y:1.6*(5+8*armPlane.lift)*page.unit;width:parent.width;height:parent.height
                ShaderEffect {
                    x:armPlane.pivotX-.26*armPlane.armLength;y:armPlane.pivotY-.14*armPlane.armLength;width:1.34*armPlane.armLength;height:.28*armPlane.armLength
                    transform:Rotation {origin.x:.26*armPlane.armLength;origin.y:.14*armPlane.armLength;angle:armPlane.swing}
                    property variant artwork:armShadowArt
                    property real phase:armPlane.lift
                    property real shadowOnly:11
                    property real darkMode:rhine.state.dark?1:0
                    fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                }
            }
            ShaderEffect {objectName:"nowTonearm"
                x:armPlane.pivotX-.26*armPlane.armLength;y:armPlane.pivotY-.14*armPlane.armLength;width:1.34*armPlane.armLength;height:.28*armPlane.armLength
                transform:Rotation {origin.x:.26*armPlane.armLength;origin.y:.14*armPlane.armLength;angle:armPlane.swing}
                property variant artwork:armShadowArt
                property real phase:armPlane.lift
                property real shadowOnly:12
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
            }
            RecordTonearm {objectName:"nowTonearmSoftwareFallback";anchors.fill:parent;visible:GraphicsInfo.api===GraphicsInfo.Software;playing:armPlane.pose<.5;reduced:rhine.state.reduced;dark:rhine.state.dark}
        }
    }
    Timer {id:recordCoverWait;interval:700;repeat:false;onTriggered:{if(!page.recordTransitioning)return;if(incomingRecord.artworkReady){page.recordCoverReady=true;page.startRecordVisualTransition();}else page.recordCoverWait.restart()}}
    NumberAnimation {id:armMotionAnimation;target:armPlane;property:"pose";to:armPlane.normalPose;easing.type:Easing.InOutCubic
        onFinished:page.handleArmMotionFinished()
    }
    SequentialAnimation {id:recordChangeAnimation
        ParallelAnimation {
            PropertyAnimation {target:record;property:"transitionY";to:-12*page.unit;duration:rhine.state.reduced?0:600;easing.type:Easing.InOutCubic}
            PropertyAnimation {target:record;property:"visualOpacity";to:0;duration:rhine.state.reduced?0:570;easing.type:Easing.InOutCubic}
            PropertyAnimation {target:incomingRecord;property:"transitionY";to:0;duration:rhine.state.reduced?0:600;easing.type:Easing.InOutCubic}
            PropertyAnimation {target:incomingRecord;property:"visualOpacity";to:1;duration:rhine.state.reduced?0:570;easing.type:Easing.InOutCubic}
        }
        PauseAnimation {duration:rhine.state.reduced?0:60}
        ScriptAction {script:page.finishRecordChange()}
    }
    NumberAnimation {id:lyricFollowAnimation;target:lyrics;property:"contentY";duration:280;easing.type:Easing.OutCubic}
    Controls.Menu {id:more;parent:page;font.family:rhineFontFamily;palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.text:page.ink
        Controls.MenuItem {objectName:"nowCollect";text:"添加到歌单";onTriggered:controller.operate("collect")}
        Controls.MenuItem {text:"查看歌曲详情";onTriggered:controller.operate("details")}
        Controls.MenuItem {text:"重新读取歌词";onTriggered:controller.operate("retry-lyrics")}
        Controls.MenuItem {text:"在官方客户端打开";onTriggered:controller.operate("official")}
        Controls.MenuItem {text:"返回浏览信息";onTriggered:controller.operate("browse")}
    }
}

