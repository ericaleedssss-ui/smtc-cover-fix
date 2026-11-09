import QtQuick
// User preference: hover descriptions are removed application-wide.
// Compatibility item for existing call sites; no popup, timer or visual content.
Item {
    property bool dark:rhine.state.dark===true
    property string text:""
    property int delay:0
    property int timeout:0
    width:0;height:0;enabled:false;Accessible.ignored:true
}
