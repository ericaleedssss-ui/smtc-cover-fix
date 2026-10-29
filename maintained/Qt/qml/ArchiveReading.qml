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
    property bool playing:false
    property var playbackController:null
    readonly property bool collectionActive:visible&&collection&&!playing
    readonly property Item content:playing?playingLoader.item:collectionLoader.item
    function dismissTopOverlay(){return content?content.dismissTopOverlay():false;}
    Loader {
        id:materialLoader
        objectName:"textFrostedLoader"
        parent:reading.materialLayer
        z:-1
        x:reading.x;y:reading.y;width:reading.width;height:reading.height
        active:reading.frosted
        visible:reading.visible&&reading.frosted
        sourceComponent:LiquidGlass {
            objectName:"textFrostedPanel"
            background:reading.visible&&reading.frosted?reading.background:null
            sampleX:materialLoader.x;sampleY:materialLoader.y
            uiScale:reading.unit;dark:reading.dark
        }
    }
    Loader {
        id:playingLoader;objectName:"nowPlayingLoader";anchors.fill:parent
        active:reading.playing&&!!reading.playbackController;visible:active&&reading.visible
        sourceComponent:NowPlayingPanel {controller:reading.playbackController;unit:reading.unit}
    }
    Loader {
        id:collectionLoader
        objectName:"playlistShowcaseLoader"
        anchors.fill:parent
        active:reading.collection&&!reading.playing
        visible:reading.collectionActive
        enabled:visible
        sourceComponent:PlaylistShowcase {controller:reading.controller;background:reading.background;unit:reading.unit}
    }
}
