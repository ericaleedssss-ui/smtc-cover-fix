"""G88: immersive disc atmosphere and independent footer now-playing navigation."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:100]);p.write_text(s.replace(old,new),encoding='utf-8')
shutil.copyfile(root/'maintained/Qt/qml/NowPlayingShortcut.qml','Qt/qml/NowPlayingShortcut.qml')
edit('Qt/CMakeLists.txt','    qml/NowPlayingPanel.qml\n','    qml/NowPlayingShortcut.qml\n    qml/NowPlayingPanel.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/NowPlayingPanel.qml','set_source_files_properties(qml/NowPlayingShortcut.qml PROPERTIES QT_RESOURCE_ALIAS NowPlayingShortcut.qml)\nset_source_files_properties(qml/NowPlayingPanel.qml')
edit('Qt/qml/Main.qml','    ArchiveActionIcon {\n        objectName:"playerShuffleArtwork"','''    NowPlayingShortcut {
        unit:root.stageScale;dark:rhine.state.dark===true;reduced:rhine.state.reduced===true
        available:!!rhine.state.playerTrackKey;playing:rhine.nowPlaying.playback.playing===true
        selected:rhine.state.nowPlaying===true&&rhine.state.mode==="archive"&&!rhine.state.modal&&!rhine.state.directoryOpen&&!rhine.state.lyricsMode
        blocked:root.rightDrawerActive;motionAllowed:root.visible&&root.visibility!==Window.Minimized
        x:root.width-98*root.stageScale;y:1011*root.stageScale
        width:36*root.stageScale;height:width;z:14
        visible:rhine.state.mode!=="boot"
        onOpenRequested:rhine.action("player:now-playing")
    }
    ArchiveActionIcon {
        objectName:"playerShuffleArtwork"''')
# Move actual drawing and the hit/volume rectangles together, not just icons.
edit('Qt/src/NativeHudPlayer.cpp','const double vx = width - 270;','const double vx = width - 310;')
edit('Qt/src/NativeHudPlayer.cpp','control(width - 108, "desktop:toggle"','control(width - 148, "desktop:toggle"')
edit('Qt/src/NativeHudPlayer.cpp','icon(width - 108, "M 2 3','icon(width - 148, "M 2 3')
edit('Qt/src/NativeHud.h','    void openPlayingSong(bool lyrics);','    void openNowPlaying();\n    void openPlayingSong(bool lyrics);')
fragment=(root/'maintained/G88-open-playing.cppfrag').read_text(encoding='utf-8')
edit('Qt/src/NativeHudController.cpp','void NativeHud::playerAction(const QStringList &parts) {',fragment+'\nvoid NativeHud::playerAction(const QStringList &parts) {')
edit('Qt/src/NativeHudController.cpp','    const auto name = parts.value(1);\n    const auto value = parts.value(2).toDouble();','    const auto name = parts.value(1);\n    if(name=="now-playing"){openNowPlaying();return;}\n    const auto value = parts.value(2).toDouble();')
edit('Qt/src/NativeHudController.cpp','    const bool destination = value == "open" ||','    const bool destination = value == "player:now-playing" || value == "open" ||')
print('G88: immersive artwork/overlapping atmosphere, fixed sheen, shared compact actions and global now-playing entry installed.')
fragment=(root/'maintained/G88-ui-checks.cppfrag').read_text(encoding='utf-8')
edit('Qt/tests/UiChecks.cpp','    qInfo() << "Frosted UI rendering and settings:"',fragment+'    qInfo() << "Frosted UI rendering and settings:"')
