import QtQuick
import QtQuick.Controls.Basic as Controls
Item {
    id:heart
    required property bool liked
    property bool pending:false
    property real unit:1
    signal toggled()
    width:32*unit;height:32*unit
    opacity:pending?.55:1
    Image {objectName:"songHeartIcon";anchors.centerIn:parent;width:24*heart.unit;height:width;source:heart.liked?"qrc:/icons/song-like-on.png":"qrc:/icons/song-like-off.png";fillMode:Image.PreserveAspectFit;smooth:true;sourceSize.width:64;sourceSize.height:64}

    Controls.ToolTip.visible:mouse.containsMouse
    Controls.ToolTip.delay:450
    Controls.ToolTip.text:pending?"正在同步…":liked?"取消喜欢":"喜欢"
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;enabled:!heart.pending;cursorShape:Qt.PointingHandCursor;onClicked:heart.toggled()}
}
