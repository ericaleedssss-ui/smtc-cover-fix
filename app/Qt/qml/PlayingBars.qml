// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_kit.go barState/step/group/drawBars and ui_pages.go nowPlayingBars.
import QtQuick

Item {
    id:bars
    objectName:"playingBars"
    property color color:"#738063"
    property bool live:rhine.nowPlaying.playback.playing===true
    property var levels:rhine.nowPlaying.playback.visualBands||[]
    property bool motionAllowed:RhineTheme.fullMotion
    property real unit:1
    property var smoothed:Array(24).fill(0)
    property var heights:[0,0,0,0]
    property real energy:0
    implicitWidth:16*unit;implicitHeight:14*unit
    function clear(){smoothed=Array(24).fill(0);heights=[0,0,0,0];energy=0;}
    onMotionAllowedChanged:if(!motionAllowed)clear()
    onVisibleChanged:if(!visible)clear()
    FrameAnimation {
        running:bars.visible&&bars.motionAllowed&&!RhineTheme.noMotion&&(bars.live||bars.energy>.01)
        onTriggered:{
            var dt=frameTime<=0||frameTime>.2?.016:frameTime,values=bars.smoothed.slice(),sum=0;
            for(var i=0;i<24;++i){var target=bars.live?Number(bars.levels[i]||0):0,k=target<values[i]?6:18;values[i]+=(target-values[i])*Math.min(1,k*dt);sum+=values[i];}
            var groups=[];for(var b=0;b<4;++b){var mean=0;for(var n=b*6;n<(b+1)*6;++n)mean+=values[n];mean/=6;groups.push(mean*mean*1.15);}
            bars.smoothed=values;bars.heights=groups;bars.energy=sum/24;
        }
    }
    Repeater {model:4
        Rectangle {
            required property int index
            objectName:"playingBar_"+index
            readonly property real gap:bars.width/4*.38
            width:(bars.width-gap*3)/4;x:index*(width+gap)
            height:Math.max(2.5*bars.unit,Math.min(bars.height,bars.height*Number(bars.heights[index])))
            anchors.verticalCenter:parent.verticalCenter;radius:width/2;color:bars.color
        }
    }
}
