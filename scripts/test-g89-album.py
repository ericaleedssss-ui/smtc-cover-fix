"""Compile the production playing-album action body with real item normalization."""
from pathlib import Path
import argparse,os,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();r=Path(__file__).resolve().parents[1];qt=a.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu';source=r.parent/'upstream/Qt/src'
s=(source/'NativeHudController.cpp').read_text();a0=s.index('    } else if (name == "song-album") {');b0=s.index('    } else if (name == "song-artist") {',a0);body=s[a0:].split('{',1)[1][:b0-a0-len(s[a0:].split('{',1)[0])-1]
harness=r'''
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <cassert>
#include "MusicData.h"
struct Music {QString provider="netease";QJsonObject current,destination;int entered=0;void enterDirectory(QJsonObject item){destination=item;++entered;}};
struct Player {QJsonObject current,state;QJsonArray queue;};
void album(Music &music,Player &player,QString &tab,int &trackOffset){
'''
checks=r'''
int main(){Music music;Player player;QString tab="songs";int offset=15;
 music.current={{"albumID","wrong"},{"album","Unrelated browser selection"}};
 player.current={{"albumID","8"},{"album","Actual album"},{"artist","Actual artist"},{"provider","netease"}};player.queue={player.current};player.state={{"position",12345},{"playing",true}};
 const auto track=player.current,state=player.state;const auto queue=player.queue;
 album(music,player,tab,offset);assert(music.entered==1&&music.destination["kind"]=="album"&&music.destination["id"]=="8"&&music.destination["title"]=="Actual album"&&tab=="overview"&&offset==0);
 assert(player.current==track&&player.state==state&&player.queue==queue);
 player.current.remove("albumID");album(music,player,tab,offset);assert(music.entered==1);
 player.current["albumID"]="0";album(music,player,tab,offset);assert(music.entered==1);
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);(d/'checks.cpp').write_text(harness+body+'}\n'+checks);env={**os.environ,'LD_LIBRARY_PATH':str(lib)};binary=d/'checks'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),'-I'+str(source),str(d/'checks.cpp'),str(source/'MusicData.cpp'),'-L'+str(lib),'-lQt6Core','-o',str(binary)],check=True,env=env);subprocess.run([str(binary)],check=True,env=env)
 print('G89 production album route passed: actual playing album, unrelated browsing selection ignored, missing/zero ID does not navigate, transport unchanged.')
