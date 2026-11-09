import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: page
    objectName: "desktopLyricsSettingsPage"
    required property var backend
    readonly property var settings: backend ? backend.desktopLyrics : ({})
    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: {
        if (fontOpen || colorTarget !== "") { fontOpen = false; colorTarget = ""; }
        else { backend.action("desktop:back"); }
    }
    readonly property string uiFont: "Rhine MiSans"
    readonly property color ink: "#30352b"
    readonly property color muted: "#797c6c"
    readonly property color accent: "#7b8263"
    readonly property color line: "#d4d1c3"
    property bool hoverPreview: true
    property bool fontOpen: false
    property string colorTarget: ""
    property real hue: 0.15
    property real saturation: 0.2
    property real brightness: 0.9
    readonly property color pickedColor: Qt.hsva(hue, saturation, brightness, 1)
    readonly property bool lightTone: settings.tone === "light"
    readonly property var palettes: [
        {key:"oat", name:"燕麦灰绿", primary:"#353b2b", secondary:"#68704c", background:"#f6ead4", lightPrimary:"#f6ead4", lightSecondary:"#d1d5b5"},
        {key:"rose", name:"奶油灰粉", primary:"#422b23", secondary:"#8b6264", background:"#efd8d6", lightPrimary:"#fff3eb", lightSecondary:"#e8c3c6"},
        {key:"sage", name:"鼠尾草米白", primary:"#34453e", secondary:"#6c786e", background:"#eeece0", lightPrimary:"#eeece0", lightSecondary:"#bfd3c8"}]
    color: "#faf7ef"
    border.color: line
    radius: 3
    function openColor(target) {
        fontOpen = false;
        colorTarget = target;
        var value = target === "primary" ? (settings.primaryColor || "#faf9ee") : target === "secondary" ? (settings.secondaryColor || "#dfdfcf") : (settings.backgroundColor || "#f5f0e4");
        hexInput.text = value;
        var c = Qt.color(value);
        hue = Math.max(0, c.hsvHue); saturation = c.hsvSaturation; brightness = c.hsvValue;
    }
    component Label: Text {
        color: page.ink
        font.family: page.uiFont;font.variableAxes:({"wght":400})
        font.pixelSize: 20
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
    component Action: Rectangle {
        property string label: ""
        property bool selected: false
        signal clicked()
        implicitWidth: 132
        implicitHeight: 40
        radius: 2
        color: selected ? page.accent : actionMouse.containsMouse ? "#eeeade" : "transparent"
        border.color: selected ? page.accent : page.line
        Label { anchors.centerIn: parent; text: parent.label; font.pixelSize: 18; color: parent.selected ? "#fffdf5" : page.ink }
        MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component FineSlider: Slider {
        id: slider
        background: Rectangle {
            x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - 2
            width: slider.availableWidth; height: 4; radius: 2; color: "#dedbcc"
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: page.accent }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 17; height: 17; radius: 9; color: page.accent
        }
    }
    // The input shield keeps editing inside this page; the playback bar remains outside it.
    MouseArea { anchors.fill: parent; onClicked: { page.fontOpen = false; page.colorTarget = ""; } onWheel: function(wheel) { wheel.accepted = true; } }
    Action { x: 40; y: 22; width: 180; label: "← 返回设置"; onClicked: page.backend.action("desktop:back") }
    Label { x: 242; y: 27; text: "桌面歌词"; font.pixelSize: 28; font.weight: Font.DemiBold ;font.variableAxes:({"wght":Font.DemiBold})}
    Label { x: 392; y: 37; text: "DESKTOP LYRICS"; color: page.muted; font.pixelSize: 13; font.letterSpacing: 2 }
    Action { x: parent.width - 330; y: 22; width: 132; label: page.settings.enabled ? "歌词已开启" : "开启歌词"; selected: page.settings.enabled === true; onClicked: page.backend.action("desktop:toggle") }
    Action { x: parent.width - 184; y: 22; width: 144; label: page.settings.locked ? "解除锁定" : "锁定位置"; onClicked: page.backend.action("desktop:lock") }
    Rectangle { x:40; y:78; width:parent.width-80; height:1; color:page.line }
    Label { x:40; y:96; text:"效果预览" }
    Row {
        x: page.width-308; y:91; spacing:0
        Action { width:134; label:"透明时"; selected:!page.hoverPreview; onClicked:page.hoverPreview=false }
        Action { width:134; label:"悬停时"; selected:page.hoverPreview; onClicked:page.hoverPreview=true }
    }
    Rectangle {
        id: previewStage
        objectName: "desktopSettingsPreview"
        x:40; y:143; width:parent.width-80; height:181
        color:"#e5dfd0"
        gradient: Gradient { orientation:Gradient.Horizontal; GradientStop { position:0; color:page.lightTone ? "#252a28" : "#e7dece" } GradientStop { position:0.5; color:page.lightTone ? "#303733" : "#f3eee3" } GradientStop { position:1; color:page.lightTone ? "#202725" : "#d8dfd5" } }
        Rectangle {
            anchors.centerIn:parent
            width:Math.min(parent.width-100, 950); height:142
            color:page.settings.backgroundColor || "#f5f0e4"
            opacity:page.hoverPreview ? page.settings.backgroundOpacity/100 : 0
            border.color:"#f8f5ec"; radius:8
        }
        Label { anchors.right:parent.right; anchors.rightMargin:Math.max(70,(parent.width-950)/2+20); y:24; text:"⠿   ♧   Aa   ×"; font.pixelSize:15; color:"#737863"; visible:page.hoverPreview }
        Column {
            anchors.centerIn:parent; width:parent.width-150; spacing:12
            Label {
                width:parent.width; horizontalAlignment:Text.AlignHCenter
                text: page.settings.primary && page.settings.primary !== "选择歌曲开始播放" ? page.settings.primary : "夜が明けるまで、ここにいて"
                font.family:!page.settings.font || page.settings.font === "MiSans" ? page.uiFont : page.settings.font; font.pixelSize:Math.min(42, Math.max(25,(page.settings.size || 26)*1.2)); font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold})
                color:(page.hoverPreview ? page.settings.hoverPrimaryColor : page.settings.primaryColor) || (page.hoverPreview ? "#30352b" : "#faf9ee")
                style:Text.Normal
            }
            Label {
                width:parent.width; horizontalAlignment:Text.AlignHCenter
                text:page.settings.secondary || "在天亮之前，请留在这里"
                font.family:!page.settings.font || page.settings.font === "MiSans" ? page.uiFont : page.settings.font;font.variableAxes:({"wght":400}); font.pixelSize:Math.min(31, Math.max(20,(page.settings.size || 26)*0.87))
                color:(page.hoverPreview ? page.settings.hoverSecondaryColor : page.settings.secondaryColor) || (page.hoverPreview ? "#68704c" : "#dfdfcf")
                style:Text.Normal
            }
        }
    }
    Label { x:40; y:344; text:"配色方案" }
    Label { x:172; y:349; width:page.width-520; text:page.lightTone ? "适合深色桌面 · 悬停时自动加深文字" : "适合浅色桌面"; color:page.muted; font.pixelSize:15 }
    Row {
        x:page.width-308; y:338; spacing:0
        Action { objectName:"desktopSettingsDarkTone"; width:134; label:"深色字"; selected:!page.lightTone; onClicked:page.backend.setDesktopTone("dark") }
        Action { objectName:"desktopSettingsLightTone"; width:134; label:"浅色字"; selected:page.lightTone; onClicked:page.backend.setDesktopTone("light") }
    }
    Row {
        x:40; y:381; width:parent.width-80; spacing:18
        Repeater {
            model:page.palettes
            delegate:Rectangle {
                required property var modelData
                readonly property color original: page.lightTone ? modelData.lightPrimary : modelData.primary
                readonly property color translation: page.lightTone ? modelData.lightSecondary : modelData.secondary
                readonly property bool chosen: page.settings.primaryColor === original.toString() && page.settings.secondaryColor === translation.toString() && page.settings.backgroundColor === modelData.background
                width:(page.width-80-54)/3; height:102; radius:2
                color:page.lightTone ? "#2a302d" : modelData.background; border.color:chosen ? page.accent : page.line; border.width:chosen ? 2 : 1
                Label { x:18; y:14; width:parent.width-70; text:modelData.name; color:parent.original; font.pixelSize:21; font.weight:Font.DemiBold ;font.variableAxes:({"wght":Font.DemiBold})}
                Label { x:18; y:47; width:parent.width-45; text:"在天亮之前，请留在这里"; color:parent.translation; font.pixelSize:17 }
                Row { x:18; y:80; spacing:7
                    Repeater { model:[parent.parent.original,parent.parent.translation,modelData.background]; delegate:Rectangle { required property string modelData; width:10; height:10; radius:5; color:modelData; border.color:"#30000000" } }
                }
                Label { anchors.right:parent.right; anchors.rightMargin:18; y:13; text:chosen ? "✓" : ""; color:page.lightTone ? "#d1d5b5" : page.accent }
                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:page.backend.applyDesktopPreset(modelData.key) }
            }
        }
    }
    Rectangle { x:40; y:502; width:parent.width-80; height:1; color:page.line }
    Label { x:40; y:527; text:"字体" }
    Action { id:fontButton; x:140; y:516; width:Math.min(380,page.width*0.27); label:(page.settings.font || "MiSans")+" ▾"; onClicked:{ page.colorTarget="";page.fontOpen=!page.fontOpen; } }
    Label { x:40; y:590; text:"字号" }
    Action { x:140; y:578; width:56; label:"−"; onClicked:page.backend.action("desktop:smaller") }
    Label { x:206; y:590; width:70; horizontalAlignment:Text.AlignHCenter; text:page.settings.size || 26 }
    Action { x:286; y:578; width:56; label:"+"; onClicked:page.backend.action("desktop:larger") }
    Label { x:40; y:644; text:"原文与译文使用同一字体"; color:page.muted; font.pixelSize:15 }
    Rectangle { x:page.width*0.47; y:520; width:1; height:147; color:page.line }
    Column {
        x:page.width*0.51; y:515; width:page.width*0.49-40; spacing:12
        Row { spacing:16
            Label { width:112; y:10; text:"原文颜色" }
            Action { width:Math.max(105,Math.min(166,(page.width*0.49-398)/2)); label:(page.settings.primaryColor || "自动明暗").toUpperCase(); onClicked:page.openColor("primary") }
            Rectangle { width:28; height:28; y:6; color:page.settings.primaryColor || "#faf9ee"; border.color:page.line }
            Label { width:94; y:10; text:"译文颜色"; font.pixelSize:18 }
            Action { width:Math.max(105,Math.min(166,(page.width*0.49-398)/2)); label:(page.settings.secondaryColor || "自动明暗").toUpperCase(); onClicked:page.openColor("secondary") }
            Rectangle { width:28; height:28; y:6; color:page.settings.secondaryColor || "#dfdfcf"; border.color:page.line }
        }
        Row { spacing:16
            Label { width:112; y:10; text:"悬停底色" }
            Action { width:Math.max(105,Math.min(166,(page.width*0.49-398)/2)); label:(page.settings.backgroundColor || "#f5f0e4").toUpperCase(); onClicked:page.openColor("background") }
            Rectangle { width:28; height:28; y:6; color:page.settings.backgroundColor || "#f5f0e4"; border.color:page.line }
        }
        Row { spacing:16
            Label { width:112; y:10; text:"底色透明度"; font.pixelSize:18 }
            FineSlider { width:Math.min(330,page.width*0.20); height:40; from:0;to:100;stepSize:1;value:100-page.settings.backgroundOpacity; onMoved:page.backend.setDesktopOpacity(100-Math.round(value)) }
            Label { y:10; text:(100-page.settings.backgroundOpacity)+"%"; color:page.muted }
        }
    }
    Rectangle { x:40; y:685; width:parent.width-80; height:1; color:page.line }
    Label { x:40; y:704; text:"修改即时生效，自动保存"; color:page.muted; font.pixelSize:16 }
    Action { x:parent.width-192; y:696; width:152; label:"恢复默认"; onClicked:page.backend.action("desktop:reset") }
    Rectangle {
        id:fontMenu
        objectName:"desktopSettingsFontMenu"
        visible:page.fontOpen; z:10; x:fontButton.x; y:240; width:fontButton.width; height:270
        color:"#faf7ef"; border.color:page.line; radius:3
        MouseArea { anchors.fill:parent }
        Rectangle { x:12;y:12;width:parent.width-24;height:40;color:"#eeeade"
            TextInput { id:fontSearch; anchors.fill:parent;anchors.margins:8;color:page.ink;font.pixelSize:18;clip:true;selectByMouse:true }
            Label { anchors.fill:fontSearch; text:"搜索已安装字体";color:page.muted;font.pixelSize:18;visible:!fontSearch.text && !fontSearch.activeFocus }
        }
        ListView {
            id:fontList; x:10;y:62;width:parent.width-20;height:198;clip:true
            model:page.fontOpen ? page.backend.desktopFonts().filter(function(name){return name.toLowerCase().indexOf(fontSearch.text.toLowerCase())>=0;}) : []
            delegate:Rectangle {
                required property string modelData
                width:fontList.width; height:40
                color:modelData===page.settings.font ? "#e5e5d7" : "transparent"
                Label { x:10;y:8;width:parent.width-20;text:modelData;font.family:modelData === "MiSans" ? page.uiFont : page.backend.preparedFont(modelData);font.variableAxes:({"wght":400});font.pixelSize:19 }
                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{page.backend.setDesktopFont(modelData);page.fontOpen=false;} }
            }
        }
    }
    Rectangle {
        id:colorMenu
        objectName:"desktopSettingsColorMenu"
        visible:page.colorTarget!==""; z:12
        x:page.width-width-40; y:213; width:380; height:290;color:"#faf7ef";border.color:page.line;radius:3
        MouseArea { anchors.fill:parent }
        Label { x:18;y:15;text:page.colorTarget==="primary"?"原文颜色":page.colorTarget==="secondary"?"译文颜色":"悬停底色";font.pixelSize:19 }
        Rectangle {
            x:18;y:50;width:parent.width-36;height:142;color:Qt.hsva(page.hue,1,1,1)
            Rectangle { anchors.fill:parent; gradient:Gradient { orientation:Gradient.Horizontal;GradientStop{position:0;color:"white"}GradientStop{position:1;color:"#00ffffff"} } }
            Rectangle { anchors.fill:parent; gradient:Gradient { GradientStop{position:0;color:"#00000000"}GradientStop{position:1;color:"black"} } }
            Rectangle { x:page.saturation*(parent.width-8);y:(1-page.brightness)*(parent.height-8);width:8;height:8;radius:4;color:"transparent";border.color:"white";border.width:2 }
            MouseArea { anchors.fill:parent;function updateColor(mouse){page.saturation=Math.max(0,Math.min(1,mouse.x/width));page.brightness=1-Math.max(0,Math.min(1,mouse.y/height));hexInput.text=page.pickedColor.toString();}onPressed:function(mouse){updateColor(mouse);}onPositionChanged:function(mouse){if(pressed)updateColor(mouse);} }
        }
        FineSlider { x:18;y:198;width:parent.width-36;height:28;from:0;to:1;value:page.hue;onMoved:{page.hue=value;hexInput.text=page.pickedColor.toString();} }
        Rectangle { x:18;y:237;width:184;height:36;color:"#eeeade";border.color:page.line
            TextInput { id:hexInput;anchors.fill:parent;anchors.margins:7;font.pixelSize:18;color:page.ink;selectByMouse:true;maximumLength:7;validator:RegularExpressionValidator{regularExpression:/#[0-9a-fA-F]{6}/} }
        }
        Action { x:220;y:235;width:142;label:"应用颜色";selected:true;onClicked:if(hexInput.acceptableInput){page.backend.setDesktopColor(page.colorTarget,hexInput.text);page.colorTarget="";} }
    }
}
