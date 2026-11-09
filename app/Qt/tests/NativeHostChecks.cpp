#include "Host.h"
#include "ProcessMetrics.h"
#include <QDir>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QUuid>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QPointer>
#include <QVector>
#include <QThread>

namespace {
bool waitFor(const std::function<bool()> &ready) {
    QElapsedTimer elapsed;
    elapsed.start();
    while (!ready() && elapsed.elapsed() < 2000) {
        QCoreApplication::processEvents();
        QThread::msleep(1);
    }
    return ready();
}
}

/** 不创建脚本引擎，验证原生业务可直接使用缓存、账号代数、封面和官方播放边界。 */
bool runNativeHostChecks(const QString &root) {
    Host host(root, true);
    const auto cacheProbe=qEnvironmentVariable("RHINE_QA_METADATA_CACHE");
    if(!cacheProbe.isEmpty()) {
        // The test host starts without loading credentials. Exercise the real
        // guest disk-cache path; a fixture catches every unexpected service call.
        host.offline=false;host.interval=0;
        int transported=0,replies=0,peakEntries=0;
        bool ok=true;
        host.fixture=[&](QString,QJsonObject){++transported;return QJsonObject{{"body",QJsonObject{{"code",200},{"source","transport"}}}};};
        const auto nonce=QUuid::createUuid().toString(QUuid::WithoutBraces);
        QStringList files;
        const auto parameters=[&](int i){return QJsonObject{{"keywords","metadata-bound-"+nonce+QString::number(i)}};};
        const auto key=[&](int i){return Host::cacheKey("enhanced-4.41.1/qq-3.3.1/kugou-ba3645f2/guest0","/search",parameters(i));};
        const auto seed=[&](int i,qint64 expiry){
            const auto name=host.diskPath(key(i));QDir().mkpath(QFileInfo(name).path());
            QFile file(name);if(!file.open(QIODevice::WriteOnly)){ok=false;return;}
            files.append(name);
            file.write(QJsonDocument(QJsonObject{{"expiry",double(expiry)},
                {"body",QJsonObject{{"code",200},{"ordinal",i},{"payload",QString(65536,QChar('a'+i%26))}}}}).toJson(QJsonDocument::Compact));
        };
        const auto expiry=QDateTime::currentMSecsSinceEpoch()+60000;
        const auto before=readProcessMetrics().residentBytes;
        for(int i=0;i<300;++i) {
            seed(i,expiry);bool received=false;
            host.offline=false;
            host.requestJson("/search",parameters(i),[&,i](QJsonObject response,QString error){
                ok&=error.isEmpty()&&response["body"].toObject()["ordinal"].toInt(-1)==i;
                received=true;++replies;
            });
            // Disk admission above is live. Dispatch is queued, so switch its
            // transport to the fixture before processing events: never network.
            host.offline=true;
            ok&=waitFor([&]{return received;});
            peakEntries=qMax(peakEntries,int(host.cache.size()));
        }
        const auto loadedEntries=host.cache.size();
        const auto after=readProcessMetrics().residentBytes;
        const bool allFromDisk=transported==0&&replies==300;
        // The newest hit must survive admission; repeat it with its file gone.
        QFile::remove(host.diskPath(key(299)));bool repeat=false;
        host.offline=false;
        host.requestJson("/search",parameters(299),[&](QJsonObject response,QString error){
            repeat=error.isEmpty()&&response["body"].toObject()["ordinal"].toInt(-1)==299;
        });
        host.offline=true;
        ok&=waitFor([&]{return repeat;})&&transported==0;
        seed(300,1);bool renewed=false;
        host.offline=false;
        host.requestJson("/search",parameters(300),[&](QJsonObject response,QString error){
            renewed=error.isEmpty()&&response["body"].toObject()["source"]=="transport";
        });
        host.offline=true;
        ok&=waitFor([&]{return renewed;})&&transported==1&&allFromDisk&&peakEntries<=256&&host.cache.size()<=256;
        const bool noWorker=host.child.state()==QProcess::NotRunning&&!host.temporary;
        ok&=noWorker;
        for(const auto &file:files)QFile::remove(file);
        QDir().mkpath(cacheProbe);QFile report(cacheProbe+"/metadata-cache.json");
        const QJsonObject result{{"passed",ok},{"disk_requests",300},{"all_initial_replies_from_disk",allFromDisk},
            {"entries_after_disk_hits",int(loadedEntries)},{"peak_entries",peakEntries},
            {"repeat_hit_without_disk",repeat},{"expired_reloaded",renewed},{"transport_calls",transported},{"no_worker_started",noWorker},
            {"resident_before_bytes",qint64(before)},{"resident_after_bytes",qint64(after)}};
        if(report.open(QIODevice::WriteOnly))report.write(QJsonDocument(result).toJson());else ok=false;
        qInfo()<<"Metadata disk admission / repeat / expiry"<<QJsonDocument(result).toJson(QJsonDocument::Compact);
        host.offline=true;
        return ok;
    }
    int requests = 0;
    host.fixture = [&](QString, QJsonObject parameters) {
        ++requests;
        return QJsonObject{{"body", QJsonObject{{"code", 200}, {"query", parameters["keywords"]}}}};
    };
    int replies = 0;
    bool ok = true;
    const auto receive = [&](QJsonObject response, QString error) {
        ++replies;
        ok &= error.isEmpty() && response["body"].toObject()["query"] == "native" &&
              response["_epoch"].toInt() == host.epoch;
    };
    host.requestJson("/search", {{"keywords", "native"}}, receive);
    host.requestJson("/search", {{"keywords", "native"}}, receive);
    ok &= waitFor([&] { return replies == 2; }) && requests == 1;
    host.requestJson("/search", {{"keywords", "native"}}, receive);
    ok &= waitFor([&] { return replies == 3; }) && requests == 1;

    // Hold three service responses open. The fourth must wait for a slot,
    // and dispatch starts must still obey the minimum interval.
    QVector<qint64> starts;
    QElapsedTimer dispatchClock;dispatchClock.start();
    int depth=0,maximumDepth=0,completed=0;
    bool bounded=true;
    host.interval=25;
    host.fixture=[&](QString,QJsonObject parameters){
        starts.append(dispatchClock.elapsed());
        ++depth;maximumDepth=qMax(maximumDepth,depth);
        const int serial=parameters["id"].toInt();
        if(serial==0){
            for(int i=1;i<4;++i)host.requestJson("/album",{{"id",i}},[&](QJsonObject,QString error){ok&=error.isEmpty();++completed;});
        }
        if(serial<3){
            QEventLoop hold;
            QTimer::singleShot(serial==2?100:350,&hold,&QEventLoop::quit);
            hold.exec();
            if(serial==2)bounded&=starts.size()==3;
        }
        --depth;
        return QJsonObject{{"body",QJsonObject{{"code",200}}}};
    };
    host.requestJson("/album",{{"id",0}},[&](QJsonObject,QString error){ok&=error.isEmpty();++completed;});
    const bool overlap=waitFor([&]{return completed==4;})&&maximumDepth==3&&bounded&&starts.size()==4;
    bool spaced=true;
    for(int i=1;i<starts.size();++i)spaced&=starts[i]-starts[i-1]>=25;
    qInfo()<<"G98 metadata overlap / spacing / starts"<<overlap<<spaced<<starts;
    ok &= overlap&&spaced;

    // Selection is made when dispatch becomes possible. Detail passes wiki;
    // equal-priority detail work retains its original order.
    QStringList order;
    completed=0;
    host.fixture=[&](QString route,QJsonObject parameters){order.append(route+parameters["id"].toString());return QJsonObject{{"body",QJsonObject{{"code",200}}}};};
    const auto receivePriority=[&](QJsonObject,QString error){ok&=error.isEmpty();++completed;};
    host.requestJson("/song/wiki/summary",{{"id","g98-priority"}},receivePriority);
    host.requestJson("/album",{{"id","g98-first"}},receivePriority);
    host.requestJson("/album",{{"id","g98-second"}},receivePriority);
    const bool prioritized=waitFor([&]{return completed==3;})&&order==QStringList{"/albumg98-first","/albumg98-second","/song/wiki/summaryg98-priority"};
    qInfo()<<"G98 metadata priority"<<prioritized<<order;
    ok &= prioritized;
    host.interval=0;
    host.fixture={};
    bool failedReleased=false;
    host.requestJson("/album",{{"id","g98-fail"}},[&](QJsonObject,QString error){failedReleased=!error.isEmpty();});
    ok &= waitFor([&]{return failedReleased;});
    bool recovered=false;
    host.fixture=[](QString,QJsonObject){return QJsonObject{{"body",QJsonObject{{"code",200}}}};};
    host.requestJson("/album",{{"id","g98-recover"}},[&](QJsonObject,QString error){recovered=error.isEmpty();});
    ok &= waitFor([&]{return recovered;});

    // Simulate a slow wiki response with a nested event loop at the service
    // boundary. A distinct detail request must finish before wiki releases.
    bool detailFinished=false,wikiFinished=false,detailOvertookWiki=false;
    host.fixture=[&](QString route,QJsonObject){
        if(route=="/song/wiki/summary"){
            QEventLoop serviceWait;
            QPointer<QEventLoop> loop(&serviceWait);
            QTimer::singleShot(0,&host,[&,loop]{
                host.requestJson("/album",{{"id","g98-fast"}},[&,loop](QJsonObject,QString error){
                    detailFinished=error.isEmpty();detailOvertookWiki=!wikiFinished;
                    if(loop)loop->quit();
                });
            });
            QTimer::singleShot(800,&serviceWait,&QEventLoop::quit);
            serviceWait.exec();
        }
        return QJsonObject{{"body",QJsonObject{{"code",200}}}};
    };
    host.requestJson("/song/wiki/summary",{{"id","g98-slow"}},[&](QJsonObject,QString error){wikiFinished=error.isEmpty();});
    const bool overtook=waitFor([&]{return wikiFinished&&detailFinished;})&&detailOvertookWiki;
    qInfo()<<"G98 metadata detail overtakes slow wiki"<<overtook;
    ok &= overtook;
    host.fixture=[&](QString,QJsonObject parameters){++requests;return QJsonObject{{"body",QJsonObject{{"code",200},{"query",parameters["keywords"]}}}};};

    const auto originalEpoch = host.epoch;
    bool staleReceived = false;
    host.requestJson("/login/qr/check", {}, [&](QJsonObject response, QString error) {
        staleReceived = error.isEmpty() && response["_epoch"].toInt() == originalEpoch &&
                        response["_epoch"].toInt() != host.epoch;
    });
    host.logout();
    ok &= waitFor([&] { return staleReceived; });

    QImage image(2, 2, QImage::Format_RGBA8888);
    image.fill(Qt::red);
    const QString cover = "https://music.126.net/native-fixture.jpg?param=1024y1024";
    host.fixtureImage(cover, image);
    bool coverReady = false;
    host.loadCover("https://music.126.net/native-fixture.jpg?param=128y128",
                   [&](QString key) { coverReady = key == cover && host.image(key) == image; });
    ok &= coverReady;
    host.setMediaArtwork(cover);
    ok &= host.mediaArtwork() == image;
    // 封面保留独立的 QImage 引用，不依赖缓存继续驻留。
    host.trimMemory({});
    ok &= host.mediaArtwork() == image;
    host.setMediaArtwork({});
    ok &= host.mediaArtwork().isNull();
    host.fixtureImage(cover, image);
    host.setMediaArtwork(cover);
    host.mediaMetadata({}, {}, {});
    ok &= host.mediaArtwork().isNull();
    host.restoreMemoryBudget();
    QImage largeCover(1024, 1024, QImage::Format_RGBA8888);
    largeCover.fill(Qt::blue);
    host.fixtureImage("current-cover", largeCover);
    host.fixtureImage("playing-cover", largeCover);
    host.trimMemory({"current-cover", "playing-cover"});
    ok &= host.image("current-cover") == largeCover && host.image("playing-cover") == largeCover;
    bool invalidId = false;
    bool official = false;
    host.playOfficial("invalid", [&](QString error) { invalidId = error == "请先选择一首歌曲"; });
    host.playOfficial("42", [&](QString value) { official = value == "OFFLINE_PLAY:42"; });
    ok &= invalidId && official;

    bool delayed = false;
    host.schedule(0, [&] { delayed = true; });
    ok &= !delayed && waitFor([&] { return delayed; });
    bool afterShutdown = false;
    host.schedule(0, [&] { afterShutdown = true; });
    host.shutdown();
    QCoreApplication::processEvents();
    ok &= !afterShutdown;
    qInfo() << "Native Host callbacks, request merging, cache, epoch, images and shutdown:"
            << (ok ? "passed" : "FAILED");
    return ok;
}
