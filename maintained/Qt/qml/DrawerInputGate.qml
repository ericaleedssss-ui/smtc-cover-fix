import QtQuick
import QtQml.Models

// Disabling the actual lower surfaces also cancels passive HoverHandlers and
// existing tooltips. The full-screen catcher consumes the complete pointer gesture.
Item {
    id: gate
    objectName: "rightDrawerInputGate"
    required property Item sceneRoot
    required property Item overlayLayer
    required property Item queueSurface
    required property Item collectionSurface
    property bool blocked: false
    signal dismissed()
    anchors.fill: parent
    z: 349
    Instantiator {
        model: gate.sceneRoot.children
        delegate: Binding {
            required property var modelData
            target: modelData
            property: "enabled"
            value: false
            when: gate.blocked && modelData!==gate && modelData!==gate.overlayLayer && modelData!==gate.queueSurface && modelData!==gate.collectionSurface
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    MouseArea {
        objectName:"drawerOutsideCatcher"
        anchors.fill:parent;enabled:gate.blocked;visible:enabled
        acceptedButtons:Qt.AllButtons;hoverEnabled:true
        cursorShape:Qt.ArrowCursor
        onClicked:gate.dismissed()
        onDoubleClicked:gate.dismissed()
        onWheel:event=>event.accepted=true
    }
}
