import QtQuick
import QtQuick.Controls.Basic as Controls
Item {
    id:heart
    required property bool liked
    property bool pending:false
    property bool known:true
    property real unit:1
    signal toggled()
    width:32*unit;height:32*unit
    opacity:pending?.55:1
    Image {visible:heart.known;objectName:"songHeartIcon";anchors.centerIn:parent;width:24*heart.unit;height:width;source:heart.liked?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png";fillMode:Image.PreserveAspectFit;smooth:true;sourceSize.width:64;sourceSize.height:64}

    Text {anchors.centerIn:parent;visible:!heart.known;text:"…";color:"#87917d";font.pixelSize:15*heart.unit}
    Controls.ToolTip.visible:mouse.containsMouse
    Controls.ToolTip.delay:450
    Controls.ToolTip.text:!known?(pending?"正在读取喜欢状态…":"喜欢状态暂不可用，点击重试"):pending?"正在同步…":liked?"取消喜欢":"喜欢"
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;enabled:!heart.pending;cursorShape:Qt.PointingHandCursor;onClicked:heart.toggled()}
}
