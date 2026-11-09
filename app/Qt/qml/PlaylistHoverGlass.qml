import QtQuick
import QtQuick.Shapes
import QtQuick.Window

// One surface per virtual list. Geometry follows the approved hover study;
// Only the shared surface captures the room; never allocate per-row textures.
Item {
    id:glass
    property real unit:1
    property bool dark:false
    property bool reduced:false
    property bool engaged:false
    property real targetY:0
    property real position:0
    property real velocity:0
    property real stretch:0
    property real flow:0
    property real tension:0
    property real tensionVelocity:0
    property real startPosition:0
    property real travel:0
    property real direction:1
    property bool initialized:false
    property Item background:null
    property bool refractive:false
    readonly property bool optical:refractive&&GraphicsInfo.api!==GraphicsInfo.Software
    property point sampleOrigin:Qt.point(0,0)
    y:position
    opacity:engaged?1:0
    visible:opacity>.001
    Behavior on opacity {NumberAnimation {duration:glass.reduced?0:100;easing.type:Easing.OutQuad}}
    function clearMotion() {velocity=0;stretch=0;flow=0;tension=0;tensionVelocity=0;}
    function follow(value,snap) {
        targetY=value;startPosition=position;travel=Math.abs(value-position);
        direction=value<position?-1:1;
        if(snap||reduced||!initialized){position=value;clearMotion();initialized=true;motion.stop();}
        else motion.start();
        engaged=true;
    }
    function dismiss() {engaged=false;motion.stop();clearMotion();initialized=false;}
    onReducedChanged: {motion.stop();position=targetY;clearMotion();}
    FrameAnimation {
        id:motion
        onTriggered: {
            const elapsed=Math.min(frameTime,.04);
            let dt=elapsed;
            while(dt>0){const h=Math.min(dt,1/240);glass.velocity+=((glass.targetY-glass.position)*720-glass.velocity*44)*h;glass.position+=glass.velocity*h;dt-=h;}
            const progress=glass.travel>8?Math.max(0,Math.min(1,Math.abs(glass.position-glass.startPosition)/glass.travel)):1;
            const gate=Math.max(0,progress<.8?(progress-.35)/.45:(1-progress)/.2);
            const pull=1.5*gate*gate*(3-2*gate)*Math.min(1,glass.travel/(50*glass.unit));
            dt=elapsed;
            while(dt>0){const h=Math.min(dt,1/240);glass.tensionVelocity+=((pull-glass.tension)*1100-glass.tensionVelocity*42)*h;glass.tension+=glass.tensionVelocity*h;dt-=h;}
            glass.stretch+=(Math.min(.22,Math.abs(glass.velocity/glass.unit)*.00019)-glass.stretch)*(1-Math.exp(-20*elapsed));
            glass.flow+=(Math.tanh(glass.velocity/(700*glass.unit))-glass.flow)*(1-Math.exp(-15*elapsed));
            if(Math.abs(glass.targetY-glass.position)<.015&&Math.abs(glass.velocity)<.08&&glass.stretch<.0003&&Math.abs(glass.flow)<.001&&Math.abs(glass.tension)<.001&&Math.abs(glass.tensionVelocity)<.02){
                glass.position=glass.targetY;glass.clearMotion();stop();
            }
        }
    }
    Item {
        id:surface
        width:parent.width;height:parent.height
        transform: [
            Scale {origin.x:surface.width/2;origin.y:surface.height/2;xScale:1.003-glass.stretch*.025;yScale:glass.reduced?1:1.04+glass.stretch},
            Matrix4x4 {matrix:Qt.matrix4x4(1,0,0,0, Math.tan(glass.flow*.14*Math.PI/180),1,0,0, 0,0,1,0, 0,0,0,1)}
        ]
        readonly property real amount:Math.max(-.18,Math.min(1.1,glass.tension))
        readonly property real r:(9+Math.max(0,amount)*8)*glass.unit
        readonly property real waist:Math.max(0,amount)*6*glass.unit
        readonly property real topBow:glass.direction*amount*(glass.direction<0?14:5.5)*glass.unit
        readonly property real bottomBow:glass.direction*amount*(glass.direction>0?14:5.5)*glass.unit
        readonly property string outline: {
            const w=width,h=height,r=surface.r,a=surface.waist,t=surface.topBow,b=surface.bottomBow;
            return `M ${r} .5 C ${w*.26} .5 ${w*.34} ${t+.5} ${w*.5} ${t+.5} S ${w*.78} .5 ${w-r} .5 Q ${w-.5} .5 ${w-.5} ${r} C ${w-a} ${h*.4} ${w-a} ${h*.65} ${w-.5} ${h-r} Q ${w-.5} ${h-.5} ${w-r} ${h-.5} C ${w*.74} ${h-.5} ${w*.66} ${h+b-.5} ${w*.5} ${h+b-.5} S ${w*.22} ${h-.5} ${r} ${h-.5} Q .5 ${h-.5} .5 ${h-r} C ${a} ${h*.65} ${a} ${h*.4} .5 ${r} Q .5 .5 ${r} .5 Z`;
        }
        Shape {
            y:3*glass.unit;width:parent.width;height:parent.height
            ShapePath {strokeColor:"transparent";fillColor:glass.dark?"#10000000":"#08363e2d";PathSvg {path:surface.outline}}
        }
        Shape {
            id:contourMask;visible:false;width:parent.width;height:parent.height
            ShapePath {strokeColor:"transparent";fillColor:"white";PathSvg {path:surface.outline}}
        }
        Loader {
            anchors.fill:parent
            active:glass.optical&&glass.visible&&!!glass.background
            sourceComponent:LiquidGlass {
                objectName:"playlistRefractiveSurface"
                background:glass.background
                sampleX:glass.sampleOrigin.x+glass.x;sampleY:glass.sampleOrigin.y+glass.y
                uiScale:glass.unit;dark:glass.dark;radius:surface.r
                refractive:true;refraction:.52;frosting:.16;tint:.07;rimStrength:.24
                silhouette:contourMask
                contourTop:surface.topBow;contourBottom:surface.bottomBow;contourWaist:surface.waist
            }
        }
        Shape {
            width:parent.width;height:parent.height
            ShapePath {
                strokeWidth:glass.unit;strokeColor:glass.dark?"#42ffffff":"#58ffffff"
                fillGradient:LinearGradient {
                    x1:0;y1:0;x2:surface.width*.1;y2:surface.height
                    GradientStop {position:0;color:glass.optical?(glass.dark?"#12ffffff":"#28fffdf4"):(glass.dark?"#20ffffff":"#50fffdf4")}
                    GradientStop {position:.42;color:glass.optical?(glass.dark?"#08ffffff":"#15fffdf4"):(glass.dark?"#12ffffff":"#30fffdf4")}
                    GradientStop {position:.7;color:glass.optical?(glass.dark?"#08a6b396":"#10f7f5e9"):(glass.dark?"#0ea6b396":"#27f7f5e9")}
                    GradientStop {position:1;color:glass.optical?(glass.dark?"#10ffffff":"#20fffdf4"):(glass.dark?"#1fffffff":"#38fffdf4")}
                }
                PathSvg {path:surface.outline}
            }
        }
    }
}
