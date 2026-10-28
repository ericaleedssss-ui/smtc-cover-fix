import QtQuick
import QtQuick.Shapes
Item {
    id: icon
    property string name: "more"
    property bool filled:false
    property color color: "#50594b"
    width:24; height:24
    readonly property var paths: ({
        search:"M 10.5 3 A 7.5 7.5 0 1 0 10.5 18 A 7.5 7.5 0 1 0 10.5 3 M 16 16 L 22 22",
        music:"M 9 18 V 5 L 21 3 V 16 M 9 7 L 21 5 M 9 18 C 9 22 2 23 2 19 C 2 15 9 15 9 18 M 21 16 C 21 20 14 21 14 17 C 14 13 21 13 21 16",
        settings:"M 9 3 L 15 3 L 16 6 L 19 5 L 22 10 L 20 12 L 22 14 L 19 19 L 16 18 L 15 21 L 9 21 L 8 18 L 5 19 L 2 14 L 4 12 L 2 10 L 5 5 L 8 6 Z M 12 8 A 4 4 0 1 0 12 16 A 4 4 0 1 0 12 8",
        back:"M 14 5 L 7 12 L 14 19 M 7 12 H 22",
        play:"M 7 3 L 21 12 L 7 21 Z",
        pause:"M 8 4 V 20 M 16 4 V 20",
        next:"M 3 5 H 15 M 3 11 H 12 M 3 17 H 10 M 19 12 V 22 M 14 17 H 24",
        comment:"M 4 3 H 21 V 17 H 12 L 6 22 V 17 H 3 V 3 Z M 7 8 H 17 M 7 12 H 14",
        collect:"M 4 5 H 10 L 13 8 H 22 V 21 H 3 V 5 Z M 12 11 V 18 M 8.5 14.5 H 15.5",
        download:"M 12 2 V 16 M 6 10 L 12 16 L 18 10 M 3 17 V 22 H 21 V 17",
        share:"M 14 3 H 22 V 11 M 22 3 L 10 15 M 9 5 H 3 V 22 H 20 V 15",
        link:"M 10 15 L 15 10 M 8 12 L 5 15 C 0 20 5 25 10 20 L 13 17 M 12 8 L 15 5 C 20 0 25 5 20 10 L 17 13",
        remove:"M 3 6 H 21 M 9 6 V 2 H 15 V 6 M 6 6 L 7 22 H 17 L 18 6 M 10 10 V 18 M 14 10 V 18",
        heart:"M 12 21 C 7 17 2 13 2 7 C 2 1 9 0 12 6 C 15 0 22 1 22 7 C 22 13 17 17 12 21 Z",
        filter:"M 2 4 H 22 L 15 12 V 21 L 9 18 V 12 Z",
        check:"M 3 12 L 9 18 L 22 4",
        close:"M 5 5 L 19 19 M 19 5 L 5 19",
        more:"M 3 12 H 4 M 11.5 12 H 12.5 M 20 12 H 21"
    })
    Shape {
        width:24; height:24; scale:Math.min(icon.width,icon.height)/24; transformOrigin:Item.TopLeft
        ShapePath {
            strokeColor:icon.color; strokeWidth:1.65; capStyle:ShapePath.RoundCap; joinStyle:ShapePath.RoundJoin
            fillColor:(icon.name==="play" || icon.filled) ? icon.color : "transparent"
            PathSvg { path:icon.paths[icon.name] || icon.paths.more }
        }
    }
}
