import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

Controls.Menu {
    id:menu
    property real unit:1
    property bool dark:rhine.state.dark===true
    readonly property bool noMotion:RhineTheme.noMotion
    popupType:Controls.Popup.Item
    modal:true;dim:false;focus:true
    closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
    height:Math.min(implicitHeight,contentItem.Window.window?contentItem.Window.window.height-16:implicitHeight)
    padding:6*unit
    margins:8
    font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*unit
    delegate:RhineMenuItem {unit:menu.unit;dark:menu.dark}
    background:Item {
        implicitWidth:RhineTheme.menuWidth*menu.unit
        Rectangle {anchors.fill:parent;radius:20*menu.unit;color:RhineTheme.surface(menu.dark);border.width:.5;border.color:menu.dark?"#24ffffff":"#1a000000"}
        PopupGlass {anchors.fill:parent;popup:menu;unit:menu.unit;dark:menu.dark;radius:20*menu.unit;frosting:.85;tint:.86;refraction:0;rimStrength:0;opacity:.5}
    }
    enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:menu.noMotion?0:130}}
    exit:Transition {NumberAnimation {property:"opacity";to:0;duration:menu.noMotion?0:100}}
}
