import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

Window {
    id: lyricsWindow
    objectName: "desktopLyricsWindow"
    required property var backend
    readonly property var lyricState: backend ? backend.desktopLyrics : ({})
    readonly property bool locked: lyricState.locked === true
    readonly property color backingTint: lyricState.backgroundColor || "#101014"
    readonly property string styleName:lyricState.style||"outline"
    readonly property bool capsule:styleName==="dark"||styleName==="light"
    readonly property bool outlined:styleName==="outline"||styleName==="color"
    readonly property color coverTint:backend.nowPlaying.info.coverTint||"#787882"
    readonly property color lamp:coverTint.hsvSaturation>=.12?Qt.hsva(coverTint.hsvHue,Math.min(.8,Math.max(.5,coverTint.hsvSaturation)),.8,1):"#528a69"
    readonly property color lyricInk:lyricState.primaryColor||(styleName==="light"?mix(lamp,Qt.rgba(0,0,0,1),.25):styleName==="color"?mix(lamp,Qt.rgba(0,0,0,1),.1):mix(lamp,Qt.rgba(1,1,1,1),styleName==="dark"?.55:.45))
    readonly property color unsungInk:styleName==="light"?Qt.rgba(.078,.078,.094,.48):styleName==="color"?mix(lamp,Qt.rgba(1,1,1,1),.55):Qt.rgba(1,1,1,styleName==="outline"?1:styleName==="plain"?.62:.5)
    readonly property color secondaryInk:lyricState.secondaryColor||(styleName==="light"?Qt.rgba(.078,.078,.094,.6):styleName==="color"?mix(lamp,Qt.rgba(0,0,0,1),.2):Qt.rgba(1,1,1,styleName==="outline"?1:styleName==="plain"?.7:.62))
    readonly property real backingOpacity:lyricState.backgroundOpacity===undefined?.8:Math.max(0,Math.min(1,Number(lyricState.backgroundOpacity)/100))
    readonly property string lineIdentity:String(lyricState.primary||"")+":"+String((lyricState.words||[]).length?lyricState.words[0].startMs:"")
    onLineIdentityChanged:if(ready&&!lyricState.reduced)lineFade.restart()
    function escaped(value){return String(value).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");}
    function mix(a,b,k){return Qt.rgba(a.r+(b.r-a.r)*k,a.g+(b.g-a.g)*k,a.b+(b.b-a.b)*k,a.a+(b.a-a.a)*k);}
    function wordColor(word){
        var start=Number(word.startMs),end=Number(word.endMs),lit=Math.max(0,Math.min(1,(Number(lyricState.positionMs)-start)/Math.max(50,end-start)));
        return mix(unsungInk,lyricInk,lit);
    }
    function primaryText(){
        var words=lyricState.words||[];
        if(!words.length)return escaped(lyricState.primary||"选择歌曲开始播放");
        return words.map(function(word){return '<span style="color:'+wordColor(word).toString()+'">'+escaped(word.text)+'</span>';}).join("");
    }
    property real requestedX: -99999
    property real requestedY: -99999
    property bool ready: false
    transientParent: null
    title: "RHINE · 桌面歌词"
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | (locked ? Qt.WindowTransparentForInput : 0)
    visible: ready && lyricState.enabled === true
    width: lyricState.width || 800
    height: Math.max(132, lyricColumn.implicitHeight + 72)
    function positionFromSettings() {
        if (requestedX !== lyricState.x || requestedY !== lyricState.y) {
            requestedX = lyricState.x;
            requestedY = lyricState.y;
            x = lyricState.x || 0;
            y = lyricState.y || 0;
        }
    }
    Component.onCompleted: {
        backend.setDesktopWindow(lyricsWindow);
        positionFromSettings();
        ready = true;
    }
    onClosing: function(close) {
        close.accepted = false;
        backend.saveDesktopPosition(x, y);
        backend.action("desktop:close");
    }
    Connections {
        target: lyricsWindow.backend
        function onDesktopLyricsChanged() { lyricsWindow.positionFromSettings(); }
    }
    HoverHandler { id: hover; enabled: !lyricsWindow.locked }
    Rectangle {
        id: backing
        objectName: "desktopLyricsBacking"
        anchors.fill: parent
        anchors.margins: 6
        radius: 8
        anchors.topMargin:42
        color:lyricsWindow.styleName==="light"?Qt.rgba(.98,.98,.99,lyricsWindow.backingOpacity):lyricsWindow.styleName==="dark"?Qt.rgba(.063,.063,.078,lyricsWindow.backingOpacity):Qt.rgba(lyricsWindow.backingTint.r,lyricsWindow.backingTint.g,lyricsWindow.backingTint.b,lyricsWindow.backingOpacity)
        border.color: "#24ffffff"
        opacity: lyricsWindow.capsule?1:hover.hovered && !lyricsWindow.locked ? .7 : 0
        Behavior on opacity { NumberAnimation { duration: lyricsWindow.lyricState.reduced ? 0 : 120 } }
    }
    MouseArea {
        id: dragArea
        objectName: "desktopLyricsDrag"
        anchors.fill: parent
        enabled: !lyricsWindow.locked
        cursorShape: Qt.SizeAllCursor
        property point pressPoint
        property point windowPoint
        onPressed: function(mouse) {
            pressPoint = Qt.point(mouse.x, mouse.y);
            windowPoint = Qt.point(lyricsWindow.x, lyricsWindow.y);
        }
        onPositionChanged: function(mouse) {
            if (pressed) {
                lyricsWindow.x += mouse.x - pressPoint.x;
                lyricsWindow.y += mouse.y - pressPoint.y;
            }
        }
        onReleased: lyricsWindow.backend.saveDesktopPosition(lyricsWindow.x, lyricsWindow.y)
        onCanceled: lyricsWindow.backend.saveDesktopPosition(lyricsWindow.x, lyricsWindow.y)
    }
    Row {
        id: toolbar
        objectName: "desktopLyricsToolbar"
        anchors.top: parent.top
        anchors.topMargin: hover.hovered?8:14
        anchors.horizontalCenter:parent.horizontalCenter
        spacing: 4
        opacity: hover.hovered&&!lyricsWindow.locked?1:0
        scale:hover.hovered?1:.96
        Behavior on opacity {NumberAnimation {duration:lyricsWindow.lyricState.reduced?0:120}}
        Behavior on scale {enabled:!lyricsWindow.lyricState.reduced;SpringAnimation {spring:4.5;damping:.82;epsilon:.001}}
        Behavior on anchors.topMargin {enabled:!lyricsWindow.lyricState.reduced;SpringAnimation {spring:4.5;damping:.82;epsilon:.1}}
        visible: opacity > 0
        enabled: !lyricsWindow.locked && hover.hovered
        Repeater {
            model: [{label:"样式",icon:"disc",action:"style"},{label:"缩小",icon:"remove",action:"desktop:smaller"},{label:"放大",icon:"collect",action:"desktop:larger"},{label: "锁定",icon:"locate", action: "desktop:lock"}, {label: "设置",icon:"settings", action: "desktop:settings"}, {label: "关闭",icon:"close", action: "desktop:close"}]
            delegate: Rectangle {
                required property var modelData
                width: 32
                height: 28
                radius: 5
                color: toolMouse.pressed?"#dd555555":toolMouse.containsMouse ? "#cc404040" : "#bb292929"
                RhineIcon {
                    anchors.centerIn: parent
                    width:16;height:16;name:modelData.icon;color:"#eeeeee"
                }
                RhineToolTip {visible:toolMouse.containsMouse;text:modelData.label;delay:500}
                MouseArea {
                    id: toolMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        lyricsWindow.backend.saveDesktopPosition(lyricsWindow.x, lyricsWindow.y);
                        if(modelData.action==="style"){
                            var styles=["dark","light","outline","color","plain"];
                            lyricsWindow.backend.setPlayerPreference("desktop-lyrics-style",styles[(styles.indexOf(lyricsWindow.styleName)+1)%styles.length]);
                        }else lyricsWindow.backend.action(modelData.action);
                    }
                }
            }
        }
    }
    Column {
        id: lyricColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.top: parent.top
        anchors.topMargin: 46
        spacing: 9
        Text {
            id: currentLine
            objectName: "desktopLyricsPrimary"
            width: parent.width
            text: lyricsWindow.primaryText()
            textFormat: Text.RichText
            color:lyricsWindow.lyricInk
            font.family: !lyricsWindow.lyricState.font || lyricsWindow.lyricState.font === "MiSans" ? "Rhine MiSans" : lyricsWindow.lyricState.font
            font.pixelSize: lyricsWindow.lyricState.size || 26
            font.weight: Font.ExtraBold;font.variableAxes:({"wght":Font.ExtraBold})
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize * 1.35
            style: lyricsWindow.outlined?Text.Outline:Text.Normal
            styleColor:lyricsWindow.styleName==="color"?"#ffffff":"#d1000000"
            NumberAnimation { id: lineFade; target: currentLine; property: "opacity"; from: 0.45; to: 1; duration: 180 }
        }
        Text {
            objectName: "desktopLyricsSecondary"
            width: parent.width
            text: lyricsWindow.lyricState.secondary || ""
            textFormat: Text.PlainText
            color:lyricsWindow.secondaryInk
            font.family: !lyricsWindow.lyricState.font || lyricsWindow.lyricState.font === "MiSans" ? "Rhine MiSans" : lyricsWindow.lyricState.font
            font.pixelSize: Math.round((lyricsWindow.lyricState.size || 26) * 0.6)
            font.weight:Font.Bold;font.variableAxes:({"wght":Font.Bold})
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize * 1.4
            elide: Text.ElideRight
            style:lyricsWindow.outlined?Text.Outline:Text.Normal
            styleColor:lyricsWindow.styleName==="color"?"#ffffff":"#d1000000"
        }
    }
}
