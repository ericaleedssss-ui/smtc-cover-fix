import QtQuick
import QtQuick.Controls.Basic as Controls

RhinePopup {
    id:picker
    objectName:"desktopSettingsColorMenu"
    property color initialColor:"white"
    property real hue:0
    property real saturation:0
    property real brightness:1
    readonly property color pickedColor:Qt.hsva(hue,saturation,brightness,1)
    signal applied(color value)
    width:Math.min(360,parent?parent.width-32:360)
    anchors.centerIn:parent
    modal:true;dim:true;padding:20
    onOpened:{hue=Math.max(0,initialColor.hsvHue);saturation=initialColor.hsvSaturation;brightness=initialColor.hsvValue;hex.text=initialColor.toString();hex.forceActiveFocus();}
    function syncHex(){hex.text=pickedColor.toString();}
    function accept(){if(hex.acceptableInput){applied(Qt.color(hex.text));close();}}
    contentItem:Column {
        spacing:14
        Text {text:picker.title||"选择颜色";font.family:rhineFontFamily;font.pixelSize:18;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});color:picker.dark?"white":"#1d1d1f"}
        Rectangle {
            id:plane;objectName:"colorSaturationValue";width:parent.width;height:150;color:Qt.hsva(picker.hue,1,1,1);clip:true;radius:8
            Rectangle {anchors.fill:parent;radius:8;gradient:Gradient {orientation:Gradient.Horizontal;GradientStop {position:0;color:"white"}GradientStop {position:1;color:"#00ffffff"}}}
            Rectangle {anchors.fill:parent;radius:8;gradient:Gradient {GradientStop {position:0;color:"transparent"}GradientStop {position:1;color:"black"}}}
            Rectangle {x:picker.saturation*parent.width-width/2;y:(1-picker.brightness)*parent.height-height/2;width:12;height:12;radius:6;color:"transparent";border.color:"white";border.width:2}
            MouseArea {anchors.fill:parent;function update(event){picker.saturation=Math.max(0,Math.min(1,event.x/width));picker.brightness=1-Math.max(0,Math.min(1,event.y/height));picker.syncHex();}onPressed:function(event){update(event);}onPositionChanged:function(event){if(pressed)update(event);}}
        }
        Controls.Slider {id:hueControl;objectName:"colorHue";width:parent.width;height:26;from:0;to:1;value:picker.hue;Accessible.name:"色相";onMoved:{picker.hue=value;picker.syncHex();}
            background:Rectangle {x:hueControl.leftPadding;y:(parent.height-height)/2;width:hueControl.availableWidth;height:12;radius:6;gradient:Gradient {orientation:Gradient.Horizontal;GradientStop {position:0;color:"red"}GradientStop {position:.167;color:"yellow"}GradientStop {position:.333;color:"lime"}GradientStop {position:.5;color:"cyan"}GradientStop {position:.667;color:"blue"}GradientStop {position:.833;color:"magenta"}GradientStop {position:1;color:"red"}}}
            handle:Rectangle {x:hueControl.leftPadding+hueControl.visualPosition*(hueControl.availableWidth-width);y:(hueControl.height-height)/2;width:18;height:18;radius:9;color:Qt.hsva(picker.hue,1,1,1);border.width:2;border.color:"white"}
        }
        Row {spacing:10
            Rectangle {width:36;height:36;radius:8;color:hex.acceptableInput?Qt.color(hex.text):picker.pickedColor;border.width:1;border.color:picker.dark?"#40ffffff":"#30000000"}
            Controls.TextField {id:hex;objectName:"colorHex";width:plane.width-46;height:36;selectByMouse:true;maximumLength:7;font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14;color:picker.dark?"white":"#1d1d1f";Accessible.name:"HEX 颜色";validator:RegularExpressionValidator {regularExpression:/#[0-9a-fA-F]{6}/}
                background:Rectangle {radius:8;color:picker.dark?"#12ffffff":"#09000000";border.width:hex.activeFocus?1:0;border.color:hex.acceptableInput?"#879b7b":"#d55e6a"}
                onEditingFinished:if(acceptableInput){var c=Qt.color(text);picker.hue=Math.max(0,c.hsvHue);picker.saturation=c.hsvSaturation;picker.brightness=c.hsvValue;}
                onAccepted:picker.accept()
            }
        }
        Row {anchors.right:parent.right;spacing:8
            RhineButton {text:"取消";onClicked:picker.close()}
            RhineButton {objectName:"colorApply";text:"应用颜色";primary:true;enabled:hex.acceptableInput;onClicked:picker.accept()}
        }
    }
    property string title:""
}
