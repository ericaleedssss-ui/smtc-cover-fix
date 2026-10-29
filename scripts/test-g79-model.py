"""Compile the production archive adapter with asynchronous explicit domain fixtures."""
from pathlib import Path
import argparse,os,tempfile,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('--qt-prefix',type=Path,required=True);a=p.parse_args();repo=Path(__file__).resolve().parents[1];qt=a.qt_prefix.resolve();inc=qt/'include/x86_64-linux-gnu/qt6';lib=qt/'lib/x86_64-linux-gnu';env={**os.environ,'LD_LIBRARY_PATH':str(lib)}
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp)
 for n in ['MusicLibrary.h','NativeHud.h']:shutil.copyfile(repo/'scripts/fixtures/g71'/n,d/n)
 for n in ['PlaylistShowcase.cpp','PlaylistShowcase.h']:shutil.copyfile(repo/'maintained/Qt/src'/n,d/n)
 for n in ['MusicData.cpp','MusicData.h']:shutil.copyfile(repo.parent/'upstream/Qt/src'/n,d/n)
 f=(d/'MusicLibrary.h').read_text();f=f.replace('quint64 account=1;', 'quint64 account=1;quint64 revision=1;QHash<QString,QJsonObject> details;')
 f=f.replace('void invalidate(){','void invalidateMetadata(){}void invalidate(){')
 f=f.replace('MusicApi *m_api=nullptr;', 'QString mode="all";MusicApi *m_api=nullptr;')
 f=f.replace('    QJsonArray libraryItems()const', '    QString libraryName()const{return "收藏歌单";}\n    int libraryIndex()const {for(int i=0;i<lists[selectedLane].size();++i)if(lists[selectedLane][i].toObject()["key"]==current["key"])return i;return 0;}\n    void selectResult(int i,int lane,bool){selectedLane=lane;current=lists[lane][i].toObject();++revision;emit invalidated();}\n    QJsonArray libraryItems()const')
 f=f.replace('void changed(){emit invalidated();}', 'void changed(){++revision;emit invalidated();}')
 (d/'MusicLibrary.h').write_text(f)
 (d/'checks.cpp').write_text(r'''
#include "PlaylistShowcase.h"
#include "MusicData.h"
#include <QCoreApplication>
#include <QTest>
#include <QSignalSpy>
#include <cassert>
void MusicLibrary::ensureLikedIDs(Completion cb){likedIDs=QJsonArray{};if(cb)cb(true);}
int MusicPlayer::enqueueMany(const QJsonArray &a){for(const auto &v:a)queue.append(v);return a.size();}
QJsonArray MusicLibrary::directoryQueue()const{return {};}
int main(int argc,char**argv){QCoreApplication app(argc,argv);Host host;MusicLibrary music(&host);NativeHud hud;
 auto a=MusicData::item("playlist","101","A","Creator"),b=MusicData::item("playlist","102","B","Creator"),c=MusicData::item("playlist","103","C","Creator");a["creatorID"]="7";a["cover"]="https://example.invalid/playlist-art";b["cover"]="https://example.invalid/b";c["cover"]="https://example.invalid/c";music.lists[2]={a,b,c};music.current=a;music.directory.reset();
 bool fail=false;bool missingDuration=false;int mutations=0;
 music.api.fixture=[&](QString route,QJsonObject p)->MusicReply{
  if(route=="/playlist/subscribe"||route=="/album/sub"){mutations++;return {QJsonObject{{"code",200}}, {}};}
  if(fail)return {{},"failed"};
  if(route=="/user/detail")return {QJsonObject{{"profile",QJsonObject{{"avatarUrl","https://example.invalid/real-user-avatar"}}}}, {}};
  if(route=="/artist/detail")return {QJsonObject{{"data",QJsonObject{{"artist",QJsonObject{{"avatar","https://example.invalid/real-artist-avatar"}}}}}}, {}};
  if(route=="/artists")return {QJsonObject{{"artist",QJsonObject{{"img1v1Url","https://example.invalid/real-artist-avatar"}}}}, {}};
  if(route=="/fixture/detail"){auto item=p["uid"].toObject();item["description"]="Real fixture description";item["trackCount"]=3;auto song=MusicData::item("song","1","First","Artist");song["duration"]=60000;if(item["kind"]=="album"){auto second=MusicData::item("song","2","Second","Artist");second["duration"]=120000;auto third=MusicData::item("song","3","Third","Artist");third["duration"]=missingDuration?0:180000;item["artists"]=QJsonArray{QJsonObject{{"id","5"},{"name","Artist"}},QJsonObject{{"id","6"},{"name","Second Artist"}}};return {QJsonArray{item,QJsonArray{song,second,third},QJsonArray{}}, {}};}return {QJsonArray{item,QJsonArray{song},QJsonArray{"1","2","3"}}, {}};}
  if(route=="/fixture/songs"){auto s=MusicData::item("song","2","Second","Artist");s["duration"]=120000;auto t=MusicData::item("song","3","Third","Artist");t["duration"]=180000;return {QJsonArray{s,t}, {}};}
  assert(false);return{};
 };
 PlaylistShowcase model(&music,&hud);model.operate("play");model.operate("play");QTest::qWait(30);
 assert(model.info()["identityAvatar"]=="https://example.invalid/real-user-avatar");assert(model.info()["cover"]==a["cover"].toString());assert(music.player.plays==1&&music.player.queue.size()==3&&music.player.queue[1].toObject()["deferred"].toBool());assert(music.current["kind"]=="playlist"&&!music.directory);
 assert(!model.info()["durationLabel"].toString().contains("1 小时"));model.preview(1);QTest::qWait(20);assert(model.songs().size()==3&&model.songs()[1].toMap()["title"]=="Second");assert(model.info()["durationLabel"].toString().contains("6 分钟"));
 model.playSong(2);assert(music.player.current["id"]=="3"&&music.player.index==2);model.operate("shuffle");assert(music.player.mode=="shuffle"&&music.player.queue.size()==3);model.operate("append");assert(music.player.queue.size()==6);
 assert(model.recordNeighbour(1)["key"]==b["key"].toString());assert(model.recordNeighbour(-1)["key"]==c["key"].toString());model.openCover(b["key"].toString());QTest::qWait(20);assert(music.current["key"]==b["key"]&&model.info()["key"]==b["key"].toString());
 model.operate("subscribe");QTest::qWait(20);assert(model.info()["subscribed"].toBool()&&mutations==1);model.operate("subscribe");assert(mutations==1);model.confirmUnsubscribe();QTest::qWait(20);assert(!model.info()["subscribed"].toBool()&&mutations==2);
 // One continuous archive sequence crosses owned, subscribed and album lanes in both directions.
 auto collected=MusicData::item("playlist","201","Collected","Other"),album=MusicData::item("album","301","Album","Artist");
 music.lists[3]={collected};music.lists[4]={album};music.changed();
 model.openCover(c["key"].toString());QTest::qWait(20);assert(model.recordNeighbour(1)["key"]==collected["key"].toString());
 model.openCover(collected["key"].toString());QTest::qWait(20);assert(music.selectedLane==3&&model.recordNeighbour(1)["key"]==album["key"].toString());
 model.openCover(album["key"].toString());QTest::qWait(20);assert(music.selectedLane==4&&model.info()["kind"]=="album"&&model.songs().size()==3);
 assert(model.recordNeighbour(1)["key"]==a["key"].toString()&&model.recordNeighbour(-1)["key"]==collected["key"].toString());
 assert(model.info()["durationLabel"].toString()=="6 分钟"&&model.info()["identityAvatar"]=="https://example.invalid/real-artist-avatar");
 model.operate("shuffle");assert(music.player.mode=="shuffle"&&music.player.queue.size()==3);
 QString action;QObject::connect(&model,&PlaylistShowcase::navigate,[&](QString value){action=value;});model.operate("details");assert(action=="music:directory");
 model.operate("creator");assert(action=="music:artist:0");model.openIdentity("6");assert(action=="music:artist:1");model.openIdentity("wrong");assert(action=="music:artist:1");model.retryIdentityAvatar();QTest::qWait(20);assert(model.info()["identityAvatar"]=="https://example.invalid/real-artist-avatar");
 model.operate("play");assert(music.player.queue.first().toObject()["queueSource"].toObject()["kind"]=="album");
 missingDuration=true;model.refresh();QTest::qWait(30);assert(model.info()["durationLabel"].toString()=="6 分钟");missingDuration=false;
 model.operate("subscribe");model.confirmUnsubscribe();QTest::qWait(20);assert(music.lists[4].isEmpty()&&music.api.requests.last().first=="/album/sub");assert(!model.recordNeighbour(-1).isEmpty());
 model.openCover(b["key"].toString());QTest::qWait(20);
 QSignalSpy changes(&model,&PlaylistShowcase::changed);++music.revision;music.player.changed();assert(changes.count()==0);
 model.operate("copy");assert(host.copied.contains("102"));
 // An old metadata response cannot replace a newly selected card, including after account changes.
 music.selectResult(0,2,false);music.selectResult(2,2,false);QTest::qWait(20);assert(model.info()["key"]==c["key"].toString());
 fail=true;model.refresh();QTest::qWait(20);assert(!model.busy()&&!model.status().isEmpty()&&model.info()["loadFailed"].toBool()&&!model.info()["loaded"].toBool());
 music.account++;music.uid="99";music.changed();QTest::qWait(20);assert(model.info()["key"]==c["key"].toString());
 qInfo("G79 actual adapter passed: container artwork and cross-lane owned/collected/album browsing, deferred full queue/provenance, shuffle/append/song preview, total-duration honesty, real selection, confirmed subscriptions, copy and stale-response isolation.");
}
''')
 flags=['-I'+str(d),'-I'+str(inc)]+['-I'+str(inc/n) for n in ['QtCore','QtNetwork','QtTest']];mocs=[]
 for n in ['MusicLibrary.h','PlaylistShowcase.h']:
  target=d/('moc_'+n+'.cpp');subprocess.run([str(qt/'lib/qt6/libexec/moc'),*flags,str(d/n),'-o',str(target)],check=True,env=env);mocs.append(str(target))
 binary=d/'checks';subprocess.run(['g++','-std=c++20','-fPIC',*flags,str(d/'PlaylistShowcase.cpp'),str(d/'MusicData.cpp'),str(d/'checks.cpp'),*mocs,'-L'+str(lib),'-lQt6Core','-lQt6Network','-lQt6Test','-o',str(binary)],env=env,check=True);subprocess.run([str(binary)],env=env,check=True)
