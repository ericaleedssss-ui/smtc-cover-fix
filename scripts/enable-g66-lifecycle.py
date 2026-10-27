"""Stabilize G66 QML model lifetime on page transitions (after G66 patch)."""
from pathlib import Path
import shutil

def edit(path, old, new):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if text.count(old) != 1:
        raise RuntimeError('G66 lifecycle anchor mismatch: ' + path)
    p.write_text(text.replace(old, new), encoding='utf-8')

root = Path(__file__).resolve().parents[1]
edit('Qt/qml/Main.qml', '''        active: rhine.state.commentsOpen === true && !!bounds
        visible: rhine.state.modal !== "profile"''', '''        property bool wanted: rhine.state.commentsOpen === true && !!bounds
        active: false
        function syncActivation() { active = wanted; }
        onWantedChanged: Qt.callLater(syncActivation)
        Component.onCompleted: syncActivation()
        visible: wanted && rhine.state.modal !== "profile"''')
old = '''        Repeater {
            model: glassQueueLoader.active ? [baseVisual, sideNavigation] : []
            delegate: ShaderEffectSource {
                required property var modelData
                x: glassQueueLoader.x - queueGlassBackdrop.pad
                y: glassQueueLoader.y - queueGlassBackdrop.pad
                width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                sourceItem: modelData
                sourceRect: Qt.rect(x, y, width, height)
                textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                live: true; smooth: true; hideSource: false
            }
        }'''
tiles = []
for name, source in [('queuePageTile', 'baseVisual'), ('queueNavigationTile', 'sideNavigation')]:
    tiles.append('''                ShaderEffectSource {
                    objectName: "%s"
                    x: glassQueueLoader.x - queueGlassBackdrop.pad
                    y: glassQueueLoader.y - queueGlassBackdrop.pad
                    width: glassQueueLoader.width + 2 * queueGlassBackdrop.pad
                    height: glassQueueLoader.height + 2 * queueGlassBackdrop.pad
                    sourceItem: %s
                    sourceRect: Qt.rect(x, y, width, height)
                    textureSize: Qt.size(Math.max(1, Math.ceil(width / 2)), Math.max(1, Math.ceil(height / 2)))
                    live: true; smooth: true; hideSource: false
                }''' % (name, source))
new = '''        Loader {
            anchors.fill: parent
            active: glassQueueLoader.active
            sourceComponent: Item {
''' + '\n'.join(tiles) + '''
            }
        }'''
edit('Qt/qml/Main.qml', old, new)
shutil.copyfile(root / 'maintained/Qt/qml/CommentsPage.qml', 'Qt/qml/CommentsPage.qml')
print('G66 lifecycle: fixed lower-layer captures, stable comment models and deferred page teardown.')

# Retain the original Windows QA, adding precise boundaries for the transition
# where the access violation occurred. Do not skip or relax an assertion.
edit('Qt/tests/UiChecks.cpp', '''    backend.action("tab:overview"); refresh();
    backend.action("music:track:5"); refresh();''', '''    qInfo() << "G66 lifecycle: leaving album comments";
    backend.action("tab:overview"); refresh();
    qInfo() << "G66 lifecycle: album comments released";
    backend.action("music:track:5"); refresh();
    qInfo() << "G66 lifecycle: album track navigation completed";''')
