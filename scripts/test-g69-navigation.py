"""Execute the production detail-request helper with controlled out-of-order replies.
Only the API/domain boundary is a fixture; no real account is contacted.
"""
from pathlib import Path
import argparse,subprocess,tempfile,os
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--qt-prefix',type=Path,required=True);args=p.parse_args()
source=args.source.resolve();q=args.qt_prefix.resolve();inc=q/'include/x86_64-linux-gnu/qt6';lib=q/'lib/x86_64-linux-gnu'
s=(source/'Qt/src/MusicDirectory.cpp').read_text(encoding='utf-8');start=s.index('void MusicLibrary::loadDirectoryDetails()');end=s.index('\n/**',start);helper=s[start:end]
fixture=r'''
#include <QCoreApplication>
#include <QJsonObject>
#include <QJsonArray>
#include <QHash>
#include <QVector>
#include <QDebug>
#include <memory>
#include <functional>
#include <cstdlib>
struct MusicReply {QJsonValue value;QString error;bool ok()const{return error.isEmpty();}};
struct MusicDirectory {QJsonObject item;QJsonArray songs,ids;int cursor=0,index=0;bool detailsPending=true,openDetails=true;quint64 detailsGeneration=0;};
struct API {
 struct Request {std::function<void(MusicReply)> reply;std::function<bool()> valid;};QVector<Request> pending;
 void call(QString,QJsonArray,std::function<void(MusicReply)> cb,std::function<bool()> valid){pending.append({cb,valid});}
 void request(QString,QJsonObject,std::function<void(MusicReply)> cb,std::function<bool()> valid){pending.append({cb,valid});}
 void resolve(int i,MusicReply reply){auto r=pending.at(i);if(r.valid())r.reply(reply);}
};
namespace MusicData {
 int cursor(const QJsonArray &songs,const QJsonArray &){return songs.size();}
 QJsonObject withQueueSource(QJsonObject song,QJsonObject){return song;}
}
struct MusicLibrary {
 std::shared_ptr<MusicDirectory> directory;quint64 m_directoryGeneration=1;API api;bool directoryLoading=false,directoryInfo=true;QString provider="netease",status;QJsonObject current;QHash<QString,QJsonObject> details;int shown=0,changes=0;
 std::function<bool()> valid(quint64 token,const quint64 *generation){return [token,generation]{return token==*generation;};}
 void changed(){++changes;}void showDirectoryInfo(){++shown;current=directory->item;}void choose(QJsonObject){}
 void loadDirectoryDetails();
};
'''
checks=r'''
void require(bool condition,const char *message){if(!condition){qFatal("FAIL %s",message);}qInfo()<<"PASS"<<message;}
int main(int argc,char **argv){QCoreApplication app(argc,argv);MusicLibrary music;
 auto a=std::make_shared<MusicDirectory>();a->item={{"kind","playlist"},{"id","A"},{"key","A"},{"title","A"}};
 auto b=std::make_shared<MusicDirectory>();b->item={{"kind","playlist"},{"id","B"},{"key","B"},{"title","B"}};
 music.directory=a;music.loadDirectoryDetails();music.loadDirectoryDetails();require(music.api.pending.size()==1,"same loading folder does not issue duplicate detail requests");
 ++music.m_directoryGeneration;music.directory=b;music.loadDirectoryDetails();
 QJsonArray payload{a->item,QJsonArray{QJsonObject{{"id","songA"}}},QJsonArray{"songA"}};
 music.api.resolve(0,{payload,{}});require(a->detailsPending&&a->songs.isEmpty()&&music.shown==0,"late A reply cannot overwrite B and leaves A resumable");
 ++music.m_directoryGeneration;music.directory=a;music.loadDirectoryDetails();require(music.api.pending.size()==3,"return to cancelled A resumes its actual detail request");
 music.api.resolve(1,{QJsonArray{b->item,QJsonArray{},QJsonArray{}},{}});require(b->detailsPending&&music.shown==0,"late B reply cannot overwrite returned A");
 music.api.resolve(2,{payload,{}});require(!a->detailsPending&&!music.directoryLoading&&a->songs.size()==1&&a->cursor==1&&music.current["id"]=="A"&&music.shown==1,"resumed A completes its original folder with consistent metadata and songs");
 music.loadDirectoryDetails();require(music.api.pending.size()==3,"completed folder is reused without a new request");
 ++music.m_directoryGeneration;music.directory=b;music.loadDirectoryDetails();music.api.resolve(3,{{},"denied"});music.loadDirectoryDetails();require(!b->detailsPending&&!music.directoryLoading&&b->item["loadError"]=="denied"&&music.api.pending.size()==4,"failed request stops loading and does not create a retry loop");
}
'''
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);cpp=d/'navigation.cpp';cpp.write_text(fixture+helper+checks,encoding='utf-8');binary=d/'checks'
 subprocess.run(['g++','-std=c++20','-fPIC','-I'+str(inc),'-I'+str(inc/'QtCore'),str(cpp),'-L'+str(lib),'-Wl,-rpath,'+str(lib),'-lQt6Core','-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True,env={**os.environ,'LD_LIBRARY_PATH':str(lib)})
