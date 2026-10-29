"""G86: now-playing content in the persistent archive reading unit."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:100]);p.write_text(s.replace(old,new),encoding='utf-8')
for name in ['NowPlaying.h','NowPlaying.cpp']:shutil.copyfile(root/'maintained/Qt/src'/name,'Qt/src/'+name)
shutil.copyfile(root/'maintained/Qt/qml/NowPlayingPanel.qml','Qt/qml/NowPlayingPanel.qml')
edit('CMakeLists.txt','    Qt/src/PlaylistShowcase.cpp','    Qt/src/NowPlaying.cpp\n    Qt/src/NowPlaying.h\n    Qt/src/PlaylistShowcase.cpp')
edit('Qt/CMakeLists.txt','    qml/ArchiveReading.qml\n','    qml/NowPlayingPanel.qml\n    qml/ArchiveReading.qml\n')
edit('Qt/CMakeLists.txt','set_source_files_properties(qml/ArchiveReading.qml','set_source_files_properties(qml/NowPlayingPanel.qml PROPERTIES QT_RESOURCE_ALIAS NowPlayingPanel.qml)\nset_source_files_properties(qml/ArchiveReading.qml')
edit('Qt/src/Engine.h','#include "PlaylistShowcase.h"','#include "PlaylistShowcase.h"\n#include "NowPlaying.h"')
edit('Qt/src/Engine.h','    Q_PROPERTY(QObject *showcase READ showcase CONSTANT)','    Q_PROPERTY(QObject *nowPlaying READ nowPlaying CONSTANT)\n    Q_PROPERTY(QObject *showcase READ showcase CONSTANT)')
edit('Qt/src/Engine.h','    QObject *showcase() const','    QObject *nowPlaying() const {return m_nowPlaying;}\n    QObject *showcase() const')
edit('Qt/src/Engine.h','    PlaylistShowcase *m_showcase=nullptr;','    NowPlaying *m_nowPlaying=nullptr;\n    PlaylistShowcase *m_showcase=nullptr;')
edit('Qt/src/Engine.cpp','    app->initialize();','    m_nowPlaying=new NowPlaying(&app->music,m_magazine,this);\n    connect(m_nowPlaying,&NowPlaying::navigate,this,&Engine::action);\n    app->initialize();')
edit('Qt/src/Engine.cpp','    delete m_showcase;m_showcase=nullptr;','    delete m_nowPlaying;m_nowPlaying=nullptr;\n    delete m_showcase;m_showcase=nullptr;')
edit('Qt/src/MusicLibrary.h','    bool wantsSongDetails = false;','    bool wantsSongDetails = false;\n    bool archiveNowPlaying = false;\n    QJsonObject archiveReturnItem;\n    std::weak_ptr<MusicDirectory> archivePlayingDirectory;')
edit('Qt/src/MusicLibrary.cpp','void MusicLibrary::showSource(int lane) {','void MusicLibrary::showSource(int lane) {\n    archiveNowPlaying=false;')
edit('Qt/src/MusicLibrary.cpp','void MusicLibrary::selectResult(int index, int lane, bool open) {','void MusicLibrary::selectResult(int index, int lane, bool open) {\n    archiveNowPlaying=false;')
edit('Qt/src/MusicLibrary.cpp','void MusicLibrary::next(int direction) {','void MusicLibrary::next(int direction) {\n    archiveNowPlaying=false;')
edit('Qt/src/MusicDirectory.cpp','    if(frame["mode"]=="archive"&&!player.roamActive)return;','    if(!player.roamActive&&(frame["mode"]=="archive"||(directory&&directoryInfo)))return;')
# Explicit player cover/title navigation must bypass passive browsing retention.
edit('Qt/src/NativeHudController.cpp','    music.directoryInfo = false;\n    music.followPlayback(music.player.current);','    music.directoryInfo = false;\n    music.frame["mode"]="detail";\n    music.followPlayback(music.player.current);')
edit('Qt/src/NativeHud.cpp','        const bool list = trackListMode && m_music->current.value("kind") == "song";','        const bool list = !m_music->archiveNowPlaying&&trackListMode && m_music->current.value("kind") == "song";')
edit('Qt/src/NativeHud.cpp','            {"currentKind", m_music->current["kind"]},','            {"nowPlaying", m_music->archiveNowPlaying&&!m_music->player.current.isEmpty()&&!m_music->player.roamActive&&!m_music->directory},\n            {"currentKind", m_music->current["kind"]},')
edit('Qt/src/NativeHud.cpp','void NativeHud::archive(double width) {','void NativeHud::archive(double width) {\n    if(m_music->archiveNowPlaying&&!m_music->directory&&!m_music->player.current.isEmpty()&&!m_music->player.roamActive)return;')
edit('Qt/qml/Main.qml','        collection:(rhine.state.archiveCollection','        playing:rhine.state.nowPlaying===true;playbackController:rhine.nowPlaying\n        collection:(rhine.state.archiveCollection')
# Discovery is a playback entry; full detail remains an explicit song action.
edit('Qt/src/MusicDiscover.cpp','''        // G53 regression contract: browsing discovery selects song details,
        // but never begins playback or replaces the current queue.
        m_store->choose(value, false, true);
        emit m_store->modeRequested("detail");''','''        if(value["unavailable"].toBool()){m_store->status="此歌曲当前不可播放";m_store->changed();return;}
        if(m_store->directory)m_store->leaveDirectory(false);
        m_store->frame["mode"]="archive";emit m_store->modeRequested("archive");
        m_store->archiveNowPlaying=true;m_store->archivePlayingDirectory=m_store->directory;m_store->archiveReturnItem=value["queueSource"].toObject();\n        m_store->player.play(value,m_store->playContext);m_store->changed();''')
# Existing native album row: only a deliberate play action starts transport.
edit('Qt/src/NativeHudMusic.cpp','    } else if (name == "track") {','''    } else if (name == "play-row") {
        if(music.directory&&last>=0&&last<music.directory->songs.size()){
            const auto song=MusicData::withQueueSource(music.directory->songs[last].toObject(),music.directory->item);
            if(!song["unavailable"].toBool()){music.archiveNowPlaying=true;music.archivePlayingDirectory=music.directory;music.archiveReturnItem=music.directory->item;music.player.play(song,music.directoryQueue());music.changed();}
        }
    } else if (name == "track") {''')
# Preserve all normal native actions; album song rows double click to play.
edit('Qt/qml/Main.qml','                        else rhine.action(modelData.action);','''                        else if(!(rhine.state.directoryOpen&&(rhine.state.currentKind==="album"||rhine.state.currentKind==="radio"||rhine.state.currentKind==="artist")&&modelData.action.startsWith("music:track:")))rhine.action(modelData.action);''')
edit('Qt/qml/Main.qml','                    onWheel: function (wheel) {\n                        root.routeWheel','''                    onDoubleClicked:function(mouse){if(mouse.button===Qt.LeftButton&&rhine.state.directoryOpen&&(rhine.state.currentKind==="album"||rhine.state.currentKind==="radio"||rhine.state.currentKind==="artist")&&modelData.action.startsWith("music:track:"))rhine.action(modelData.action.replace("music:track:","music:play-row:"));}
                    onWheel: function (wheel) {
                        root.routeWheel''')
# Update the obsolete discovery browse-only contract to the requested playback contract.
edit('Qt/tests/UiChecks.cpp','''    check(music.current["kind"] == "song" && hud.modal.isEmpty() && hud.frame["mode"] == "detail",
          "daily recommendation click opens song details");
    check(music.player.current == discoveryPlaying && music.player.queue == discoveryQueue,
          "browsing a recommendation does not start playback or replace the queue");''','''    check(music.player.current["id"]==testRecommendation["id"]&&hud.modal.isEmpty()&&hud.frame["mode"]=="archive"&&music.archiveNowPlaying,
          "G86 daily recommendation starts playback in the shared now-playing surface");
    check(findVisual(window->contentItem(),"nowPlayingPanel"),"G86 discovery uses actual now-playing QML content");''')
print('G86: shared now-playing content, explicit detail navigation and playback entry semantics installed.')

# Home search and profile song entries share the same playback semantics.
edit('Qt/src/NativeHudMusic.cpp','        music.selectResult(parts.value(3).toInt(), parts.value(2).toInt());','        const int lane=parts.value(2).toInt(),index=parts.value(3).toInt();\n        if(lane>=0&&lane<5&&index>=0&&index<music.lists[lane].size()&&music.lists[lane][index].toObject()["kind"]=="song"){\n            music.selectResult(index,lane,false);if(!music.current["unavailable"].toBool())music.play();\n        }else music.selectResult(index,lane);')
edit('Qt/src/NativeHudProfile.cpp','            m_music->choose(MusicData::withQueueSource(item, origin), false, true); m_scene.mode("detail"); frame["mode"] = "detail";','            if(!item["unavailable"].toBool()){\n                if(m_music->directory)m_music->leaveDirectory(false);\n                m_music->frame["mode"]="archive";m_scene.mode("archive");frame["mode"]="archive";\n                m_music->archiveNowPlaying=true;m_music->archivePlayingDirectory=m_music->directory;m_music->archiveReturnItem=origin;\n                m_music->player.play(MusicData::withQueueSource(item,origin),m_music->playContext);m_music->changed();\n            }')

# The archive's existing Enter/open action is also a playback entry for songs.
edit('Qt/src/NativeHudController.cpp','            } else {\n                m_scene.mode("detail");\n                music.loadSongWiki();\n\n            }','            } else if(frame["mode"]=="archive"){\n                if(!music.current["unavailable"].toBool())music.play();\n            } else {\n                m_scene.mode("detail");music.loadSongWiki();\n            }')

# G87: shared small-area disc atmosphere shader; no new effects dependency.
shutil.copyfile(root/'maintained/Qt/shaders/recordAtmosphere.frag','Qt/shaders/recordAtmosphere.frag')
edit('CMakeLists.txt','    Qt/shaders/archiveIcon.frag','    Qt/shaders/recordAtmosphere.frag\n    Qt/shaders/archiveIcon.frag')

# G87: only explicit playback selections enter the now-playing content.
edit('Qt/src/MusicLibrary.cpp','    const bool replaceQueue = byUser', '    if(byUser&&!player.roamActive&&frame["mode"]=="archive"){archiveNowPlaying=true;archivePlayingDirectory=directory;archiveReturnItem=current["queueSource"].toObject();}\n    const bool replaceQueue = byUser')
edit('Qt/src/MusicLibrary.cpp','        player.play(queue.first().toObject(), queue);','        archiveNowPlaying=true;archivePlayingDirectory=directory;archiveReturnItem=directory?directory->item:current;\n        player.play(queue.first().toObject(), queue);changed();')
edit('Qt/qml/Main.qml','            if(globalTools.dismiss())return;','            if(globalTools.dismiss())return;\n            if(rhine.state.mode==="archive"&&rhine.state.nowPlaying===true){rhine.nowPlaying.operate("browse");return;}')
# G87: leaving a played directory returns to the shared home surface, even
# when the old parent happened to be a song-detail page.
edit('Qt/src/MusicDirectory.cpp','    detailLoading = false;\n    if (restore) {','''    detailLoading = false;
    if(restore&&!directory&&archiveNowPlaying&&archivePlayingDirectory.lock()==folder&&!player.current.isEmpty()&&!player.roamActive){\n        archivePlayingDirectory.reset();
        selectedLane=folder->parentLane;selectedPhysical=folder->parentPhysical;
        const auto origin=archiveReturnItem.isEmpty()?folder->item:archiveReturnItem;
        choose(origin,false,false);frame["mode"]="archive";
        emit selectionRequested(folder->parentPhysical,{{"axis","lane"},{"direction",-1}});
        emit modeRequested("archive");changed();return;
    }
    if (restore) {''')
edit('Qt/src/NativeHudController.cpp','    auto &music = *m_music;\n    if (music.directory && music.directory != previous.directory) { music.leaveDirectory(false); }','''    auto &music = *m_music;
    if(music.archiveNowPlaying&&!music.player.roamActive&&!music.player.current.isEmpty()&&music.directory&&music.archivePlayingDirectory.lock()==music.directory&&music.directory!=previous.directory&&!previous.directory){\n        music.archivePlayingDirectory.reset();
        music.leaveDirectory(false);
        music.choose(music.archiveReturnItem.isEmpty()?previous.item:music.archiveReturnItem,false,false);
        m_scene.mode("archive");frame["mode"]="archive";music.frame["mode"]="archive";
        modal.clear();closing=false;lyricsMode=false;music.changed();m_host->invalidate();return true;
    }
    if (music.directory && music.directory != previous.directory) { music.leaveDirectory(false); }''')

edit('Qt/src/MusicLibrary.cpp','        player.play(current, currentSongList());','        player.play(current, currentSongList());changed();')
edit('Qt/src/MusicLibrary.cpp','    player.play(current);','    player.play(current);changed();')
