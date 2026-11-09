#pragma once
#include <QQmlAbstractUrlInterceptor>
#include <QQmlProperty>
#include <QQuickItem>
#include <QTimer>
#include <QJsonDocument>
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <functional>
#include <algorithm>
#include <QVariantAnimation>
#include <QQmlEngine>
#include <QQmlContext>
#include "../src/PipelineDiagnostics.h"

// Only installed for isolated, explicitly requested QA launches. All public
// artwork resolves to the same transparent pixel before network/decode begins.
class CollectionArtworkBlock final : public QQmlAbstractUrlInterceptor {
public:
    QUrl intercept(const QUrl &url, DataType type) override {
        if(type==UrlString && (url.scheme()=="https"||url.scheme()=="http"||url.toString().startsWith("data:image/")))
            return QUrl("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=");
        return url;
    }
};

// Drives normal read-only account/playlist paths, without replacing API replies
// or advancing the render loop. No titles, song IDs, URLs or account data leave
// the isolated portable package. FrameProfiler supplies real render timings.
class CollectionPerformanceProbe final : public QObject {
public:
    CollectionPerformanceProbe(Engine &backend,QQuickWindow *window,FrameProfiler &profiler,QString output)
        :QObject(window),b(backend),w(window),p(profiler),out(output) {
        QDir().mkpath(out);clock.start();w->resize(1707,960);b.resize(1707,960);
        for(auto *screen:QGuiApplication::screens())if(screen->name()==qEnvironmentVariable("RHINE_QA_SCREEN")){w->setScreen(screen);w->setPosition(screen->availableGeometry().topLeft()+QPoint(40,40));break;}
        p.setReportDirectory(out);p.startRecording();
        // Ablation traversal runs at the same sampling cadence, never on every
        // frame. Its first second is excluded from steady-state comparisons.
        connect(&timer,&QTimer::timeout,this,[this]{tick();});timer.start(1000);
        if(PipelineDiagnostics::enabled()) {
            heartbeat.setTimerType(Qt::PreciseTimer);heartbeat.setInterval(5);lastBeat.start();
            connect(&heartbeat,&QTimer::timeout,this,[this]{const double ms=lastBeat.nsecsElapsed()/1e6;lastBeat.restart();if(ms>8)PipelineDiagnostics::mark("ui.heartbeat-late",{{"interval_ms",ms}});});heartbeat.start();
            connect(&observer,&QTimer::timeout,this,[this]{observe();});observer.start(100);
        }
        if(PipelineDiagnostics::enabled())QTimer::singleShot(500,this,[this]{w->resize(1707,960);b.resize(1707,960);});
        mark("startup");
    }
private:
    Engine &b;QQuickWindow *w;FrameProfiler &p;QString out,phase="startup";QTimer timer;QElapsedTimer clock;
    qint64 since=0;int state=0,attempts=0,scroll=0;QJsonObject selected,initial;QList<QJsonObject> playlists;QVariantAnimation scrollAnimation;
    QString lastInventoryPhase,lastResourcePhase;QJsonObject lastShape;
    QTimer heartbeat,observer;QElapsedTimer lastBeat;QHash<QString,QPointer<QQuickItem>> watched;int cycles=0;
    bool noBlur=qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_NO_BLUR")==1;
    bool noTargets=qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_NO_TARGETS")==1;
    QQuickItem *find(QQuickItem *item,const QString &name) {
        if(item->objectName()==name)return item;
        for(auto *child:item->childItems())if(auto *found=find(child,name))return found;
        return nullptr;
    }
    void write(const QString &name,QJsonObject row) {
        row["elapsed_ms"]=clock.elapsed();row["utc_ms"]=QDateTime::currentMSecsSinceEpoch();row["phase"]=phase;
        QFile f(out+"/"+name);if(f.open(QIODevice::WriteOnly|QIODevice::Append))f.write(QJsonDocument(row).toJson(QJsonDocument::Compact)+"\n");
    }
    void mark(QString name){phase=name;since=clock.elapsed();write("events.jsonl",{});PipelineDiagnostics::mark("phase."+name);}
    void observe() {
        for(const auto &name:{"playlistMagazineLoader","songDetailLoader","songWall"}) {
            auto *item=find(w->contentItem(),name);if(!item)item=w->findChild<QQuickItem*>(name);
            if(item==watched.value(name))continue;
            if(item) {PipelineDiagnostics::qml("object.created."+QString(name));connect(item,&QObject::destroyed,this,[name]{PipelineDiagnostics::mark("object.destroyed."+QString(name));});}
            watched[name]=item;
        }
    }
    void pane(QString name) {
        if(auto *page=find(w->contentItem(),"songDetailPage"))QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant(name)));
        PipelineDiagnostics::qml("input.pane."+name);
    }
    void applySwitches() {
        if(!noBlur&&!noTargets)return;
        const auto objects=w->findChildren<QObject*>();
        for(auto *o:objects) {
            if(o->property("_collectionAblationApplied").toBool())continue;
            o->setProperty("_collectionAblationApplied",true);
            if(noBlur&&o->property("blurEnabled").isValid()&&o->property("blurEnabled").toBool())o->setProperty("blurEnabled",false);
            if(noTargets) {
                if(QByteArray(o->metaObject()->className()).startsWith("QQuickShaderEffectSource")) {
                    o->setProperty("live",false);o->setProperty("sourceItem",QVariant::fromValue<QQuickItem*>(nullptr));
                }
                if(auto *i=qobject_cast<QQuickItem*>(o);i&&i->QQuickItem::isTextureProvider())QQmlProperty(i,"layer.enabled").write(false);
            }
        }
    }
    void sample() {
        PipelineDiagnostics::Scope sampleTrace("probe.sample");
        auto &m=b.app->music;auto row=b.host.diagnosticResources();
        row["window_w"]=w->width();row["window_h"]=w->height();
        row["qml_network"]=ArtworkDiagnostics::snapshot();
        row["directory_songs"]=m.directory?m.directory->songs.size():0;row["directory_ids"]=m.directory?m.directory->ids.size():0;
        row["directory_metadata_bytes"]=m.directory?QJsonDocument(m.directory->songs).toJson(QJsonDocument::Compact).size():0;
        row["directory_loading"]=m.directoryLoading;row["tracks"]=m.tracks.size();row["qml_objects"]=w->findChildren<QObject*>().size();
        if(PipelineDiagnostics::enabled()&&lastResourcePhase==phase) {
            for(auto it=lastShape.cbegin();it!=lastShape.cend();++it)row[it.key()]=it.value();
            write("resources.jsonl",row);return;
        }
        lastResourcePhase=phase;
        int images=0,ready=0,targets=0,layers=0; qint64 sourcePixels=0,layerPixels=0;
        for(auto *o:w->findChildren<QObject*>()) {
            const auto cls=QByteArray(o->metaObject()->className());
            if(cls.startsWith("QQuickImage")&&o->property("sourceSize").isValid()) {
                ++images;ready+=o->property("status").toInt()==1;const auto s=o->property("sourceSize").toSize();sourcePixels+=qint64(qMax(0,s.width()))*qMax(0,s.height());
            }
            if(cls.startsWith("QQuickShaderEffectSource")&&o->property("sourceItem").value<QQuickItem*>())++targets;
            if(auto *i=qobject_cast<QQuickItem*>(o);i&&i->QQuickItem::isTextureProvider()) {
                ++layers;layerPixels+=qint64(i->width()*w->devicePixelRatio())*qint64(i->height()*w->devicePixelRatio());
            }
        }
        row["qml_images"]=images;row["qml_images_ready"]=ready;row["configured_source_pixels_estimate"]=sourcePixels;
        row["effect_sources"]=targets;row["item_layers"]=layers;row["layer_pixels_estimate"]=layerPixels;
        row["no_covers"]=qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_NO_COVERS")==1;row["no_blur"]=noBlur;row["no_targets"]=noTargets;
        for(const auto *key:{"qml_objects","qml_images","qml_images_ready","configured_source_pixels_estimate","effect_sources","item_layers","layer_pixels_estimate"})lastShape[key]=row[key];
        write("resources.jsonl",row);
        if(PipelineDiagnostics::enabled()&&phase!=lastInventoryPhase) {
            lastInventoryPhase=phase;QJsonArray inventory;for(auto *o:w->findChildren<QObject*>()) {
                const auto cls=QByteArray(o->metaObject()->className());
                auto *i=qobject_cast<QQuickItem*>(o);if(!i)continue;
                const bool layer=i->QQuickItem::isTextureProvider();
                if(!layer&&!cls.startsWith("QQuickShaderEffectSource")&&!cls.startsWith("QQuickImage")&&!cls.startsWith("QQuickLoader"))continue;
                QStringList path;for(auto *q=o;q&&path.size()<5;q=q->parent())path.append(QString::fromLatin1(q->metaObject()->className()).section('_',0,0)+":"+q->objectName());
                const auto size=o->property("sourceSize").toSize();
                inventory.append(QJsonObject{{"path",path.join("/")},{"layer",layer},{"visible",i->isVisible()},{"w",i->width()},{"h",i->height()},{"status",o->property("status").toInt()},{"source_w",size.width()},{"source_h",size.height()},{"has_source",!o->property("source").toString().isEmpty()},{"has_source_item",o->property("sourceItem").value<QQuickItem*>()!=nullptr}});
            }
            write("inventory.jsonl",{{"objects",inventory}});
        }
    }
    void home() {
        auto &m=b.app->music;auto &hud=b.app->hud;
        if(m.directory)m.leaveDirectory(false);m.current=initial;m.wantsSongDetails=false;
        hud.lyricsMode=false;hud.modal.clear();hud.closing=false;b.scene.review("archive");m.changed();b.wake();
    }
    void open() {PipelineDiagnostics::qml("input.open-playlist");home();b.app->music.enterDirectory(selected);b.wake();}
    void finish(QString error={}) {
        timer.stop();heartbeat.stop();observer.stop();PipelineDiagnostics::save(out);write("completion.jsonl",{{"error",error},{"playlist_count",playlists.size()},{"selected_track_count",selected["trackCount"]}});
        p.saveRecording();QCoreApplication::exit(error.isEmpty()?0:3);
    }
    void tick() {
        auto &m=b.app->music;const auto age=clock.elapsed()-since;applySwitches();sample();
        if(clock.elapsed()>360000){finish("probe timeout");return;}
        switch(state) {
        case 0:
            if(clock.elapsed()<8000||m.restoringAccount)return;
            if(m.uid.isEmpty()){finish("saved account unavailable");return;}
            initial=m.current;m.loadMoreSource(2);mark("load-playlist-index");state=1;break;
        case 1:
            if(m.personalLoading)return;
            for(int lane:{2,3})for(const auto &v:m.lists[lane])if(v.toObject()["kind"]=="playlist")playlists.append(v.toObject());
            if(playlists.isEmpty()){if(++attempts<3){m.loadMoreSource(2);return;}finish("no saved-account playlists returned");return;}
            std::sort(playlists.begin(),playlists.end(),[](const QJsonObject &a,const QJsonObject &z){return a["trackCount"].toInt()>z["trackCount"].toInt();});
            selected=playlists.first();home();mark("home-index-ready");state=2;break;
        case 2:if(age<6000)return;open();mark("playlist-open");state=3;break;
        case 3:
            if(m.directoryLoading||age<10000)return;
            if(!m.directory||m.directory->songs.isEmpty()){finish("playlist returned no tracks");return;}
            if(qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_SMOOTH")==1)if(auto *list=find(w->contentItem(),"magazineTrackList")) {
                const auto start=list->property("contentY").toDouble();
                const auto limit=list->property("contentHeight").toDouble()-list->height();
                scrollAnimation.setStartValue(start);scrollAnimation.setEndValue(qMin(limit,start+list->height()*7.5));scrollAnimation.setDuration(10000);
                connect(&scrollAnimation,&QVariantAnimation::valueChanged,this,[list=QPointer<QQuickItem>(list)](const QVariant &v){if(list)list->setProperty("contentY",v);});scrollAnimation.start();
            }
            mark("playlist-scroll");state=4;break;
        case 4:
            if(qEnvironmentVariableIntValue("RHINE_QA_COLLECTION_SMOOTH")!=1)if(auto *list=find(w->contentItem(),"magazineTrackList")) {
                const auto limit=list->property("contentHeight").toDouble()-list->height();
                list->setProperty("contentY",qMin(limit,list->property("contentY").toDouble()+list->height()*.75));
            }
            if(++scroll<10)return;
            mark("playlist-idle");state=5;break;
        case 5:if(age<6000)return;home();mark("return-home");state=6;break;
        case 6:if(age<8000)return;open();mark("playlist-reopen");state=7;break;
        case 7:
            if(m.directoryLoading||age<8000)return;
            if(m.directory&&!m.directory->songs.isEmpty()) {
                const auto song=m.directory->songs.first().toObject();
                if(PipelineDiagnostics::enabled()){m.player.queue=m.directoryQueue();m.player.current=song;emit m.player.changed();PipelineDiagnostics::qml("input.open-song");}
                m.choose(song,false,true);b.app->hud.lyricsMode=true;b.scene.review("detail");m.changed();b.wake();
            }
            mark("song-detail");state=8;break;
        case 8:if(age<8000)return;if(PipelineDiagnostics::enabled()){pane("wall");mark("wall-open");state=10;}else{home();mark("final-home");state=9;}break;
        case 9:if(age<8000)return;finish();break;
        case 10:if(age<8000)return;
            if(auto *field=find(w->contentItem(),"songWallField")) {
                scrollAnimation.disconnect();scrollAnimation.setStartValue(field->property("contentX").toDouble());scrollAnimation.setEndValue(qMin(field->property("contentWidth").toDouble()-field->width(),field->property("contentX").toDouble()+field->width()*2));scrollAnimation.setDuration(8000);
                connect(&scrollAnimation,&QVariantAnimation::valueChanged,this,[field=QPointer<QQuickItem>(field)](const QVariant &v){if(field)field->setProperty("contentX",v);});scrollAnimation.start();
            }
            mark("wall-scroll");state=11;break;
        case 11:if(age<8000)return;pane("lyrics");mark("wall-hidden");state=12;break;
        case 12:if(age<8000)return;home();mark("all-pages-closed");state=13;break;
        case 13:if(age<12000)return;if(++cycles<=3){open();mark("cycle-open-"+QString::number(cycles));state=14;}else{mark("retained-home");state=15;}break;
        case 14:if(m.directoryLoading||age<4000)return;home();mark("cycle-closed-"+QString::number(cycles));state=13;break;
        case 15:if(age<10000)return;
            if(auto *engine=qmlEngine(w))engine->collectGarbage();mark("after-js-gc");state=16;break;
        case 16:if(age<8000)return;b.host.trimMemory({m.coverImage});mark("after-native-cache-trim");state=17;break;
        case 17:if(age<8000)return;
            w->setPersistentSceneGraph(false);w->setPersistentGraphics(false);w->hide();w->releaseResources();
            QTimer::singleShot(500,this,[this]{w->show();});mark("renderer-recreated");state=18;break;
        case 18:if(age<10000)return;mark("final-home");state=9;break;
        }
    }
};
