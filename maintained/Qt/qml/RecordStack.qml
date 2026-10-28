import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls
Item {
    id: stack
    required property var controller
    property real unit:1
    property bool reduced:false
    property var front:controller.info
    property var rear:controller.covers
    property var paintedFront:({})
    property var frozenRear:[]
    property var chosen:({})
    property string startingKey:""
    property bool turning:false
    property real progress:0
    property real oldSlide:0
    property real oldTilt:0
    property real oldOpacity:1
    property real size:Math.min(width-38*unit,height-30*unit)
    HoverHandler {id:area;margin:55*stack.unit}
    function choose(value) {
        if(turning) return;
        if(reduced) {controller.openCover(value.key);return;}
        startingKey=String(front.key||"");chosen=value;frozenRear=rear;turning=true;progress=0;oldSlide=0;oldTilt=0;oldOpacity=1;
        turn.restart();
    }
    onFrontChanged:{
        if(turning && front.key!==startingKey && front.key!==chosen.key){turn.stop();turning=false;oldSlide=0;oldTilt=0;oldOpacity=1;}
        if(!turning) paintedFront=front;
    }
    Component.onCompleted:paintedFront=front
    Repeater {
        model:stack.turning?stack.frozenRear:stack.rear
        delegate: Item {
            id:sleeve
            required property var modelData
            required property int index
            objectName:"recordSleeve_"+modelData.key
            width:stack.size;height:width
            property bool expanded:area.hovered || coverMouse.containsMouse
            x:18*stack.unit + (expanded ? (22+index*14)*stack.unit : (-15-index*9)*stack.unit)
            y:18*stack.unit + (expanded ? (-4-index*5)*stack.unit : (-7-index*5)*stack.unit)
            rotation:(index-1)*5-6
            z:coverMouse.containsMouse?12:3-index
            Behavior on x {NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Behavior on y {NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Rectangle {anchors.fill:parent;anchors.margins:-3;radius:4;color:"#20000000";y:3}
            Rectangle {anchors.fill:parent;color:"#ebe8df";radius:3
                Image {anchors.fill:parent;anchors.margins:2;source:sleeve.modelData.cover || "";sourceSize.width:512;sourceSize.height:512;fillMode:Image.PreserveAspectCrop;asynchronous:true}
            }
            Controls.ToolTip.visible:coverMouse.containsMouse && !stack.turning
            Controls.ToolTip.delay:350
            Controls.ToolTip.text:modelData.title || ""
            MouseArea {id:coverMouse;anchors.fill:parent;hoverEnabled:true;enabled:!stack.turning;cursorShape:Qt.PointingHandCursor;onClicked:stack.choose(sleeve.modelData)}
        }
    }
    Item {
        x:18*stack.unit+stack.oldSlide;y:18*stack.unit-stack.progress*8*stack.unit
        width:stack.size;height:width;rotation:stack.oldTilt;opacity:stack.turning?stack.oldOpacity:1;z:10
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
        layer.effect:MultiEffect {shadowEnabled:true;shadowBlur:.65;shadowOpacity:.22;shadowVerticalOffset:8;shadowColor:"#48533e"}
        Rectangle {x:1;y:7;width:parent.width;height:parent.height;radius:4;color:"#25000000"}
        Rectangle {anchors.fill:parent;color:"#e6e2d7";radius:3
            Image {objectName:"playlistMainCover";anchors.fill:parent;source:stack.paintedFront.cover || "";asynchronous:true;sourceSize.width:640;sourceSize.height:640;fillMode:Image.PreserveAspectCrop}
        }
    }
    Image {
        visible:stack.turning;z:25
        x:18*stack.unit-(1-stack.progress)*45*stack.unit
        y:18*stack.unit-(1-stack.progress)*25*stack.unit
        width:stack.size;height:width;rotation:(1-stack.progress)*-9
        source:stack.chosen.cover || "";sourceSize.width:640;sourceSize.height:640;fillMode:Image.PreserveAspectCrop;asynchronous:true
        opacity:Math.min(1,stack.progress*2.5)
    }
    SequentialAnimation {
        id:turn
        ParallelAnimation {
            NumberAnimation {target:stack;property:"oldSlide";to:-55*stack.unit;duration:190;easing.type:Easing.InOutCubic}
            NumberAnimation {target:stack;property:"oldTilt";to:-7;duration:190;easing.type:Easing.InOutCubic}
            NumberAnimation {target:stack;property:"progress";to:.45;duration:190;easing.type:Easing.InOutCubic}
        }
        ScriptAction {script:if(stack.chosen.kind!=="album")stack.controller.openCover(stack.chosen.key)}
        ParallelAnimation {
            NumberAnimation {target:stack;property:"oldSlide";to:-85*stack.unit;duration:330;easing.type:Easing.OutCubic}
            NumberAnimation {target:stack;property:"oldOpacity";to:0;duration:220}
            NumberAnimation {target:stack;property:"progress";to:1;duration:330;easing.type:Easing.OutCubic}
        }
        ScriptAction {script:{stack.paintedFront=stack.front;stack.oldSlide=0;stack.oldTilt=0;stack.oldOpacity=1;stack.turning=false;if(stack.chosen.kind==="album")stack.controller.openCover(stack.chosen.key);}}
    }
}
