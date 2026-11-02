import QtQuick

Item {
    id: page
    property real unit: 1
    property var rows: rhine.state.lyricRows || []
    clip: true
    Item {
        id: textLayer
        anchors.fill: parent
        Repeater {
            model: page.rows.length
            delegate: Item {
                required property int index
                property var entry: page.rows[index] || ({})
                x: 4 * page.unit; y: (entry.y || 0) * page.unit
                width: page.width - 145 * page.unit
                opacity: entry.focused ? 1 : 0.28
                Behavior on opacity { enabled: !rhine.state.reduced; NumberAnimation { duration: 200 } }
                Text { text: parent.entry.original || ""; textFormat: Text.PlainText; color: rhine.state.dark ? "#ebebe6" : "#191b17"; font.family: rhineFontFamily; font.pixelSize: 34 * page.unit; font.weight: Font.Bold; lineHeightMode: Text.FixedHeight; lineHeight: 47 * page.unit }
                Text { y: (parent.entry.translationY || 0) * page.unit; text: parent.entry.translation || ""; textFormat: Text.PlainText; color: rhine.state.dark ? "#c6c7bf" : "#5f6259"; font.family: rhineFontFamily; font.pixelSize: 17 * page.unit; lineHeightMode: Text.FixedHeight; lineHeight: 26 * page.unit }
            }
        }
    }
    ShaderEffectSource {
        id: textTexture
        sourceItem: textLayer
        hideSource: true
        visible: false
        live: true
        smooth: true
    }
    ShaderEffect {
        objectName: "lyricsEdgeEffect"
        anchors.fill: parent
        property variant source: textTexture
        property size panelSize: Qt.size(width, height)
        property real unit: page.unit
        fragmentShader: "qrc:/shaders/lyricsEdge.frag.qsb"
    }
}
