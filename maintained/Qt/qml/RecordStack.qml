import QtQuick
import QtQuick.Window
import QtQuick.Effects
Item {
    id:stack
    required property var controller
    property Item background
    property real unit:1
    property bool reduced:false
    property bool editorial:false
    readonly property var front:controller.info
    readonly property var rear:controller.covers
    property var paintedFront:({})
    property string awaitingKey:""
    property string queuedKey:""
    property string queuedFromKey:""
    property var chosen:({})
    property string startingKey:""
    property string lastPreparedKey:""
    property string hoveredKey:""
    property bool expanded:false
    property bool turning:false
    property bool switchCooldown:false
    property string pendingKey:""
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
    function pose(slot,insert){
        if(slot===0)return {x:frontX,y:frontY,r:editorial?2:0,s:1,a:1,z:10};
        var side=slot<0?-1:1;
        var far=Math.abs(slot)>1;
        if(far)return {x:frontX+side*size*(insert?.34:.68),y:frontY+size*(insert?.22:-.10),r:side*(insert?19:25),s:insert?.94:.98,a:0,z:1};
        if(editorial)return {x:frontX+(side<0?-size*.17:size*.10),y:frontY+(side<0?16:-7)*unit,r:side<0?-8:5.5,s:.98,a:1,z:side<0?2:1};
        return {x:frontX+(far?side*size*.64:(side<0?-size*.075:(expanded?gap:size*.12))),
            y:frontY-(far?12:(expanded?5:3))*unit,r:side<0?-13:(expanded?6.8:5.2),s:1,a:far?0:1,z:2};
    }
    function cardFor(key){for(var i=0;i<cards.count;++i){var c=cards.itemAt(i);if(c&&c.record.key===key)return c;}return null;}
    function freeCard(){for(var i=0;i<cards.count;++i){var c=cards.itemAt(i);if(c&&!c.record.key)return c;}return null;}
    function assignRecord(card,record){
        if(card.record.key!==record.key||!card.coverSource)card.coverSource=record.cover||"";
        card.record=record;
    }
    function resumeQueuedTurn(){
        if(!queuedKey||turning)return;
        Qt.callLater(function(){
            for(var i=0;i<stack.rear.length;++i)if(stack.rear[i].key===stack.queuedKey){stack.choose(stack.rear[i]);return;}
            stack.queuedKey="";stack.syncCards();
        });
    }
    function syncCards(){
        if(turning||queuedKey||(awaitingKey&&String(front.key||"")!==awaitingKey))return;
        awaitingKey="";
        var desired=[];
        if(front&&front.key)desired.push({record:front,slot:0});
        for(var i=0;i<rear.length;++i)desired.push({record:rear[i],slot:Number(rear[i].side)});
        for(i=0;i<cards.count;++i){var c=cards.itemAt(i);if(!c)continue;var keep=false;
            for(var j=0;j<desired.length;++j)if(desired[j].record.key===c.record.key)keep=true;
            if(!keep)c.record=({});
        }
        for(i=0;i<desired.length;++i){var d=desired[i];var existing=cardFor(d.record.key);
            if(existing){assignRecord(existing,d.record);existing.slot=d.slot;continue;}
            var added=freeCard();if(!added)continue;
            added.snapping=true;added.entering=d.slot!==0;added.slot=d.slot===0?0:d.slot*2;assignRecord(added,d.record);
            // Late metadata uses the same entry path instead of appearing at rest.
            if(d.slot!==0)settleCard(added,d.slot);else releaseSnap(added);
        }
        paintedFront=front;
    }
    function releaseSnap(card){Qt.callLater(function(){card.snapping=false;});}
    function settleCard(card,slot){Qt.callLater(function(){if(!stack.turning&&card.record.key){card.snapping=false;card.slot=slot;card.entering=false;}});}
    function hold(key){if(turning||switchCooldown||queuedKey)return;hoveredKey=key;expanded=true;closeFan.stop();}
    function release(key){if(turning||switchCooldown||queuedKey)return;if(hoveredKey===key)hoveredKey="";closeFan.restart();}
    function choose(value){
        if(turning||switchCooldown||awaitingKey||!value||!value.key||value.key===front.key)return;
        if(queuedKey&&queuedKey!==value.key)return;
        direction=value.side===-1?-1:1;
        if(reduced){switchCooldown=true;controller.openCover(value.key);cooldown.restart();return;}
        chosen=value;startingKey=String(front.key||"");
        var entering=controller.recordNeighbour(2*direction);
        if(entering&&entering.key&&!cardFor(entering.key)){
            var extra=freeCard();if(extra){extra.snapping=true;extra.entering=true;extra.slot=2*direction;assignRecord(extra,entering);}
        }
        for(var n=0;n<cards.count;++n){var imageCard=cards.itemAt(n);
            if(imageCard&&imageCard.record.key&&imageCard.imageLoading){queuedKey=value.key;queuedFromKey=String(front.key||"");closeFan.stop();return;}
        }
        queuedKey="";queuedFromKey="";
        for(var i=0;i<cards.count;++i){var c=cards.itemAt(i);if(!c||!c.record.key)continue;
            c.startX=c.x;c.startY=c.y;c.startRotation=c.rotation;c.startScale=c.scale;c.startOpacity=c.opacity;
            c.targetSlot=c.slot-direction;
        }
        closeFan.stop();hoveredKey="";progress=0;turning=true;for(i=0;i<cards.count;++i)cards.itemAt(i).snapping=false;turn.restart();
    }
    onFrontChanged:{
        var key=String(front.key||"");
        if(queuedKey&&key!==queuedFromKey){queuedKey="";queuedFromKey="";}
        if(key&&key!==lastPreparedKey){lastPreparedKey=key;recordPrefetch.restart();}
        if(awaitingKey&&key!==awaitingKey&&key!==startingKey){commitTurn.stop();pendingKey="";awaitingKey="";}
        if(turning&&key!==startingKey&&key!==chosen.key){turn.stop();turning=false;awaitingKey="";}
        syncCards();
    }
    onRearChanged:syncCards()
    Component.onCompleted:{syncCards();recordPrefetch.restart();}
    // Decode the next entering images ahead of time; these never paint a cover.
    Image {visible:false;source:{var current=stack.front;var neighbours=stack.rear;return stack.controller.recordNeighbour(2).cover||"";}sourceSize.width:512;sourceSize.height:512;asynchronous:true}
    Image {visible:false;source:{var current=stack.front;var neighbours=stack.rear;return stack.controller.recordNeighbour(-2).cover||"";}sourceSize.width:512;sourceSize.height:512;asynchronous:true}
    Timer {id:cooldown;interval:180;onTriggered:stack.switchCooldown=false}
    Timer {id:recordPrefetch;interval:280;repeat:false;onTriggered:if(!stack.turning)stack.controller.prepareRecords()}
    Timer {id:commitTurn;interval:16;repeat:false;onTriggered:{var key=stack.pendingKey;stack.pendingKey="";if(key)stack.controller.openCover(key);}}
    Timer {id:closeFan;interval:170;onTriggered:if(!stack.turning&&!stack.queuedKey&&!area.hovered&&!stack.hoveredKey)stack.expanded=false}
    Item {x:-18*stack.unit;y:-8*stack.unit;width:stack.width+36*stack.unit;height:stack.height+64*stack.unit
        HoverHandler {id:area;onHoveredChanged:{if(stack.turning||stack.switchCooldown||stack.queuedKey)return;if(hovered){stack.expanded=true;closeFan.stop();stack.controller.prepareRecords();}else closeFan.restart();}}
    }
    // Four existing render slots: three resting cards and the real entering neighbour.
    // Their image identity never changes while the turn is running.
    Repeater {
        id:cards
        model:4
        delegate:Item {
            id:card
            property var record:({})
            property string coverSource:""
            readonly property bool imageLoading:!!coverSource&&(coverImage.status===Image.Loading||coverImage.status===Image.Null)
            property bool snapping:false
            property bool entering:false
            property int slot:99
            property int targetSlot:99
            property real startX:0
            property real startY:0
            property real startRotation:0
            property real startScale:1
            property real startOpacity:1
            readonly property var destination:stack.pose(stack.turning?targetSlot:slot,!stack.turning&&entering)
            readonly property real p:{
                var t=stack.progress;
                if(Math.abs(slot)>1){t=Math.max(0,(t-.14)/.86);return t*t*(3-2*t);}
                if(Math.abs(targetSlot)>1){t=Math.min(1,t/.82);return t*t*(3-2*t);}
                return t;
            }
            readonly property real arch:stack.turning?Math.sin(Math.PI*p):0
            readonly property bool chosen:record.key===stack.chosen.key
            readonly property bool oldMain:slot===0
            readonly property bool hovered:!stack.turning&&stack.hoveredKey===record.key
            objectName:"recordSleeve_"+(record.key||"")
            visible:!!record.key
            width:stack.size;height:width
            x:stack.turning?startX+(destination.x-startX)*p+((chosen?stack.direction:(oldMain?-stack.direction:0))*stack.size*.22*arch):destination.x
            y:stack.turning?startY+(destination.y-startY)*p-(chosen?6:oldMain?4:0)*stack.unit*arch:destination.y-(hovered?6*stack.unit:0)
            rotation:stack.turning?startRotation+(destination.r-startRotation)*p+(chosen?stack.direction*2:0)*arch:destination.r
            scale:stack.turning?startScale+(destination.s-startScale)*p:(hovered?1.012:1)
            opacity:!record.key?0:(stack.turning?startOpacity+(destination.a-startOpacity)*p:destination.a)
            z:stack.turning?(slot===0?10-8*p:targetSlot===0?2+8*p:1):destination.z
            Behavior on x {enabled:!stack.turning&&!card.snapping;NumberAnimation {duration:stack.reduced?0:210;easing.type:Easing.OutCubic}}
            Behavior on y {enabled:!stack.turning&&!card.snapping;NumberAnimation {duration:stack.reduced?0:210;easing.type:Easing.OutCubic}}
            Behavior on rotation {enabled:!stack.turning&&!card.snapping;NumberAnimation {duration:stack.reduced?0:220;easing.type:Easing.OutCubic}}
            Behavior on scale {enabled:!stack.turning&&!card.snapping;NumberAnimation {duration:stack.reduced?0:160;easing.type:Easing.OutCubic}}
            Behavior on opacity {enabled:!stack.turning&&!card.snapping;NumberAnimation {duration:stack.reduced?0:210;easing.type:Easing.OutCubic}}
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
            layer.effect:MultiEffect {shadowEnabled:true;shadowBlur:.6;shadowOpacity:card.slot===0?.2:0;shadowVerticalOffset:6;shadowColor:"#48533e"}
            Rectangle {anchors.fill:parent;anchors.margins:-2;radius:3;color:"#ebe9df"}
            Image {id:coverImage;objectName:card.slot===0?"playlistMainCover":"recordImage_"+card.record.key;anchors.fill:parent;source:card.coverSource;onStatusChanged:if(status===Image.Ready||status===Image.Error)stack.resumeQueuedTurn();sourceSize.width:512;sourceSize.height:512;fillMode:Image.PreserveAspectCrop;asynchronous:true}
            MouseArea {
                objectName:"recordHit_"+card.record.key
                x:card.slot<0?0:parent.width-width;y:0
                width:card.slot<0?stack.size*.22:(stack.expanded?stack.gap:stack.size*.16);height:parent.height
                enabled:card.slot!==0&&Math.abs(card.slot)===1&&!stack.turning&&!stack.awaitingKey
                hoverEnabled:enabled;cursorShape:Qt.PointingHandCursor
                onEntered:stack.hold(card.record.key)
                onPositionChanged:if(containsMouse)stack.hold(card.record.key)
                onExited:stack.release(card.record.key)
                onClicked:stack.choose(Object.assign({},card.record,{side:card.slot}))
            }
        }
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
        NumberAnimation {target:stack;property:"progress";from:0;to:1;duration:460;easing.type:Easing.InOutCubic}
        ScriptAction {script:{
            var key=String(stack.chosen.key||"");
            for(var i=0;i<cards.count;++i){var c=cards.itemAt(i);if(!c||!c.record.key)continue;
                c.slot=c.targetSlot;c.entering=false;
                if(Math.abs(c.slot)>1)c.record=({});
            }
            stack.paintedFront=stack.chosen;
            stack.awaitingKey=key;
            stack.turning=false;
            stack.switchCooldown=true;cooldown.restart();
            stack.pendingKey=key;commitTurn.restart();
        }}
    }
}
