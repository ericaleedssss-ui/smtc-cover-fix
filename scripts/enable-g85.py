"""G85: compact archive metadata and one secondary column controller."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
shutil.copyfile(root/'maintained/Qt/qml/ArchiveNavigator.qml','Qt/qml/ArchiveNavigator.qml')
edit('Qt/CMakeLists.txt','    qml/ArchiveReading.qml\n','    qml/ArchiveNavigator.qml\n    qml/ArchiveReading.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/ArchiveReading.qml','set_source_files_properties(qml/ArchiveNavigator.qml PROPERTIES QT_RESOURCE_ALIAS ArchiveNavigator.qml)\nset_source_files_properties(qml/ArchiveReading.qml')
edit('Qt/qml/Main.qml','    ArchiveActionIcon {\n        objectName:"playerShuffleArtwork"', '''    ArchiveNavigator {
        id:archiveNavigator
        controller:rhine;navigation:rhine.state.archiveNavigation||({})
        unit:root.stageScale;dark:rhine.state.dark;reduced:rhine.state.reduced
        width:implicitWidth;height:implicitHeight
        x:archiveReading.x+(archiveReading.width-width)/2
        y:Math.min(archiveReading.y+archiveReading.height+16*root.stageScale,976*root.stageScale-height-12*root.stageScale)
        downOffset:archiveReading.x-x
        z:84
        visible:rhine.state.mode==="archive"&&!rhine.state.directoryOpen&&!rhine.state.modal&&!rhine.state.viewer&&!rhine.state.lyricsMode&&!rhine.state.commentsOpen
    }
    ArchiveActionIcon {
        objectName:"playerShuffleArtwork"''')
edit('Qt/src/NativeHud.cpp','            {"currentKind", m_music->current["kind"]},','''            {"archiveNavigation", QJsonObject{{"index",m_music->sourceOrder().indexOf(m_music->selectedLane)+1},{"total",m_music->sourceOrder().size()},{"name",m_music->libraryName()}}},
            {"currentKind", m_music->current["kind"]},''')
# Only the archive landing navigation is replaced. Directory controls stay native.
edit('Qt/src/NativeHud.cpp','    const auto nav = width * 0.2625;','    if(music.directory){\n    const auto nav = width * 0.2625;')
edit('Qt/src/NativeHud.cpp','         nav, 850, 12);\n}', '         nav, 850, 12);\n    }\n}')
edit('Qt/src/NativeHud.cpp','        text(QStringLiteral("第 %1 / %2 项")','        if(music.directory)text(QStringLiteral("第 %1 / %2 项")')
edit('Qt/src/NativeHud.cpp','void NativeHud::footer(double width) {','void NativeHud::footer(double width) {\n    if(frame["mode"]=="archive"&&!m_music->directory)return;')
# Playback follows only when already viewing playback/details. Roaming is unchanged.
edit('Qt/src/MusicDirectory.cpp','void MusicLibrary::followPlayback(QJsonObject value) {','''void MusicLibrary::followPlayback(QJsonObject value) {
    // Transport controls never replace the archive browsing selection or glass.
    if(frame["mode"]=="archive"&&!player.roamActive)return;''')
print('G85: compact archive navigation and browse-preserving playback changes installed.')
