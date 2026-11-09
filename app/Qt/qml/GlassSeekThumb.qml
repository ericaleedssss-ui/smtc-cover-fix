// Cloudy ui_player.go scrubber + pinned MyGo plugins/glass Clear material.
// Lens, tone and rim equations: MIT; see vendor/cloudy-ui-reference/mygo-glass.
import QtQuick
import QtQuick.Window

Item {
    id:thumb
    property real unit:1
    property bool dark:false
    property Item background:null
    property Item track:null
    property bool hovered:false
    property bool pressed:false
    property bool blocked:false
    property string session:""
    property real fraction:0
    property real displayFraction:0
    property bool ready:false
    property string previousSession:""
    readonly property bool transitioning:settleTimer.running||blocked
    readonly property bool wanted:(hovered||pressed)&&!transitioning
    property real reveal:0
    property real growth:pressed?1.25:1
    opacity:reveal
    visible:reveal>.001
    scale:growth
    width:30*unit;height:18*unit
    Behavior on reveal {enabled:!thumb.transitioning;NumberAnimation {duration:RhineTheme.duration(160);easing.type:Easing.OutCubic}}
    Behavior on growth {NumberAnimation {duration:RhineTheme.duration(340);easing.type:Easing.OutBack;easing.overshoot:1}}
    function syncPosition(){displayFraction=fraction;}
    onFractionChanged:Qt.callLater(syncPosition)
    onSessionChanged:{
        if(ready&&previousSession&&session&&session!==previousSession&&!RhineTheme.noMotion){
            // Hide before rebinding the new progress; wait for the full bar trail.
            settleTimer.restart();reveal=0;
        }
        previousSession=session;
        Qt.callLater(syncPosition);
    }
    onWantedChanged:reveal=wanted?1:0
    Component.onCompleted:{ready=true;previousSession=session;displayFraction=fraction;reveal=wanted?1:0;}
    Timer {id:settleTimer;interval:1270}
    readonly property real padding:20*unit
    readonly property point origin:{thumb.x;thumb.y;if(thumb.parent){thumb.parent.x;thumb.parent.y;}return thumb.background?thumb.mapToItem(thumb.background,0,0):Qt.point(0,0)}
    readonly property point railOrigin:thumb.track?Qt.point(thumb.x-thumb.track.x,thumb.y-thumb.track.y):Qt.point(0,0)
    ShaderEffectSource {
        id:sceneTexture;visible:false;live:thumb.visible;sourceItem:thumb.background
        sourceRect:Qt.rect(thumb.origin.x-thumb.padding,thumb.origin.y-thumb.padding,thumb.width+2*thumb.padding,thumb.height+2*thumb.padding)
        textureSize:Qt.size(Math.ceil((thumb.width+2*thumb.padding)*Screen.devicePixelRatio),Math.ceil((thumb.height+2*thumb.padding)*Screen.devicePixelRatio))
        smooth:true
    }
    ShaderEffect {
        x:-thumb.padding;y:-thumb.padding;width:thumb.width+2*thumb.padding;height:thumb.height+2*thumb.padding
        property variant scene:sceneTexture
        property size panelSize:Qt.size(thumb.width,thumb.height)
        property real paddingWidth:thumb.padding
        property real uiScale:thumb.unit
        property real pixelWidth:1/Screen.devicePixelRatio
        property point railOffset:thumb.railOrigin
        property size railSize:Qt.size(thumb.track?thumb.track.width:1,thumb.track?thumb.track.height:1)
        property real railFraction:thumb.track?thumb.track.fraction:0
        property real railThickness:thumb.track?thumb.track.lineThickness:0
        property real railFeather:thumb.track?thumb.track.featherWidth:0
        property color playedColor:thumb.track?thumb.track.playedColor:"transparent"
        property color unplayedColor:thumb.track?thumb.track.unplayedColor:"transparent"
        fragmentShader:"qrc:/shaders/clearSeekGlass.frag.qsb"
    }
}
