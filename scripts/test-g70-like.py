"""Execute the production like toggle with success/failure/account fixtures."""
from pathlib import Path
import argparse,subprocess,tempfile,os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();src=a.source.resolve();q=a.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(src/'Qt/src/MusicMutation.cpp').read_text(encoding='utf-8');helper=s[s.index('QJsonArray without('):s.index('\n}\n\nbool MusicLibrary::canMutate')]
method=s[s.index('void MusicLibrary::like('):s.index('\nvoid MusicLibrary::subscribe(')]
fixture=r'''
#include "MusicData.h"
#include <QCoreApplication>
#include <QTimer>
#include <QDebug>
#include <optional>
#include <array>
#include <functional>
struct MusicReply {QJsonValue value;QString error;bool ok()const{return error.isEmpty();}};
struct API {QJsonArray ids;bool reject=false;void call(QString,QJsonArray,std::function<void(MusicReply)> cb,std::function<bool()> valid){if(valid())cb({ids,reject?"denied":""});}};
struct MusicLibrary {
 QString uid="42",provider="netease",status;QJsonObject current;std::array<QJsonArray,5> lists;std::array<int,5> totals{};int likedCursor=0;std::optional<QJsonArray> likedIDs;QHash<QString,QString> subscriptionStates;quint64 m_accountGeneration=1;API api;QJsonObject request;bool reject=false;int changes=0,calls=0;
 void changed(){++changes;}QString providerName(){return "NetEase";}std::function<bool()> valid(quint64 a,const quint64 *b){return[a,b]{return a==*b;};}
 void mutate(QString,QJsonObject args,std::function<void(QJsonObject)> success){++calls;request=args;if(!reject)success({});changed();}
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
 const int before=m.calls;m.uid.clear();m.like(song);check(m.calls==before&&m.status.contains("登录"),"logged-out like makes no mutation and reports login requirement");
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'like.cpp';cpp.write_text(fixture+helper+method+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-O2','-std=c++20','-fPIC','-I'+str(src/'Qt/src'),'-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),str(src/'Qt/src/MusicData.cpp'),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
