import QtQuick
import QtQuick.Window
import QtQuick.Effects

Item {
    id: glass
    required property Item background
    property real sampleX: 0
    property real sampleY: 0
    property real uiScale: 1
    property bool dark: false
    property real radius: 22 * uiScale
    // Opt-in native adaptation; existing callers retain their original material.
    property bool refractive: false
    property real refraction: .8
    property real frosting: .28
    property real tint: .10
    property Item silhouette: null
    property real contourTop: 0
    property real contourBottom: 0
    property real contourWaist: 0
    property real rimStrength: 1
    property real readingComfort: 0
    property real shadowStrength: 1
    property bool materialEnabled:true
    readonly property real offsetCap: {
        if(!refractive)return 0;
        var maxRaw=0;
        for(var j=0;j<=32;++j)for(var i=0;i<=32;++i){
            var ix=i/32-.5,iy=j/32-.5;
            var qx=Math.abs(ix)-.3+.6,qy=Math.abs(iy)-.2+.6;
            var d=Math.min(Math.max(qx,qy),0)+Math.hypot(Math.max(qx,0),Math.max(qy,0))-.6;
            var t=Math.max(0,Math.min(1,(d-.15-.8)/(-.8)));
            var s=t*t*(3-2*t);s=s*s*(3-2*s);
            maxRaw=Math.max(maxRaw,Math.abs(ix*(s-1)*width),Math.abs(iy*(s-1)*height));
        }
        return maxRaw*.25;
    }
    readonly property real padding: 22 * uiScale
    readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software
    ShaderEffectSource {
        id: raw
        x: -glass.padding; y: -glass.padding
        width: glass.width+2*glass.padding; height: glass.height+2*glass.padding
        sourceItem: glass.materialEnabled?glass.background:null
        sourceRect: Qt.rect(glass.sampleX+x,glass.sampleY+y,width,height)
        textureSize: Qt.size(Math.max(1,Math.ceil(width*Screen.devicePixelRatio/(glass.refractive?1:2))),Math.max(1,Math.ceil(height*Screen.devicePixelRatio/(glass.refractive?1:2))))
        visible: false; live: true; smooth: true; hideSource: false
    }
    MultiEffect {
        id: blur
        objectName: "textFrostedEffect"
        source: raw; width: raw.width; height: raw.height
        visible: false; autoPaddingEnabled: false
        blurEnabled: true; blurMax: 48; blur: glass.refractive?.65:.9
    }
    ShaderEffectSource {
        id: blurTexture
        sourceItem: blur; visible: false; live: true; smooth: true
        textureSize: raw.textureSize
    }
    ShaderEffectSource {
        id: contourTexture; sourceItem: glass.silhouette
        sourceRect: Qt.rect(-glass.padding,-glass.padding,raw.width,raw.height)
        textureSize: raw.textureSize
        visible: false; live: true; smooth: true
    }
    ShaderEffect {
        objectName: "liquidGlassMaterial"
        visible: !glass.software&&glass.materialEnabled
        x: -glass.padding; y: -glass.padding
        width: raw.width; height: raw.height
        property variant blurred: blurTexture
        property variant scene: raw
        property size panelSize: Qt.size(glass.width,glass.height)
        property real paddingWidth: glass.padding
        property real cornerRadius: glass.radius
        property real darkMode: glass.dark ? 1 : 0
        property real refraction: glass.refraction
        property real frosting: glass.frosting
        property real tintAmount: glass.tint
        property real offsetCap: glass.offsetCap
        property real rimStrength: glass.rimStrength
        property real readingComfort: glass.readingComfort
        property real shadowStrength: glass.shadowStrength
        property real customContour: glass.silhouette ? 1 : 0
        property vector3d contour: Qt.vector3d(glass.contourTop,glass.contourBottom,glass.contourWaist)
        property variant silhouette: contourTexture
        fragmentShader: glass.refractive ? "qrc:/shaders/refractiveGlass.frag.qsb" : "qrc:/shaders/liquidGlass.frag.qsb"
    }
    Rectangle {
        anchors.fill: parent; radius: glass.radius; visible: glass.software||!glass.materialEnabled
        color: glass.dark ? "#df252923" : "#dfefede5"
        border.color: glass.dark ? "#407e8476" : "#aafffdf5"
    }
}
