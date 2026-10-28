import QtQuick
import QtQuick.Controls.Basic as Controls
Item {
    id: tools
    required property Item background
    property real unit:1
    readonly property real u:Math.max(.9,unit)
    visible:rhine.state.mode!=="boot" && rhine.state.viewer!==true
    component Tool: Rectangle {
        property string iconName
        property string label
        property string action
        width:48*tools.u; height:48*tools.u; radius:height/2
        color:mouse.containsMouse ? (rhine.state.dark ? "#284f6344" : "#16677c58") : "transparent"
        Behavior on color {ColorAnimation {duration:100}}
        RhineIcon {anchors.centerIn:parent;width:23*tools.u;height:width;name:parent.iconName;color:rhine.state.dark?"#e8eadd":"#384333"}
        Controls.ToolTip.visible:mouse.containsMouse
        Controls.ToolTip.delay:500
        Controls.ToolTip.text:label
        MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:rhine.action(parent.action)}
    }
    Item {
        x:28*tools.u;y:25*tools.u;width:48*tools.u;height:width
        objectName:"globalBack"
        visible:rhine.state.mode==="detail" || rhine.state.directoryOpen===true || !!rhine.state.modal
        LiquidGlass {anchors.fill:parent;background:tools.background;sampleX:parent.x;sampleY:parent.y;uiScale:tools.u;radius:height/2;dark:rhine.state.dark===true}
        Tool {iconName:"back";label:"返回";action:"back"}
    }
    Item {
        x:tools.width-width-28*tools.u;y:25*tools.u;width:168*tools.u;height:56*tools.u
        LiquidGlass {anchors.fill:parent;background:tools.background;sampleX:parent.x;sampleY:parent.y;uiScale:tools.u;radius:height/2;dark:rhine.state.dark===true}
        Row {anchors.centerIn:parent;spacing:4*tools.u
            Tool {objectName:"globalSearch";iconName:"search";label:"搜索";action:"search"}
            Tool {objectName:"globalLibrary";iconName:"music";label:"我的音乐";action:"saved"}
            Tool {objectName:"globalSettings";iconName:"settings";label:"设置";action:"settings"}
        }
    }
}
