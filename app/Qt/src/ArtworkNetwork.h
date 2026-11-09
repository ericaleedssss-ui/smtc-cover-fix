#pragma once
#include "AppStorage.h"
#include "PipelineDiagnostics.h"
#include <QQmlNetworkAccessManagerFactory>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QDir>
#include <QNetworkReply>
#include <QJsonObject>
#include <atomic>

struct ArtworkDiagnostics {
    inline static std::atomic<qint64> requests=0,bytes=0,hits=0,unsized=0,active=0;
    static QJsonObject snapshot() {
        return {{"requests",requests.load()},{"download_bytes",bytes.load()},{"disk_hits",hits.load()},
            {"unsized_requests",unsized.load()},{"active",active.load()}};
    }
};

// QML artwork shares a bounded public-image cache, independently of account API data.
class ArtworkNetwork final : public QNetworkAccessManager {
public:
    explicit ArtworkNetwork(QObject *parent) : QNetworkAccessManager(parent) {
        const auto directory=AppStorage::cacheDirectory()+"/artwork";
        QDir().mkpath(directory);
        auto *disk=new QNetworkDiskCache(this);
        disk->setCacheDirectory(directory);
        disk->setMaximumCacheSize(64*1024*1024);
        setCache(disk);
        setTransferTimeout(10000);
    }
protected:
    QNetworkReply *createRequest(Operation operation,const QNetworkRequest &original,QIODevice *outgoing=nullptr) override {
        auto request=original;
        const auto host=request.url().host();
        if(host=="music.126.net"||host.endsWith(".music.126.net")) {
            request.setRawHeader("User-Agent","Mozilla/5.0 RhineMusicDatabase");
            request.setRawHeader("Referer","https://music.163.com/");
            request.setAttribute(QNetworkRequest::CacheLoadControlAttribute,QNetworkRequest::PreferCache);
            request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,QNetworkRequest::NoLessSafeRedirectPolicy);
        }
        auto *reply=QNetworkAccessManager::createRequest(operation,request,outgoing);
        if(qEnvironmentVariableIsSet("RHINE_QA_COLLECTION_PROBE")) {
            const int traceId=++PipelineDiagnostics::serial;
            PipelineDiagnostics::mark("qml-cover.request",{{"request",traceId}});
            connect(reply,&QNetworkReply::finished,reply,[reply,traceId]{PipelineDiagnostics::mark("qml-cover.response",{{"request",traceId},{"cached",reply->attribute(QNetworkRequest::SourceIsFromCacheAttribute).toBool()},{"error",int(reply->error())}});});
            ++ArtworkDiagnostics::requests;++ArtworkDiagnostics::active;
            if(!request.url().query().contains("param="))++ArtworkDiagnostics::unsized;
            connect(reply,&QNetworkReply::downloadProgress,reply,[last=qint64(0)](qint64 received,qint64) mutable {
                if(received>last){ArtworkDiagnostics::bytes+=received-last;last=received;}
            });
            connect(reply,&QNetworkReply::finished,reply,[reply]{--ArtworkDiagnostics::active;if(reply->attribute(QNetworkRequest::SourceIsFromCacheAttribute).toBool())++ArtworkDiagnostics::hits;});
        }
        return reply;
    }
};
class ArtworkNetworkFactory final : public QQmlNetworkAccessManagerFactory {
public:
    QNetworkAccessManager *create(QObject *parent) override {return new ArtworkNetwork(parent);}
};
