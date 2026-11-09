import QtQuick
import QtQuick.Window

// Capture only lower visual layers, never the overlay containing this popup.
// Each capture is popup-sized and is released when the popup closes.
Item {
    id:surface
    required property var popup
    property real unit:1
    property real radius:14*unit
    property bool dark:false
    property real frosting:.66
    property real tint:.16
    property real refraction:.64
    property real rimStrength:.25
    readonly property var host:Window.window
    readonly property var layers:host&&host.popupGlassSources?host.popupGlassSources:[]
    readonly property point sceneOrigin:{
        popup.x;popup.y;popup.width;popup.height;x;y;width;height;
        return host?mapToItem(host.contentItem,0,0):Qt.point(0,0);
    }
    readonly property bool engaged:popup.visible&&visible&&rhineRefractiveGlass&&rhine.visualPreferences.glassPanels!==false
    Loader {
        anchors.fill:parent
        active:surface.engaged
        sourceComponent:Item {
            Item {
                id:lowerLayers
                visible:false
                width:surface.width+44*surface.unit;height:surface.height+44*surface.unit
                Repeater {
                    model:surface.layers
                    ShaderEffectSource {
                        required property var modelData
                        anchors.fill:parent
                        sourceItem:modelData&&modelData.visible?modelData:null
                        readonly property point origin:sourceItem?sourceItem.mapFromItem(surface.host.contentItem,surface.sceneOrigin.x-22*surface.unit,surface.sceneOrigin.y-22*surface.unit):Qt.point(0,0)
                        sourceRect:Qt.rect(origin.x,origin.y,width,height)
                        textureSize:Qt.size(Math.max(1,Math.ceil(width*Screen.devicePixelRatio)),Math.max(1,Math.ceil(height*Screen.devicePixelRatio)))
                        live:true;smooth:true;hideSource:false
                    }
                }
            }
            LiquidGlass {
                objectName:"popupRefractiveSurface"
                anchors.fill:parent;background:lowerLayers
                sampleX:22*surface.unit;sampleY:22*surface.unit
                uiScale:surface.unit;radius:surface.radius;dark:surface.dark
                refractive:true;refraction:surface.refraction;frosting:surface.frosting;tint:surface.tint;rimStrength:surface.rimStrength
            }
        }
    }
    Rectangle {
        anchors.fill:parent;visible:!rhineRefractiveGlass||rhine.visualPreferences.glassPanels===false;radius:surface.radius
        color:surface.dark?"#292929":"#fafafa"
        border.width:1;border.color:surface.dark?"#555555":"#dddddd"
    }
}
