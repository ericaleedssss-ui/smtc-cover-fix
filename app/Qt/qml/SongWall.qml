// SPDX-License-Identifier: AGPL-3.0-only
// Ported from Cloudy ui_wall.go at 250da6d; Qt input/rendering adapter.
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects

Item {
    id:wall
    objectName:"songWall"
    property var rows:[]
    property bool useQueueModel:false
    readonly property var queueRevision:useQueueModel?rhine.nowPlaying.queueRevision:0
    readonly property int entryCount:useQueueModel?rhine.nowPlaying.queueCount:rows.length
    readonly property bool hasDeferred:useQueueModel?(queueRevision,rhine.nowPlaying.queueHasDeferred()):rows.some(function(r){return r.deferred;})
    property real topInset:74
    property Item backdrop:null
    readonly property string fontFamily:rhine.uiFont||"Microsoft YaHei UI"
    readonly property var song:rhine.nowPlaying.info
    readonly property var playback:rhine.nowPlaying.playback
    readonly property bool reduced:rhine.state.reduced===true||rhine.visualPreferences.motion!=="full"
    readonly property int playingIndex:useQueueModel?(queueRevision,rhine.nowPlaying.queueIndex(wall.song.session)):rows.findIndex(function(row){return row.key===wall.song.session;})
    readonly property int columns:Math.max(1,Math.min(entryCount,Math.max(Math.min(entryCount,Math.max(1,Math.floor((width-96+14)/126))),Math.ceil(Math.sqrt(entryCount*2.5)))))
    readonly property int rowCount:Math.ceil(entryCount/columns)
    readonly property real songHeight:Math.min(320,Math.max(200,height*.36))
    readonly property real planeWidth:columns*126-14
    readonly property real planeHeight:rowCount*126-14
    readonly property real planeX:Math.max(48,(width-planeWidth)/2)
    readonly property real planeY:72
    property string centeredSession:""
    // Retain inexpensive row/input objects and scroll state. Release decoded
    // artwork and offscreen frost targets after the short return window.
    property bool resourcesActive:true
    Timer {id:releaseResources;interval:2000;onTriggered:wall.resourcesActive=false}
    property real sway:0
    clip:true
    function centerPlaying(initial){
        if(playingIndex<0||field.dragging)return;
        var x=planeX+(playingIndex%columns)*126, y=planeY+Math.floor(playingIndex/columns)*126;
        if(!initial&&x>=field.contentX&&x+112<=field.contentX+field.width&&y>=field.contentY+72&&y+112<=field.contentY+field.height-112)return;
        var toX=Math.max(0,Math.min(field.contentWidth-field.width,x+56-field.width/2));
        var toY=Math.max(0,Math.min(field.contentHeight-field.height,y+56-(field.height+72-112)/2));
        panX.stop();panY.stop();
        if(initial||reduced){field.contentX=toX;field.contentY=toY;}
        else {panX.to=toX;panY.to=toY;panX.start();panY.start();}
    }
    function syncPlaying(){if(centeredSession!==song.session){var initial=!centeredSession;centeredSession=song.session;centerPlaying(initial);}}
    function hydrate(){
        if(!visible)return;
        var indices=[];
        for(var r=field.firstRow;r<=field.lastRow;++r)for(var c=field.firstColumn;c<=field.lastColumn;++c){var i=r*columns+c;if(i<entryCount)indices.push(i);}
        rhine.nowPlaying.hydrateQueue(indices);
    }
    onRowsChanged:hydration.restart()
    onQueueRevisionChanged:hydration.restart()
    onVisibleChanged:if(visible){releaseResources.stop();resourcesActive=true;syncPlaying();hydration.restart();}else{panX.stop();panY.stop();releaseResources.restart();}
    onPlayingIndexChanged:syncPlaying()
    onWidthChanged:centerPlaying(true)
    onHeightChanged:centerPlaying(true)
    Component.onCompleted:{syncPlaying();hydration.restart();}
    Timer {id:hydration;interval:80;onTriggered:wall.hydrate()}
    Timer {interval:16000;repeat:true;running:wall.visible&&wall.hasDeferred;onTriggered:wall.hydrate()}
    NumberAnimation {id:panX;target:field;property:"contentX";duration:800;easing.type:Easing.OutCubic}
    NumberAnimation {id:panY;target:field;property:"contentY";duration:800;easing.type:Easing.OutCubic}
    SequentialAnimation on sway {
        running:wall.visible&&wall.playback.playing&&!wall.reduced;loops:Animation.Infinite
        NumberAnimation {from:-36;to:36;duration:7000;easing.type:Easing.InOutSine}
        NumberAnimation {from:36;to:-36;duration:7000;easing.type:Easing.InOutSine}
    }
    Flickable {
        id:field;objectName:"songWallField"
        x:0;y:wall.topInset+wall.songHeight-36;width:wall.width;height:Math.max(1,wall.height-y)
        contentWidth:Math.max(width,wall.planeWidth+96);contentHeight:Math.max(height,wall.planeHeight+72+112)
        clip:true;boundsBehavior:Flickable.DragAndOvershootBounds;flickableDirection:Flickable.HorizontalAndVerticalFlick
        maximumFlickVelocity:3000;flickDeceleration:1500;pressDelay:120
        rebound:Transition {NumberAnimation {properties:"x,y";duration:800;easing.type:Easing.OutCubic}}
        onMovementStarted:{panX.stop();panY.stop();}
        readonly property int firstColumn:Math.max(0,Math.floor((contentX-wall.planeX-48)/126))
        readonly property int lastColumn:Math.min(wall.columns-1,Math.floor((contentX+width-wall.planeX+48)/126))
        readonly property int firstRow:Math.max(0,Math.floor((contentY-wall.planeY-20)/126))
        readonly property int lastRow:Math.min(wall.rowCount-1,Math.floor((contentY+height-wall.planeY+20)/126))
        readonly property int poolColumns:Math.min(wall.columns,Math.ceil(width/126)+3)
        readonly property int poolRows:Math.min(wall.rowCount,Math.ceil(height/126)+2)
        onFirstColumnChanged:hydration.restart()
        onFirstRowChanged:hydration.restart()
        Repeater {
            model:field.poolRows
            // Cloudy wall(): animate one row pose, not every cover's geometry.
            delegate:Item {
                id:wallRow
                required property int index
                readonly property int row:field.firstRow+(index-field.firstRow%field.poolRows+field.poolRows)%field.poolRows
                property real rowSway:wall.playback.playing&&!wall.reduced?wall.sway*(row%2===0?1:-1):0
                x:wall.planeX;y:wall.planeY+row*126;width:wall.planeWidth;height:112
                transform:Translate {x:wallRow.rowSway}
                Behavior on rowSway {enabled:!wall.playback.playing&&!wall.reduced;NumberAnimation {duration:1200;easing.type:Easing.OutCubic}}
            Repeater {
            model:field.poolColumns
            delegate:Controls.AbstractButton {
                id:tile
                required property int index
                readonly property int row:wallRow.row
                readonly property int column:field.firstColumn+(index%field.poolColumns-field.firstColumn%field.poolColumns+field.poolColumns)%field.poolColumns
                readonly property int modelData:row*wall.columns+column
                readonly property bool valid:row<wall.rowCount&&column<wall.columns&&modelData<wall.entryCount
                readonly property var track:valid?(wall.useQueueModel?(wall.queueRevision,rhine.nowPlaying.queueRow(modelData)):wall.rows[modelData]):({})
                readonly property bool current:modelData===wall.playingIndex
                readonly property real pointerY:wallRow.y-field.contentY+tilePointer.point.position.y
                readonly property bool pointerAllowed:!field.moving&&pointerY>36&&pointerY<field.height-112
                readonly property bool over:hovered&&pointerAllowed
                objectName:valid?"wallTile_"+modelData:"wallPool_"+index
                x:column*126;y:0
                width:112;height:112;hoverEnabled:true
                HoverHandler {id:tilePointer}
                visible:valid;enabled:valid&&!track.unavailable
                Accessible.name:track.title||"歌曲"
                scale:current?1.08:down&&pointerAllowed?.96:over?1.04:1
                opacity:track.unavailable?.4:1
                Behavior on scale {enabled:!wall.reduced;SpringAnimation {spring:5.5;damping:.72;epsilon:.001}}
                background:Item {}
                contentItem:Rectangle {
                    radius:14;color:"#14ffffff"
                    layer.enabled:wall.resourcesActive&&tile.current
                    layer.effect:MultiEffect {shadowEnabled:true;shadowColor:"#99000000";shadowBlur:.6;shadowVerticalOffset:14}
                    ProfileArtwork {id:tileArt;objectName:"wallArtwork";anchors.fill:parent;requested:wall.resourcesActive;url:tile.track.cover||"";sourceSize:Qt.size(240,240);visible:false}
                    ShaderEffect {
                        anchors.fill:parent;property variant source:tileArt;property size artworkSize:Qt.size(width,height);property real radius:14
                        property real sourceAspect:tileArt.implicitWidth/Math.max(1,tileArt.implicitHeight)
                        fragmentShader:"qrc:/shaders/roundedArtwork.frag.qsb"
                        opacity:tileArt.status===Image.Ready?1:0;Behavior on opacity {NumberAnimation {duration:wall.reduced?0:180}}
                    }
                    Rectangle {anchors.fill:parent;radius:14;color:"transparent";border.width:tile.current?2:0;border.color:"#e6ffffff"}
                    Rectangle {x:8;y:8;width:28;height:22;radius:11;color:"#66000000";visible:tile.current;PlayingBars {anchors.centerIn:parent;color:"white"}}
                    Rectangle {
                        anchors.fill:parent;radius:14;opacity:tile.over?1:0
                        Behavior on opacity {NumberAnimation {duration:wall.reduced?0:120}}
                        gradient:Gradient {GradientStop {position:0;color:"transparent"} GradientStop {position:.45;color:"transparent"} GradientStop {position:1;color:"#c7000000"}}
                        Column {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:8;spacing:1
                            Text {width:parent.width;text:tile.track.title||"";elide:Text.ElideRight;color:"white";font.family:wall.fontFamily;font.pixelSize:12;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold})}
                            Text {width:parent.width;text:tile.track.artist||"";elide:Text.ElideRight;color:"#b3ffffff";font.family:wall.fontFamily;font.variableAxes:({"wght":400});font.pixelSize:11}
                        }
                    }
                }
                onClicked:if(!current&&pointerAllowed)rhine.action("player:queue-play:"+track.index+":"+encodeURIComponent(track.key))
                TapHandler {acceptedButtons:Qt.RightButton;onTapped:if(tile.pointerAllowed){var p=tile.mapToItem(null,112,20);rhine.magazine.showSongMenu("queue",tile.track.index,tile.track.key,p.x,p.y);}}
            }
        }
            }
        }
    }
    MouseArea {
        x:field.x;y:field.y;width:field.width;height:field.height;acceptedButtons:Qt.NoButton
        onWheel:function(wheel){
            panX.stop();panY.stop();field.cancelFlick();
            var dx=wheel.pixelDelta.x||wheel.angleDelta.x/2,dy=wheel.pixelDelta.y||wheel.angleDelta.y/2;
            if(wheel.modifiers&Qt.ShiftModifier){dx+=dy;dy=0;}
            field.contentX=Math.max(0,Math.min(field.contentWidth-field.width,field.contentX-dx));
            field.contentY=Math.max(0,Math.min(field.contentHeight-field.height,field.contentY-dy));wheel.accepted=true;
        }
    }
    component BlurLevel:Item {
            id:level
            property variant input
            property bool foot
            property real bandHeight
            property real lo
            property real hi
            readonly property real radius:level.foot?14:16
            property alias texture:result
            width:input.width;height:input.height;visible:false
            ShaderEffect {id:horizontal;width:level.width;height:level.height;visible:false;property variant source:level.input;property variant original:level.input;property size area:Qt.size(width,height);property vector2d direction:Qt.vector2d(1,0);property real sigma:Math.sqrt(level.hi*level.hi-level.lo*level.lo);property real composite:0;property real bandHeight:level.bandHeight;property real foot:level.foot?1:0;property real radius:level.radius;property real lo:level.lo;property real hi:level.hi;fragmentShader:"qrc:/shaders/cloudyGaussian.frag.qsb"}
            ShaderEffectSource {id:horizontalTexture;sourceItem:horizontal;width:level.width;height:level.height;textureSize:Qt.size(width,height);visible:false;live:true}
            // Fold the unchanged progressive mask into the vertical pass. No
            // intermediate vertical copy or separate mask render target.
            ShaderEffect {id:vertical;width:level.width;height:level.height;visible:false;property variant source:horizontalTexture;property variant original:level.input;property size area:Qt.size(width,height);property vector2d direction:Qt.vector2d(0,1);property real sigma:Math.sqrt(level.hi*level.hi-level.lo*level.lo);property real composite:1;property real bandHeight:level.bandHeight;property real foot:level.foot?1:0;property real radius:level.radius;property real lo:level.lo;property real hi:level.hi;fragmentShader:"qrc:/shaders/cloudyGaussian.frag.qsb"}
            ShaderEffectSource {id:result;sourceItem:vertical;width:level.width;height:level.height;textureSize:Qt.size(width,height);visible:false;live:true}
        }
    component Frost:Item {
        id:frost
        property bool foot:false
        objectName:foot?"wallFooterFrost":"wallHeaderFrost"
        clip:true
        width:wall.width;height:foot?112:72
        // Cloudy ui_wall.go: 72/112 DIP bands, blur radii 16/14, and
        // backdropOver's exact smoothstep. Composite once, rather than
        // overlaying translucent blur over the still-sharp cover layer.
        ShaderEffectSource {id:strip;sourceItem:field;sourceRect:Qt.rect(-48,(frost.foot?field.height-frost.height:0)-48,frost.width+96,frost.height+96);textureSize:Qt.size(width,height);width:frost.width+96;height:frost.height+96;visible:false;live:true}
        // Direct blurLevels port from Cloudy's pinned MyGo glass implementation:
        // sigma doubles, variances add, each level composites over the last.
        BlurLevel {id:level1;foot:frost.foot;bandHeight:frost.height;input:strip;lo:0;hi:(frost.foot?14:16)/16}
        BlurLevel {id:level2;foot:frost.foot;bandHeight:frost.height;input:level1.texture;lo:level1.hi;hi:(frost.foot?14:16)/8}
        BlurLevel {id:level3;foot:frost.foot;bandHeight:frost.height;input:level2.texture;lo:level2.hi;hi:(frost.foot?14:16)/4}
        BlurLevel {id:level4;foot:frost.foot;bandHeight:frost.height;input:level3.texture;lo:level3.hi;hi:(frost.foot?14:16)/2}
        BlurLevel {id:level5;foot:frost.foot;bandHeight:frost.height;input:level4.texture;lo:level4.hi;hi:frost.foot?14:16}
        ShaderEffectSource {id:backdropStrip;sourceItem:wall.backdrop;sourceRect:Qt.rect(0,frost.foot?wall.height-frost.height:field.y,frost.width,frost.height);textureSize:Qt.size(width,height);width:frost.width;height:frost.height;visible:false;live:true}
        ShaderEffect {anchors.fill:parent;property variant sharpSource:strip;property variant blurSource:level5.texture;property variant backdropSource:backdropStrip;property size area:Qt.size(width,height);property real foot:frost.foot?1:0;fragmentShader:"qrc:/shaders/cloudyWallFrost.frag.qsb"}
        MouseArea {anchors.fill:parent;visible:frost.foot;onWheel:function(event){event.accepted=true;}}
    }
    Loader {y:field.y;width:wall.width;height:72;active:wall.resourcesActive;sourceComponent:Frost {}}
    Loader {y:wall.height-height;width:wall.width;height:112;active:wall.resourcesActive;sourceComponent:Frost {foot:true}}
    Row {
        anchors.horizontalCenter:parent.horizontalCenter;y:wall.topInset;spacing:36;width:Math.min(parent.width-144,headerCover.width+36+440);height:wall.songHeight
        Rectangle {
            id:headerCover
            anchors.verticalCenter:parent.verticalCenter;width:wall.songHeight-48;height:width;radius:14;color:"#14ffffff"
            scale:wall.playback.playing?1:.92
            Behavior on scale {enabled:!wall.reduced;SpringAnimation {spring:4;damping:.65;epsilon:.001}}
            layer.enabled:wall.resourcesActive;layer.effect:MultiEffect {shadowEnabled:true;shadowColor:"#8c000000";shadowBlur:.7;shadowVerticalOffset:20}
            ProfileArtwork {anchors.fill:parent;requested:wall.resourcesActive;url:wall.song.cover||"";sourceSize:Qt.size(600,600);layer.enabled:wall.resourcesActive;layer.effect:MultiEffect {maskEnabled:true;maskSource:headerMask}}
            Item {id:headerMask;anchors.fill:parent;layer.enabled:wall.resourcesActive;visible:false;Rectangle {anchors.fill:parent;radius:14;color:"white"}}
        }
        Column {width:parent.width-headerCover.width-parent.spacing;anchors.verticalCenter:parent.verticalCenter;spacing:4
            Item {width:parent.width;height:Math.max(34,wallTitle.implicitHeight)
                Text {id:wallTitle;objectName:"wallTitle";width:Math.min(implicitWidth,Math.max(1,parent.width-80));anchors.verticalCenter:parent.verticalCenter;text:wall.song.title||"";font.family:wall.fontFamily;font.pixelSize:26;font.weight:Font.ExtraBold;font.variableAxes:({"wght":Font.ExtraBold});color:"white";elide:Text.ElideRight}
                RhineSongActions {prefix:"wall";x:wallTitle.width+8;anchors.verticalCenter:parent.verticalCenter}
            }
            RhineCreditLine {width:parent.width;pixelSize:14;song:wall.song;onActivated:function(target){rhine.magazine.openSongCredit(wall.song.key,target);}}
            Item {width:1;height:10}
            Text {width:parent.width;text:(rhine.nowPlaying.lines[wall.playback.index]||{}).text||"";font.family:rhineFontFamily;font.pixelSize:17;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});color:"#d9ffffff";wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
            Text {width:parent.width;text:(rhine.nowPlaying.lines[Number(wall.playback.index)+1]||{}).text||"";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;color:"#61ffffff";elide:Text.ElideRight}
        }
    }
    Text {anchors.centerIn:field;visible:wall.entryCount===0;text:"待播清单为空";color:"#aaaaaa";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:18}
}
