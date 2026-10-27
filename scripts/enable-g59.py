"""G59: consolidate glass player, responsive metadata and slower edge fades.

Apply after G58. The radio, scrobbling and original G56/G57 tests remain
unchanged; only presentation coordinates and text mask lengths are adjusted.
"""
from pathlib import Path
def edit(path, old, new):
    p=Path(path)
    s=p.read_text(encoding="utf-8")
    n=s.count(old)
    if n!=1:
        raise RuntimeError(f"G59 anchor mismatch for {path}: {n} occurrences of {old[:92]!r}")
    p.write_text(s.replace(old,new,1),encoding="utf-8")

# Exactly match the dynamic native title/reactions geometry. Before G59,
# a blanket width of 400px kept short songs and their hearts artificially apart.
edit("Qt/src/NativeHud.cpp",
    '            {"playerTitleBounds", rect(QRectF(109, 1003, std::max(125., width / 2. - 560.), 29))},',
    '            {"playerTitleBounds", rect(QRectF(109, 1003, std::clamp(m_glyphs->width(m_music->player.current.value("title").toString(), 19, "demibold") + 14., 116., 252.), 29))},')

# The physical capsule has to float clear of the window bottom. Importantly,
# this is the ONLY glass layer and native no longer paints a duplicate panel.
edit("Qt/qml/Main.qml",
    '        x: 15 * root.stageScale; y: 976 * root.stageScale\n        width: root.width - 30 * root.stageScale; height: 102 * root.stageScale',
    '        x: 32 * root.stageScale; y: 990 * root.stageScale\n        width: root.width - 64 * root.stageScale; height: 78 * root.stageScale')
edit("Qt/qml/Main.qml",
    '            sampleX: 15 * root.stageScale; sampleY: 976 * root.stageScale\n            uiScale: root.stageScale; radius: 51 * root.stageScale',
    '            sampleX: 32 * root.stageScale; sampleY: 990 * root.stageScale\n            uiScale: root.stageScale; radius: 39 * root.stageScale')

# The two pause stages are deliberate. Title moves left to end, rests,
# returns right to start, rests again. It never teleports or wraps.
edit("Qt/qml/PlayerTitleMarquee.qml",
    '        property real fadePx: 19 * viewport.unit',
    '        property real fadePx: 28 * viewport.unit')
edit("Qt/qml/PlayerTitleMarquee.qml",
    '        PauseAnimation { duration: 1300 }',
    '        PauseAnimation { duration: 1900 }')
edit("Qt/qml/PlayerTitleMarquee.qml",
    '        PauseAnimation { duration: 1450 }',
    '        PauseAnimation { duration: 1900 }')

# Make the vertical navigation feather almost 2.4x longer while remaining
# mask-based. This avoids the old per-row opacity regression.
edit("Qt/qml/SideNavigation.qml",
    '            property real fadePx: 35 * navigation.unit',
    '            property real fadePx: 82 * navigation.unit')
edit("Qt/qml/SideNavigation.qml",
    '            property real blurStrength: 1.1 * navigation.unit',
    '            property real blurStrength: 1.6 * navigation.unit')

# The separate lyric reading shader is 100/112 logical pixels in G53.
# Widen both smoothstep ramps, including the center-to-edge gentle gradient.
edit("Qt/shaders/lyricsEdge.frag",
    'smoothstep(0.0, min(100.0 * unit, size.y * .22), y)',
    'smoothstep(0.0, min(178.0 * unit, size.y * .35), y)')
edit("Qt/shaders/lyricsEdge.frag",
    'smoothstep(0.0, min(112.0 * unit, size.y * .24), size.y - y)',
    'smoothstep(0.0, min(198.0 * unit, size.y * .38), size.y - y)')

# Regressions for precisely the G58 visuals shown in user screenshots.
q=Path("Qt/src/NativeHudPlayer.cpp").read_text(encoding="utf-8")
assert 'const double reactionX = 109 + infoWidth + 25;' in q
assert 'const double infoWidth = std::clamp(' in q
assert 'op({"fill-path", capsule' not in q and 'op({"path", capsule' not in q
assert 'clock(player.state["position"]' not in q.split("void NativeHud::playerBar(")[1].split("void NativeHud::playerPanel(")[0]
qml=Path("Qt/qml/Main.qml").read_text(encoding="utf-8")
assert 'width: root.width - 64 * root.stageScale; height: 78 * root.stageScale' in qml
print("G59: single floating pill, shorter marquee, adjoining reactions, longer lyric/navigation edge fades.")
