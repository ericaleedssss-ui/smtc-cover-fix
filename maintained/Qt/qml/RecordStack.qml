import QtQuick
import QtQuick.Window
import QtQuick.Effects
Item {
    id:stack
    required property var controller
    property Item background
    property real unit:1
    property bool reduced:false
    readonly property var front:controller.info
    readonly property var rear:controller.covers
    property var paintedFront:({})
    property var frozenRear:[]
    property var chosen:({})
    property string startingKey:""
    property string lastPreparedKey:""
    property string hoveredKey:""
    property bool expanded:false
    property bool turning:false
    property bool switchCooldown:false
    property real progress:0
    property int direction:1
    readonly property real size:Math.min(width-42*unit,height-24*unit)
    readonly property real frontX:(width-size)/2
    readonly property real frontY:14*unit
    readonly property real gap:size*.22
    readonly property var hoveredRecord:{for(var i=0;i<rear.length;++i)if(rear[i].key===hoveredKey)return rear[i];return ({});}
    readonly property var previousRecord:{for(var i=0;i<rear.length;++i)if(Number(rear[i].side)===-1)return rear[i];return ({});}
    readonly property var nextRecord:{for(var i=0;i<rear.length;++i)if(Number(rear[i].side)===1)return rear[i];return ({});}
    readonly property var previewRecords:{
        var items=[];
        if(previousRecord&&previousRecord.key)items.push({record:previousRecord,slot:-1});
        if(front&&front.key)items.push({record:front,slot:0});
        if(nextRecord&&nextRecord.key)items.push({record:nextRecord,slot:1});
        return items;
    }
    function hold(key){hoveredKey=key;expanded=true;closeFan.stop();}
    function release(key){if(hoveredKey===key)hoveredKey="";closeFan.restart();}
    function choose(value){
        if(turning||switchCooldown||!value||!value.key||value.key===front.key)return;
        direction=value.side===-1?-1:1;
        if(reduced){switchCooldown=true;controller.openCover(value.key);cooldown.restart();return;}
        startingKey=String(front.key||"");chosen=value;frozenRear=rear;turning=true;progress=0;turn.restart();
    }
    onFrontChanged:{
        var key=String(front.key||"");if(key&&key!==lastPreparedKey){lastPreparedKey=key;controller.prepareRecords();}
        if(turning&&front.key!==startingKey&&front.key!==chosen.key){turn.stop();turning=false;}
        if(!turning)paintedFront=front;
    }
    Component.onCompleted:paintedFront=front
    Timer {id:cooldown;interval:180;onTriggered:stack.switchCooldown=false}
    Timer {id:closeFan;interval:170;onTriggered:if(!stack.turning&&!area.hovered&&!stack.hoveredKey)stack.expanded=false}
    Item {x:-18*stack.unit;y:-8*stack.unit;width:stack.width+36*stack.unit;height:stack.height+64*stack.unit
        HoverHandler {id:area;onHoveredChanged:{if(hovered){stack.expanded=true;closeFan.stop();stack.controller.prepareRecords();}else closeFan.restart();}}
    }
    Repeater {
        model:stack.turning?stack.frozenRear:stack.rear
        delegate:Item {
            id:sleeve
            required property var modelData
            required property int index
            readonly property int side:modelData.side===-1?-1:1
            objectName:"recordSleeve_"+modelData.key
            width:stack.size;height:width
            x:stack.frontX+side*(stack.expanded?stack.gap:14*stack.unit)
            y:stack.frontY-(stack.expanded?5:3)*stack.unit-(stack.hoveredKey===modelData.key?6*stack.unit:0)
            rotation:side*(stack.expanded?6:5)
            z:stack.hoveredKey===modelData.key?4:2
            Behavior on x {NumberAnimation {duration:stack.reduced?0:180;easing.type:Easing.OutCubic}}
            Behavior on y {NumberAnimation {duration:stack.reduced?0:180;easing.type:Easing.OutCubic}}
            Rectangle {anchors.fill:parent;anchors.margins:-3;color:"#d8d9cf";radius:4;border.width:1;border.color:"#aaffffff"}
            Image {anchors.fill:parent;source:sleeve.modelData.cover||"";sourceSize.width:512;sourceSize.height:512;fillMode:Image.PreserveAspectCrop;asynchronous:true}
            MouseArea {objectName:"recordHit_"+sleeve.modelData.key
                x:sleeve.side<0?0:parent.width-width;y:0;width:stack.expanded?stack.gap:18*stack.unit;height:parent.height
                enabled:!stack.turning;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                onEntered:stack.hold(sleeve.modelData.key)
                onExited:stack.release(sleeve.modelData.key)
                onClicked:stack.choose(sleeve.modelData)
            }
        }
    }
    Item {
        x:stack.frontX-stack.direction*stack.progress*stack.gap;y:stack.frontY-stack.progress*5*stack.unit
        width:stack.size;height:width;rotation:-stack.direction*stack.progress*6;z:10
        opacity:stack.turning?1-stack.progress*.9:1
        layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
        layer.effect:MultiEffect {shadowEnabled:true;shadowBlur:.6;shadowOpacity:.2;shadowVerticalOffset:6;shadowColor:"#48533e"}
        Rectangle {anchors.fill:parent;anchors.margins:-2;radius:3;color:"#ebe9df"}
        Image {objectName:"playlistMainCover";anchors.fill:parent;source:stack.paintedFront.cover||"";sourceSize.width:640;sourceSize.height:640;fillMode:Image.PreserveAspectCrop;asynchronous:true}
    }
    Image {
        visible:stack.turning;z:20;x:stack.frontX+stack.direction*(1-stack.progress)*stack.gap;y:stack.frontY-(1-stack.progress)*5*stack.unit
        width:stack.size;height:width;rotation:stack.direction*(1-stack.progress)*6;opacity:.35+stack.progress*.65
        source:stack.chosen.cover||"";sourceSize.width:640;sourceSize.height:640;fillMode:Image.PreserveAspectCrop;asynchronous:true
    }
    Row {
        id:previewStrip
        objectName:"recordPreviewStrip"
        x:stack.frontX+Math.max(0,(stack.size-width)/2)
        y:stack.frontY+stack.size+9*stack.unit
        spacing:8*stack.unit;z:25
        visible:stack.expanded&&!stack.turning&&stack.previewRecords.length>1
        Repeater {
            model:stack.previewRecords
            delegate:Rectangle {
                required property var modelData
                readonly property var record:modelData.record||({})
                readonly property int slot:Number(modelData.slot)
                readonly property bool current:slot===0
                objectName:current?"recordPreviewCurrent":"recordPreview_"+record.key
                width:32*Math.max(.9,stack.unit);height:width;radius:4
                color:current?(rhine.state.dark?"#45503e":"#edf1e8"):"#e6e9df"
                border.width:current||stack.hoveredKey===record.key?2:1
                border.color:current?"#738265":(stack.hoveredKey===record.key?"#7f906d":"#aaffffff")
                Image {anchors.fill:parent;anchors.margins:2;source:parent.record.cover||"";sourceSize.width:80;sourceSize.height:80;fillMode:Image.PreserveAspectCrop;asynchronous:true}
                MouseArea {
                    anchors.fill:parent
                    enabled:!parent.current&&!!parent.record.key&&!stack.turning
                    hoverEnabled:enabled
                    cursorShape:enabled?Qt.PointingHandCursor:Qt.ArrowCursor
                    onEntered:if(enabled)stack.hold(parent.record.key)
                    onExited:if(enabled)stack.release(parent.record.key)
                    onClicked:if(enabled)stack.choose(parent.record)
                }
            }
        }
        Text {text:stack.controller.info.recordsLoading?"读取中…":"更多收藏";height:32*Math.max(.9,stack.unit);verticalAlignment:Text.AlignVCenter;color:rhine.state.dark?"#b3bea6":"#7b876e";font.family:rhineFontFamily;font.pixelSize:11*Math.max(.9,stack.unit)
            visible:stack.controller.info.recordsMore===true&&Number(stack.controller.info.recordPosition)>=Number(stack.controller.info.recordCount)-1
            MouseArea {anchors.fill:parent;enabled:!stack.controller.info.recordsLoading;cursorShape:Qt.PointingHandCursor;onClicked:stack.controller.prepareRecords()}
        }
    }
    Rectangle {
        objectName:"recordTargetInfo";x:stack.frontX+6*stack.unit;y:stack.frontY+stack.size*.55;width:stack.size-12*stack.unit;height:targetText.implicitHeight+20*stack.unit
        visible:!!stack.hoveredRecord.key&&!stack.turning;z:30;radius:8*stack.unit;color:rhine.state.dark?"#eb30392b":"#edf3f1e7";border.width:1;border.color:"#60ffffff"
        Column {id:targetText;x:10*stack.unit;y:10*stack.unit;width:parent.width-20*stack.unit;spacing:4*stack.unit
            Text {objectName:"recordTargetTitle";width:parent.width;text:stack.hoveredRecord.title||"";wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;color:rhine.state.dark?"#e6ebdf":"#36402f";font.family:rhineFontFamily;font.pixelSize:13*Math.max(.9,stack.unit)}
            Text {width:parent.width;text:(stack.hoveredRecord.kind==="album"?"专辑":"歌单")+(stack.hoveredRecord.artist?" · "+stack.hoveredRecord.artist:"");elide:Text.ElideRight;color:rhine.state.dark?"#acb79e":"#7b866d";font.family:rhineFontFamily;font.pixelSize:11*Math.max(.9,stack.unit)}
        }
    }
    SequentialAnimation {
        id:turn
        NumberAnimation {target:stack;property:"progress";to:.36;duration:190;easing.type:Easing.InOutCubic}
        ScriptAction {script:if(stack.chosen.kind!=="album")stack.controller.openCover(stack.chosen.key)}
        NumberAnimation {target:stack;property:"progress";to:1;duration:330;easing.type:Easing.OutCubic}
        ScriptAction {script:{stack.paintedFront=stack.front;stack.turning=false;stack.hoveredKey="";closeFan.restart();if(stack.chosen.kind==="album")stack.controller.openCover(stack.chosen.key);}}
    }
}
