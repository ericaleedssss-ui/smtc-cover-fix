#include "PlaylistMagazine.h"
#include "MusicData.h"
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QThread>
#include <QSignalSpy>
#include <QAbstractItemModelTester>
#include <QTcpServer>
#include <QTcpSocket>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <cstdlib>
void require(bool good,const char *s){if(!good){qCritical()<<"FAIL"<<s;std::exit(1);}qInfo()<<"PASS"<<s;}
void events(int ms=40){QElapsedTimer t;t.start();while(t.elapsed()<ms){QCoreApplication::processEvents();QThread::msleep(1);}}
QJsonObject song(int n){auto s=MusicData::item("song",QString::number(n),"Song "+QString::number(n),"Artist");s["album"]="Album";s["duration"]=240000;return s;}
QJsonArray MusicLibrary::directoryQueue()const{return directory?MusicData::withQueueSource(directory->songs,directory->item):QJsonArray();}
int main(int argc,char **argv){
    QCoreApplication app(argc,argv);Host host;MusicLibrary music(&host);NativeHud hud;
    auto a=std::make_shared<MusicDirectory>();a->item=MusicData::item("playlist","123","Collection A","Owner");a->item["creatorID"]="42";a->item["cover"]="https://example.org/a.jpg";
    for(int i=0;i<4080;++i){a->songs.append(song(i+100));a->ids.append(QString::number(i+100));}a->cursor=4080;a->item["trackCount"]=4080;music.directory=a;
    for(int i=0;i<10;++i){auto s=MusicData::item(i==9?"album":"playlist",QString::number(2000+i),"Actual collection "+QString::number(i));s["cover"]="https://example.org/"+QString::number(i)+".jpg";music.lists[i==9?4:2].append(s);}
    music.api.fixture=[](QString route,QJsonObject)->MusicReply{if(route=="/fixture/likedIDs")return{QJsonArray{"100","101","102"},{}};return{QJsonObject{{"total",0}},{}};};
    PlaylistMagazine model(&music,&hud);QAbstractItemModelTester tester(&model,QAbstractItemModelTester::FailureReportingMode::Fatal);
    QSignalSpy resets(&model,&QAbstractItemModel::modelReset);QSignalSpy inserts(&model,&QAbstractItemModel::rowsInserted);
    require(model.rowCount()==4080&&model.covers().size()==2,"4,080 real model rows, only two adjacent real collection covers");
    require(!model.data(model.index(0),PlaylistMagazine::HeartKnown).toBool(),"G76 unknown initial heart state is explicit, not silently unliked");
    events();require(model.data(model.index(0),PlaylistMagazine::Heart).toBool()&&model.data(model.index(1),PlaylistMagazine::Heart).toBool()&&model.data(model.index(2),PlaylistMagazine::Heart).toBool(),"G76 multiple existing likes appear automatically before any click");
    require(model.data(model.index(3),PlaylistMagazine::HeartKnown).toBool()&&!model.data(model.index(3),PlaylistMagazine::Heart).toBool()&&resets.count()==0,"G76 authoritative response updates heart roles without resetting the song model");
    int likeLoads=0;for(const auto &r:music.api.requests)if(r.first=="/fixture/likedIDs")++likeLoads;require(likeLoads==1,"G76 initial state uses one shared request");
    const auto covers=model.covers();for(int i=0;i<30;++i)model.sync();require(resets.count()==0&&model.covers()==covers,"unrelated sync does not reset large list or reshuffle records");
    model.savePosition(model.session(),777);hud.queueCollectionOpen=true;model.sync();require(model.scrollPosition()==777&&resets.count()==0,"secondary overlays preserve exact page scroll and model");hud.queueCollectionOpen=false;
    music.player.current=song(9999);music.player.queue={music.player.current};music.player.index=0;
    QSignalSpy nav(&model,&PlaylistMagazine::navigate);model.openCover(model.covers().at(0).toMap()["key"].toString());require(nav.count()==1&&music.player.current["id"]=="9999"&&music.player.queue.size()==1,"record navigation emits a real internal destination without playing or replacing queue");
    model.rowAction("select","netease:101");model.rowAction("select","netease:102");model.bulk("collect");require(hud.queueCollectionOpen&&hud.queueCollectionTracks.size()==2&&hud.queueCollectionTracks.first().toObject()["id"]=="101","multi-selection captures immutable actual songs for existing collection picker");hud.queueCollectionOpen=false;
    model.selectAll(false);model.rowAction("select","netease:101");model.bulk("append");require(music.player.queue.size()==2&&music.player.index==0&&music.player.current["id"]=="9999","append preserves playing song and queue index");
    model.bulk("append");require(music.player.queue.size()==2,"bulk append skips duplicate queue identities");
    model.search("Song 101");require(model.rowCount()>0&&model.rowCount()<4080,"playlist search filters real source rows");model.search("");
    model.showSongMenu("directory",7,"netease:107",50,80);events();model.songAction("copy");require(host.copied.endsWith("id=107"),"context copy acts on right-clicked song, not playing song or page selection");
    model.showSongMenu("directory",7,"netease:107",50,80);model.songAction("next");require(music.player.queue.at(1).toObject()["id"]=="107","context next uses captured song");
    model.showSongMenu("directory",7,"netease:NOT107",50,80);require(!model.songMenu()["visible"].toBool(),"stale rendered identity closes menu instead of targeting shifted row");
    model.showSongMenu("directory",0,"netease:100",50,80);events();require(model.songMenu()["canRemove"].toBool(),"owned playlist enables removal");a->item["creatorID"]="other";model.sync();require(!model.songMenu()["canRemove"].toBool(),"non-owner cannot remove playlist songs");a->item["creatorID"]="42";
    music.api.fixture=[](QString route,QJsonObject)->MusicReply{if(route=="/playlist/tracks")return{QJsonObject{{"code",200}}, {}};return{QJsonObject{{"total",0}}, {}};};
    model.selectAll(false);model.rowAction("select","netease:100");model.rowAction("select","netease:101");model.closeMenu();model.bulk("remove");require(model.removalCount()==2&&a->songs.size()==4080,"bulk removal requires explicit confirmation");model.removeConfirmed();events(100);require(a->songs.size()==4078&&model.rowCount()==4078&&a->cursor==4078,"confirmed server-success removal updates songs and consumed-ID cursor");
    music.api.fixture=[](QString route,QJsonObject)->MusicReply{if(route=="/playlist/tracks")return{{},"Rejected"};return{QJsonObject{{"total",0}}, {}};};
    model.selectAll(false);model.rowAction("select","netease:102");model.bulk("remove");model.removeConfirmed();events(100);require(a->songs.size()==4078,"rejected removal retains songs and reports failure");
    model.share();require(host.copied.contains("playlist?id=123"),"playlist share uses the actual playlist ID");
    model.savePosition(model.session(),888);model.setTab("comments");model.savePosition(model.session(),888);music.directory=std::make_shared<MusicDirectory>();music.directory->item=MusicData::item("playlist","456","Collection B");model.sync();events();require(model.socialRows().isEmpty(),"late social response from previous page cannot populate new playlist");
    music.directory=a;model.sync();require(model.scrollPosition()==888,"page-owned view state survives visiting another folder");model.setTab("songs");
    music.api.fixture=[](QString route,QJsonObject)->MusicReply{if(route=="/song/download/url/v1")return{QJsonObject{{"data",QJsonObject{{"url",""}}}}, {}};return{QJsonObject{}, {}};};
    model.selectAll(false);model.rowAction("select","netease:102");model.bulk("download");events(220);require(model.status().contains("未下载 1"),"download without an authorized URL reports failure rather than a fake success");
    // Streaming success and HTML failure use a local HTTP fixture, never an account or external media.
    QTcpServer server;require(server.listen(QHostAddress::LocalHost,0),"local download fixture starts");QByteArray payload="RIFF-G69-unique-offline-fixture-audio";bool html=false;
    QObject::connect(&server,&QTcpServer::newConnection,[&]{auto *socket=server.nextPendingConnection();QObject::connect(socket,&QTcpSocket::readyRead,socket,[&,socket]{socket->readAll();const auto body=html?QByteArray("<html>expired</html>"):payload;socket->write("HTTP/1.1 200 OK\r\nContent-Type: "+QByteArray(html?"text/html":"audio/wav")+"\r\nContent-Length: "+QByteArray::number(body.size())+"\r\nConnection: close\r\n\r\n"+body);socket->disconnectFromHost();});});
    const auto downloadFile=QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)+"/RhineMusic/G69_offline_"+QString::number(QCoreApplication::applicationPid())+"-102.wav";
    require(!QFile::exists(downloadFile),"download fixture never overwrites an existing file");
    auto s=a->songs.first().toObject();s["title"]="G69_offline_"+QString::number(QCoreApplication::applicationPid());a->songs[0]=s;model.sync();
    music.api.fixture=[&](QString route,QJsonObject)->MusicReply{if(route=="/song/download/url/v1")return{QJsonObject{{"data",QJsonObject{{"url","http://127.0.0.1:"+QString::number(server.serverPort())+"/audio"},{"type","wav"}}}}, {}};return{QJsonObject{}, {}};};
    model.selectAll(false);model.rowAction("select","netease:102");model.bulk("download");events(350);QFile downloaded(downloadFile);require(downloaded.open(QIODevice::ReadOnly)&&downloaded.readAll()==payload,"authorized download streams actual fixture bytes and commits a complete file");downloaded.close();QFile::remove(downloadFile);
    html=true;model.bulk("download");events(350);require(!QFile::exists(downloadFile)&&model.status().contains("未下载 1"),"expired HTML response is not saved as an audio file");
    model.bulk("download");model.cancelDownload();events(180);require(!QFile::exists(downloadFile)&&!model.downloading(),"cancel drops an in-flight URL response and leaves no partial file");
    // Demand-load every page before append-all, retaining current playback and skipping unavailable tracks.
    auto c=std::make_shared<MusicDirectory>();c->item=MusicData::item("playlist","789","Large paged collection");c->item["creatorID"]="42";
    for(int i=500;i<705;++i){c->ids.append(QString::number(i));if(i<505)c->songs.append(song(i));}c->cursor=5;
    music.directory=c;music.directoryInfo=false;music.directoryLoading=true;music.current={};model.sync();require(model.active(),"playlist-to-playlist loading keeps the existing magazine Loader active");
    music.directoryInfo=true;music.directoryLoading=false;model.sync();resets.clear();
    music.api.fixture=[&](QString route,QJsonObject values)->MusicReply{
        if(route=="/fixture/page"){QJsonArray out;const int cursor=values["cursor"].toInt();for(int i=cursor;i<std::min(cursor+100,205);++i){auto s=song(500+i);if(i==204)s["unavailable"]=true;out.append(s);}return{out,{}};}
        if(route=="/playlist/tracks")return{QJsonObject{{"code",200}},{}};
        return{QJsonObject{}, {}};
    };
    music.player.current=song(9999);music.player.queue={music.player.current};music.player.index=0;const int plays=music.player.plays;
    model.bulk("append-all");events(180);
    require(c->cursor==205&&c->songs.size()==205&&music.pageRequests==2&&music.player.queue.size()==205&&music.player.current["id"]=="9999"&&music.player.plays==plays,
        "append-all fetches all metadata pages, skips unavailable songs and never starts playback");
    require(resets.count()==0&&inserts.count()>=2,"paged songs append model rows without resetting existing delegates");
    model.selectAll(true);music.api.requests.clear();model.bulk("remove");model.removeConfirmed();events(380);
    int chunks=0;for(const auto &request:music.api.requests)if(request.first=="/playlist/tracks"){++chunks;require(request.second["tracks"].toString().split(',').size()<=100,"batch mutation request is bounded to 100 IDs");}
    require(chunks==3&&c->songs.isEmpty()&&model.rowCount()==0,"205-song confirmed deletion executes three sequential bounded writes");
    music.directory=a;model.sync();model.rowAction("select","netease:102");
    model.showSongMenu("directory",0,"netease:102",0,0);require(model.songMenu()["visible"].toBool(),"account-cancellation fixture starts with an actual captured menu");++music.account;music.uid="another";model.sync();require(!model.songMenu()["visible"].toBool()&&model.selectedCount()==0,"account switch clears captured menu and multi-selection");
    // G70: edit query repeatedly while metadata pages are still in flight.
    auto searching=std::make_shared<MusicDirectory>();searching->item=MusicData::item("playlist","7070","Search fixture");
    for(int i=500;i<705;++i){searching->ids.append(QString::number(i));if(i<505)searching->songs.append(song(i));}searching->cursor=5;
    music.directory=searching;music.directoryLoading=false;model.sync();bool rejectSearch=false;
    music.api.fixture=[&](QString route,QJsonObject values)->MusicReply{if(route=="/fixture/page"){
        if(rejectSearch)return{{},"offline"};QJsonArray out;int cursor=values["cursor"].toInt();for(int i=cursor;i<std::min(cursor+100,205);++i)out.append(song(500+i));return{out,{}};}return{QJsonObject{}, {}};};
    model.search("Song 704");model.search("Song 60");model.search("Song 6");model.search("");events(80);
    require(model.query().isEmpty()&&!model.busy()&&model.rowCount()==searching->songs.size(),"clearing during async search restores every loaded row and cancels search work");
    model.search("Song 704");events(100);require(searching->cursor==205&&model.rowCount()==1&&model.data(model.index(0),PlaylistMagazine::Track).toMap()["id"]=="704","latest keyword searches all paginated tracks, including a previously unloaded final song");
    model.search("no-match");require(model.rowCount()==0&&!model.busy(),"completed no-result search releases loading");model.search("Artist");require(model.rowCount()==205,"artist search updates without Enter");model.search("Album");require(model.rowCount()==205,"album search updates without Enter");
    searching->songs={song(500)};searching->cursor=1;rejectSearch=true;model.sync();model.search("Song 700");events(100);
    require(!model.busy()&&!music.directoryLoading&&model.status().contains("失败"),"failed search paging releases busy state and gives retry feedback");
    rejectSearch=false;model.search("Song 704");events(100);require(model.rowCount()==1&&searching->cursor==205,"typing after failure starts and completes a new full search");
    model.search("");music.likedIDs=QJsonArray{"500"};music.lists[1]={song(501)};model.sync();
    require(model.data(model.index(0),PlaylistMagazine::Heart).toBool()&&!model.data(model.index(1),PlaylistMagazine::Heart).toBool(),"authoritative liked IDs override a stale liked shelf");
    model.setFilter("liked");require(model.rowCount()==1,"liked filtering shares the same authoritative heart state");model.setFilter("all");
    music.lists[2]={};music.lists[3]={};music.lists[4]={};
    for(int i=0;i<9;++i){auto item=MusicData::item("playlist",QString::number(7100+i),"Ordered "+QString::number(i));item["cover"]="https://example.org/record"+QString::number(i);music.lists[2].append(item);}
    const auto selectRecord=[&](int i,bool replace){auto f=std::make_shared<MusicDirectory>();f->item=music.lists[2][i].toObject();f->recordBrowse=replace;music.directory=f;model.sync();};
    selectRecord(2,false);require(model.recordNeighbour(2)["key"]==music.lists[2][4].toObject()["key"].toVariant()&&model.recordNeighbour(-2)["key"]==music.lists[2][0].toObject()["key"].toVariant(),"G75 real lookahead supplies the entering neighbour in both directions");const auto playback=music.player.current;const auto queueBefore=music.player.queue;
    for(int i=2;i<7;++i){auto right=model.covers().last().toMap();require(right["key"].toString()==music.lists[2][i+1].toObject()["key"].toString(),"right neighbour follows full canonical collection order beyond three covers");model.openCover(right["key"].toString());require(nav.last().at(0).toString().startsWith("music:collection-browse:"),"cover emits replacement-session navigation rather than normal history push");selectRecord(i+1,true);}
    require(music.player.current==playback&&music.player.queue==queueBefore,"continuous record browsing never changes playback or queue");
    music.hasMore[2]=true;selectRecord(8,true);require(model.recordNeighbour(2).isEmpty(),"G75 incomplete collection never invents an entering cover");require(model.covers().size()==1,"incomplete collection never wraps prematurely to the first loaded item");model.prepareRecords();require(music.collectionLoads==1&&music.lastCollectionLane==2,"collection edge requests the existing personal-playlist pager");
    auto nextRecord=MusicData::item("playlist","7109","Later page");nextRecord["cover"]="https://example.org/later";music.lists[2].append(nextRecord);music.hasMore[2]=false;model.sync();require(model.covers().last().toMap()["id"]=="7109","new metadata page supplies the next real collection without a fixed-three loop");selectRecord(9,true);require(model.covers().last().toMap()["id"]=="7100","completed collection naturally wraps to its first real item");
    // G74: actual server-success state, explicit intended direction and stale-page guard.
    auto subscription=std::make_shared<MusicDirectory>();subscription->item=MusicData::item("playlist","7400","Subscribe target");subscription->item["creatorID"]="not-me";
    music.directory=subscription;music.uid="42";music.subscriptions.clear();music.lists[3]={};model.sync();
    bool rejectSubscription=true;music.api.fixture=[&](QString,QJsonObject)->MusicReply{return {QJsonObject{},rejectSubscription?"denied":""};};
    const auto subscriptionKey=model.session();model.setSubscribed(subscriptionKey,true);events(30);
    require(!model.info()["subscribed"].toBool()&&music.lists[3].isEmpty(),"G74 rejected subscription never paints success or mutates the collection");
    rejectSubscription=false;model.setSubscribed(subscriptionKey,true);events(30);
    require(model.info()["subscribed"].toBool()&&music.api.requests.last().first=="/playlist/subscribe"&&music.api.requests.last().second["t"].toInt()==1&&music.lists[3].size()==1,"G74 confirmed collection uses the playlist ID, updates membership and selects subscribe direction");
    model.setSubscribed(subscriptionKey,false);events(30);require(!model.info()["subscribed"].toBool()&&music.lists[3].isEmpty()&&music.api.requests.last().second["t"].toInt()==2,"G74 confirmed unsubscribe clears server-confirmed membership");
    const auto writes=music.api.requests.size();model.setSubscribed("old-page-key",true);require(music.api.requests.size()==writes,"G74 stale confirmation cannot target the current page");
    subscription->item["subscribed"]=true;model.sync();require(model.info()["subscribed"].toBool(),"G74 detail subscription state survives an incompletely loaded personal shelf");
    auto album=std::make_shared<MusicDirectory>();album->item=MusicData::item("album","7401","Album target");music.directory=album;model.sync();require(!model.active(),"G74 normal album details retain their native introduction reader");
    album->recordBrowse=true;model.sync();require(model.active(),"G74 album handoff keeps the persistent magazine active");
    model.setSubscribed(model.session(),true);events(30);require(music.api.requests.last().first=="/album/sub"&&music.lists[4].size()==1,"G74 album collection uses the album mutation endpoint");
    auto countsA=std::make_shared<MusicDirectory>();countsA->item=MusicData::item("playlist","7601","Count A");countsA->item["subscribedCount"]=9999;
    auto countsB=std::make_shared<MusicDirectory>();countsB->item=MusicData::item("playlist","7602","Count B");countsB->item["subscribedCount"]=8888;
    music.api.fixture=[](QString route,QJsonObject args)->MusicReply{if(route=="/playlist/subscribers")return{QJsonObject{{"total",args["id"]=="7601"?17:29},{"subscribers",QJsonArray{}}},{}};return{QJsonObject{}, {}};};
    music.directory=countsA;model.sync();require(!model.info().contains("collectorCount"),"G76 a new playlist never reuses an old collector count");
    music.directory=countsB;model.sync();events();require(model.info()["collectorCount"].toInt()==29,"G76 only the current playlist subscriber total is accepted, not collection counts or late A responses");
    music.api.fixture=[](QString,QJsonObject)->MusicReply{return{QJsonObject{{"subscribers",QJsonArray{QJsonObject{}}}}, {}};};
    music.directory=countsA;model.sync();events();require(!model.info().contains("collectorCount")&&!model.info()["collectorError"].toString().isEmpty(),"G76 missing total remains unknown; neither page length nor subscribedCount is substituted");
    music.likedIDs.reset();music.api.fixture=[](QString route,QJsonObject)->MusicReply{if(route=="/fixture/likedIDs")return{{},"offline"};return{QJsonObject{}, {}};};
    model.retryLikes();events();require(!music.likedIDs&&!model.info()["likesError"].toString().isEmpty(),"G76 failed initial state stays explicit and retryable");
    music.api.fixture=[](QString route,QJsonObject)->MusicReply{if(route=="/fixture/likedIDs")return{QJsonArray{"500"},{}};return{QJsonObject{}, {}};};
    music.directory=countsB;model.sync();events();require(music.likedIDs==QJsonArray{"500"},"G76 entering another playlist retries an unknown failed state automatically");
    qInfo()<<"All actual PlaylistMagazine controller/model checks passed (fixture domain dependencies).";
}
