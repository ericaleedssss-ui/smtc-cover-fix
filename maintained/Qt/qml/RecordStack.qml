import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls
Item {
    id: stack
    required property var controller
    property real unit:1
    property bool reduced:false
    property Item background
    property string hoveredKey:""
    property bool expanded:false
    Timer {id:closeFan;interval:180;onTriggered:if(!stack.turning&&!area.hovered&&!stack.hoveredKey)stack.expanded=false}
    function hold(key){hoveredKey=key;expanded=true;closeFan.stop();}
    function release(key){if(hoveredKey===key)hoveredKey="";closeFan.restart();}
    readonly property real gap:size*.29
    readonly property var hoveredRecord:{for(var i=0;i<rear.length;++i)if(rear[i].key===hoveredKey)return rear[i];return ({});}
    property var front:controller.info
    property var rear:controller.covers
    property var paintedFront:({})
    property var frozenRear:[]
    property var chosen:({})
    property string startingKey:""
    property bool turning:false
    property bool switchCooldown:false
    Timer {id:cooldown;interval:180;onTriggered:stack.switchCooldown=false}
    property real progress:0
    property real oldSlide:0
    property real oldTilt:0
    property real oldOpacity:1
    property real size:Math.min(width-38*unit,height-70*unit)
    Item {
        x:0;y:-22*stack.unit;width:stack.expanded?stack.size+stack.gap*stack.rear.length+36*stack.unit:stack.width
        height:stack.size+104*stack.unit
        HoverHandler {id:area;onHoveredChanged:{if(hovered){stack.expanded=true;closeFan.stop();}else closeFan.restart();}}
    }
    function choose(value) {
        if(turning || switchCooldown || !value || !value.key || value.key===front.key) return;
        if(reduced) {switchCooldown=true;controller.openCover(value.key);cooldown.restart();return;}
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
            property bool expanded:stack.expanded
            x:18*stack.unit + (expanded ? (index+1)*stack.gap : (-15-index*9)*stack.unit)
            y:18*stack.unit + (expanded ? (-4-index*6-(stack.hoveredKey===modelData.key?9:0))*stack.unit : (-7-index*5)*stack.unit)
            rotation:(index-1)*5-6
            z:3-index
            Behavior on x {NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Behavior on y {NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Rectangle {anchors.fill:parent;anchors.margins:-3;radius:4;color:"#20000000";y:3}
            Rectangle {anchors.fill:parent;color:"#ebe8df";radius:3;border.width:stack.hoveredKey===sleeve.modelData.key?2:0;border.color:"#9baa83"
                Image {anchors.fill:parent;anchors.margins:2;source:sleeve.modelData.cover || "";sourceSize.width:512;sourceSize.height:512;fillMode:Image.PreserveAspectCrop;asynchronous:true}
            }
            // Only the exposed right-hand strip owns this record. Raising its
            // artwork never moves a full-size hit area over a neighbouring record.
            MouseArea {id:coverMouse;objectName:"recordHit_"+sleeve.modelData.key
                anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:parent.bottom
                width:stack.expanded?stack.gap:22*stack.unit
                hoverEnabled:true;enabled:!stack.turning;cursorShape:Qt.PointingHandCursor
                onEntered:stack.hold(sleeve.modelData.key)
                onExited:stack.release(sleeve.modelData.key)
                onClicked:stack.choose(sleeve.modelData)
            }
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
    Row {
        objectName:"recordPreviewStrip"
        x:18*stack.unit;y:stack.size+34*stack.unit;spacing:9*stack.unit;z:30
        visible:stack.expanded&&!stack.turning
        Repeater {model:stack.rear
            delegate:Rectangle {
                required property var modelData
                objectName:"recordPreview_"+modelData.key
                width:46*stack.unit;height:width;radius:5
                color:"#e8ebe0";border.width:stack.hoveredKey===modelData.key?2:1;border.color:stack.hoveredKey===modelData.key?"#7b8c65":"#aaffffff"
                Image {anchors.fill:parent;anchors.margins:3;source:parent.modelData.cover||"";sourceSize.width:96;sourceSize.height:96;fillMode:Image.PreserveAspectCrop;asynchronous:true}
                MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                    onEntered:stack.hold(parent.modelData.key)
                    onExited:stack.release(parent.modelData.key)
                    onClicked:stack.choose(parent.modelData)
                }
            }
        }
    }
    Item {
        id:targetInfo;objectName:"recordTargetInfo"
        x:18*stack.unit+stack.size+stack.gap*stack.rear.length+12*stack.unit;y:20*stack.unit
        width:222*stack.unit;height:targetText.implicitHeight+30*stack.unit;z:35
        visible:!!stack.hoveredRecord.key&&!stack.turning
        Loader {anchors.fill:parent;active:!!stack.background
            sourceComponent:LiquidGlass {background:stack.background;sampleX:targetInfo.mapToItem(stack.background,0,0).x;sampleY:targetInfo.mapToItem(stack.background,0,0).y;uiScale:stack.unit;radius:12*stack.unit;dark:rhine.state.dark===true}
        }
        Rectangle {anchors.fill:parent;radius:12*stack.unit;color:rhine.state.dark?"#b82e3728":"#c9f4f2e9";border.width:1;border.color:"#60ffffff"}
        Column {id:targetText;x:14*stack.unit;y:14*stack.unit;width:parent.width-28*stack.unit;spacing:7*stack.unit
            Text {objectName:"recordTargetTitle";width:parent.width;text:stack.hoveredRecord.title||"";wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;color:rhine.state.dark?"#e6ebdf":"#36402f";font.family:rhineFontFamily;font.pixelSize:14*Math.max(.9,stack.unit);font.weight:Font.Medium}
            Text {width:parent.width;text:(stack.hoveredRecord.kind==="album"?"专辑":"歌单")+(stack.hoveredRecord.artist?" · "+stack.hoveredRecord.artist:"");wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;color:rhine.state.dark?"#acb79e":"#7b866d";font.family:rhineFontFamily;font.pixelSize:12*Math.max(.9,stack.unit)}
        }
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
        ScriptAction {script:{stack.paintedFront=stack.front;stack.oldSlide=0;stack.oldTilt=0;stack.oldOpacity=1;stack.turning=false;stack.hoveredKey="";closeFan.restart();if(stack.chosen.kind==="album")stack.controller.openCover(stack.chosen.key);}}
    }
}
