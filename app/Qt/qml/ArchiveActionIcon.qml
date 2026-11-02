import QtQuick
import QtQuick.Window
Item {
    id:icon
    property url source
    property color tint:"#384332"
    Image {id:mask;objectName:"archiveActionImage";readonly property bool ready:status===Image.Ready;anchors.fill:parent;source:icon.source;fillMode:Image.PreserveAspectFit;smooth:true;cache:true;visible:GraphicsInfo.api===GraphicsInfo.Software}
    ShaderEffect {anchors.fill:parent;visible:GraphicsInfo.api!==GraphicsInfo.Software;property variant source:mask;property color tint:icon.tint;fragmentShader:"qrc:/shaders/archiveIcon.frag.qsb"}
}
