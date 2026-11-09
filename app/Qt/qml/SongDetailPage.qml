// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_nowplaying.go; native Qt rendering and playback adapter.
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects

Item {
    id:page
    objectName:"songDetailPage"
    readonly property var hud:rhine.state
    property var retainedSong:({})
    property real revealProgress:1
    property bool transitionOpen:true
    property rect barCover:Qt.rect(0,0,0,0)
    property rect barTitle:Qt.rect(0,0,0,0)
    property rect barScrub:Qt.rect(0,0,0,0)
    property rect barPlay:Qt.rect(0,0,0,0)
    property real barRotation:0
    property bool barDark:false
    readonly property bool flying:sameSong&&!reduced&&revealProgress>0&&revealProgress<1&&barCover.width>0
    readonly property real landed:flying?easeRange(revealProgress,.995,.999):1
    readonly property real flightOpacity:easeRange(revealProgress,0,.001)*(1-easeRange(revealProgress,.999,1))
    function flightRect(from,target){
        var p=target.mapToItem(page,0,0),k=revealProgress;
        return Qt.rect(from.x+(p.x-from.x)*k,from.y+(p.y-from.y)*k,from.width+(target.width-from.width)*k,from.height+(target.height-from.height)*k);
    }
    readonly property var song:transitionOpen?(hud.detailSong||({})):retainedSong
    readonly property string songIdentity:song.key||""
    onSongChanged:if(transitionOpen&&song.key)retainedSong=song
    function easeRange(k,from,to){var t=Math.max(0,Math.min(1,(k-from)/(to-from)));return t*t*(3-2*t);}
    readonly property real contentReveal:easeRange(revealProgress,.45,.95)
    readonly property var playback:rhine.nowPlaying.playback
    readonly property var preferences:hud.playerPreferences||({})
    readonly property bool sameSong:song.key===rhine.nowPlaying.info.key
    readonly property bool reduced:hud.reduced===true||effects.motion!=="full"
    readonly property var effects:rhine.visualPreferences
    property real fogTime:0
    property real fogSpeed:0
    readonly property color coverTint:rhine.nowPlaying.info.coverTint||"#787882"
    function fogColor(value,saturation){return Qt.hsva(coverTint.hsvHue<0?0:coverTint.hsvHue,saturation,value,1);}
    readonly property real fogSaturation:coverTint.hsvSaturation>.12?Math.min(.85,Math.max(.6,coverTint.hsvSaturation*1.3)):coverTint.hsvSaturation
    FrameAnimation {running:page.visible&&page.effects.fog&&!page.reduced&&page.effects.motion==="full"&&(page.playback.playing||page.fogSpeed>.005);onTriggered:{var dt=Math.min(frameTime,.05);page.fogSpeed+=(Number(page.playback.playing)-page.fogSpeed)*(1-Math.exp(-2.61*dt));page.fogTime+=page.fogSpeed*dt;}}
    readonly property bool wide:width>=860
    readonly property real margin:wide?Math.max(72,(width-1280)/2):24
    readonly property real coverSide:Math.max(120,Math.min(440,width*.36,height-436))
    readonly property bool immersive:tab==="stage"||tab==="wall"
    readonly property var lyricLines:sameSong?rhine.nowPlaying.lines:[]
    readonly property int activeLine:sameSong?Number(playback.index):-1
    property string tab:"lyrics"
    property string requestedTab:"lyrics"
    property var preparedPanes:({})
    readonly property var requestedLoader:({queue:queueLoader,comments:commentsLoader,stage:stageLoader,wall:wallLoader})[requestedTab]
    readonly property bool paneReady:!requestedLoader||requestedLoader.status===Loader.Ready
    property real lyricScale:preferences.lyricScale||1
    property bool following:true
    property real renderPositionMs:Number(playback.positionMs||0)
    property real clockAge:0
    FrameAnimation {running:page.visible&&page.tab==="lyrics"&&page.sameSong&&page.playback.playing;onTriggered:{page.clockAge=Math.min(.3,page.clockAge+frameTime);page.renderPositionMs=Number(page.playback.positionMs||0)+page.clockAge*1000;}}
    Connections {target:rhine.nowPlaying;function onPlaybackChanged(){page.clockAge=0;page.renderPositionMs=Number(page.playback.positionMs||0);}function onFollowRequested(){page.resumeFollow();}}
    function escaped(value){return String(value||"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");}
    function wordText(line,active){
        var words=line.words||[];
        if(!active||!words.length)return escaped(line.text);
        return words.map(function(w){var lit=Math.max(0,Math.min(1,(renderPositionMs-Number(w.startMs))/Math.max(50,Number(w.endMs)-Number(w.startMs))));return '<span style="color:'+Qt.rgba(1,1,1,.38+.62*lit).toString()+'">'+escaped(w.text)+'</span>';}).join("");
    }
    function openCredit(link){rhine.magazine.openSongCredit(song.key||"",link);}
    function browseLyrics(){following=false;lyricReturn.restart();}
    function resumeFollow(){lyricReturn.stop();following=true;follow();}
    Timer {id:lyricReturn;objectName:"detailLyricReturn";interval:4000;onTriggered:{if(lyrics.dragging||lyrics.flicking)restart();else page.resumeFollow();}}
    property bool styleOpen:false
    readonly property var selectedTabItem:tabRepeater.itemAt(Math.max(0,tabs.findIndex(function(t){return t.key===tab;})))
    readonly property var tabs:[{key:"lyrics",label:"歌词"},{key:"stage",label:"律动"},{key:"queue",label:"待播清单"},{key:"wall",label:"选歌"},{key:"comments",label:"评论"+(hud.socialCommentCount>0?Math.floor(hud.socialCommentCount):"")}]
    function choose(key){
        if(key===tab&&!paneMotion.busy){if(key==="stage")openStageMenu();return;}
        styleOpen=false;
        requestedTab=key;
        var prepared=Object.assign({},preparedPanes);prepared[key]=true;preparedPanes=prepared;
        paneMotion.run(function(){page.tab=key;rhine.action(key==="comments"?"tab:comments":"tab:overview");});
    }
    RhineContentMotion {id:paneMotion;objectName:"detailContentMotion";ready:page.paneReady}
    function openStageMenu(){var button=tabRepeater.itemAt(1);if(!button)return;var p=button.mapToItem(page,0,button.height);styleMenu.x=p.x;styleMenu.y=p.y+8;styleMenu.open();}
    function clock(seconds){seconds=Math.max(0,Math.floor(seconds||0));return Math.floor(seconds/60)+":"+String(seconds%60).padStart(2,"0");}
    function lyricClock(seconds){return clock(seconds).padStart(5,"0");}
    function toggle(){rhine.action(sameSong?"player:toggle":"music:play");}
    function follow(){
        if(!following||activeLine<0)return;
        lyrics.currentIndex=activeLine;
        Qt.callLater(function(){
            if(!page.following)return;
            var item=lyrics.itemAtIndex(page.activeLine);
            if(!item){lyrics.positionViewAtIndex(page.activeLine,ListView.Contain);item=lyrics.itemAtIndex(page.activeLine);}
            if(!item)return;
            var to=Math.max(lyrics.originY,Math.min(lyrics.originY+lyrics.contentHeight-lyrics.height+lyrics.bottomMargin,item.y-lyrics.height*.3));
            lyricGlide.stop();if(page.reduced)lyrics.contentY=to;else{lyricGlide.to=to;lyricGlide.start();}
        });
    }
    onActiveLineChanged:follow()
    onSongIdentityChanged:Qt.callLater(resumeFollow)
    Component.onCompleted:{tab=hud.detailTab==="comments"?"comments":"lyrics";page.forceActiveFocus();follow();}
    Keys.onSpacePressed:toggle()
    HoverHandler {id:windowPointer}
    component Tool:Controls.AbstractButton {
        id:tool;property string glyph;property string tip;property bool active:false;property real iconSize:20
        width:34;height:34;hoverEnabled:true;focusPolicy:Qt.StrongFocus;Accessible.name:tip
        scale:down?.88:1;Behavior on scale {enabled:!page.reduced;NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
        background:Rectangle {objectName:"detailToolSurface";radius:height/2;color:tool.hovered||tool.visualFocus?"#24808080":"transparent";Behavior on color {ColorAnimation {duration:page.reduced?0:120}}}
        contentItem:Item {RhineIcon {anchors.centerIn:parent;width:tool.iconSize;height:width;name:({play:"cloudyPlay",pause:"cloudyPause",previousTrack:"cloudyPrev",nextTrack:"cloudyNext",shuffle:"cloudyShuffle",repeat:"cloudyRepeat",repeatOne:"cloudyRepeat1",volume:"cloudyVolume",mute:"cloudyMute",chevron:"cloudyDown",more:"cloudyMore"})[tool.glyph]||tool.glyph;filled:tool.glyph==="cloudyHeart"&&tool.active;color:tool.active?"#ef6575":"#eeeeee"}}
        HoverHandler {cursorShape:Qt.PointingHandCursor}
    }
    Item {id:detailBackdrop;anchors.fill:parent;opacity:page.easeRange(page.revealProgress,0,.3)
    Rectangle {anchors.fill:parent;color:"#484646"}
    Image {id:coverBackdrop;anchors.fill:parent;source:page.song.cover||"";fillMode:Image.PreserveAspectCrop;asynchronous:true;sourceSize:Qt.size(80,80);visible:false}
    MultiEffect {anchors.fill:parent;source:coverBackdrop;blurEnabled:true;blurMax:64;blur:1;brightness:-.12;saturation:-.75;opacity:.35}
    Rectangle {anchors.fill:parent;color:"#28373737"}
    ShaderEffect {anchors.fill:parent;visible:page.effects.fog;property size area:Qt.size(width,height);property real time:page.fogTime;property real bass:page.playback.visualBass||0;property color deep:page.fogColor(.3,page.fogSaturation);property color fog:page.fogColor(.72,page.fogSaturation*.6);fragmentShader:"qrc:/shaders/cloudyFog.frag.qsb"}
    }
    MouseArea {anchors.fill:parent;onPressed:page.forceActiveFocus()}
    Tool {objectName:"songDetailBack";anchors.horizontalCenter:parent.horizontalCenter;y:6;glyph:"chevron";tip:"返回";opacity:windowPointer.hovered||visualFocus?1:0;Behavior on opacity {NumberAnimation {duration:page.reduced?0:200}} onClicked:rhine.action("player:detail-close")}
    Flickable {
        id:tabsScroll;z:2;x:page.margin;y:46;width:page.width-page.margin*2;height:36;contentWidth:tabRow.width;contentHeight:height;clip:true;boundsBehavior:Flickable.StopAtBounds;opacity:page.contentReveal*(windowPointer.hovered||activeFocus?1:0)
        Behavior on opacity {NumberAnimation {duration:page.reduced?0:200}}
        Rectangle {objectName:"detailTabIndicator";x:page.selectedTabItem?page.selectedTabItem.x:0;y:0;width:page.selectedTabItem?page.selectedTabItem.width:54;height:28;radius:14;color:"#24ffffff"
            Behavior on x {enabled:!page.reduced;NumberAnimation {duration:240;easing.type:Easing.OutCubic}}
            Behavior on width {enabled:!page.reduced;NumberAnimation {duration:200;easing.type:Easing.OutCubic}}
        }
        Row {id:tabRow;spacing:6
            Repeater {id:tabRepeater;model:page.tabs;delegate:Controls.AbstractButton {
                id:tabButton;objectName:"detailTab_"+modelData.key;required property var modelData;width:tabLabel.implicitWidth+28+(modelData.key==="stage"?16:0);height:28;hoverEnabled:true;Accessible.name:modelData.label
                property real arrowReveal:modelData.key==="stage"&&page.tab==="stage"?1:0
                Behavior on arrowReveal {NumberAnimation {duration:page.reduced?0:150;easing.type:Easing.OutCubic}}
                background:Rectangle {radius:18;color:tabButton.down?"#26ffffff":tabButton.hovered?"#16ffffff":"transparent";Behavior on color {ColorAnimation {duration:page.reduced?0:120}}}
                contentItem:Item {
                    Text {id:tabLabel;x:(parent.width-width)/2-8*tabButton.arrowReveal;anchors.verticalCenter:parent.verticalCenter;text:tabButton.modelData.label;font.family:rhineFontFamily;font.pixelSize:13;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:page.tab===tabButton.modelData.key?"#ffffff":"#a9a9a9"}
                    Item {objectName:tabButton.modelData.key==="stage"?"stageStyleSelector":"";anchors.fill:parent;visible:tabButton.arrowReveal>0;opacity:tabButton.arrowReveal
                        RhineIcon {objectName:"stageModeArrow";x:tabLabel.x+tabLabel.width+6;anchors.verticalCenter:parent.verticalCenter;width:10;height:10;name:"cloudyDown";color:"white"}
                    }
                }
                onClicked:page.choose(modelData.key)
            }}
        }
    }
    RhineMenu {id:styleMenu;objectName:"stageModeMenu";dark:true
        Repeater {model:[{key:"flow",label:"流光"},{key:"steps",label:"云阶"},{key:"tilt",label:"倾诉"}];delegate:RhineMenuItem {required property var modelData;objectName:"stageMode_"+modelData.key;text:modelData.label;checkable:true;checked:(page.preferences.stageStyle||"flow")===modelData.key;onTriggered:paneMotion.run(function(){rhine.setPlayerPreference("stage-style",modelData.key);})}}
        Controls.MenuSeparator {}
        RhineMenuItem {objectName:"stageSparksToggle";text:"火花";checkable:true;checked:page.preferences.stageSparks===true;onTriggered:rhine.setPlayerPreference("stage-sparks",checked?"on":"off")}
    }
    Item {
        id:body;objectName:"detailStandardBody";x:page.margin;y:46;width:page.width-2*page.margin;height:page.height-y-44;opacity:page.contentReveal*paneMotion.progress;enabled:!paneMotion.busy
        transform:Translate {y:paneMotion.offset}
        Column {
            id:left;objectName:"detailLeftColumn";width:page.wide?Math.max(280,page.coverSide):Math.max(220,body.width*.38);spacing:0;visible:!page.immersive
            y:Math.max(0,(body.height-height)/2)
            Rectangle {id:detailCover;width:Math.min(left.width,page.coverSide);height:width;radius:14;color:"#35ffffff";opacity:page.landed
                layer.enabled:true;layer.effect:MultiEffect {shadowEnabled:true;shadowColor:"#60000000";shadowBlur:.5;shadowVerticalOffset:12}
                ProfileArtwork {anchors.fill:parent;url:page.song.cover||"";sourceSize:Qt.size(700,700);layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:detailCoverMask}}
            }
            Item {id:detailCoverMask;width:detailCover.width;height:detailCover.height;layer.enabled:true;visible:false;Rectangle {anchors.fill:parent;radius:14;color:"white"}}
            Item {width:1;height:36}
            Item {width:parent.width;height:detailTitle.height+4+credits.height
                Text {id:detailTitle;objectName:"detailTitle";width:Math.max(1,parent.width-88);height:Math.max(30,implicitHeight);text:page.song.title||"";font.family:rhineFontFamily;font.pixelSize:22;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});color:"#ffffff";elide:Text.ElideRight;opacity:page.landed}
                RhineCreditLine {id:credits;objectName:"detailCredits";anchors.top:detailTitle.bottom;anchors.topMargin:4;width:parent.width;height:22;song:page.song;pixelSize:15;onActivated:function(target){page.openCredit(target);}}
                Tool {objectName:"detailLike";x:parent.width-80;anchors.verticalCenter:detailTitle.verticalCenter;width:38;height:38;iconSize:22;glyph:"cloudyHeart";tip:active?"取消喜欢":"喜欢";active:page.sameSong&&rhine.nowPlaying.info.liked;onClicked:rhine.action("music:like")}
                Tool {objectName:"detailMore";x:parent.width-34;anchors.verticalCenter:detailTitle.verticalCenter;glyph:"more";tip:"更多";onClicked:{var p=mapToItem(null,0,height);rhine.magazine.showSongMenu("detail",0,"",p.x,p.y);}}
            }
            Item {width:1;height:18}
            Item {id:standardTransport;objectName:"detailStandardTransport";width:parent.width;height:transportContent.implicitHeight
                Column {id:transportContent;width:parent.width;spacing:0
                    Controls.Slider {id:seek;objectName:"detailSeek";width:parent.width;height:16;from:0;to:1;enabled:page.sameSong&&page.playback.seekable;opacity:page.landed
                        property string seekSession:""
                        onPressedChanged:if(pressed)seekSession=rhine.nowPlaying.info.session;else rhine.action("player:detail-seek:"+encodeURIComponent(seekSession)+":"+value)
                        Binding {target:seek;property:"value";when:!seek.pressed;value:hud.playbackDuration>0?hud.playbackPosition/hud.playbackDuration:0;restoreMode:Binding.RestoreNone}
                        background:Rectangle {id:standardRail;x:seek.leftPadding;y:seek.topPadding+seek.availableHeight/2-height/2;width:seek.availableWidth;height:4;radius:2;color:unplayedColor;property real fraction:seek.visualPosition;property real lineThickness:4;property real featherWidth:0;property color playedColor:"#eeeeee";property color unplayedColor:"#35ffffff";Rectangle {width:parent.width*parent.fraction;height:parent.height;radius:2;color:parent.playedColor}}
                        handle:GlassSeekThumb {id:standardThumb;objectName:"detailSeekThumb";x:seek.leftPadding+displayFraction*seek.availableWidth-width/2;y:seek.topPadding+seek.availableHeight/2-height/2;dark:true;background:detailBackdrop;track:standardRail;hovered:seek.hovered;pressed:seek.pressed;session:String(rhine.nowPlaying.info.session||"");fraction:seek.visualPosition}
                    }
                    Row {width:parent.width;height:16;Text {width:parent.width/2;text:page.clock(page.sameSong?hud.playbackPosition:0);color:"#aaaaaa";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12} Text {width:parent.width/2;horizontalAlignment:Text.AlignRight;text:"-"+page.clock(page.sameSong?hud.playbackDuration-hud.playbackPosition:Number(page.song.duration)/1000);color:"#aaaaaa";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:12}}
                    Item {width:1;height:14}
                    Row {anchors.horizontalCenter:parent.horizontalCenter;spacing:14;height:51
                        Tool {objectName:"detailShuffle";y:8.5;glyph:"shuffle";iconSize:17.36;tip:"随机播放";opacity:hud.playerShuffle?1:.45;onClicked:rhine.action("player:shuffle")}
                        Tool {y:5.6;width:39.8;height:39.8;glyph:"previousTrack";iconSize:23.8;tip:"上一首";onClicked:rhine.action("player:prev")}
                        Tool {id:detailPlay;objectName:"detailPlay";width:51;height:51;iconSize:35;glyph:page.sameSong&&page.playback.playing?"pause":"play";tip:page.sameSong&&page.playback.playing?"暂停":"播放";onClicked:page.toggle();opacity:page.landed}
                        Tool {y:5.6;width:39.8;height:39.8;glyph:"nextTrack";iconSize:23.8;tip:"下一首";onClicked:rhine.action("player:next")}
                        Tool {objectName:"detailRepeat";y:8.5;glyph:hud.playerMode==="one"?"repeatOne":"repeat";iconSize:17.36;tip:"循环";opacity:hud.playerMode==="off"?.45:1;onClicked:rhine.action("player:repeat")}
                    }
                    Item {width:1;height:18}
                    Row {objectName:"detailVolumeRow";anchors.horizontalCenter:parent.horizontalCenter;spacing:4;height:32
                        Tool {width:32;height:32;iconSize:16;glyph:page.hud.playerVolume>0?"volume":"mute";tip:"静音";onClicked:rhine.action("player:mute")}
                        Controls.Slider {id:volume;anchors.verticalCenter:parent.verticalCenter;width:180;from:0;to:1;value:hud.playerVolume||0;onMoved:rhine.action("player:volume-fraction:"+value);height:16
                            background:Rectangle {x:volume.leftPadding;y:(volume.height-height)/2;width:volume.availableWidth;height:volume.hovered||volume.pressed?5:4;radius:height/2;color:"#2effffff"
                                Rectangle {width:Math.max(parent.height,volume.visualPosition*parent.width);height:parent.height;radius:height/2;color:"#b3ffffff"
                                    layer.enabled:page.effects.npLight;layer.effect:MultiEffect {shadowEnabled:true;shadowColor:Qt.rgba(1,1,1,Number(page.effects.glowLevel)*.7);shadowBlur:.7;shadowHorizontalOffset:0;shadowVerticalOffset:0}
                                }
                            }
                            handle:Item {}
                        }
                    }
                }
            }
        }
        Row {objectName:"detailLyricTools";x:(left.width-width)/2;y:left.y+left.height+12;spacing:10;visible:page.tab==="lyrics";opacity:windowPointer.hovered||activeFocus?1:0
            component Chip:Controls.AbstractButton {
                id:chip;property string label;property string tip;property string glyph:"";property real textSize:12;property bool changed:false
                height:26;hoverEnabled:true;Accessible.name:tip;padding:0
                background:Rectangle {radius:height/2;color:chip.hovered||chip.visualFocus?"#1affffff":"transparent";Behavior on color {ColorAnimation {duration:120}}}
                contentItem:Item {Text {anchors.centerIn:parent;visible:!chip.glyph;text:chip.label;font.family:rhineFontFamily;font.pixelSize:chip.textSize;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:chip.hovered?"white":chip.changed?"#d9ffffff":"#8cffffff";font.features:{"tnum":1}}RhineIcon {anchors.centerIn:parent;visible:!!chip.glyph;width:14;height:14;name:chip.glyph;color:chip.hovered?"white":"#8cffffff"}}
                HoverHandler {cursorShape:Qt.PointingHandCursor}
            }
            Rectangle {width:112;height:32;radius:16;color:"#0affffff";border.width:1;border.color:"#1affffff"
                Row {anchors.centerIn:parent
                    Chip {objectName:"detailLyricSmaller";width:30;label:"A";textSize:11;tip:"歌词字号减小";onClicked:rhine.setPlayerPreference("lyric-scale",String(Math.max(.7,page.lyricScale-.1)))}
                    Chip {objectName:"detailLyricScale";width:48;label:Math.round(page.lyricScale*100)+"%";tip:"恢复歌词字号";changed:page.lyricScale!==1;onClicked:rhine.setPlayerPreference("lyric-scale","1")}
                    Chip {objectName:"detailLyricLarger";width:30;label:"A";textSize:16;tip:"歌词字号增大";onClicked:rhine.setPlayerPreference("lyric-scale",String(Math.min(1.6,page.lyricScale+.1)))}
                }
            }
            Rectangle {width:144;height:32;radius:16;color:"#0affffff";border.width:1;border.color:"#1affffff"
                Row {anchors.centerIn:parent
                    Chip {objectName:"detailLyricEarlier";width:44;label:"提前";textSize:13;tip:"歌词提前 0.1 秒";onClicked:rhine.action("player:lyrics-shift:100")}
                    Chip {objectName:"detailLyricOffset";width:52;label:(Number(page.playback.offsetMs)>=0?"+":"")+(Number(page.playback.offsetMs||0)/1000).toFixed(1)+"s";tip:"恢复歌词时间";changed:!!page.playback.offsetMs;onClicked:rhine.action("player:lyrics-shift:"+(-Number(page.playback.offsetMs||0)))}
                    Chip {objectName:"detailLyricLater";width:44;label:"延后";textSize:13;tip:"歌词延后 0.1 秒";onClicked:rhine.action("player:lyrics-shift:-100")}
                }
            }
            Rectangle {width:34;height:32;radius:16;color:"#0affffff";border.width:1;border.color:"#1affffff"
                Chip {objectName:"detailLyricSettings";anchors.centerIn:parent;width:30;glyph:"cloudySettings";tip:"更多歌词设置";onClicked:rhine.action("settings:lyrics")}
            }
        }
        Item {
            id:right;objectName:"detailStandardPane";x:left.width+(page.wide?72:24);y:Math.max(left.y,36);width:Math.max(1,body.width-x);height:Math.max(1,body.height-y);visible:!page.immersive
            ListView {
                id:lyrics;objectName:"detailLyrics";anchors.fill:parent;visible:page.tab==="lyrics";clip:true;model:page.lyricLines;spacing:6;topMargin:0;bottomMargin:page.height*.5
                boundsBehavior:Flickable.StopAtBounds;onMovementStarted:{lyricGlide.stop();page.browseLyrics();}onMovementEnded:if(!page.following)lyricReturn.restart()
                onModelChanged:Qt.callLater(page.follow)
                NumberAnimation {id:lyricGlide;target:lyrics;property:"contentY";duration:600;easing.type:Easing.OutCubic}
                WheelHandler {
                    target:null;acceptedDevices:PointerDevice.Mouse|PointerDevice.TouchPad
                    onWheel:function(event){
                        lyricGlide.stop();page.browseLyrics();lyrics.cancelFlick();
                        var delta=event.pixelDelta.y!==0?event.pixelDelta.y:event.angleDelta.y/120*72;
                        var lower=lyrics.originY-lyrics.topMargin;
                        var upper=Math.max(lower,lyrics.originY+lyrics.contentHeight-lyrics.height+lyrics.bottomMargin);
                        lyrics.contentY=Math.max(lower,Math.min(upper,lyrics.contentY-delta));
                        event.accepted=true;
                    }
                }
                highlightMoveDuration:page.reduced?0:600
                highlight:Item {}
                highlightRangeMode:ListView.NoHighlightRange
                preferredHighlightBegin:height*.3;preferredHighlightEnd:height*.3
                delegate:Controls.AbstractButton {
                    id:lyric;objectName:"detailLyric_"+index;required property var modelData;required property int index;width:lyrics.width;height:lyricContent.implicitHeight+20;padding:0;leftPadding:12;rightPadding:96;topPadding:10;bottomPadding:10;hoverEnabled:true;enabled:page.sameSong
                    readonly property bool active:index===page.activeLine
                    scale:active?1:.94;transformOrigin:Item.Left
                    Behavior on scale {enabled:!page.reduced;SpringAnimation {spring:3.5;damping:.9;epsilon:.001}}
                    background:Rectangle {objectName:"detailLyricSurface";radius:14;color:lyric.down?"#18ffffff":lyric.hovered?"#0fffffff":"transparent";Behavior on color {ColorAnimation {duration:page.reduced?0:120}}}
                    contentItem:Column {id:lyricContent;spacing:6;opacity:lyric.active?1:lyric.hovered?.55:.28
                        Behavior on opacity {NumberAnimation {duration:page.reduced?0:380}}
                        Text {objectName:"detailLyricWords_"+lyric.index;width:parent.width;text:page.wordText(lyric.modelData,lyric.active);textFormat:Text.RichText;font.family:rhineFontFamily;font.pixelSize:Math.round(30*page.lyricScale);font.weight:Font.ExtraBold;font.variableAxes:({"wght":Font.ExtraBold});color:"white";wrapMode:Text.Wrap;lineHeight:1.25
                            layer.enabled:lyric.active&&page.effects.npLight
                            layer.effect:MultiEffect {shadowEnabled:true;shadowColor:Qt.rgba(1,1,1,Number(page.effects.glowLevel)*.7);shadowBlur:.65;shadowHorizontalOffset:0;shadowVerticalOffset:0}
                        }
                        Text {width:parent.width;visible:page.preferences.translation!==false&&!!text;text:lyric.modelData.translation||"";font.family:rhineFontFamily;font.pixelSize:17;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:"#cccccc";wrapMode:Text.Wrap}
                    }
                    Controls.AbstractButton {
                        id:lineSeek;objectName:"detailLyricSeek_"+lyric.index
                        anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter
                        width:70;height:32;hoverEnabled:true;opacity:lyric.hovered||hovered||visualFocus?1:0
                        enabled:page.sameSong&&page.playback.seekable
                        Accessible.name:"跳转到 "+page.lyricClock(Number(lyric.modelData.startMs)/1000)
                        background:Item {}
                        contentItem:Row {spacing:5
                            RhineIcon {anchors.verticalCenter:parent.verticalCenter;width:12;height:12;name:"play";color:lineSeek.hovered?"#eeeeee":"#99ffffff"}
                            Text {objectName:"detailLyricTime";anchors.verticalCenter:parent.verticalCenter;text:page.lyricClock(Number(lyric.modelData.startMs)/1000);font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13;color:lineSeek.hovered?"#eeeeee":"#99ffffff";font.features:{"tnum":1}}
                        }
                        Behavior on opacity {NumberAnimation {duration:page.reduced?0:120}}
                        HoverHandler {cursorShape:Qt.PointingHandCursor}
                        onClicked:rhine.nowPlaying.seekLine(lyric.index,rhine.nowPlaying.info.session)
                    }
                    onClicked:rhine.nowPlaying.seekLine(index,rhine.nowPlaying.info.session)
                }
                Text {anchors.centerIn:parent;width:parent.width;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;visible:page.lyricLines.length===0;text:!page.sameSong?"播放此歌曲后显示同步歌词":page.playback.lyricStatus==="loading"?"正在读取歌词…":"暂无同步歌词";font.family:rhineFontFamily;font.pixelSize:22;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});color:"#80ffffff"}
            }
            Loader {id:queueLoader;anchors.fill:parent;asynchronous:true;active:page.tab==="queue"||page.preparedPanes.queue===true;visible:page.tab==="queue";sourceComponent:SongQueue {}}
            Loader {id:commentsLoader;anchors.fill:parent;asynchronous:true;active:page.tab==="comments"||page.preparedPanes.comments===true;visible:page.tab==="comments";sourceComponent:SongComments {}}
        }
    }
    Loader {id:stageLoader;objectName:"detailStagePane";x:0;y:46;width:page.width;height:Math.max(1,stageTransport.y-y);asynchronous:true;active:page.tab==="stage"||page.preparedPanes.stage===true;visible:page.tab==="stage";opacity:page.contentReveal*paneMotion.progress;enabled:!paneMotion.busy;transform:Translate {y:paneMotion.offset} sourceComponent:LyricStage {lines:page.lyricLines;currentIndex:page.activeLine;positionMs:page.playback.positionMs||0;playing:page.playback.playing;style:page.preferences.stageStyle||"flow";sparks:page.preferences.stageSparks===true;reduced:page.reduced;translation:page.preferences.translation!==false}}
    Loader {id:wallLoader;anchors.fill:parent;asynchronous:true;active:page.tab==="wall"||page.preparedPanes.wall===true;visible:page.tab==="wall";opacity:page.contentReveal*paneMotion.progress;enabled:!paneMotion.busy;transform:Translate {y:paneMotion.offset} sourceComponent:SongWall {useQueueModel:!rhinePipelineLegacy;rows:rhinePipelineLegacy?rhine.nowPlaying.queue:[];backdrop:detailBackdrop}}
    Item {id:stageTransport;objectName:"detailImmersiveTransport";visible:page.immersive;enabled:!paneMotion.busy;x:48;height:page.tab==="wall"?92:96;y:page.height-height;width:page.width-2*x;opacity:page.contentReveal*paneMotion.progress
        MouseArea {anchors.fill:parent;onWheel:function(event){event.accepted=true;}}
        ProgressSmoke {width:parent.width;height:80;y:-60;head:immersiveSeek.visualPosition*width;bass:page.playback.visualBass||0;playing:page.playback.playing;visible:page.effects.smoke&&!page.reduced&&page.effects.motion==="full"}
        Controls.Slider {id:immersiveSeek;objectName:"detailImmersiveSeek";width:parent.width;height:14;from:0;to:1;enabled:page.sameSong&&page.playback.seekable;opacity:page.landed
            property string seekSession:""
            onPressedChanged:if(pressed)seekSession=rhine.nowPlaying.info.session;else rhine.action("player:detail-seek:"+encodeURIComponent(seekSession)+":"+value)
            Binding {target:immersiveSeek;property:"value";when:!immersiveSeek.pressed;value:hud.playbackDuration>0?hud.playbackPosition/hud.playbackDuration:0;restoreMode:Binding.RestoreNone}
            background:Rectangle {id:immersiveRail;x:immersiveSeek.leftPadding;y:immersiveSeek.topPadding+immersiveSeek.availableHeight/2-height/2;width:immersiveSeek.availableWidth;height:4;radius:2;color:unplayedColor;property real fraction:immersiveSeek.visualPosition;property real lineThickness:4;property real featherWidth:0;property color playedColor:"#eeeeee";property color unplayedColor:"#35ffffff";Rectangle {width:parent.width*parent.fraction;height:parent.height;radius:2;color:parent.playedColor}}
            handle:GlassSeekThumb {id:immersiveThumb;objectName:"detailImmersiveSeekThumb";x:immersiveSeek.leftPadding+displayFraction*immersiveSeek.availableWidth-width/2;y:immersiveSeek.topPadding+immersiveSeek.availableHeight/2-height/2;dark:true;background:detailBackdrop;track:immersiveRail;hovered:immersiveSeek.hovered;pressed:immersiveSeek.pressed;session:String(rhine.nowPlaying.info.session||"");fraction:immersiveSeek.visualPosition}
        }
        ProfileArtwork {id:immersiveCover;visible:page.tab!=="wall";x:0;y:24;width:44;height:44;url:page.song.cover||"";sourceSize:Qt.size(96,96);opacity:page.landed;layer.enabled:true;layer.effect:MultiEffect {maskEnabled:true;maskSource:immersiveMask}}
        Item {id:immersiveMask;width:44;height:44;visible:false;layer.enabled:true;Rectangle {anchors.fill:parent;radius:8;color:"white"}}
        Text {id:immersiveTitle;objectName:"immersiveTitle";visible:page.tab!=="wall";x:56;y:28;width:Math.min(Math.max(implicitWidth,immersiveArtist.implicitWidth),Math.max(32,(parent.width<950?parent.width-280:parent.width/2-140)-56-84));text:page.song.title||"";color:"white";font.family:rhineFontFamily;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});font.pixelSize:14;elide:Text.ElideRight;opacity:page.landed}
        RhineCreditLine {id:immersiveArtist;objectName:"immersiveCredits";visible:page.tab!=="wall";x:56;y:48;width:Math.max(32,immersiveTitle.width);song:page.song;includeAlbum:false;idleColor:"#8cffffff";pixelSize:12;onActivated:function(target){page.openCredit(target);}}
        RhineSongActions {prefix:"immersive";iconSize:17;visible:page.tab!=="wall";x:immersiveTitle.x+immersiveTitle.width+12;y:29}
        Row {x:page.tab!=="wall"&&parent.width<950?parent.width-width:(parent.width-width)/2;y:24;height:44;spacing:11
            Tool {anchors.verticalCenter:parent.verticalCenter;glyph:"shuffle";iconSize:13.64;width:iconSize+16;height:width;tip:"随机播放";opacity:hud.playerShuffle?1:.45;onClicked:rhine.action("player:shuffle")}
            Tool {anchors.verticalCenter:parent.verticalCenter;glyph:"previousTrack";iconSize:18.7;width:iconSize+16;height:width;tip:"上一首";onClicked:rhine.action("player:prev")}
            Tool {id:immersivePlay;objectName:"detailImmersivePlay";anchors.verticalCenter:parent.verticalCenter;iconSize:27.5;width:iconSize+16;height:width;glyph:page.sameSong&&page.playback.playing?"pause":"play";tip:"播放 / 暂停";onClicked:page.toggle();opacity:page.landed}
            Tool {anchors.verticalCenter:parent.verticalCenter;glyph:"nextTrack";iconSize:18.7;width:iconSize+16;height:width;tip:"下一首";onClicked:rhine.action("player:next")}
            Tool {anchors.verticalCenter:parent.verticalCenter;glyph:hud.playerMode==="one"?"repeatOne":"repeat";iconSize:13.64;width:iconSize+16;height:width;tip:"循环";opacity:hud.playerMode==="off"?.45:1;onClicked:rhine.action("player:repeat")}
        }
        Text {visible:page.tab==="wall";y:38;text:page.clock(hud.playbackPosition);color:"#80ffffff";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:Math.round(11.5)}
        Text {visible:page.tab==="wall"||parent.width>=950;anchors.right:parent.right;y:38;text:page.tab==="wall"?"-"+page.clock(hud.playbackDuration-hud.playbackPosition):page.clock(hud.playbackPosition)+" / "+page.clock(hud.playbackDuration);color:"#80ffffff";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:Math.round(11.5)}
    }
    Item {
        id:flights;objectName:"detailSharedFlights";anchors.fill:parent;visible:page.flying;opacity:page.flightOpacity
        readonly property rect cover:page.flightRect(page.barCover,page.immersive?immersiveCover:detailCover)
        readonly property rect title:page.flightRect(page.barTitle,page.immersive?immersiveTitle:detailTitle)
        readonly property rect scrub:page.flightRect(page.barScrub,page.immersive?immersiveSeek:seek)
        readonly property rect play:page.flightRect(page.barPlay,page.immersive?immersivePlay:detailPlay)
        readonly property color ink:Qt.rgba((page.barDark?.92:.08)*(1-page.revealProgress)+page.revealProgress,(page.barDark?.92:.085)*(1-page.revealProgress)+page.revealProgress,(page.barDark?.92:.075)*(1-page.revealProgress)+page.revealProgress,1)
        Rectangle {
            id:flyingCover;objectName:"detailFlyingCover";x:flights.cover.x;y:flights.cover.y;width:flights.cover.width;height:flights.cover.height
            radius:page.barCover.width/2*(1-page.revealProgress)+14*page.revealProgress;color:"#18ffffff"
            rotation:page.barRotation*(1-page.revealProgress)
            layer.enabled:true;layer.effect:MultiEffect {shadowEnabled:true;shadowColor:"#60000000";shadowBlur:.5;shadowVerticalOffset:2+28*page.revealProgress;maskEnabled:true;maskSource:flightMask}
            ProfileArtwork {anchors.fill:parent;url:page.song.cover||"";sourceSize:Qt.size(700,700)}
        }
        Item {id:flightMask;width:flyingCover.width;height:flyingCover.height;layer.enabled:true;visible:false;Rectangle {anchors.fill:parent;radius:flyingCover.radius;color:"white"}}
        Text {objectName:"detailFlyingTitle";x:flights.title.x;y:flights.title.y;width:flights.title.width;height:flights.title.height;text:page.song.title||"";font.family:rhineFontFamily;font.pixelSize:13.5+(page.immersive?.5:8.5)*page.revealProgress;font.weight:page.revealProgress<.5?Font.DemiBold:Font.Bold;font.variableAxes:({"wght":page.revealProgress<.5?Font.DemiBold:Font.Bold});color:flights.ink;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}
        Item {objectName:"detailFlyingScrub";x:flights.scrub.x;y:flights.scrub.y;width:flights.scrub.width;height:flights.scrub.height
            Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width;height:4;radius:2;color:Qt.rgba(1,1,1,.18)
                Rectangle {width:parent.width*Math.max(0,Math.min(1,page.hud.playbackDuration>0?page.hud.playbackPosition/page.hud.playbackDuration:0));height:4;radius:2;color:"#e6ffffff"}
            }
        }
        RhineIcon {objectName:"detailFlyingPlay";x:flights.play.x+8;y:flights.play.y+8;width:Math.max(0,flights.play.width-16);height:Math.max(0,flights.play.height-16);name:page.playback.playing?"pause":"play";color:flights.ink}
    }
}
