import QtQuick
import QtQuick.Controls.Basic as Controls
FocusScope {
    id:search
    required property var controller
    property real unit:1
    property bool dark:false
    property bool expanded:false
    property bool syncing:false
    property string boundSession:""
    signal editing()
    readonly property string keyword:field.text
    width:(expanded?244:94)*unit;height:38*unit
    objectName:"playlistSearch"
    Behavior on width {NumberAnimation {duration:rhine.state.reduced?0:190;easing.type:Easing.OutCubic}}
    function restoreSession(){
        if(boundSession===String(controller.session||""))return;
        syncing=true;boundSession=String(controller.session||"");field.text=controller.query||"";
        expanded=field.text.length>0;field.focus=false;syncing=false;
    }
    function open(){expanded=true;field.forceActiveFocus();}
    Component.onCompleted:restoreSession()
    Connections {target:search.controller;function onChanged(){search.restoreSession();}}
    Rectangle {anchors.fill:parent;radius:height/2;color:search.dark?"#403a4132":"#58ffffff";border.width:1;border.color:field.activeFocus?"#8c9e7b":"#406d7d5d"}
    RhineIcon {x:13*search.unit;anchors.verticalCenter:parent.verticalCenter;width:17*search.unit;height:width;name:"search";color:search.dark?"#c0c9b6":"#7e8775"}
    Text {x:37*search.unit;anchors.verticalCenter:parent.verticalCenter;text:"搜索";visible:!search.expanded;color:search.dark?"#c0c9b6":"#7e8775";font.family:rhineFontFamily;font.pixelSize:13*search.unit}
    MouseArea {anchors.fill:parent;visible:!search.expanded;cursorShape:Qt.PointingHandCursor;onClicked:search.open()}
    TextInput {
        id:field;objectName:"playlistSearchInput"
        x:37*search.unit;width:parent.width-72*search.unit;height:parent.height
        visible:search.expanded;verticalAlignment:Text.AlignVCenter;clip:true;selectByMouse:true
        color:search.dark?"#e4e8db":"#30392e";font.family:rhineFontFamily;font.pixelSize:13*search.unit
        // No binding from a delayed backend value to an actively edited buffer.
        // All edits, paste, deletion and clear are sent synchronously; no timer
        // can survive a page change and overwrite the following search.
        onTextChanged:if(!search.syncing){search.editing();search.controller.search(text);}
        onActiveFocusChanged:if(!activeFocus&&!text.length)search.expanded=false
        Keys.onEscapePressed:function(event){focus=false;if(!text.length)search.expanded=false;event.accepted=true;}
        Text {anchors.fill:parent;verticalAlignment:Text.AlignVCenter;text:"在歌单中搜索…";visible:!field.text.length;color:search.dark?"#a3ad97":"#7e8775";font:field.font}
    }
    Item {objectName:"playlistSearchClear";visible:search.expanded&&field.text.length>0;anchors.right:parent.right;anchors.rightMargin:8*search.unit;anchors.verticalCenter:parent.verticalCenter;width:28*search.unit;height:width
        RhineIcon {anchors.centerIn:parent;width:14*search.unit;height:width;name:"close";color:search.dark?"#c0c9b6":"#7e8775"}
        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{field.text="";field.forceActiveFocus();}}
    }
}
