import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

Controls.ComboBox {
    id:control
    property real unit:1
    property bool dark:rhine.state.dark===true
    implicitHeight:36*unit
    leftPadding:12*unit;rightPadding:32*unit
    font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:13*unit
    contentItem:Text {text:control.displayText;font:control.font;color:control.dark?"#eeece4":"#343c32";verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight;opacity:control.enabled?1:.4}
    indicator:RhineIcon {x:control.width-width-10*control.unit;anchors.verticalCenter:parent.verticalCenter;width:14*control.unit;height:width;name:"chevron";color:control.dark?"#c5c8bd":"#666f61";rotation:control.popup.visible?180:0}
    background:Rectangle {radius:10*control.unit;color:control.down?(control.dark?"#30ffffff":"#20000000"):control.hovered?(control.dark?"#20ffffff":"#14000000"):(control.dark?"#15ffffff":"#0a000000");border.width:control.visualFocus?1:0;border.color:control.dark?"#b4c6a5":"#6f8562"}
    delegate:RhineMenuItem {required property int index;unit:control.unit;dark:control.dark;width:list.width;text:control.textAt(index);checkable:true;checked:control.currentIndex===index;highlighted:control.highlightedIndex===index}
    popup:RhinePopup {
        id:choices;parent:control;unit:control.unit;dark:control.dark;focus:false
        y:control.height+5*unit
        width:Math.max(control.width,Math.min(300*unit,(control.Window.window?control.Window.window.width:400)-32))
        height:Math.min(list.contentHeight+12*unit,Math.max(80,(control.Window.window?control.Window.window.height:600)-32))
        padding:6*unit;margins:8;cornerRadius:16*unit
        contentItem:ListView {id:list;clip:true;implicitHeight:contentHeight;model:control.popup.visible?control.delegateModel:null;currentIndex:control.highlightedIndex;boundsBehavior:Flickable.StopAtBounds;Controls.ScrollBar.vertical:Controls.ScrollBar {}}
    }
}
