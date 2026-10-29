import QtQuick
import QtQuick.Controls.Basic as Controls

// The existing column actions own ordering, selection and keyboard navigation.
Item {
    id:nav
    objectName:"archiveNavigator"
    required property var controller
    property var navigation:({})
    property real unit:1
    property real downOffset:-160*unit
    property bool dark:false
    property bool reduced:false
    readonly property int total:Number(navigation.total||0)
    readonly property int position:Math.max(1,Math.min(total,Number(navigation.index||1)))
    readonly property color ink:dark?"#dfe5d6":"#46503e"
    implicitWidth:254*unit
    implicitHeight:82*unit
    component Arrow:Controls.Button {
        id:button
        property string glyph
        property string actionName
        width:34*nav.unit;height:width
        focusPolicy:Qt.NoFocus
        hoverEnabled:true
        Accessible.name:glyph==="←"?"上一栏目":glyph==="→"?"下一栏目":"浏览下一项"
        onClicked:nav.controller.action(actionName)
        HoverHandler {cursorShape:Qt.PointingHandCursor}
        contentItem:Text {text:button.glyph;color:nav.ink;font.family:rhineFontFamily;font.pixelSize:19*nav.unit;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
        background:Item {
            Rectangle {anchors.fill:parent;anchors.topMargin:2*nav.unit;anchors.bottomMargin:-2*nav.unit;radius:height/2;color:nav.dark?"#18313928":"#103c4435"}
            Rectangle {anchors.fill:parent;radius:height/2;color:button.down?(nav.dark?"#80596948":"#d3dcc9"):(button.hovered?(nav.dark?"#705d6d50":"#e7ecdf"):(nav.dark?"#4447503e":"#acf4f3eb"));border.width:nav.unit;border.color:nav.dark?"#2679826e":"#70fffff8"
                Behavior on color {ColorAnimation {duration:nav.reduced?0:120}}
            }
        }
    }
    Arrow {objectName:"archiveBrowseNext";x:nav.downOffset;y:18*unit;glyph:"↓";actionName:"next"}
    Arrow {objectName:"archiveColumnPrevious";x:0;y:18*unit;glyph:"←";actionName:"column-prev";enabled:nav.total>1}
    Item {
        x:44*unit;width:parent.width-88*unit;height:parent.height
        Text {objectName:"archiveColumnNumber";anchors.horizontalCenter:parent.horizontalCenter;y:6*nav.unit;text:String(nav.position).padStart(2,"0")+" / "+String(nav.total).padStart(2,"0");font.family:rhineFontFamily;font.pixelSize:11*nav.unit;color:nav.ink;opacity:.65}
        Text {objectName:"archiveColumnName";y:28*nav.unit;width:parent.width;text:nav.navigation.name||"";textFormat:Text.PlainText;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter;font.family:rhineFontFamily;font.pixelSize:15*nav.unit;color:nav.ink}
        Rectangle {x:12*nav.unit;y:60*nav.unit;width:parent.width-24*nav.unit;height:2*nav.unit;radius:height/2;color:nav.dark?"#375341":"#26737d68"
            Rectangle {objectName:"archiveColumnProgress";height:parent.height;width:parent.width*(nav.total?nav.position/nav.total:0);radius:parent.radius;color:nav.dark?"#a5b597":"#7a8d6b";Behavior on width {NumberAnimation {duration:nav.reduced?0:160;easing.type:Easing.OutCubic}}}
        }
    }
    Arrow {objectName:"archiveColumnNext";x:parent.width-width;y:18*unit;glyph:"→";actionName:"column-next";enabled:nav.total>1}
}
