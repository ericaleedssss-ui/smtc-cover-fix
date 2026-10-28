"""Execute production playlistTracks/playlistTracksPage using async mutation fixtures.
No account or external API is contacted; the batching code is extracted unchanged.
"""
from pathlib import Path
import argparse,subprocess,tempfile,os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args()
src=a.source.resolve();q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(src/'Qt/src/MusicMutation.cpp').read_text(encoding='utf-8');batch=s[s.index('void MusicLibrary::playlistTracks('):]
fixture=r'''
#include "MusicData.h"
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QTimer>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QThread>
#include <QDebug>
#include <array>
#include <memory>
#include <functional>
struct MusicDirectory {std::shared_ptr<MusicDirectory> parent;QJsonObject item;QJsonArray songs,ids;};
struct MusicLibrary:QObject {
 using Completion=std::function<void(bool)>;
 QString provider="netease";std::array<QJsonArray,5> lists;std::shared_ptr<MusicDirectory> directory;
 quint64 account=1;int calls=0,failAt=0,switchAt=0,peak=0;bool writeLoading=false;QVector<QJsonObject> requests;QStringList accepted;
 quint64 accountGeneration()const{return account;}bool canEditPlaylist(QJsonObject)const{return true;}
 void playlistTracks(QString,QJsonArray,Completion);void playlistTracksPage(QString,QJsonArray,int,quint64,Completion);
 void playlistTrack(QString id,QJsonObject song,bool,Completion done){mutate("/playlist/tracks",{{"pid",id},{"tracks",song["id"]},{"op","add"}},[](QJsonObject){},done);}
 void mutate(QString route,QJsonObject values,std::function<void(QJsonObject)> success,Completion done){
  if(writeLoading)qFatal("concurrent batch write");writeLoading=true;++calls;requests.append(values);peak=std::max(peak,int(values["tracks"].toString().split(',').size()));
  const int request=calls;
  QTimer::singleShot(0,this,[this,request,values,success,done]{bool ok=request!=failAt;if(ok){accepted.append(values["tracks"].toString().split(','));success({});}if(request==switchAt)++account;writeLoading=false;if(done)done(ok);});
 }
};
'''
checks=r'''
void require(bool good,const char *s){if(!good)qFatal("FAIL %s",s);qInfo()<<"PASS"<<s;}
void settle(MusicLibrary &m){QElapsedTimer t;t.start();while(m.writeLoading&&t.elapsed()<8000){QCoreApplication::processEvents();QThread::msleep(1);}require(!m.writeLoading,"batch chain finishes within deadline");}
int main(int argc,char **argv){QCoreApplication app(argc,argv);MusicLibrary m;auto playlist=MusicData::item("playlist","6501","Owned");m.lists[2]={playlist};
 QJsonArray songs;QStringList expected;for(int i=0;i<4079;++i){const auto id=QString::number(650000+i);songs.append(MusicData::item("song",id));expected.append(id);}
 int completions=0;bool result=false;auto done=[&](bool ok){++completions;result=ok;};
 m.playlistTracks("6501",songs,done);require(completions==0&&m.writeLoading,"collection does not report success before its async writes finish");settle(m);
 require(result&&completions==1&&m.calls==41&&m.peak==100&&m.accepted==expected,"4,079-song collection writes every ID exactly once in 41 sequential bounded batches");
 for(const auto &r:m.requests)require(r["pid"]=="6501"&&r["op"]=="add","every batch retains the exact destination and add operation");
 m.calls=0;m.failAt=2;m.accepted.clear();m.requests.clear();completions=0;m.playlistTracks("6501",songs,done);settle(m);
 require(!result&&completions==1&&m.calls==2&&m.accepted==expected.mid(0,100),"failure in the second batch stops later writes and reports failure once");
 m.calls=0;m.failAt=0;m.accepted.clear();completions=0;m.playlistTracks("6501",songs,done);settle(m);
 require(result&&completions==1&&m.accepted==expected,"deliberate retry submits the full captured selection");
 m.calls=0;m.switchAt=1;m.accepted.clear();completions=0;m.playlistTracks("6501",songs,done);settle(m);
 require(!result&&completions==1&&m.calls==1,"account change stops the collection chain before the next batch");
 m.directory=std::make_shared<MusicDirectory>();m.directory->item=playlist;
 m.calls=0;m.switchAt=0;m.accepted.clear();completions=0;m.playlistTracks("6501",MusicData::slice(songs,0,101),done);settle(m);
 require(result&&completions==1&&m.calls==2&&m.accepted==expected.mid(0,101),"101-song boundary executes a 100-song batch and the existing single-song path");
 m.playlistTracks("6501",MusicData::slice(songs,0,100),done);settle(m);require(m.directory->songs.size()==100&&m.directory->ids.size()==100,"retry preserves unique cached membership for successful bulk writes");
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'collection.cpp';cpp.write_text(fixture+batch+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-O2','-std=c++20','-fPIC','-I'+str(src/'Qt/src'),'-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),str(src/'Qt/src/MusicData.cpp'),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
