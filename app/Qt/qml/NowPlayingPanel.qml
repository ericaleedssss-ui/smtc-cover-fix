import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

Item {
    id:page
    objectName:"nowPlayingPanel"
    required property var controller
    property Item background:null
    property point backgroundOrigin:Qt.point(0,0)
    property int lyricGlassUsers:0
    property int hoveredLyric:-1
    property int focusedLyric:-1
    readonly property int previewLyric:hoveredLyric>=0?hoveredLyric:focusedLyric
    readonly property var previewLine:previewLyric>=0&&previewLyric<controller.lines.length?controller.lines[previewLyric]:null
    readonly property Item previewLyricItem:previewLyric>=0?lyrics.itemAtIndex(previewLyric):null
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
    function syncMotion(){
        for(var animation of [recordSpin,platterPulse]){
            if(!animation)continue;
            if(motion){if(animation.paused)animation.resume();else if(!animation.running)animation.start();}
            else if(animation.running&&!animation.paused)animation.pause();
        }
    }
    onMotionChanged:syncMotion()
    Component.onCompleted:{
        frontDeck.visualInfo=mergeInfo({},info);
        visualInitialized=true;
        acceptInfo(info);
        updatePlayback();
        syncMotion();
        controller.loadHotComment();
    }
    NumberAnimation on spinPhase {id:recordSpin;from:0;to:1;duration:40000;loops:Animation.Infinite;running:false}
    NumberAnimation on platterPhase {id:platterPulse;from:0;to:1;duration:6500;loops:Animation.Infinite;running:false}
    property bool following:true
    // Two persistent decks exchange roles instead of copying artwork at handoff.
    // One preparation/swap flow owns the arm; metadata never restarts motion.
    property bool primaryIsFront:true
    readonly property var frontDeck:primaryIsFront?record:incomingRecord
    readonly property var backDeck:primaryIsFront?incomingRecord:record
    property string swapStage:"idle"
    property real swapProgress:0
    property var pendingInfo: null
    property bool prepareTimedOut:false
    property bool preparingDeck:false
    property int preparedFrames:0
    property bool lastStablePlaying:false
    property string lastStableSession:""
    readonly property bool armResting:recordTransitioning||!(playback.loading?(lastStablePlaying&&lastStableSession===session):playback.playing)
    property bool lyricFollowPending:false
    property int followAttempts:0
    property bool visualInitialized:false
    readonly property bool recordTransitioning:swapStage!=="idle"
    // Title etched in the clear seat ring. Rebuilt only when the song changes.
    readonly property string etchText:(info.title||"")+"  ·  "+(info.artist||"")+"  ·  SIDE A  ·  33⅓  ·  RHINE MUSIC DATABASE  ·  "
    function etchGlyphs(text,radius,px){
        var out=[],a=-Math.PI*.5,r=Math.max(1,radius);
        for(var i=0;i<text.length&&a<Math.PI*1.45;++i){var ch=text[i];var w=(ch.charCodeAt(0)>0x2e80?1.0:.6)*px;a+=w/2/r;out.push({c:ch,a:a});a+=w/2/r+.7/r;}
        return out;
    }
    function dismissTopOverlay(){if(more.visible){more.close();return true;}return false;}
    function resumeFollowing(){
        following=true;lyricFollowPending=true;followAttempts=0;
        lyrics.cancelFlick();lyricFollowAnimation.stop();Qt.callLater(page.follow);
    }
    function follow(){
        if(!visible||!following||playback.index<0||playback.index>=lyrics.count||lyrics.height<=0)return;
        var item=lyrics.itemAtIndex(playback.index);
        if(!item){
            // A distant seek may target a delegate outside ListView's cache.
            lyricFollowAnimation.stop();lyrics.positionViewAtIndex(playback.index,ListView.Center);
            if(followAttempts++<3)Qt.callLater(page.follow);
            return;
        }
        followAttempts=0;lyricFollowPending=false;
        var previous=lyrics.itemAtIndex(Math.max(0,playback.index-1));
        var next=lyrics.itemAtIndex(Math.min(lyrics.count-1,playback.index+1));
        var start=previous?previous.y:item.y;
        var end=next?next.y+next.height:item.y+item.height;
        // Fit three complete entries when possible. For long bilingual lines,
        // show current + next intact instead of two clipped half-entries.
        var desired=end-start<=lyrics.height?start-(lyrics.height-(end-start))/2:item.y-6*unit;
        var target=Math.max(lyrics.originY,Math.min(lyrics.originY+Math.max(0,lyrics.contentHeight-lyrics.height),desired));
        if((lyricFollowAnimation.running&&Math.abs(lyricFollowAnimation.to-target)<.5)||Math.abs(lyrics.contentY-target)<.5)return;
        lyricFollowAnimation.stop();lyricFollowAnimation.to=target;lyricFollowAnimation.duration=RhineTheme.noMotion?0:280;lyricFollowAnimation.start();
        lyricFollowPending=false;
    }
    function stamp(ms){var s=Math.max(0,Math.floor(ms/1000));return String(Math.floor(s/60)).padStart(2,"0")+":"+String(s%60).padStart(2,"0");}
    function clearLyricPreview(){hoveredLyric=-1;focusedLyric=-1;}
    onVisibleChanged:if(!visible)clearLyricPreview()
    function mergeInfo(base,next){
        var merged=Object.assign({},base||{});if(next)for(var key in next)merged[key]=next[key];return merged;
    }
    function beginRecordChange(next){
        if(!next||!next.session)return;
        preparingDeck=true;
        swapStage="preparing";prepareTimedOut=false;pendingInfo=null;preparedFrames=0;
        artworkDeadline.restart();
        backDeck.visualInfo=mergeInfo({},next);
        preparingDeck=false;
        maybeStartSwap();
    }
    function maybeStartSwap(){
        if(!visualInitialized||preparingDeck||swapStage!=="preparing"||!armPlane||armPlane.pose<.995)return;
        if(!backDeck.artworkReady&&!prepareTimedOut)return;
        if(!rhine.state.reduced&&preparedFrames<2)return;
        artworkDeadline.stop();
        swapStage="swapping";
        recordChangeAnimation.start();
    }
    function finishRecordChange(){
        if(swapStage!=="swapping")return;
        primaryIsFront=!primaryIsFront;
        swapProgress=0;
        var queued=pendingInfo;pendingInfo=null;
        if(queued&&queued.session!==frontDeck.visualSession){beginRecordChange(queued);return;}
        if(queued)frontDeck.visualInfo=mergeInfo(frontDeck.visualInfo,queued);
        swapStage="idle";
    }
    function acceptInfo(next){
        if(!visualInitialized)return;
        next=next||({});
        if(!next.session){
            artworkDeadline.stop();recordChangeAnimation.stop();swapStage="idle";swapProgress=0;pendingInfo=null;
            frontDeck.visualInfo=({});backDeck.visualInfo=({});
        }else if(swapStage==="swapping"){
            // Freeze both painted identities until this movement finishes.
            pendingInfo=mergeInfo({},next);
        }else if(swapStage==="preparing"){
            if(next.session===frontDeck.visualSession){
                artworkDeadline.stop();frontDeck.visualInfo=mergeInfo(frontDeck.visualInfo,next);swapStage="idle";
            }else if(next.session!==backDeck.visualSession){beginRecordChange(next);}
            else {backDeck.visualInfo=mergeInfo(backDeck.visualInfo,next);maybeStartSwap();}
        }else if(next.session!==frontDeck.visualSession){
            beginRecordChange(next);
        }else{
            frontDeck.visualInfo=mergeInfo(frontDeck.visualInfo,next);
        }
        if(next.session!==session){clearLyricPreview();session=next.session||"";following=true;lyricFollowPending=true;Qt.callLater(page.follow);}
    }
    onInfoChanged:{acceptInfo(info);controller.loadHotComment();}
    property string session:""
    function updatePlayback(){
        if(!playback.loading){lastStablePlaying=!!playback.playing;lastStableSession=info.session||"";}
        follow();
    }
    Connections {target:page.controller;function onPlaybackChanged(){page.updatePlayback();}
        function onFollowRequested(){page.resumeFollowing();}
        function onLinesChanged(){page.clearLyricPreview();page.lyricFollowPending=true;Qt.callLater(page.follow);}}
    Timer {id:artworkDeadline;interval:1800;onTriggered:{page.prepareTimedOut=true;page.maybeStartSwap();}}
    FrameAnimation {running:page.visible&&page.swapStage==="preparing"&&(page.backDeck.artworkReady||page.prepareTimedOut);onTriggered:{page.preparedFrames++;page.maybeStartSwap();}}
    component Label:Text {textFormat:Text.PlainText;font.family:rhineFontFamily;font.variableAxes:({"wght":400});color:page.ink;font.pixelSize:13*page.unit;elide:Text.ElideRight}
    component Action:Controls.Button {
        id:button
        property string symbol
        property string artwork:""
        property string subtitle:""
        focusPolicy:Qt.NoFocus;hoverEnabled:true
        implicitWidth:88*page.unit;implicitHeight:36*page.unit
        leftPadding:4*page.unit;rightPadding:4*page.unit;topPadding:4*page.unit;bottomPadding:4*page.unit
        HoverHandler {cursorShape:Qt.PointingHandCursor;enabled:button.enabled}
        contentItem:Item {
            Rectangle {objectName:"nowActionIcon";x:0;anchors.verticalCenter:parent.verticalCenter;width:28*page.unit;height:width;radius:width/2;color:button.hovered?(rhine.state.dark?"#50fffdf3":"#c8fffdf6"):(rhine.state.dark?"#30fffdf3":"#8cfffdf6");border.width:.8*page.unit;border.color:rhine.state.dark?"#70fffdf3":"#e6fffdf3"
                RhineIcon {anchors.centerIn:parent;width:14*page.unit;height:width;name:button.symbol;color:page.ink;visible:!!button.symbol&&!button.artwork}
                Image {anchors.centerIn:parent;width:18*page.unit;height:width;source:button.artwork;visible:!!source;fillMode:Image.PreserveAspectFit;sourceSize:Qt.size(24,24)}
            }
            Column {id:actionText;x:36*page.unit;anchors.verticalCenter:parent.verticalCenter;spacing:2*page.unit;visible:!!button.text
                Label {text:button.text;font.pixelSize:12*page.unit;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium})}
                Label {text:button.subtitle;font.pixelSize:9*page.unit;color:page.muted;visible:!!text}
            }
        }
        width:button.text?36*page.unit+actionText.implicitWidth+8*page.unit:implicitWidth
        background:Item {}
        opacity:enabled?1:.45
    }
    MouseArea {anchors.fill:parent;onClicked:{} onWheel:e=>{var p=mapToItem(null,e.x,e.y);rhine.wheelInput(p.x/page.unit,p.y/page.unit,e.pixelDelta.y,e.angleDelta.y);e.accepted=true;}}
    Label {x:26*unit;y:25*unit;width:page.textWidth;text:"NOW PLAYING / 正在播放";font.pixelSize:11*unit;color:page.muted}
    Label {id:songTitle;objectName:"nowPlayingTitle";x:26*unit;y:55*unit;width:page.textWidth;height:implicitHeight;text:info.title||"正在播放";font.pixelSize:27*unit;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});wrapMode:Text.Wrap;maximumLineCount:2
        color:titleHit.containsMouse?page.muted:page.ink
        MouseArea {id:titleHit;objectName:"nowPlayingTitleHit";anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:page.controller.operate("details")}
    }
    Label {objectName:"nowAlbum";x:26*unit;y:songTitle.y+songTitle.height+7*unit;width:page.textWidth;text:info.album||"";font.pixelSize:12*unit;color:albumHit.containsMouse?page.ink:page.muted
        MouseArea {id:albumHit;objectName:"nowAlbumHit";anchors.fill:parent;enabled:!!page.info.albumID&&String(page.info.albumID)!=="0";hoverEnabled:true;cursorShape:enabled?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:page.controller.operate("album")}
    }
    // The row's time pill stays reachable when the pointer leaves its text.
    // Observe the parent so foreground lyric controls cannot mask hover exit.
    HoverHandler {
        onHoveredChanged:if(!hovered)page.hoveredLyric=-1
        onPointChanged:{
            var p=point.position;
            if(p.x<lyrics.x||p.x>lyrics.x+lyrics.width||p.y<lyrics.y||p.y>lyrics.y+lyrics.height)page.hoveredLyric=-1;
        }
    }
    ListView {
        id:lyrics;objectName:"nowPlayingLyrics";x:24*unit;y:146*unit;width:page.textWidth+4*unit;height:Math.max(0,Math.min(161*unit,actions.y-y-14*unit))
        model:page.controller.lines;clip:true;boundsBehavior:Flickable.StopAtBounds;spacing:8*unit;cacheBuffer:height
        onWidthChanged:Qt.callLater(page.follow)
        onHeightChanged:Qt.callLater(page.follow)
        onContentHeightChanged:Qt.callLater(page.follow)
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
        layer.effect:ShaderEffect {property variant source;property size panelSize:Qt.size(lyrics.width,lyrics.height);property real topInset:0;property real fadePx:10*page.unit;property real fadeTop:1;property real bottomFadePx:10*page.unit;fragmentShader:"qrc:/shaders/magazineEdgeFade.frag.qsb"}
        WheelHandler {target:null;onWheel:e=>{page.following=false;lyricFollowAnimation.stop();var dy=e.pixelDelta.y||e.angleDelta.y/120*55*page.unit;lyrics.contentY=Math.max(lyrics.originY,Math.min(lyrics.originY+Math.max(0,lyrics.contentHeight-lyrics.height),lyrics.contentY-dy));e.accepted=true;}}
        onDraggingChanged:if(dragging){page.following=false;lyricFollowAnimation.stop();}
        delegate:Item {
            id:line
            required property var modelData
            required property int index
            objectName:"nowLyric_"+index
            property bool current:index===page.playback.index
            readonly property bool previewHovered:hit.containsMouse||(lyricTime.hovered&&page.hoveredLyric===index)
            activeFocusOnTab:true
            onActiveFocusChanged:{
                if(activeFocus){page.focusedLyric=index;page.following=false;lyricFollowAnimation.stop();lyrics.positionViewAtIndex(index,ListView.Contain);}
                else if(page.focusedLyric===index)page.focusedLyric=-1;
            }
            width:lyrics.width;height:Math.max(38*page.unit,words.implicitHeight+8*page.unit)
            // At rest, never leave a half sentence at either edge. Manual
            // scrolling still exposes the complete lyric history naturally.
            opacity:page.following&&(y-lyrics.contentY<-.5||y-lyrics.contentY+height>lyrics.height+.5)?0:1
            Loader {
                objectName:"nowLyricGlass_"+line.index;anchors.fill:parent
                active:page.visible&&!!page.background&&(line.previewHovered||line.activeFocus)
                sourceComponent:PlaylistHoverGlass {
                    background:lyricBackdrop;unit:page.unit;dark:rhine.state.dark
                    sampleOrigin:{lyrics.contentY;line.y;return line.mapToItem(lyricBackdrop,0,0)}
                    refractive:rhineRefractiveGlass;engaged:true;reduced:rhine.state.reduced
                    Component.onCompleted:page.lyricGlassUsers++
                    Component.onDestruction:if(page)page.lyricGlassUsers--
                }
            }
            Column {id:words;x:2*page.unit;y:4*page.unit;width:parent.width-x-(page.playback.timed?84:6)*page.unit;spacing:4*page.unit
                Label {width:parent.width;text:line.modelData.text||"";wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:20*page.unit;font.weight:Font.Medium;font.variableAxes:({"wght":Font.Medium});lineHeight:1.12;color:line.current||line.previewHovered?page.ink:(rhine.state.dark?Qt.lighter(page.muted,1.12):Qt.darker(page.muted,1.18));opacity:line.current||line.previewHovered?1:.88}
                Label {width:parent.width;text:line.modelData.translation||"";visible:!!text;wrapMode:Text.Wrap;elide:Text.ElideNone;font.pixelSize:11.5*page.unit;lineHeight:1.12;color:page.ink;opacity:line.current?.78:.66}
            }
            Keys.onReturnPressed:page.controller.seekLine(line.index,page.info.session)
            Keys.onSpacePressed:page.controller.seekLine(line.index,page.info.session)
            Accessible.role:Accessible.Button;Accessible.name:line.modelData.text||"";Accessible.onPressAction:page.controller.seekLine(line.index,page.info.session)
            MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;cursorShape:page.playback.timed&&page.playback.seekable?Qt.PointingHandCursor:Qt.ArrowCursor;onEntered:page.hoveredLyric=line.index;onClicked:page.controller.seekLine(line.index,page.info.session)}
        }
        Label {anchors.centerIn:parent;visible:lyrics.count===0;text:page.playback.lyricStatus==="loading"?"正在读取歌词…":(page.playback.lyricStatus==="error"?"歌词暂不可用":"暂无歌词");color:page.muted}
    }
    Controls.Button {
        id:lyricTime;objectName:"nowLyricTime";x:lyrics.x+lyrics.width-width-6*unit
        y:lyrics.y+(page.previewLyricItem?page.previewLyricItem.y-lyrics.contentY:0)+4*unit
        width:72*unit;height:24*unit;padding:0;focusPolicy:Qt.NoFocus;hoverEnabled:true
        visible:page.visible&&page.playback.timed&&!!page.previewLine&&!!page.previewLyricItem&&page.previewLyricItem.opacity>0&&y>=lyrics.y&&y+height<=lyrics.y+lyrics.height
        enabled:page.playback.seekable
        Accessible.name:"跳转到 "+page.stamp(page.previewLine?page.previewLine.startMs:0)
        onClicked:if(page.previewLine)page.controller.seekLine(page.previewLyric,page.info.session)
        contentItem:Item {
            Row {anchors.centerIn:parent;spacing:3*page.unit
                RhineIcon {objectName:"nowLyricTimeIcon";anchors.verticalCenter:parent.verticalCenter;width:10*page.unit;height:width;name:"play";color:rhine.state.dark?"#d8e7bb":"#405a35"}
                Label {objectName:"nowLyricTimeText";text:page.stamp(page.previewLine?page.previewLine.startMs:0);font.pixelSize:12*page.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:rhine.state.dark?"#d8e7bb":"#405a35"}
            }
        }
        // Match the top toolbar's expanded pill, without a glass capture/shadow.
        background:Rectangle {radius:height/2;color:rhine.state.dark?"#d02b3327":"#60ffffff";border.width:page.unit*.7;border.color:rhine.state.dark?"#50ffffff":"#bbffffff"}
        HoverHandler {cursorShape:parent.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
    }
    Controls.Button {
        id:returnToLyric;objectName:"nowLyricsFollow";x:lyrics.x+lyrics.width-width;y:lyrics.y-33*unit
        width:28*unit;height:width;padding:6*unit;visible:!page.following&&lyrics.count>0
        Accessible.name:"回到当前歌词";onClicked:page.resumeFollowing()
        contentItem:RhineIcon{name:"locate";color:page.ink}
        background:Rectangle{radius:width/2;color:rhine.state.dark?"#405c6853":"#a8fffdf6";border.width:.7*page.unit;border.color:rhine.state.dark?"#60929b86":"#c0ffffff"}
        HoverHandler{cursorShape:Qt.PointingHandCursor}
        RhineToolTip {visible:parent.hovered;text:"回到当前歌词";delay:500}
    }
    Controls.Button {
        id:hotComment;objectName:"nowHotComment";x:26*unit;y:page.height-height-10*unit;width:page.textWidth;height:26*unit;padding:0
        visible:!!page.controller.hotComment;Accessible.name:"查看歌曲评论"
        onClicked:page.controller.operate("comments")
        contentItem:Item{
            TextMetrics {id:openingInk;font:openingQuote.font;text:openingQuote.text}
            TextMetrics {id:closingInk;font:closingQuote.font;text:closingQuote.text}
            Label {id:openingQuote;objectName:"nowHotCommentOpen";x:quoteText.x-2*page.unit-openingInk.tightBoundingRect.x-openingInk.tightBoundingRect.width;width:20*page.unit;height:parent.height;text:"“";font.pixelSize:20*page.unit;color:page.muted}
            Label {id:quoteText;objectName:"nowHotCommentText";x:14*page.unit;width:Math.min(implicitWidth,Math.max(0,parent.width-28*page.unit));height:parent.height;verticalAlignment:Text.AlignVCenter;text:page.controller.hotComment;font.pixelSize:11*page.unit;color:parent.parent.hovered?page.ink:page.muted;maximumLineCount:1;wrapMode:Text.NoWrap;elide:Text.ElideRight}
            Label {id:closingQuote;objectName:"nowHotCommentClose";x:quoteText.x+quoteText.width+2*page.unit-closingInk.tightBoundingRect.x;width:20*page.unit;height:parent.height;text:"”";font.pixelSize:20*page.unit;color:page.muted}
        }
        background:Item{}
        HoverHandler{cursorShape:Qt.PointingHandCursor}
    }
    Row {id:actions;x:26*unit;y:Math.min(331*unit,metadata.y-height-(controller.status?20:8)*unit);spacing:14*unit;height:36*unit
        Action {objectName:"nowLike";enabled:info.canLike&&info.likeKnown&&!info.likeBusy;text:info.likeKnown?(info.liked?"已喜欢":"喜欢"):"读取中";subtitle:info.liked?"留在喜欢里":"收藏这首歌";artwork:page.info.likeKnown?(page.info.liked?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png"):"";Accessible.name:info.liked?"取消喜欢":"喜欢";onClicked:controller.operate("like")}
        Action {objectName:"nowComments";symbol:"comment";text:"评论";subtitle:rhine.state.socialSongID===page.info.id&&rhine.state.socialCommentCount>=0?String(rhine.state.socialCommentCount)+" 条评论":"查看评论";onClicked:controller.operate("comments")}
        Action {objectName:"nowShare";symbol:"share";text:"分享";subtitle:"分享这首歌";Accessible.name:"分享";onClicked:controller.operate("share")}
        Controls.Button {objectName:"nowMore";width:36*page.unit;height:36*page.unit;padding:0;leftPadding:0;rightPadding:0;topPadding:0;bottomPadding:0;focusPolicy:Qt.NoFocus;hoverEnabled:true;Accessible.name:"更多操作"
            contentItem:Item {Row {anchors.centerIn:parent;spacing:3.5*page.unit;Repeater {model:3;Rectangle {width:2.6*page.unit;height:width;radius:width/2;color:page.ink}}}}
            background:Item {Rectangle {objectName:"nowMoreSurface";anchors.centerIn:parent;width:28*page.unit;height:width;radius:width/2;color:parent.parent.hovered?(rhine.state.dark?"#50fffdf3":"#c8fffdf6"):(rhine.state.dark?"#30fffdf3":"#8cfffdf6");border.width:.8*page.unit;border.color:rhine.state.dark?"#70fffdf3":"#e6fffdf3"}}
            HoverHandler {cursorShape:Qt.PointingHandCursor}
            RhineToolTip {visible:parent.hovered;text:"更多操作";delay:500}
            onClicked:{var p=mapToItem(page,0,height);more.x=Math.max(0,Math.min(page.width-more.implicitWidth,p.x));more.y=Math.min(page.height-more.implicitHeight,Math.max(0,p.y+6*page.unit));more.open();}
        }
    }
    Label {x:26*unit;y:metadata.y-16*unit;width:page.textWidth;text:controller.status||"";font.pixelSize:10*unit;color:page.muted}
    Row {id:metadata;x:26*unit;y:hotComment.y-height-6*unit;width:page.textWidth;spacing:8*unit;height:26*unit
        Rectangle {width:24*page.unit;height:width;radius:width/2;color:rhine.state.dark?"#59614f":"#cdd2c5"
            RhineIcon {anchors.centerIn:parent;width:16*page.unit;height:width;name:"user";color:page.muted}
            Image {anchors.fill:parent;source:page.info.artistAvatar||"";fillMode:Image.PreserveAspectFit}
        }
        ArtistMarquee {people:page.info.artists||[];fallback:page.info.artist||"未知艺人";unit:page.unit;height:26*page.unit;width:Math.min(implicitWidth,Math.max(45*page.unit,metadata.width*.34));onPersonClicked:id=>page.controller.openArtist(id)}
        Label {height:26*page.unit;verticalAlignment:Text.AlignVCenter;text:"│";color:page.muted}
        Label {id:date;objectName:"nowReleaseDate";height:26*page.unit;verticalAlignment:Text.AlignVCenter;text:info.date||"发行日期暂无";font.pixelSize:12*page.unit;color:page.muted}
        Label {height:26*page.unit;verticalAlignment:Text.AlignVCenter;text:"│";color:page.muted}
        Label {objectName:"nowGenres";height:26*page.unit;verticalAlignment:Text.AlignVCenter;width:Math.max(28*page.unit,metadata.width-x);text:(page.info.tags||[]).length?page.info.tags.join(" / "):(page.info.tagsLoading?"曲风读取中…":page.info.tagsFailed?"曲风读取失败，点击重试":"曲风暂无");font.pixelSize:12*page.unit;color:page.muted
            MouseArea {anchors.fill:parent;enabled:!!page.info.tagsFailed;cursorShape:Qt.PointingHandCursor;onClicked:page.controller.operate("retry-tags")}
        }
    }
    component RecordVisual: Item {
        property var visualInfo:({})
        required property bool front
        readonly property string nameSuffix:front?"":"Incoming"
        readonly property real transitionY:front?-12*page.unit*page.swapProgress:16*page.unit*(1-page.swapProgress)
        readonly property real visualOpacity:front?1-page.swapProgress:page.swapStage==="preparing"?.001:page.swapProgress
        readonly property bool artworkReady:!!visualInfo.coverPixels&&printArt.status===Image.Ready&&printArt.source.toString()===visualInfo.coverPixels
        readonly property string etchLabel:(visualInfo.title||"")+"  ·  "+(visualInfo.artist||"")+"  ·  SIDE A  ·  33⅓  ·  RHINE MUSIC DATABASE  ·  "
        onArtworkReadyChanged:page.maybeStartSwap()
        property real phase:page.platterPhase
        readonly property string visualSession:(visualInfo&&visualInfo.session)||""
        objectName:front?"nowRecord":"nowRecordIncoming"
        visible:front||page.swapStage!=="idle"
        z:front?2:1
        width:page.discSize;height:width
        x:parent.width-width+38*page.unit
        y:(parent.height-height)/2-6*page.unit+transitionY
        opacity:visualOpacity
        Item {id:plane;objectName:"nowRecordBase"+nameSuffix;anchors.fill:parent;anchors.margins:-page.vinylInset
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
            layer.effect:ShaderEffect {property variant artwork;property real phase:0;property real shadowOnly:5;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            transform:[Rotation {objectName:"nowRecordTilt"+nameSuffix;origin.x:plane.width/2;origin.y:plane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:38},Rotation {origin.x:plane.width/2;origin.y:plane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
            ShaderEffect {objectName:"nowRecordShadow"+nameSuffix;opacity:.48;x:-parent.width*.32-12*page.unit;y:-parent.height*.32+20*page.unit;width:parent.width*1.64;height:width
                property variant artwork:shadowArt;property real phase:page.spinPhase;property real shadowOnly:1;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                Image {id:shadowArt;visible:false;source:visualInfo.coverPixels||"";sourceSize:Qt.size(64,64);asynchronous:true;cache:true}
            }
            ShaderEffect {objectName:"nowRecordContactEdge"+nameSuffix;x:-2*page.unit;y:6*page.unit;width:parent.width;height:parent.height
                property variant artwork:printArt;property real phase:0;property real shadowOnly:10;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            ShaderEffect {objectName:"nowRecordPlatter"+nameSuffix;anchors.fill:parent
                property variant artwork:printArt;property real phase:recordPrint.width/(plane.width*2);property real shadowOnly:9;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            Item {id:recordPrint;objectName:"nowRecordPrint"+nameSuffix;anchors.fill:parent;anchors.margins:page.vinylInset+4*page.unit;transformOrigin:Item.Center
                opacity:1;property real spinAngle:page.spinPhase*360
                property real coverReveal:printArt.status===Image.Ready?1:0
                Behavior on coverReveal {NumberAnimation {duration:RhineTheme.noMotion?0:180}}
                Image {id:printArt;objectName:"nowRecordArtwork"+nameSuffix;anchors.fill:parent;source:visualInfo.coverPixels||"";fillMode:Image.PreserveAspectFit;asynchronous:true;cache:true;retainWhileLoading:true
                    opacity:recordPrint.coverReveal;visible:GraphicsInfo.api===GraphicsInfo.Software;rotation:visible?recordPrint.spinAngle:0}
                ShaderEffect {anchors.fill:parent;visible:GraphicsInfo.api!==GraphicsInfo.Software;opacity:recordPrint.coverReveal
                    property variant artwork:printArt;property real phase:recordPrint.spinAngle/360;property real shadowOnly:2;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            }
            Item {id:etch;objectName:"nowRecordEtch"+nameSuffix;anchors.centerIn:parent;width:recordPrint.width+plane.width*.10;height:width;rotation:recordPrint.spinAngle
                readonly property real radius:recordPrint.width/2+plane.width*.022;layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true
                Repeater {model:page.etchGlyphs(etchLabel,etch.radius,11*page.unit)
                    Text {required property var modelData;text:modelData.c;textFormat:Text.PlainText;font.family:rhineFontFamily;font.pixelSize:11*page.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});font.letterSpacing:0;color:rhine.state.dark?"#e6e8de":"#4a4034";opacity:.90
                        x:etch.width/2+Math.cos(modelData.a)*etch.radius-width/2;y:etch.height/2+Math.sin(modelData.a)*etch.radius-height/2;rotation:modelData.a*180/Math.PI+90}
                }
            }
            ShaderEffect {objectName:"nowRecordGloss"+nameSuffix;anchors.fill:parent
                property variant artwork:printArt;property real phase:recordPrint.width/(plane.width*2);property real shadowOnly:4;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
        }
    }
    // Capture only the material and the record beneath the lyrics. Keeping
    // foreground text and hover surfaces outside this subtree avoids feedback.
    Item {id:lyricBackdrop;objectName:"nowLyricBackdrop";anchors.fill:parent;z:-1
        ShaderEffectSource {
            objectName:"nowLyricBaseCapture";anchors.fill:parent
            sourceItem:page.lyricGlassUsers>0?page.background:null
            sourceRect:Qt.rect(page.backgroundOrigin.x,page.backgroundOrigin.y,width,height)
            live:page.visible&&page.lyricGlassUsers>0;visible:page.lyricGlassUsers>0
            smooth:true;hideSource:false
        }
    }
    Item {id:discField;objectName:"nowDiscField";parent:lyricBackdrop;anchors.fill:parent;clip:true
        // One composite owns both temporary decks, all reflections and bounce.
        // It alone applies screen-space focal fade and the exact glass boundary.
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
        layer.effect:ShaderEffect {objectName:"nowRecordComposite";property variant artwork;property real phase:discField.width/Math.max(1,discField.height);property real shadowOnly:7;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
        Item {objectName:"nowRecordRings";anchors.fill:parent;opacity:page.motion?1:0;Behavior on opacity {NumberAnimation {duration:240}}
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software;layer.smooth:true;layer.samplerName:"artwork"
            layer.effect:ShaderEffect {property variant artwork;property real phase:0;property real shadowOnly:3;property real darkMode:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            Item {id:haloPlane;x:page.frontDeck.x;y:(parent.height-page.discSize)/2-6*page.unit;width:page.discSize;height:width
                transform:[Rotation {origin.x:haloPlane.width/2;origin.y:haloPlane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:38},Rotation {origin.x:haloPlane.width/2;origin.y:haloPlane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
                ShaderEffect {objectName:"nowRippleShader";x:-parent.width*.45;y:x;width:parent.width*1.90;height:width;property variant artwork:armShadowArt;property real phase:page.platterPhase;property real shadowOnly:0;property real darkMode:rhine.state.dark?1:0;fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"}
            }
        }
        RecordVisual {id:incomingRecord;front:!page.primaryIsFront}
        RecordVisual {id:record;front:page.primaryIsFront}
        Image {id:armShadowArt;visible:false;source:page.frontDeck.visualInfo.coverPixels||"";sourceSize:Qt.size(64,64);asynchronous:true;cache:true}
        // Tonearm in the same inclined plane as the platter. Everything outside
        // the glass is clipped by discField and its composite, like the record.
        Item {id:armPlane;objectName:"nowTonearmPlane";x:record.x-page.vinylInset;y:(parent.height-record.height)/2-6*page.unit-page.vinylInset;width:record.width+2*page.vinylInset;height:width;z:3
            visible:GraphicsInfo.api!==GraphicsInfo.Software
            transform:[Rotation {origin.x:armPlane.width/2;origin.y:armPlane.height/2;axis.x:1;axis.y:0;axis.z:0;angle:38},Rotation {origin.x:armPlane.width/2;origin.y:armPlane.height/2;axis.x:0;axis.y:0;axis.z:1;angle:18}]
            // Keep the bearing outside the cropped platter and let the
            // headshell settle on the broad outer groove band.  The arm
            // remains in the platter plane, so these proportions inherit the
            // same foreshortening as the record and never cross the etched
            // seat or the printed centre artwork.
            readonly property real armLength:width*.54
            readonly property real pivotX:width*1.154
            readonly property real pivotY:height*.370
            // 0 = stylus in the lead-out ring, 1 = lifted and swung clear of the record.
            property real pose:page.armResting?1:0
            Behavior on pose {NumberAnimation {duration:RhineTheme.noMotion?0:500;easing.type:Easing.InOutSine}}
            onPoseChanged:page.maybeStartSwap()
            readonly property real lift:Math.min(1,pose*2.4)
            readonly property real swing:-149+18*pose
            // The fixed upper-right key casts down-left in the record plane.
            // Keep the existing lift distance and animation ownership.
            Item {objectName:"nowTonearmShadow";x:-(5+8*armPlane.lift)*page.unit;y:(5+8*armPlane.lift)*page.unit;width:parent.width;height:parent.height
                ShaderEffect {
                    x:armPlane.pivotX-.26*armPlane.armLength;y:armPlane.pivotY-.16*armPlane.armLength;width:1.42*armPlane.armLength;height:.32*armPlane.armLength
                    transform:Rotation {origin.x:.26*armPlane.armLength;origin.y:.16*armPlane.armLength;angle:armPlane.swing}
                    property variant artwork:armShadowArt
                    property real phase:armPlane.lift
                    property real shadowOnly:11
                    property real darkMode:rhine.state.dark?1:0
                    fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
                }
            }
            ShaderEffect {objectName:"nowTonearm"
                x:armPlane.pivotX-.26*armPlane.armLength;y:armPlane.pivotY-.16*armPlane.armLength;width:1.42*armPlane.armLength;height:.32*armPlane.armLength
                transform:Rotation {origin.x:.26*armPlane.armLength;origin.y:.16*armPlane.armLength;angle:armPlane.swing}
                property variant artwork:armShadowArt
                property real phase:armPlane.lift
                property real shadowOnly:12
                property real darkMode:rhine.state.dark?1:0
                fragmentShader:"qrc:/shaders/recordAtmosphere.frag.qsb"
            }
        }
    }
    NumberAnimation {id:recordChangeAnimation;target:page;property:"swapProgress";from:0;to:1;duration:RhineTheme.noMotion?0:650;easing.type:Easing.InOutSine;onFinished:page.finishRecordChange()}
    NumberAnimation {id:lyricFollowAnimation;target:lyrics;property:"contentY";duration:280;easing.type:Easing.OutCubic}
    RhineMenu {id:more;parent:page;font.family:rhineFontFamily;font.variableAxes:({"wght":400});palette.window:rhine.state.dark?"#30382a":"#f3f1e8";palette.text:page.ink
        objectName:"nowPlayingMoreMenu";popupType:Controls.Popup.Item

        RhineMenuItem {objectName:"nowCollect";text:"添加到歌单";onTriggered:controller.operate("collect")}
        RhineMenuItem {text:"查看歌曲详情";onTriggered:controller.operate("details")}
        RhineMenuItem {text:"重新读取歌词";onTriggered:controller.operate("retry-lyrics")}
        RhineMenuItem {text:"在官方客户端打开";onTriggered:controller.operate("official")}
        RhineMenuItem {text:"返回浏览信息";onTriggered:controller.operate("browse")}
    }
}
