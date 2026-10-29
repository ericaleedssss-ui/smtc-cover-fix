"""G81: retain one original archive glass and change only its content."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
shutil.copyfile(root/'maintained/Qt/qml/ArchiveReading.qml','Qt/qml/ArchiveReading.qml')
edit('Qt/CMakeLists.txt','    qml/PlaylistShowcase.qml\n','    qml/ArchiveReading.qml\n    qml/PlaylistShowcase.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/PlaylistShowcase.qml','set_source_files_properties(qml/ArchiveReading.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveReading.qml)\nset_source_files_properties(qml/PlaylistShowcase.qml')
# Restore the original glass implementation and its exact shader constants.
edit('Qt/qml/LiquidGlass.qml','    property real edgeStrength: 1\n','')
edit('Qt/qml/LiquidGlass.qml','        property real edgeStrength: glass.edgeStrength\n','')
edit('Qt/shaders/liquidGlass.frag','    float edgeStrength;\n','')
edit('Qt/shaders/liquidGlass.frag','float opticalEdge=exp(-depth/4.5)*edgeStrength;','float opticalEdge=exp(-depth/4.5);')
edit('Qt/shaders/liquidGlass.frag','float shadow=.12*mix(.3,1.0,edgeStrength)*exp(','float shadow=.12*exp(')
# Publish the same reading region for every archive selection, including empty
# collections. The glass preference toggles only sampling, never the content.
edit('Qt/src/NativeHud.cpp','if (textFrosted && frame["mode"] == "archive"','if (frame["mode"] == "archive"')
edit('Qt/src/NativeHud.cpp','        if((m_music->current["kind"]!="playlist"&&m_music->current["kind"]!="album")||m_music->directory)readingPanel = QRectF(left, list ? 205 : 437, std::max(1.0, width - left - 31),\n                              list ? 642 : 380);','        readingPanel = QRectF(left, list ? 205 : 400, std::max(1.0, width - left - 31),\n                              list ? 642 : 440);')
p=Path('Qt/qml/Main.qml');s=p.read_text(encoding='utf-8')
a=s.index('    // 背景采样与文字分层，避免把文字本身一起模糊。');b=s.index('    Loader {\n        id: discGlassLoader',a)
s=s[:a]+s[b:]
a=s.index('    Loader {\n        id:showcaseLoader;');b=s.index('    GlobalTools {id:globalTools;',a)
s=s[:a]+'''    ArchiveReading {
        id:archiveReading
        property var bounds:rhine.state.readingPanel
        visible:!!bounds
        x:(bounds?bounds.x:0)*root.stageScale;y:(bounds?bounds.y:0)*root.stageScale
        width:(bounds?bounds.width:0)*root.stageScale;height:(bounds?bounds.height:0)*root.stageScale
        z:84
        background:backgroundLayer;materialLayer:baseVisual;controller:rhine.showcase
        unit:root.stageScale;dark:rhine.state.dark;frosted:rhine.state.textFrosted===true
        collection:(rhine.state.currentKind==="playlist"||rhine.state.currentKind==="album")&&!rhine.state.directoryOpen
    }
'''+s[b:]
s=s.replace('        id: backgroundLayer\n','        id: backgroundLayer\n        z:-2\n')
s=s.replace('if(showcaseLoader.item&&showcaseLoader.item.dismissTopOverlay())return;','if(archiveReading.dismissTopOverlay())return;')
s=s.replace('if(showcaseLoader.active&&showcaseLoader.item.showSongs){showcaseLoader.item.scrollSongs(wheel);','if(archiveReading.collectionActive&&archiveReading.content&&archiveReading.content.showSongs){archiveReading.content.scrollSongs(wheel);')
assert 'showcaseLoader.' not in s
p.write_text(s,encoding='utf-8')
print('G81: one persistent archive reading unit, exact original glass, content-only collection view installed.')
# The reading region now owns content independently of the frosting preference.
# Keep the old native regression in sync; the real QML self-test separately
# requires sampling to stop and release the effect when frosting is disabled.
edit('Qt/tests/NativeHudChecks.cpp',
     '// 毛玻璃只覆盖阅读区，不改变歌曲或交互；关闭后不保留采样区域。',
     '// 阅读区承载内容；磨砂开关只控制采样，不移除内容布局。')
edit('Qt/tests/NativeHudChecks.cpp',
     'check(panel.value("x").toDouble() > 900 && panel.value("y").toDouble() == 437,\n                      "reading area bounds");',
     '''check(panel.value("x").toDouble() > 900 && panel.value("width").toDouble() < 960 &&
                          panel.value("y").toDouble() == 400 && panel.value("height").toDouble() == 440,
                      "shared reading area bounds");''')
edit('Qt/tests/NativeHudChecks.cpp',
     'check(hud.state().value("readingPanel").isNull(), "off clears sampling area");',
     '''check(!hud.state().value("textFrosted").toBool(), "off disables frosting");
                check(hud.state().value("readingPanel").toObject() == panel,
                      "off preserves the shared reading content region");
                check(music->current.value("key") == song(1).value("key") && hasAction(hud.hits, "open"),
                      "off preserves the selected song and its details action");''')
