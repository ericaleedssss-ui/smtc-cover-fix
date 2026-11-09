import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.Button {
    id:button
    objectName:"globalNowPlaying"
    property real unit:1
    property bool available:false
    property bool playing:false
    property bool selected:false
    property bool dark:false
    property bool reduced:false
    property bool blocked:false
    property bool motionAllowed:true
    signal openRequested()
    implicitWidth:36*unit;implicitHeight:36*unit
    enabled:available&&!blocked
    hoverEnabled:true
    focusPolicy:Qt.NoFocus
    padding:7*unit
    Accessible.name:"打开正在播放页面"
    onClicked:openRequested()
    HoverHandler {cursorShape:button.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
    background:Rectangle {radius:width/2;color:button.hovered?"#326f845e":button.selected?"#1c6f845e":"transparent";border.width:button.hovered||button.selected?.7*button.unit:0;border.color:"#65fffdf3";Behavior on color {ColorAnimation {duration:120}}}
    contentItem:Item {
        opacity:button.available?1:.35
        PlayingBars {anchors.centerIn:parent;unit:button.unit;live:button.playing&&button.available;motionAllowed:button.motionAllowed&&!button.reduced&&RhineTheme.fullMotion;color:button.dark?"#b8c7a6":"#738063"}
    }
}
