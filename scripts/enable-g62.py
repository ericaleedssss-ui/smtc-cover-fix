"""G62: round album artwork, cohesive socials, expressive contour sweep,
and a native-action backed QML glass queue with aligned hoverable rows.
Runs AFTER G61 so older invariant checks stay intact.
"""
from pathlib import Path
import shutil

def edit(path, old, new):
    p=Path(path)
    s=p.read_text(encoding="utf-8")
    found=s.count(old)
    if found != 1:
        raise RuntimeError(f"G62 anchor mismatch {path}: {found} for {old[:110]!r}")
    p.write_text(s.replace(old,new,1),encoding="utf-8")

# Present cover art as a genuinely circular QML image, not a squared native
# thumbnail with a circle drawn over it. Native click targets remain functional.
edit("Qt/src/NativeHudPlayer.cpp",
    '''    const double coverX = 40, coverY = cy - 26;
    if (!player.coverImage.isEmpty()) { image(player.coverImage, coverX, coverY, 52, 52); }
    else {
        op({"ellipse", subtle, coverX, coverY, 52, 52});
        op({"ellipse", textInk, coverX + 23, coverY + 23, 6, 6});
    }''',
    '''    const double coverX = 45, coverY = cy - 29;
    // The actual artwork is QML-masked as a circular album disc. Rendering
    // a native square underneath would leave its four corners uncovered.''')
edit("Qt/src/NativeHudPlayer.cpp",
    '    const double infoWidth = 204.;  // fixed metadata viewport; title overflows only inside its marquee',
    '''    const double infoX = 119.;
    const double infoWidth = 167.;  // fixed marquee viewport for EVERY song''')
edit("Qt/src/NativeHudPlayer.cpp",
    '    centeredText(fit(artist, 14, infoWidth), 109, cy + 14, 14);',
    '    centeredText(fit(artist, 14, infoWidth), infoX, cy + 14, 14);')
edit("Qt/src/NativeHudPlayer.cpp",
    '        hit(coverX, coverY, 52, 52, "player:song-lyrics", "歌曲歌词");',
    '        hit(coverX, coverY, 60, 60, "player:song-lyrics", "歌曲歌词");')
edit("Qt/src/NativeHudPlayer.cpp",
    '        hit(109, cy - 26, infoWidth, 26, "player:song-detail", "歌曲详情");',
    '        hit(infoX, cy - 26, infoWidth, 26, "player:song-detail", "歌曲详情");')
edit("Qt/src/NativeHudPlayer.cpp",
    '        double ax = 109;',
    '        double ax = infoX;')
edit("Qt/src/NativeHudPlayer.cpp",
    '        for (int i = 0; i < artists.size() && ax < 109 + infoWidth; ++i) {',
    '        for (int i = 0; i < artists.size() && ax < infoX + infoWidth; ++i) {')
edit("Qt/src/NativeHudPlayer.cpp",
    '            const double remaining = 109 + infoWidth - ax;',
    '            const double remaining = infoX + infoWidth - ax;')
edit("Qt/src/NativeHudPlayer.cpp",
    '            hit(109, cy + 1, infoWidth, 25, "player:song-lyrics", "查看歌词");',
    '            hit(infoX, cy + 1, infoWidth, 25, "player:song-lyrics", "查看歌词");')
edit("Qt/src/NativeHudPlayer.cpp",
    '    const double reactionX = 109 + infoWidth + 18;',
    '    const double reactionX = infoX + infoWidth + 8;  // fixed close to album metadata')

# Title pixels and hit geometry are tied to the exact same fixed range.
edit("Qt/src/NativeHud.cpp",
    '            {"playerTitleBounds", rect(QRectF(109, 1003, 204., 29))},',
    '            {"playerTitleBounds", rect(QRectF(119, 1003, 167., 29))},')
edit("Qt/src/NativeHud.cpp",
    '            {"playerTitle", m_music->player.current.value("title").toString()},',
    '''            {"playerTitle", m_music->player.current.value("title").toString()},
            {"playerCoverUrl", m_music->player.current.value("cover").toString()},''')

