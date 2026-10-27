"""G58 presentation-only polish: truly pill-shaped glass, bidirectional
title pan with soft edge fades, and scroll-content-only sidebar gradient.
Runs *after* the passing G57 patches. Anchored and reviewable.
"""
from pathlib import Path
import shutil

def edit(path, old, new):
    p = Path(path)
    content = p.read_text(encoding="utf-8")
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"G58 anchor {path}: expected 1, found {count}: {old[:95]!r}")
    p.write_text(content.replace(old, new, 1), encoding="utf-8")

root = Path(__file__).resolve().parents[1]
for name in ("Qt/qml/PlayerTitleMarquee.qml", "Qt/shaders/softEdgeFade.frag"):
    dst = Path(name)
    dst.parent.mkdir(exist_ok=True, parents=True)
    shutil.copyfile(root / "maintained" / name, dst)

edit("CMakeLists.txt",
    "    Qt/shaders/lyricsEdge.frag)",
    "    Qt/shaders/lyricsEdge.frag\n    Qt/shaders/softEdgeFade.frag)")

edit("Qt/CMakeLists.txt",
    "set_source_files_properties(qml/SideNavigation.qml PROPERTIES QT_RESOURCE_ALIAS SideNavigation.qml)",
    "set_source_files_properties(qml/SideNavigation.qml PROPERTIES QT_RESOURCE_ALIAS SideNavigation.qml)\n"
    "set_source_files_properties(qml/PlayerTitleMarquee.qml PROPERTIES QT_RESOURCE_ALIAS PlayerTitleMarquee.qml)")
edit("Qt/CMakeLists.txt",
    "    qml/SideNavigation.qml\n    qml/DiscoverGlass.qml",
    "    qml/SideNavigation.qml\n    qml/PlayerTitleMarquee.qml\n    qml/DiscoverGlass.qml")

edit("Qt/src/NativeHud.cpp",
    '            {"playbackPosition", m_music->player.state.value("position").toDouble() / 1000.},',
    '''            {"playerTitle", m_music->player.current.value("title").toString()},
            {"playerTitleBounds", rect(QRectF(109, 1003, std::max(125., width / 2. - 560.), 29))},
            {"playbackPosition", m_music->player.state.value("position").toDouble() / 1000.},''')

edit("Qt/qml/Main.qml",
    '''    Hud {
        anchors.fill: parent
        engine: rhine
    }
    }''',
    '''    Hud {
        anchors.fill: parent
        engine: rhine
    }
    // Lyrics/detail hit areas still come from the native HUD. Only the
    // text pixels move, so a long title never blocks the click handlers.
    Loader {
        id: titleMarqueeLoader
        objectName: "playerTitleMarqueeLoader"
        property var bounds: rhine.state.playerTitleBounds
        active: !!bounds && !!rhine.state.playerTitle && rhine.state.mode !== "boot"
        x: (bounds ? bounds.x : 109) * root.stageScale
        y: (bounds ? bounds.y : 1003) * root.stageScale
        width: (bounds ? bounds.width : 130) * root.stageScale
        height: (bounds ? bounds.height : 29) * root.stageScale
        z: 14
        sourceComponent: PlayerTitleMarquee {
            value: rhine.state.playerTitle || ""
            unit: root.stageScale
        }
    }
    }''')

edit("Qt/qml/SideNavigation.qml",
     '            "shuffle": "M4 7 H7',
     '            "infinity": "M 6 16 C 2 16 2 8 6 8 C 9 8 10 11 12 12 C 14 13 15 16 18 16 C 22 16 22 8 18 8 C 15 8 14 11 12 12 C 10 13 9 16 6 16 Z",\n            "shuffle": "M4 7 H7')
edit("Qt/qml/SideNavigation.qml",
     '{label:"漫游", icon:"shuffle", tab:"roam"}',
     '{label:"漫游", icon:"infinity", tab:"roam"}')

# Remove the legacy per-playlist-row fade before drawing the entire list
# through one mask, avoiding double fading and nested-coordinate bugs.
edit("Qt/qml/SideNavigation.qml",
    '        opacity: Math.max(0, Math.min(1, (y - list.contentY + height) / (24 * navigation.unit), (list.height - (y - list.contentY)) / (24 * navigation.unit)))',
    '        opacity: 1')

# Source the entire scroll viewport in an offscreen texture. This keeps its
# original interactive hierarchy untouched and masks the composited pixels,
# rather than fading individual row opacities (the G55 regression).
edit("Qt/qml/SideNavigation.qml",
    '''        }
    }

    component DividerLine: Rectangle {''',
    '''        }
        ShaderEffectSource {
            id: navigationTexture
            sourceItem: list
            hideSource: true
            visible: false
            live: true
            smooth: true
        }
        ShaderEffect {
            id: navigationFeather
            objectName: "navigationEdgeFade"
            x: list.x; y: list.y
            width: list.width; height: list.height
            property variant source: navigationTexture
            property size panelSize: Qt.size(width, height)
            property real horizontal: 0
            property real fadePx: 35 * navigation.unit
            property real fadeStart: list.contentY > 3 ? 1 : 0
            property real fadeEnd: list.contentY < list.contentHeight - list.height - 3 ? 1 : 0
            property real blurStrength: 1.1 * navigation.unit
            fragmentShader: "qrc:/shaders/softEdgeFade.frag.qsb"
        }
    }

    component DividerLine: Rectangle {''')

# For the radio, selecting the actual station also visibly chooses its sidebar row.
edit("Qt/qml/SideNavigation.qml",
    '''rhine.action("roam:start");
                                navigation.scheduleClose();''',
    '''rhine.action("roam:start");
                                navigation.selected = "roam";
                                navigation.scheduleClose();''')

# The glass itself has exactly half-height corner radii. Unlike G57 the
# native path also matches these semicircular ends pixel-for-pixel.
edit("Qt/qml/Main.qml",
    "            uiScale: root.stageScale; radius: 45 * root.stageScale",
    "            uiScale: root.stageScale; radius: 51 * root.stageScale")
print("G58: G57 native bar plus Qt-rendered title and scroll-only fade mask.")
