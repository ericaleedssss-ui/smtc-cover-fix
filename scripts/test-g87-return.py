"""Compile the production saved-page return method against explicit history fixtures."""
from pathlib import Path
import argparse,os,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1];qt=a.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu'
s=(root.parent/'upstream/Qt/src/NativeHudController.cpp').read_text();start=s.index('bool NativeHud::restorePage()');end=s.index('\n/**',start);code=s[start:end]
harness=r'''
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QString>
#include <memory>
#include <cassert>
struct MusicDirectory {QJsonObject item;};
struct MusicLibrary {
 QJsonObject current,frame,archiveReturnItem;QJsonArray playContext;
 std::shared_ptr<MusicDirectory> directory;std::weak_ptr<MusicDirectory> archivePlayingDirectory;
 bool archiveNowPlaying=true,directoryInfo=true;int selectedLane=2,selectedPhysical=0;
 struct {bool roamActive=false;QJsonObject current{{"kind","song"},{"id","1"}};}player;
 quint64 accountGeneration()const{return 1;}
 void leaveDirectory(bool){directory.reset();directoryInfo=false;}
 void choose(QJsonObject v,bool,bool){current=v;}
 void showDirectoryInfo(){directoryInfo=true;}
 void selectionRequested(int,QJsonObject){}void changed(){}
};
struct ViewReturn {
 QJsonObject item;std::shared_ptr<MusicDirectory> directory;QJsonArray context;
 QString target,mode="archive",modal,tab="overview",artistTab="songs",query,groupBy,activeGroup,focus;
 int lane=2,physical=0,trackOffset=0,bodyOffset=0,listOffset=4,collection=0;bool directoryInfo=false,lyrics=false;quint64 account=1;
};
struct NativeHud {
 MusicLibrary *m_music;QVector<ViewReturn> m_viewBack;QJsonObject frame;
 struct {QString value;void mode(QString s){value=s;}}m_scene;
 struct Host {void invalidate(){}}host,*m_host=&host;
 QString modal,tab,artistTab,query,groupBy,activeGroup,focusAction;bool closing=false,lyricsMode=false;
 int trackOffset=0,bodyOffset=0,listOffset=0,musicCollection=0;
 explicit NativeHud(MusicLibrary *m):m_music(m){}
 void openModal(QString s){modal=s;}bool restorePage();
};
'''
checks=r'''
int main(){
 const QJsonObject collection{{"kind","playlist"},{"key","netease:playlist:10"},{"title","Playlist"}};
 // Previously playing elsewhere does not hijack an unplayed discovery playlist.
 MusicLibrary m;m.directory=std::make_shared<MusicDirectory>();m.directory->item=collection;m.current=collection;
 NativeHud h(&m);ViewReturn previous;previous.item={{"kind","album"},{"key","old"}};previous.target="netease:playlist:10";previous.modal="discover";h.m_viewBack={previous};
 assert(h.restorePage());assert(h.modal=="discover"&&h.listOffset==4&&m.current==previous.item&&!m.directory);
 // Playback started in this exact folder deliberately returns to home now-playing.
 m.directory=std::make_shared<MusicDirectory>();m.directory->item=collection;m.current=collection;m.directoryInfo=true;m.archivePlayingDirectory=m.directory;m.archiveReturnItem=collection;h.m_viewBack={previous};
 assert(h.restorePage());assert(h.modal.isEmpty()&&h.frame["mode"]=="archive"&&m.current==collection&&!m.directory&&m.archivePlayingDirectory.expired());
 // Even reopening the same playlist creates a new browsing session. It is not
 // the folder where playback was started, so normal discovery return survives.
 auto played=std::make_shared<MusicDirectory>();played->item=collection;m.archivePlayingDirectory=played;
 m.directory=std::make_shared<MusicDirectory>();m.directory->item=collection;m.current=collection;m.directoryInfo=true;h.m_viewBack={previous};
 assert(h.restorePage());assert(h.modal=="discover"&&h.listOffset==4&&m.current==previous.item);
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);(d/'checks.cpp').write_text(harness+code+checks);env={**os.environ,'LD_LIBRARY_PATH':str(lib)};binary=d/'checks'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),str(d/'checks.cpp'),'-L'+str(lib),'-lQt6Core','-o',str(binary)],check=True,env=env)
 subprocess.run([str(binary)],check=True,env=env)
 print('G87 actual restorePage passed: discovery position retained, exact played directory returns home, reopening same ID cannot inherit old playback navigation.')
