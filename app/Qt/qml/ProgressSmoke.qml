// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_player.go drawSmoke; deterministic wisps, Qt Canvas adapter.
import QtQuick
import "StageLayout.js" as Stage
Canvas {
    id:smoke
    property real head:0
    property real bass:0
    property bool playing:false
    property color ink:"#cbd9e5"
    property real time:0
    renderTarget:Canvas.Image
    FrameAnimation {running:smoke.visible&&smoke.playing;onTriggered:{smoke.time+=Math.min(frameTime,.05);smoke.requestPaint();}}
    onPlayingChanged:requestPaint()
    onVisibleChanged:requestPaint()
    onHeadChanged:requestPaint()
    onPaint:{
        var p=getContext("2d");p.clearRect(0,0,width,height);if(!playing)return;
        var interval=1.4/36, first=Math.floor(time/interval), cy=height-12;
        for(var j=0;j<36;++j){var k=first-j,age=time-k*interval;if(age<0||age>1.4||Stage.random(k,5)>.6+.4*bass)continue;
            var f=age/1.4,x=head-age*(12+22*Stage.random(k,1)),y=cy-age*(12+18*Stage.random(k,2))+Math.sin(age*(2.5+2*Stage.random(k,3))+Stage.random(k,4)*2*Math.PI)*6*f;
            var size=3+f*(12+10*Stage.random(k,4)),alpha=.5*Math.pow(1-f,1.4)*(.75+.5*bass);
            var g=p.createRadialGradient(x,y,0,x,y,size);g.addColorStop(0,Qt.rgba(ink.r,ink.g,ink.b,alpha));g.addColorStop(1,"transparent");p.fillStyle=g;p.fillRect(x-size,y-size,size*2,size*2);
        }
    }
}
