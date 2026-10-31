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
    property real phase:0
    implicitWidth:36*unit;implicitHeight:36*unit
    enabled:available&&!blocked
    hoverEnabled:true
    focusPolicy:Qt.NoFocus
    padding:7*unit
    Accessible.name:"打开正在播放页面"
    onClicked:openRequested()
    Controls.ToolTip.visible:hovered&&!blocked
    Controls.ToolTip.text:available?"打开正在播放页面":"尚未播放歌曲"
    Controls.ToolTip.delay:500
    HoverHandler {cursorShape:button.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
    NumberAnimation on phase {from:0;to:1;duration:1400;loops:Animation.Infinite;running:button.visible&&button.playing&&button.enabled&&!button.reduced&&button.motionAllowed}
    background:Rectangle {radius:width/2;color:button.hovered?"#326f845e":button.selected?"#1c6f845e":"transparent";border.width:button.hovered||button.selected?.7*button.unit:0;border.color:"#65fffdf3";Behavior on color {ColorAnimation {duration:120}}}
    contentItem:Item {
        opacity:button.available?1:.35
        Repeater {model:4
            Rectangle {required property int index
                objectName:"nowPlayingBar_"+index
                width:2*button.unit;radius:width/2;x:(parent.width-17*button.unit)/2+index*5*button.unit;anchors.verticalCenter:parent.verticalCenter
                height:(button.playing&&!button.reduced?8+9*(.5+.5*Math.sin(button.phase*Math.PI*2+index*1.5)):9+index%2*4)*button.unit
                color:button.dark?"#b8c7a6":"#738063"
            }
        }
    }
}
