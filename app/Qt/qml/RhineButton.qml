import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Button {
    id:button
    property real unit:1
    property bool dark:rhine.state.dark===true
    property bool primary:false
    property bool destructive:false
    readonly property color ink:RhineTheme.ink(dark)
    readonly property bool noMotion:RhineTheme.noMotion
    implicitHeight:RhineTheme.controlHeight*unit
    implicitWidth:Math.max(76*unit,implicitContentWidth+32*unit)
    leftPadding:16*unit;rightPadding:16*unit;topPadding:8*unit;bottomPadding:8*unit
    hoverEnabled:true;focusPolicy:Qt.StrongFocus
    font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*unit
    contentItem:Text {text:button.text;font:button.font;opacity:button.enabled?1:.4;color:button.primary?"#fffdf7":button.destructive?(button.dark?"#f0aaa3":"#aa4643"):button.ink;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
    background:Rectangle {
        radius:RhineTheme.controlRadius*button.unit
        color:button.primary?(button.destructive?"#a54c48":button.dark?"#637555":"#6f8562"):button.down?(button.dark?"#30ffffff":"#20000000"):button.hovered||button.visualFocus?(button.dark?"#20ffffff":"#10000000"):(button.dark?"#10ffffff":"#0a000000")
        opacity:button.enabled?1:.45;border.width:button.visualFocus?1:0;border.color:button.dark?"#b4c6a5":"#6f8562"
        Behavior on color {ColorAnimation {duration:button.noMotion?0:120}}
    }
    HoverHandler {cursorShape:button.enabled?Qt.PointingHandCursor:Qt.ArrowCursor}
}
