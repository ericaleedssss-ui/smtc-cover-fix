import QtQuick

// Small cached vector drawing. Repaint only on size/theme changes; animation
// transforms the cached image, never redraws paths on each playback frame.
Item {
    id:arm
    property bool playing:false
    property bool reduced:false
    property bool dark:false
    readonly property real pivotX:width*86/120
    readonly property real pivotY:height*22/250
    property real armAngle:playing?0:-12
    Behavior on armAngle {enabled:arm.visible&&!arm.reduced;NumberAnimation {duration:280;easing.type:Easing.OutCubic}}
    transform:Rotation {origin.x:arm.pivotX;origin.y:arm.pivotY;angle:arm.armAngle}
    Canvas {
        id:surface;objectName:"nowTonearmSurface";anchors.fill:parent
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        Connections {target:arm;function onDarkChanged(){surface.requestPaint();}}
        onPaint:{
            var c=getContext("2d");c.reset();c.scale(width/120,height/250);
            function shaft(){c.beginPath();c.moveTo(86,31);c.bezierCurveTo(86,82,80,126,65,161);c.bezierCurveTo(58,178,49,191,44,204);}
            function rounded(x,y,w,h,r){c.beginPath();c.moveTo(x+r,y);c.lineTo(x+w-r,y);c.quadraticCurveTo(x+w,y,x+w,y+r);c.lineTo(x+w,y+h-r);c.quadraticCurveTo(x+w,y+h,x+w-r,y+h);c.lineTo(x+r,y+h);c.quadraticCurveTo(x,y+h,x,y+h-r);c.lineTo(x,y+r);c.quadraticCurveTo(x,y,x+r,y);c.closePath();}
            c.lineCap="round";c.lineJoin="round";
            // Three soft contact-shadow widths under the raised metal shaft.
            c.save();c.translate(4,7);
            for(var j=0;j<3;j++){shaft();c.lineWidth=20-j*5;c.strokeStyle=["rgba(55,48,39,.035)","rgba(55,48,39,.065)","rgba(55,48,39,.13)"][j];c.stroke();}
            c.beginPath();c.arc(86,22,20,0,Math.PI*2);c.fillStyle="rgba(55,48,39,.15)";c.fill();
            c.save();c.translate(44,211);c.rotate(.38);rounded(-13,-23,26,46,5);c.fill();c.restore();c.restore();
            // Thin darker underside, satin body and a narrow offset highlight.
            shaft();c.lineWidth=12;c.strokeStyle=arm.dark?"#999990":"#aaa89e";c.stroke();
            var metal=c.createLinearGradient(38,80,91,85);metal.addColorStop(0,"#bbb9b0");metal.addColorStop(.36,"#f8f7f0");metal.addColorStop(.56,"#fffef8");metal.addColorStop(1,"#cbc9bf");
            shaft();c.lineWidth=9;c.strokeStyle=metal;c.stroke();
            c.save();c.translate(-1.5,-1);shaft();c.lineWidth=2;c.strokeStyle="rgba(255,255,251,.9)";c.stroke();c.restore();
            // Raised pivot: contact rim, radial bevel, spindle and specular lip.
            c.beginPath();c.arc(86,22,20,0,Math.PI*2);c.fillStyle="#a8a69c";c.fill();
            var hub=c.createRadialGradient(80,15,1,86,22,20);hub.addColorStop(0,"#fffef7");hub.addColorStop(.65,"#e9e7dd");hub.addColorStop(.88,"#c9c7bc");hub.addColorStop(1,"#aaa89e");
            c.beginPath();c.arc(86,21,19,0,Math.PI*2);c.fillStyle=hub;c.fill();c.strokeStyle="rgba(255,255,249,.85)";c.lineWidth=1;c.stroke();
            c.beginPath();c.arc(86,21,5,0,Math.PI*2);c.fillStyle="#c2c0b5";c.fill();
            c.beginPath();c.arc(84.5,19.5,2,0,Math.PI*2);c.fillStyle="#efeee6";c.fill();
            // Connector sleeve and rounded cartridge with two recessed seams.
            c.save();c.translate(44,211);c.rotate(.38);
            rounded(-6,-32,12,17,3);c.fillStyle="#b3b1a7";c.fill();
            var shell=c.createLinearGradient(-13,0,13,0);shell.addColorStop(0,"#bcbab0");shell.addColorStop(.22,"#f7f6ed");shell.addColorStop(.65,"#fffef6");shell.addColorStop(1,"#d1cfc3");
            rounded(-13,-22,26,44,5);c.fillStyle=shell;c.fill();c.lineWidth=1;c.strokeStyle="#d0cec3";c.stroke();
            for(var k=0;k<2;k++){rounded(-8,-13+k*23,16,2.5,1);c.fillStyle="#c8c6bb";c.fill();}
            rounded(-2,21,4,7,1);c.fillStyle="#8b8a80";c.fill();c.restore();
        }
    }
}
