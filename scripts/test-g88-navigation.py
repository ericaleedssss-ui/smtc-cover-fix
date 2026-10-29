"""Compile production global now-playing navigation with real provenance normalization."""
from pathlib import Path
import argparse,os,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();r=Path(__file__).resolve().parents[1];qt=a.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu'
code=(r/'maintained/G88-open-playing.cppfrag').read_text()
assert code in (r.parent/'upstream/Qt/src/NativeHudController.cpp').read_text()
harness=r'''
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QString>
#include <memory>
#include <cassert>
#include "MusicData.h"
struct MusicDirectory {QJsonObject item;};
struct MusicLibrary {
 struct {QJsonObject current,state;QJsonArray queue;bool roamActive=false;int index=1;QString mode="shuffle";}player;
 QJsonObject current,frame,archiveReturnItem;std::shared_ptr<MusicDirectory> directory;std::weak_ptr<MusicDirectory> archivePlayingDirectory;bool archiveNowPlaying=false;int changes=0;
 void leaveDirectory(bool){directory.reset();}void changed(){++changes;}
};
struct NativeHud {
 MusicLibrary *m_music;QJsonObject frame;QString modal,focusAction,hoveredLink;
 bool closing=false,lyricsMode=false,queueOpen=false,commentsOpen=false;QVector<int> m_modalBack{1};int oldLyricsCalls=0;
 struct {QString value;bool viewerClosed=false;void mode(QString s){value=s;}void viewerKey(QString){viewerClosed=true;}}m_scene;
 struct Host {void invalidate(){}}host,*m_host=&host;
 explicit NativeHud(MusicLibrary *m):m_music(m){}
 void closeModal(bool){closing=true;}void closeComments(){commentsOpen=false;}
 void openPlayingSong(bool lyrics){if(lyrics)++oldLyricsCalls;}
 void openNowPlaying();
};
'''
checks=r'''
int main(){
 MusicLibrary m;NativeHud h(&m);h.modal="settings";h.openNowPlaying();assert(h.modal=="settings"&&!m.archiveNowPlaying&&m.changes==0);
 const auto origin=MusicData::item("playlist","17","Playback source",{},"netease");
 m.player.current=MusicData::withQueueSource(MusicData::item("song","1","Song","Artist","netease"),origin);m.player.queue={m.player.current,MusicData::item("song","2","Next","Artist","netease")};m.player.state={{"playing",true},{"position",12345}};
 const auto song=m.player.current,transport=m.player.state;const auto queue=m.player.queue;
 m.current=MusicData::item("album","99","Unrelated browsing",{},"netease");m.directory=std::make_shared<MusicDirectory>();m.directory->item=m.current;h.commentsOpen=true;h.lyricsMode=true;h.queueOpen=true;h.frame["viewer"]=true;
 h.openNowPlaying();assert(m.archiveNowPlaying&&!m.directory&&m.archiveReturnItem["id"]=="17"&&m.archivePlayingDirectory.expired());
 assert(h.modal.isEmpty()&&!h.closing&&!h.commentsOpen&&!h.lyricsMode&&!h.queueOpen&&h.m_modalBack.isEmpty()&&h.frame["mode"]=="archive"&&h.m_scene.viewerClosed);
 assert(m.player.current==song&&m.player.queue==queue&&m.player.state==transport&&m.player.index==1&&m.player.mode=="shuffle");
 h.openNowPlaying();assert(m.player.current==song&&m.player.queue==queue&&m.player.state==transport);
 m.player.roamActive=true;m.archiveNowPlaying=false;h.openNowPlaying();assert(h.oldLyricsCalls==1&&!m.archiveNowPlaying&&m.player.roamActive&&m.player.queue==queue);
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);(d/'checks.cpp').write_text(harness+code+checks);env={**os.environ,'LD_LIBRARY_PATH':str(lib)};binary=d/'checks';source=r.parent/'upstream/Qt/src'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),'-I'+str(source),str(d/'checks.cpp'),str(source/'MusicData.cpp'),'-L'+str(lib),'-lQt6Core','-o',str(binary)],check=True,env=env);subprocess.run([str(binary)],check=True,env=env)
 print('G88 production navigation passed: global entry from another folder/settings, real playback origin, unchanged song/queue/position/mode, repeated entry, empty and FM behavior.')
