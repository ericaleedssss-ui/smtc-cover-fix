import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.AbstractButton {
    id:heart
    required property bool liked
    property bool pending:false
    property bool known:true
    property real unit:1
    readonly property bool dark:rhine.state.dark===true
    width:32*unit;height:32*unit
    enabled:!pending
    hoverEnabled:true
    Accessible.name:!known?"重新读取喜欢状态":liked?"取消喜欢":"喜欢"
    Accessible.role:Accessible.CheckBox
    Accessible.checkable:true
    Accessible.checked:liked
    onClicked:toggled()
    opacity:pending?.55:1
    background:Rectangle {radius:height/2;color:heart.down?RhineTheme.press(heart.dark):heart.hovered||heart.visualFocus?RhineTheme.hover(heart.dark):"transparent";border.width:heart.visualFocus?1:0;border.color:RhineTheme.muted(heart.dark)}
    contentItem:Item {RhineIcon {visible:heart.known;objectName:"songHeartIcon";anchors.centerIn:parent;width:22*heart.unit;height:width;name:"cloudyHeart";filled:heart.liked;color:heart.liked?"#ef6575":RhineTheme.muted(heart.dark)}}

    Text {anchors.centerIn:parent;visible:!heart.known;text:"…";color:"#87917d";font.pixelSize:15*heart.unit}
    RhineToolTip {visible:heart.hovered;delay:450;text:!parent.known?(parent.pending?"正在读取喜欢状态…":"喜欢状态暂不可用，点击重试"):parent.pending?"正在同步…":parent.liked?"取消喜欢":"喜欢"}
    HoverHandler {cursorShape:Qt.PointingHandCursor}
}
