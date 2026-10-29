import QtQuick
import QtQuick.Window
Item {
    id:view
    objectName:"archiveArtistMarquee"
    property var people:[]
    property string fallback:""
    property real unit:1
    property real shift:0
    readonly property real distance:Math.max(0,names.width-width)
    signal personClicked(string id)
    clip:true
    Item {
        id:surface;anchors.fill:parent
        Row {
            id:names;x:view.shift;height:parent.height;spacing:0
            Repeater {
                model:view.people.length?view.people:[{id:"",name:view.fallback}]
                delegate:Text {
                    required property var modelData
                    required property int index
                    objectName:"archiveArtist_"+(modelData.id||"unknown")
                    height:view.height;verticalAlignment:Text.AlignVCenter
                    text:(index?" / ":"")+(modelData.name||"");textFormat:Text.PlainText
                    font.family:rhineFontFamily;font.pixelSize:13*view.unit
                    color:rhine.state.dark?"#eceee3":"#30372e"
                    MouseArea {anchors.fill:parent;enabled:!!parent.modelData.id;cursorShape:Qt.PointingHandCursor;onClicked:view.personClicked(parent.modelData.id)}
                }
            }
        }
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software&&view.distance>0
        layer.effect:ShaderEffect {
            property variant source
            property size panelSize:Qt.size(view.width,view.height)
            property real horizontal:1
            property real fadePx:12*view.unit
            property real fadeStart:view.shift< -1?1:0
            property real fadeEnd:names.width+view.shift>view.width+1?1:0
            property real blurStrength:0
            fragmentShader:"qrc:/shaders/softEdgeFade.frag.qsb"
        }
    }
    HoverHandler {id:hover}
    SequentialAnimation {
        id:pan;running:view.visible&&view.distance>2&&!rhine.state.reduced;paused:hover.hovered;loops:Animation.Infinite
        PauseAnimation {duration:1300}
        NumberAnimation {target:view;property:"shift";from:0;to:-view.distance;duration:Math.max(2300,view.distance*25);easing.type:Easing.InOutSine}
        PauseAnimation {duration:1300}
        NumberAnimation {target:view;property:"shift";from:-view.distance;to:0;duration:Math.max(2300,view.distance*25);easing.type:Easing.InOutSine}
    }
    onPeopleChanged:{shift=0;if(visible&&distance>2&&!rhine.state.reduced)pan.restart();}
}
