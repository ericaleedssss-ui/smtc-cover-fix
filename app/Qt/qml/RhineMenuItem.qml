import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.MenuItem {
    id:entry
    property real unit:menu&&menu.unit!==undefined?menu.unit:1
    property bool dark:menu&&menu.dark!==undefined?menu.dark:rhine.state.dark===true
    implicitWidth:(RhineTheme.menuWidth-12)*unit;implicitHeight:RhineTheme.menuRowHeight*unit
    leftPadding:(checkable?34:12)*unit;rightPadding:12*unit
    font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*unit
    opacity:enabled?1:.4
    contentItem:Text {text:entry.text;font:entry.font;color:RhineTheme.ink(entry.dark);verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
    indicator:Text {x:10*entry.unit;anchors.verticalCenter:parent.verticalCenter;width:18*entry.unit;text:entry.checked?"✓":"";color:entry.dark?"#b4c6a5":"#6f8562";font.pixelSize:15*entry.unit;visible:entry.checkable}
    background:Rectangle {radius:RhineTheme.rowRadius*entry.unit;color:entry.down?(RhineTheme.press(entry.dark)):entry.highlighted||entry.hovered||entry.visualFocus?(RhineTheme.hover(entry.dark)):"transparent";border.width:entry.visualFocus?1:0;border.color:entry.dark?"#80927a":"#82957a";Behavior on color {ColorAnimation {duration:RhineTheme.duration(100)}}}
}
