import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Popup {
    id:pane
    property real unit:1
    property bool dark:rhine.state.dark===true
    property real cornerRadius:20*unit
    readonly property bool noMotion:RhineTheme.noMotion
    readonly property bool fullMotion:!noMotion&&rhine.visualPreferences.motion==="full"
    parent:Controls.Overlay.overlay
    popupType:Controls.Popup.Item
    padding:16*unit;focus:true
    closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
    background:Item {
        Rectangle {anchors.fill:parent;radius:pane.cornerRadius;color:RhineTheme.surface(pane.dark)}
        PopupGlass {anchors.fill:parent;popup:pane;unit:pane.unit;dark:pane.dark;radius:pane.cornerRadius;frosting:.85;tint:.86;refraction:0;rimStrength:0;opacity:.5}
    }
    enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:pane.noMotion?0:150}}
    exit:Transition {NumberAnimation {property:"opacity";to:0;duration:pane.noMotion?0:110}}
    Controls.Overlay.modal:Rectangle {color:"#40000000"}
}
