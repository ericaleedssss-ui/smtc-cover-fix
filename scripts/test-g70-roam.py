"""Run unchanged production FM session methods with a controlled API/audio boundary."""
from pathlib import Path
import argparse,subprocess,tempfile,os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();src=a.source.resolve();q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(src/'Qt/src/MusicPlayer.cpp').read_text(encoding='utf-8');start=s.index('void MusicPlayer::startRoam(');end=s.index('    if (queue.isEmpty())',s.index('void MusicPlayer::next(',start));production=s[start:end]+'}\n'
fixture=r'''
#include "MusicData.h"
#include <QCoreApplication>
#include <QPointer>
#include <QVector>
#include <QDebug>
#include <optional>
#include <functional>
struct MusicReply {QJsonValue value;QString error;bool ok()const{return error.isEmpty();}};
struct MusicApi {using Valid=std::function<bool()>;QString provider="netease";struct Request{QString route;QJsonObject args;std::function<void(MusicReply)> cb;Valid valid;};QVector<Request> requests;
 void request(QString r,QJsonObject a,std::function<void(MusicReply)> cb,Valid v){requests.append({r,a,cb,v});}
 void complete(int i,MusicReply reply){auto r=requests.at(i);if(r.valid())r.cb(reply);}
};
struct MusicPlayer:QObject {
 MusicApi *m_api;QJsonArray queue,m_roamSavedQueue;QJsonObject current,m_roamSavedCurrent,state;int index=-1,m_roamSavedIndex=-1;QString mode="all",status,roamStatus,m_roamUid,m_roamSavedMode;bool roamActive=false,roamLoading=false,m_roamSavedPaused=false,m_roamInternalPlay=false,m_resumePaused=false;quint64 m_roamGeneration=0,m_generation=0;double m_roamSavedPosition=0,m_resumePosition=0;MusicApi::Valid m_roamAccountValid;int changes=0,starts=0,plays=0;
 explicit MusicPlayer(MusicApi *api):m_api(api){}
 void changed(){++changes;}void roamSongStarted(){++starts;}void setPaused(bool p){state["playing"]=!p;}
 void play(QJsonObject song,std::optional<QJsonArray> source=std::nullopt,std::optional<int> at=std::nullopt){++plays;++m_generation;current=song;if(source)queue=*source;if(at)index=*at;}
 void startRoam(QString,MusicApi::Valid);void fetchRoam();void retryRoam();void dislikeRoam();void leaveRoam(bool);void next(int,bool=false);
};
'''
checks=r'''
void check(bool b,const char *m){if(!b)qFatal("FAIL %s",m);qInfo()<<"PASS"<<m;}
MusicReply picks(int id){return {QJsonObject{{"data",QJsonArray{QJsonObject{{"id",id},{"name","FM pick"},{"artists",QJsonArray{QJsonObject{{"id",7},{"name","Artist"}}}},{"album",QJsonObject{{"id",8},{"name","Album"}}}}}}}, {}};}
int main(int argc,char **argv){QCoreApplication app(argc,argv);MusicApi api;MusicPlayer p(&api);auto normal=MusicData::item("song","42");p.queue={normal,MusicData::item("song","43")};p.current=normal;p.index=0;p.state={{"playing",false},{"position",12345}};const auto saved=p.queue;bool account=true;
 p.startRoam("uid",[&]{return account;});check(p.roamActive&&p.roamLoading&&api.requests.size()==1&&api.requests[0].route=="/personal/fm/mode","FM starts through the real personalized service and saves ordinary context");
 api.complete(0,picks(700));check(p.current["id"]=="700"&&p.roamActive&&p.starts==1&&!p.roamLoading,"first station response starts one real song and invokes existing lyric navigation");
 p.next(1);check(api.requests.size()==2&&api.requests[1].route=="/personal/fm/mode","exhausted station refills from the service, without static grid or dislike feedback");api.complete(1,picks(701));check(p.current["id"]=="701"&&p.starts==2,"next recommendation continues the session");
 p.dislikeRoam();check(api.requests.size()==3&&api.requests[2].route=="/fm_trash"&&api.requests[2].args["id"]=="701","dislike captures the actual current FM song for real feedback");
 p.next(1);check(api.requests.size()==3&&p.roamLoading,"next during pending feedback cannot invalidate its completion and strand loading");
 api.complete(2,{{},"rejected"});check(!p.roamLoading&&p.current["id"]=="701"&&api.requests.size()==3,"rejected dislike retains the song and releases loading for retry");
 p.dislikeRoam();api.complete(3,{QJsonObject{}, {}});check(api.requests.size()==5&&api.requests[4].route=="/personal/fm/mode","confirmed dislike fetches a fresh recommendation");api.complete(4,picks(702));check(p.current["id"]=="702","confirmed feedback advances to the new station pick");
 p.next(1);const int late=api.requests.size()-1;p.leaveRoam(true);check(!p.roamActive&&!p.roamLoading&&p.queue==saved&&p.current==normal&&p.index==0&&p.mode=="all"&&p.m_resumePosition==12345&&p.m_resumePaused,"exit restores exact ordinary queue, song, index, mode, position and paused state");api.complete(late,picks(999));check(p.queue==saved&&p.current==normal,"late FM replies after exit cannot replace restored playback");
 p.startRoam("uid",[&]{return account;});const int pending=api.requests.size()-1;account=false;api.complete(pending,picks(900));check(p.current==normal,"account-invalid FM response cannot play a recommendation");p.leaveRoam(false);
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'roam.cpp';cpp.write_text(fixture+production+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-O2','-std=c++20','-fPIC','-I'+str(src/'Qt/src'),'-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),str(src/'Qt/src/MusicData.cpp'),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
