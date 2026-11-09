import QtQuick
import QtQuick.Controls.Basic as Controls

Rectangle {
    id: tabs
    required property var options
    property string current: ""
    property real unit: 1
    property bool dark: false
    property bool reduced: false
    property real segmentWidth: 58 * unit
    signal chosen(string key)
    readonly property int selectedIndex: {
        for (var i = 0; i < options.length; ++i) if (options[i].key === current) return i;
        return -1;
    }
    width: segmentWidth * options.length + 4 * unit
    height: 34 * unit
    radius: height / 2
    color: dark ? "#14ffffff" : "#0f000000"
    Rectangle {
        objectName: "profileTabSelection"
        x: 2 * tabs.unit + Math.max(0, tabs.selectedIndex) * tabs.segmentWidth
        y: 2 * tabs.unit
        width: tabs.segmentWidth
        height: tabs.height - 4 * tabs.unit
        radius: height / 2
        color: tabs.dark ? "#3dffffff" : "#ffffff"
        visible: tabs.selectedIndex >= 0
        border.width: tabs.dark ? 0 : 1
        border.color: "#12000000"
        Behavior on x { enabled:!tabs.reduced; SpringAnimation { spring:4.5; damping:.85; epsilon:.1 } }
    }
    Row {
        x: 2 * tabs.unit; y: 2 * tabs.unit
        Repeater {
            model: tabs.options
            delegate: Controls.AbstractButton {
                id: segment
                required property var modelData
                objectName: "profileSegment_" + modelData.key
                width: tabs.segmentWidth; height: tabs.height - 4 * tabs.unit
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: modelData.label
                background: Rectangle {
                    radius: height / 2
                    color: segment.down ? (tabs.dark ? "#24ffffff" : "#16000000") : segment.hovered ? (tabs.dark ? "#0affffff" : "#08000000") : "transparent"
                    border.width: segment.visualFocus ? 1 : 0
                    border.color: tabs.dark ? "#aab5a0" : "#808a78"
                    Behavior on color { ColorAnimation { duration: tabs.reduced ? 0 : 100 } }
                }
                contentItem: Text {
                    text: segment.modelData.label
                    font.family: rhineFontFamily
                    font.pixelSize: 13 * tabs.unit
                    font.weight: tabs.current === segment.modelData.key ? Font.DemiBold : Font.Normal;font.variableAxes:({"wght":tabs.current === segment.modelData.key ? Font.DemiBold : Font.Normal})
                    color: tabs.dark ? "#e4e8db" : "#30392e"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                onClicked: tabs.chosen(modelData.key)
            }
        }
    }
}
