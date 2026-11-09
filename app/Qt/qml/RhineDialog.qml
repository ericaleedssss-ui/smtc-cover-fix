import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Dialog {
    id:dialog
    property real unit:1
    property bool dark:rhine.state.dark===true
    property string message:""
    property string confirmText:"确认"
    property string cancelText:"取消"
    property bool destructive:false
    readonly property bool noMotion:RhineTheme.noMotion
    parent:Controls.Overlay.overlay;popupType:Controls.Popup.Item
    anchors.centerIn:parent
    width:Math.min(420*unit,parent?parent.width-32:420*unit)
    padding:24*unit;spacing:18*unit
    modal:true;dim:true;focus:true
    closePolicy:Controls.Popup.CloseOnEscape
    onOpened:cancelButton.forceActiveFocus()
    background:Item {
        Rectangle {anchors.fill:parent;radius:20*dialog.unit;color:dialog.dark?"#232327":"#f6f6f8"}
        PopupGlass {anchors.fill:parent;popup:dialog;unit:dialog.unit;dark:dialog.dark;radius:20*dialog.unit;frosting:1;tint:.86;opacity:.5}
    }
    header:Text {text:dialog.title;color:dialog.dark?"#eeece4":"#343c32";font.family:rhineFontFamily;font.pixelSize:20*dialog.unit;font.weight:Font.DemiBold;font.variableAxes:({"wght":Font.DemiBold});wrapMode:Text.Wrap;leftPadding:dialog.leftPadding;rightPadding:dialog.rightPadding;topPadding:dialog.topPadding}
    contentItem:Text {text:dialog.message;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:dialog.dark?"#c5c8bd":"#666f61";font.family:rhineFontFamily;font.variableAxes:({"wght":400});font.pixelSize:14*dialog.unit;lineHeight:1.45}
    footer:Item {
        implicitHeight:36*dialog.unit+dialog.bottomPadding
        Row {anchors.right:parent.right;anchors.rightMargin:dialog.rightPadding;spacing:10*dialog.unit
            RhineButton {id:cancelButton;objectName:"dialogCancel";unit:dialog.unit;dark:dialog.dark;text:dialog.cancelText;onClicked:dialog.reject()}
            RhineButton {objectName:"dialogConfirm";unit:dialog.unit;dark:dialog.dark;text:dialog.confirmText;primary:true;destructive:dialog.destructive;onClicked:dialog.accept()}
        }
    }
    enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:dialog.noMotion?0:160}}
    exit:Transition {NumberAnimation {property:"opacity";to:0;duration:dialog.noMotion?0:110}}
    Controls.Overlay.modal:Rectangle {color:"#50000000"}
}
