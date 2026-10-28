"""Execute the production like toggle with success/failure/account fixtures."""
from pathlib import Path
import argparse,subprocess,tempfile,os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();src=a.source.resolve();q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(src/'Qt/src/MusicMutation.cpp').read_text(encoding='utf-8');helper=s[s.index('QJsonArray without('):s.index('\n}\n\nbool MusicLibrary::canMutate')]
method=s[s.index('void MusicLibrary::ensureLikedIDs('):s.index('\nvoid MusicLibrary::subscribe(')]
library=(src/'Qt/src/MusicLibrary.cpp').read_text(encoding='utf-8');pager=library[library.index('void MusicLibrary::loadLikedIDs('):library.index('\nvoid MusicLibrary::loadMoreSource(')]
fixture=r'''
#include "MusicData.h"
#include <QCoreApplication>
#include <QTimer>
#include <QDebug>
#include <optional>
#include <array>
#include <functional>
#include <QSet>
#include <QVector>
struct MusicReply {QJsonValue value;QString error;bool ok()const{return error.isEmpty();}};
struct API {
 QJsonArray ids,songs;bool reject=false,hold=false;int requests=0;QVector<std::function<void()>> pending;
 void call(QString operation,QJsonArray,std::function<void(MusicReply)> cb,std::function<bool()> valid){
  ++requests;const MusicReply reply{operation=="songs"?songs:ids,reject?"denied":""};auto deliver=[cb,valid,reply]{if(valid())cb(reply);};
  if(hold)pending.append(deliver);else deliver();
 }
 void flush(){auto copy=std::move(pending);pending.clear();for(const auto &cb:copy)cb();}
};
struct MusicLibrary {
 QString uid="42",provider="netease",status;QJsonObject current;std::array<QJsonArray,5> lists;std::array<int,5> totals{};int likedCursor=0;std::optional<QJsonArray> likedIDs;QHash<QString,QString> subscriptionStates;quint64 m_accountGeneration=1;API api;QJsonObject request;bool reject=false;int changes=0,calls=0;
 void changed(){++changes;}QString providerName(){return "NetEase";}std::function<bool()> valid(quint64 a,const quint64 *b){return[a,b]{return a==*b;};}
 void mutate(QString,QJsonObject args,std::function<void(QJsonObject)> success){++calls;request=args;if(!reject)success({});changed();}
 using Completion=std::function<void(bool)>;
 bool m_likedIDsLoading=false;quint64 m_likedIDsAccount=0;QString m_likedIDsError;QVector<Completion> m_likedIDWaiters;
 QString likedIDsError()const{return m_likedIDsError;}
 void ensureLikedIDs(Completion done={});
 int personalCompletions=0;std::array<bool,5> hasMore{};
 void completePersonal(int,QString={}){++personalCompletions;}
 void loadLikedIDs(int,quint64,QString);
 void like(QJsonObject);
};
'''
checks=r'''
void check(bool b,const char *s){if(!b)qFatal("FAIL %s",s);qInfo()<<"PASS"<<s;}
int main(int argc,char **argv){QCoreApplication app(argc,argv);MusicLibrary m;const auto song=MusicData::item("song","77");m.likedIDs=QJsonArray{};m.lists[1]={song};m.reject=true;m.like(song);
 check(m.request["id"]=="77"&&m.request["like"].toBool()&&m.likedIDs->isEmpty(),"server IDs determine like direction; failed write never paints an unconfirmed red heart");
 m.reject=false;m.like(song);check(m.likedIDs->size()==1&&m.lists[1].size()==1&&m.totals[1]==1,"confirmed like updates IDs, shelf and count without duplicate membership");
 m.reject=true;m.like(song);check(!m.request["like"].toBool()&&m.likedIDs->size()==1,"failed unlike retains the actual red-heart state");
 m.reject=false;m.like(song);check(m.likedIDs->isEmpty()&&m.lists[1].isEmpty()&&m.totals[1]==0,"confirmed unlike clears IDs, shelf and count");
 m.likedIDs.reset();m.api.ids={"77"};m.like(song);check(m.likedIDs&&m.likedIDs->isEmpty()&&!m.request["like"].toBool(),"unknown state fetches actual liked IDs before choosing toggle direction");
 m.likedIDs.reset();m.api.hold=true;m.api.ids={"77"};int ready=0;const int fetched=m.api.requests;
 m.ensureLikedIDs([&](bool ok){ready+=ok;});m.ensureLikedIDs([&](bool ok){ready+=ok;});m.like(song);
 check(m.api.requests==fetched+1&&!m.likedIDs,"G76 page initialization, shelf and click share one in-flight ID request");
 m.api.flush();check(ready==2&&m.likedIDs&&m.likedIDs->isEmpty()&&!m.request["like"].toBool(),"G76 queued click uses the fetched state and applies exactly one unlike");
 m.likedIDs.reset();m.api.ids={"77"};m.ensureLikedIDs();m.likedIDs=QJsonArray{"99"};m.api.flush();check(m.likedIDs==QJsonArray{"99"},"G76 late initial read never overwrites a newer confirmed cache");
 m.likedIDs.reset();m.api.ids={"77"};m.ensureLikedIDs();++m.m_accountGeneration;m.uid="other";m.api.flush();check(!m.likedIDs,"G76 old-account ID response is rejected");
 m.api.ids={"99"};m.ensureLikedIDs();m.api.flush();check(m.likedIDs==QJsonArray{"99"},"G76 the new account starts its own independent request");
 m.likedIDs.reset();m.api.reject=true;m.ensureLikedIDs();m.api.flush();check(!m.likedIDs&&!m.likedIDsError().isEmpty(),"G76 failed initial lookup stays unknown rather than an empty authoritative list");
 m.api.reject=false;m.api.ids={};m.ensureLikedIDs();m.api.flush();check(m.likedIDs&&m.likedIDs->isEmpty(),"G76 a deliberate retry can confirm an actually empty liked list");
 m.likedIDs.reset();m.api.hold=true;m.api.ids={"77"};m.api.songs={song};m.likedCursor=0;m.lists[1]={};const int pageFetches=m.api.requests;
 m.ensureLikedIDs();m.loadLikedIDs(1,m.m_accountGeneration,m.uid);check(m.api.requests==pageFetches+1,"G76 personal shelf joins the same initial request");
 m.api.flush();m.like(song);m.api.flush();check(m.likedIDs&&m.likedIDs->isEmpty()&&m.lists[1].isEmpty()&&m.totals[1]==0,"G76 late song metadata cannot undo an unlike or restore stale shelf totals");
 const int before=m.calls;m.uid.clear();m.like(song);check(m.calls==before&&m.status.contains("登录"),"logged-out like makes no mutation and reports login requirement");
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'like.cpp';cpp.write_text(fixture+helper+method+pager+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-O2','-std=c++20','-fPIC','-I'+str(src/'Qt/src'),'-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),str(src/'Qt/src/MusicData.cpp'),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