# The QML overlay owns the queue layout; remove the legacy native modal UI
# entirely, otherwise it bleeds through the frosted surface and doubles
# lettering and rules. Backend action dispatch still handles row controls.
p=Path("Qt/src/NativeHudModal.cpp")
s=p.read_text(encoding="utf-8")
start=s.index('    if (modal == "player") {')
end=s.index('    if (modal == "lyrics-source") {',start)
assert end>start and 'playerPanel(panelX, panelY, panelW);' in s[start:end]
s=s[:start]+'''    if (modal == "player") {
        // G62 queue is drawn with aligned QML ListView rows over LiquidGlass.
        // Keep modal hit reset and render state, but never draw native text,
        // divider lines or an opaque beige box underneath the glass.
        hits = {};
        m_modalControls = false;
        restore();
        return;
    }
'''+s[end:]
p.write_text(s,encoding="utf-8")

# Keep the queue's public action protocol: play, remove, clear, close.
# Expose one coherent data model, only while the queue is actually open.
edit("Qt/src/NativeHud.cpp",
    '            {"modal", modal},',
    '''            {"modal", modal},
            {"queueBounds", modal == "player" ? QJsonObject{
                {"x", bounds.x()}, {"y", bounds.y()},
                {"width", bounds.width()}, {"height", bounds.height()}} : QJsonObject{}},
            {"queueRows", modal == "player" ? m_music->player.queue : QJsonArray{}},
            {"queueCount", m_music->player.queue.size()},
            {"queueIndex", m_music->player.index},
            {"queueRoaming", m_music->player.roamActive},
            {"queueCurrentTitle", m_music->player.current.value("title").toString()},
            {"queueCurrentArtist", m_music->player.current.value("artist").toString()},''')

# A real circular source mask (not Rectangle.clip, which is rectangular).
# Retains an interactive native hitbox for opening the lyrics.
edit("Qt/qml/Main.qml",
    '''    // Playback edge-trail is decorative and never captures mouse input.''',
    '''    Item {
        id: circularPlayerCover
        objectName: "circularPlayerCover"
        x: 45 * root.stageScale
        y: 1000 * root.stageScale
        width: 60 * root.stageScale
        height: 60 * root.stageScale
        z: 16
        visible: rhine.state.mode !== "boot" && !!rhine.state.playerCoverUrl
        Rectangle {
            id: discMask
            anchors.fill: parent
            radius: width / 2
            color: "white"
            visible: false
        }
        Image {
            id: discPhoto
            anchors.fill: parent
            source: rhine.state.playerCoverUrl || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: false
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: rhine.state.dark ? "#34493e" : "#b9bfae"
            visible: discPhoto.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: "♪"
                color: rhine.state.dark ? "#d4dfd0" : "#6e7a63"
                font.pixelSize: 25 * root.stageScale
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: discPhoto
            maskEnabled: true
            maskSource: discMask
            maskThreshold: 0.5
            maskSpreadAtMin: 0
            maskSpreadAtMax: 0.05
            visible: discPhoto.status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(.5, root.stageScale * .8)
            border.color: rhine.state.dark ? "#70c5d2c3" : "#aaf6f4e7"
        }
    }

    // Playback edge-trail is decorative and never captures mouse input.''')

# G61's speed ramp was right in spirit, but only 730 ms hid the bottom.
# Keep the accelerate-then-decelerate InOutCubic curve as explicitly requested.
# Increase glow and length on the bottom edge so the whole route is legible.
edit("Qt/qml/Main.qml",
    '''            duration: 730
            easing.type: Easing.InOutCubic''',
    '''            duration: 1270
            easing.type: Easing.InOutCubic''')
edit("Qt/qml/Main.qml",
    'var length = Math.min(distance * .17, 118 * root.stageScale);',
    'var length = Math.min(distance * .22, 174 * root.stageScale);')
edit("Qt/qml/Main.qml",
    'var fade = Math.min(1, (1 - travel) * 9);',
    'var fade = Math.min(1, (1 - travel) * 17);')
edit("Qt/qml/Main.qml",
    'ctx.lineWidth = (pass === 0 ? 7 : 2.7) * root.stageScale;',
    'ctx.lineWidth = (pass === 0 ? 10 : 3.2) * root.stageScale;')
