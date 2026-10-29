"""Compile the real followPlayback implementation against explicit navigation fixtures."""
from pathlib import Path
import argparse,os,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];source=root.parent/'upstream/Qt/src';qt=a.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu'
s=(source/'MusicDirectory.cpp').read_text(encoding='utf-8');start=s.index('void MusicLibrary::followPlayback(');code=s[start:]
# followPlayback is the final definition in the current pinned source.
assert code.rstrip().endswith('}') and code.count('void MusicLibrary::')==1
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp)
 harness=r'''
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <array>
#include <memory>
#include <cassert>
#include "MusicData.h"
struct MusicDirectory {std::shared_ptr<MusicDirectory> parent;QJsonObject item,parentItem;QJsonArray songs,ids;int cursor=0,index=0,anchor=0,parentPhysical=0,parentLane=0;};
struct MusicLibrary {
 QJsonObject current,frame;std::shared_ptr<MusicDirectory> directory;bool directoryInfo=false,directoryLoading=false;int selectedPhysical=0,selectedLane=2,m_directoryGeneration=0,selected=0;
 std::array<QVector<int>,5> physicalSlots;
 struct {bool roamActive=false;QJsonArray queue;} player;
 void selectDirectory(int i,QString,QString,int){++selected;current=directory->songs[i].toObject();}
 void followPlayback(QJsonObject value);
};
'''
 checks=r'''
int main(){MusicLibrary m;auto album=MusicData::item("album","1","Album","Artist");auto song=MusicData::item("song","2","Next","Artist");m.player.queue={song};m.frame={{"mode","archive"},{"selected",0}};m.current=album;
 m.followPlayback(song);assert(m.current==album&&!m.directory&&m.frame["mode"]=="archive"&&m.selected==0);
 m.current={};m.followPlayback(song);assert(m.current.isEmpty()&&!m.directory&&m.selected==0);
 // Album/podcast detail lists keep their browsing folder while playing.
 m.directory=std::make_shared<MusicDirectory>();m.directory->item={{"kind","album"}};m.directoryInfo=true;m.current=album;m.frame["mode"]="detail";auto folder=m.directory;m.followPlayback(song);assert(m.directory==folder&&m.current==album&&m.selected==0);
 m.directory.reset();m.directoryInfo=false;
 // Existing detail browsing still follows the playing track.
 m.frame["mode"]="detail";m.followPlayback(song);assert(m.current==song&&m.directory&&m.selected==1&&m.frame["mode"]=="detail");
 // Roaming is exempt from the landing-page guard and keeps its original route.
 MusicLibrary fm;fm.frame={{"mode","archive"},{"selected",0}};fm.player.roamActive=true;fm.player.queue={song};fm.followPlayback(song);assert(fm.selected==1&&fm.frame["mode"]=="detail");
}
'''
 (d/'checks.cpp').write_text(harness+code+checks,encoding='utf-8');env={**os.environ,'LD_LIBRARY_PATH':str(lib)}
 binary=d/'checks';subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),'-I'+str(source),str(d/'checks.cpp'),str(source/'MusicData.cpp'),'-L'+str(lib),'-lQt6Core','-o',str(binary)],check=True,env=env);subprocess.run([str(binary)],check=True,env=env)
 print('G85 production followPlayback passed: archive and empty archive retained, detail follow and roaming unchanged.')
