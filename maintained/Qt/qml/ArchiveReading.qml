import QtQuick

// One archive reading unit: a persistent original glass surface below the
// native text pass, with interactive collection content above the input pass.
Item {
    id:reading
    objectName:"archiveReading"
    required property Item background
    required property Item materialLayer
    required property var controller
    property real unit:1
    property bool dark:false
    property bool frosted:true
    property bool collection:false
    readonly property bool collectionActive:visible&&collection
    readonly property Item content:collectionLoader.item
    function dismissTopOverlay(){return content?content.dismissTopOverlay():false;}
    Loader {
        id:materialLoader
        objectName:"textFrostedLoader"
        parent:reading.materialLayer
        z:-1
        x:reading.x;y:reading.y;width:reading.width;height:reading.height
        active:reading.visible&&reading.frosted
        sourceComponent:LiquidGlass {
            objectName:"textFrostedPanel"
            background:reading.background
            sampleX:materialLoader.x;sampleY:materialLoader.y
            uiScale:reading.unit;dark:reading.dark
        }
    }
    Loader {
        id:collectionLoader
        objectName:"playlistShowcaseLoader"
        anchors.fill:parent
        active:reading.collectionActive
        sourceComponent:PlaylistShowcase {controller:reading.controller;background:reading.background;unit:reading.unit}
    }
}