edit("Qt/qml/Main.qml",
    '''                        ? "rgba(158,198,142," + (fade * .10 * (f1 + .10)) + ")"
                        : "rgba(101,155,93," + (fade * .82 * (f1 * f1)) + ")";''',
    '''                        ? "rgba(158,198,142," + (fade * .18 * (.38 + .62 * f1)) + ")"
                        : "rgba(101,155,93," + (fade * .94 * (.19 + .81 * f1 * f1)) + ")";''')

# Existing softEdgeFade shader has been in the CMake shader bundle since G58.
# Reuse it; do not add a second homemade fade or sacrifice row interactivity.
root=Path(__file__).resolve().parents[1]
target=Path("Qt/qml/PlayerQueueGlass.qml")
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(root/"maintained/Qt/qml/PlayerQueueGlass.qml",target)
edit("Qt/CMakeLists.txt",
    'set_source_files_properties(qml/PlayerTitleMarquee.qml PROPERTIES QT_RESOURCE_ALIAS PlayerTitleMarquee.qml)',
    '''set_source_files_properties(qml/PlayerTitleMarquee.qml PROPERTIES QT_RESOURCE_ALIAS PlayerTitleMarquee.qml)
set_source_files_properties(qml/PlayerQueueGlass.qml PROPERTIES QT_RESOURCE_ALIAS PlayerQueueGlass.qml)''')
edit("Qt/CMakeLists.txt",
    '    qml/PlayerTitleMarquee.qml\n    qml/DiscoverGlass.qml',
    '    qml/PlayerTitleMarquee.qml\n    qml/PlayerQueueGlass.qml\n    qml/DiscoverGlass.qml')
edit("Qt/qml/Main.qml",
    '''    // Lyrics/detail hit areas still come from the native HUD. Only the
    // text pixels move, so a long title never blocks the click handlers.''',
    '''    Loader {
        id: glassQueueLoader
        objectName: "glassQueueLoader"
        property var bounds: rhine.state.queueBounds
        active: rhine.state.modal === "player"
        x: (bounds ? bounds.x : 0) * root.stageScale
        y: (bounds ? bounds.y : 0) * root.stageScale
        width: (bounds ? bounds.width : 430) * root.stageScale
        height: (bounds ? bounds.height : 842) * root.stageScale
        z: 245
        sourceComponent: PlayerQueueGlass {
            background: backgroundLayer
            sampleX: glassQueueLoader.x
            sampleY: glassQueueLoader.y
            unit: root.stageScale
        }
    }
    // Lyrics/detail hit areas still come from the native HUD. Only the
    // text pixels move, so a long title never blocks the click handlers.''')

# Use a content-addressed MSVC compiler cache when the Actions runner has
# sccache available; no cached build output is blindly reused. Ninja still
# checks source dependencies and changed C++/QML files are rebuilt correctly.
edit("scripts/build.cjs",
    "        \`-DRHINE_RELEASE_BUILD=\${version.release ? 'ON' : 'OFF'}\`,\n    ]);",
    """        \`-DRHINE_RELEASE_BUILD=\${version.release ? 'ON' : 'OFF'}\`,
        ...(process.env.RHINE_USE_COMPILER_CACHE === '1'
            ? ['-DCMAKE_C_COMPILER_LAUNCHER=sccache',
               '-DCMAKE_CXX_COMPILER_LAUNCHER=sccache']
            : []),
    ]);""")

native=Path("Qt/src/NativeHudPlayer.cpp").read_text(encoding="utf-8")
modal=Path("Qt/src/NativeHudModal.cpp").read_text(encoding="utf-8")
qml=Path("Qt/qml/Main.qml").read_text(encoding="utf-8")
assert "const double reactionX = infoX + infoWidth + 8;" in native
assert "image(player.coverImage, coverX" not in native.split("void NativeHud::playerBar(")[1].split("void NativeHud::playerPanel(")[0]
assert "playerPanel(panelX, panelY, panelW);" not in modal
assert 'objectName: "circularPlayerCover"' in qml
assert 'duration: 1270' in qml and "Easing.InOutCubic" in qml
assert 'objectName: "glassQueueLoader"' in qml
assert 'objectName: "playerQueueEdgeFade"' in target.read_text(encoding="utf-8")
print("G62: circular cover, closer social cluster, readable accelerating/decelerating rim light, QML glass queue.")
