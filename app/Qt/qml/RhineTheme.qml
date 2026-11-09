pragma Singleton
import QtQuick

// Cloudy ui_pane.go: shared palette, geometry and motion contract.
QtObject {
    readonly property string family:rhineFontFamily
    readonly property int menuWidth:268
    readonly property int menuRowHeight:39
    readonly property int paneRadius:20
    readonly property int rowRadius:14
    readonly property int controlHeight:36
    readonly property int controlRadius:10
    readonly property bool noMotion:rhine.state.reduced||rhine.visualPreferences.motion==="off"
    readonly property bool fullMotion:!noMotion&&rhine.visualPreferences.motion==="full"
    function ink(dark){return dark?"#ffffff":"#1d1d1f";}
    function muted(dark){return dark?"#99ffffff":"#9e1d1d1f";}
    function faint(dark){return dark?"#6bffffff":"#6b1d1d1f";}
    function hover(dark){return dark?"#1affffff":"#121d1d1f";}
    function press(dark){return dark?"#29ffffff":"#1f1d1d1f";}
    function line(dark){return dark?"#1affffff":"#1a1d1d1f";}
    function surface(dark){return dark?"#232327":"#f6f6f8";}
    function accent(dark){return dark?"#b4c6a5":"#6f8562";}
    function duration(milliseconds){return noMotion?0:milliseconds;}
}
