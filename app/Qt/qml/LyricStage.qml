// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy stage renderer port; see licenses/cloudy/SOURCE.md.
import QtQuick
import QtQuick.Effects
import "StageLayout.js" as Stage

Item {
    id:stage
    objectName:"lyricStage"
    property var lines:[]
    property int currentIndex:-1
    property real positionMs:0
    property bool playing:false
    property real renderPositionMs:positionMs
    onPositionMsChanged:renderPositionMs=playing&&Math.abs(renderPositionMs-positionMs)<200?renderPositionMs+(positionMs-renderPositionMs)*.2:positionMs
    onPlayingChanged:renderPositionMs=positionMs
    onVisibleChanged:renderPositionMs=positionMs
    onReducedChanged:renderPositionMs=positionMs
    FrameAnimation {running:stage.visible&&stage.playing&&!stage.reduced;onTriggered:stage.renderPositionMs=Math.min(stage.positionMs+250,stage.renderPositionMs+Math.min(frameTime,.05)*1000)}
    property string style:"flow"
    property bool reduced:false
    property bool translation:true
    property bool sparks:false
    property color accent:"#cbd9e5"
    readonly property var current:currentIndex>=0&&currentIndex<lines.length?lines[currentIndex]:({})
    readonly property var previous:currentIndex>0&&currentIndex<lines.length?lines[currentIndex-1]:({})
    readonly property string next:currentIndex+1<lines.length?(lines[currentIndex+1].text||""):""
    readonly property real footerHeight:(translation&&!!current.translation)||!!next?stageFooter.implicitHeight+32:0
    readonly property real previousFade:reduced?0:1-Stage.cubic((renderPositionMs-Number(current.startMs||0))/400)
    readonly property real currentEnd:Number(current.endMs)>Number(current.startMs)?Number(current.endMs):Math.min(Number(current.startMs||0)+6000,currentIndex+1<lines.length?Number(lines[currentIndex+1].startMs):Infinity)
    readonly property bool interlude:currentIndex<0||(currentIndex+1<lines.length&&renderPositionMs>currentEnd+1000&&Number(lines[currentIndex+1].startMs)-currentEnd>4000)
    readonly property real breakProgress:Stage.clamp((renderPositionMs-(currentIndex<0?0:Number(current.endMs)))/Math.max(100,(currentIndex+1<lines.length?Number(lines[currentIndex+1].startMs):renderPositionMs)-(currentIndex<0?0:Number(current.endMs))))
    clip:true
    function measure(text,lean){return rhine.glyphs.measureText(text,rhineFontFamily,64,lean?Font.Light:Font.ExtraBold,lean);}
    component Line:Item {
        id:line
        property var lyricLine:({})
        property real fade:1
        readonly property var layout:Stage.layout(lyricLine,stage.style,width,height,stage.measure)
        opacity:fade
        Repeater {
            model:stage.style==="steps"?line.layout.filter(function(w,i,a){return i===0||w.part!==a[i-1].part;}):[]
            delegate:Item {
                required property var modelData
                readonly property var row:modelData.row
                readonly property real since:(stage.renderPositionMs-row.first+80)/1000
                readonly property real entry:stage.reduced?1:Stage.spring(since)
                readonly property real guide:stage.reduced?1:Stage.cubic(since/.4)
                x:row.leftEdge+row.x+(stage.reduced?0:(row.left?-40:40)*(1-entry));y:row.bottom
                width:row.rightEdge-row.leftEdge;height:1
                scale:stage.reduced?1:.85+.15*entry
                opacity:(stage.reduced?1:Stage.clamp(since/.1))*guide
                readonly property color ink:stage.renderPositionMs>row.end?"#38ffffff":stage.accent
                Rectangle {x:parent.row.left?-8:parent.width+8;y:16-height;width:1;height:32*parent.guide;color:parent.ink}
                Rectangle {x:parent.row.left?-16:parent.width+16-width;y:8;width:(parent.width+36)*parent.guide;height:1;color:parent.ink}
            }
        }
        Repeater {
            model:line.layout
            delegate:Item {
                id:word
                required property var modelData
                readonly property var spec:modelData
                readonly property real since:(stage.renderPositionMs-Number(spec.word.startMs))/1000
                readonly property real before:(stage.renderPositionMs-Number(spec.first||0)+250)/1000
                readonly property real shown:Stage.clamp((before-(spec.order||0)*(spec.row&&spec.row.lean?.05:.04))/.5)
                readonly property real entry:1-Math.pow(1-Stage.clamp(before/(spec.row&&spec.row.lean?.6:.55)),2)
                readonly property real duration:Math.min(.9,Math.max(.2,(Number(spec.word.endMs)-Number(spec.word.startMs))/1000))
                readonly property real swell:since<0?0:since<=duration?Math.sin(since/duration*Math.PI):.25*Stage.clamp((since-duration)/(duration*1.2))
                readonly property var motion:Stage.wordState(spec.word,spec.shape,stage.renderPositionMs)
                readonly property real rowSince:(stage.renderPositionMs-Number(spec.first||0)+80)/1000
                readonly property real rowEntry:Stage.spring(rowSince)
                readonly property bool tilt:spec.kind==="tilt"
                readonly property bool steps:spec.kind==="steps"
                readonly property real rowX:steps?Number(spec.row.x)+(spec.row.left?-40:40)*(1-rowEntry):0
                readonly property real rowScale:steps&&!stage.reduced?.85+.15*rowEntry:1
                x:(steps?spec.row.center+(spec.x-spec.row.center)*rowScale:spec.x)+(stage.reduced?0:tilt?0:motion.x)+rowX
                y:spec.y+(stage.reduced?0:tilt?(spec.row.lean?24:20)*(1-entry)+(spec.row.lean?(spec.order%2===0?-1:1)*spec.size/6*(2-shown):0):motion.y)
                width:spec.width;height:spec.size*1.5
                rotation:stage.reduced||tilt?0:motion.rotate
                scale:stage.reduced?1:tilt?(1+swell*(spec.row.lean?.18:.15))*(spec.row.lean?.92+.08*entry:1):motion.scale*(steps?.85+.15*rowEntry:1)
                opacity:stage.reduced?1:tilt?entry*shown:motion.opacity*(steps?Stage.clamp(rowSince/.1):1)
                Loader {
                    objectName:"stageWordSparks";z:1;anchors.centerIn:parent;width:word.width;height:word.height
                    active:stage.sparks&&!stage.reduced&&word.since>=0&&word.since<.6
                    sourceComponent:Item {
                        readonly property real t:Stage.clamp(word.since/.6)
                        readonly property real reach:Math.max(width,height)*.75*(word.spec.shape.last?1.6:1)
                        readonly property real out:1-Math.pow(1-t,3)
                        Repeater {
                            model:word.spec.shape.last?16:9
                            delegate:Rectangle {
                                required property int index
                                readonly property real angle:2*Math.PI*(index+Stage.random(Number(word.spec.word.startMs),index)*.7)/(word.spec.shape.last?16:9)
                                readonly property real dx:Math.cos(angle)
                                readonly property real dy:Math.sin(angle)
                                readonly property real edge:parent.width*.35*Math.abs(dx)+parent.height*.35*Math.abs(dy)
                                readonly property real head:edge+parent.reach*(.55+.45*Stage.random(Number(word.spec.word.startMs),index+50))*parent.out
                                readonly property real tail:Math.max(edge,head-parent.reach*.3*(1-parent.t))
                                x:parent.width/2+dx*tail;y:parent.height/2+dy*tail-height/2
                                width:Math.max(0,head-tail);height:.8+1.6*(1-parent.t)
                                rotation:angle*180/Math.PI;transformOrigin:Item.Left
                                color:Qt.rgba(stage.accent.r+(1-stage.accent.r)*.6*(1-parent.t),stage.accent.g+(1-stage.accent.g)*.6*(1-parent.t),stage.accent.b+(1-stage.accent.b)*.6*(1-parent.t),.9*Math.pow(1-parent.t,2))
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn:parent
                    text:word.spec.word.text||""
                    font.family:rhineFontFamily;font.pixelSize:Math.round(word.spec.size)
                    font.weight:word.tilt?(word.spec.row.lean?Font.Light:Font.Normal):Font.ExtraBold;font.variableAxes:({"wght":word.tilt?(word.spec.row.lean?Font.Light:Font.Normal):Font.ExtraBold})
                    font.italic:word.tilt&&word.spec.row.lean
                    color:word.tilt&&word.spec.row.lean?stage.accent:"white"
                    opacity:word.tilt||stage.reduced?1:word.motion.ink
                    layer.enabled:!stage.reduced&&!word.tilt&&(word.motion.glow>.01||word.motion.blur>.3)
                    layer.effect:MultiEffect {
                        blurEnabled:word.motion.blur>.3;blurMax:16;blur:Math.max(0,word.motion.blur/16)
                        shadowEnabled:word.motion.glow>.01;shadowColor:Qt.rgba(stage.accent.r,stage.accent.g,stage.accent.b,.85*word.motion.glow)
                        shadowBlur:1;shadowHorizontalOffset:0;shadowVerticalOffset:0
                    }
                }
            }
        }
    }
    Line {anchors.fill:parent;lyricLine:stage.previous;fade:stage.previousFade;visible:fade>0&&!!lyricLine.text}
    Line {anchors.fill:parent;lyricLine:stage.current;visible:!stage.interlude}
    Row {
        anchors.centerIn:parent;spacing:18;visible:stage.interlude&&stage.lines.length>0
        Repeater {model:3;Rectangle {required property int index;width:16;height:16;radius:8;color:"white";opacity:.2+.7*Stage.clamp(stage.breakProgress*3-index);scale:stage.reduced?1:1+.12*Math.sin(stage.renderPositionMs/420)}}
    }
    Column {
        id:stageFooter
        anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.bottomMargin:24;spacing:8
        Text {width:parent.width;visible:stage.translation&&!!text;text:stage.current.translation||"";horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;color:"#b8ffffff";font.family:rhineFontFamily;font.pixelSize:18;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})}
        Text {width:parent.width;text:stage.next;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;color:"#52ffffff";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14}
    }
    Text {anchors.centerIn:parent;visible:!stage.lines.length;text:"暂无同步歌词";font.family:rhineFontFamily;font.pixelSize:28;font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold});color:"#70ffffff"}
}
