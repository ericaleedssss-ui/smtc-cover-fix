// Opt-in, isolated production-window performance run. No account writes.
static int runPerformanceChecks(Engine &backend, QQuickWindow *window, const QString &output) {
    QDir().mkpath(output);
    QElapsedTimer clock; clock.start();
    auto &music=backend.app->music; auto &hud=backend.app->hud;
    const auto viewport=qEnvironmentVariableIntValue("RHINE_QA_PERF_DAILY_WINDOW")==1?QSize(1707,960):QSize(1280,900);
    window->resize(viewport); backend.resize(viewport.width(),viewport.height());
    const std::function<QQuickItem*(QQuickItem*,QString)> find=[&](QQuickItem *item,QString name)->QQuickItem* {
        if(!item)return nullptr; if(item->objectName()==name)return item;
        for(auto *child:item->childItems())if(auto *found=find(child,name))return found;
        return nullptr;
    };
    QFile samples(output+"/samples.jsonl"); if(!samples.open(QIODevice::WriteOnly))return 1;
    QFile events(output+"/events.jsonl");if(!events.open(QIODevice::WriteOnly))return 1;
    const auto event=[&](QJsonObject row){row["elapsed_ms"]=clock.elapsed();events.write(QJsonDocument(row).toJson(QJsonDocument::Compact)+"\n");events.flush();};
    QString phase="startup"; QMutex mutex; QList<double> gaps; qint64 lastFrame=0;
    QObject owner;
    auto connection=QObject::connect(window,&QQuickWindow::frameSwapped,&owner,[&]{
        const auto now=clock.nsecsElapsed(); QMutexLocker lock(&mutex);
        if(lastFrame&&gaps.size()<20000)gaps.append((now-lastFrame)/1e6); lastFrame=now;
    },Qt::DirectConnection);
    qint64 lastSample=clock.nsecsElapsed(),lastCpu=readProcessMetrics().cpuNanoseconds;
    const auto sample=[&]{
        const auto now=clock.nsecsElapsed(); const auto process=readProcessMetrics();
        auto row=QJsonObject::fromVariantMap(backend.performance());
        row["phase"]=phase;row["elapsed_ms"]=clock.elapsed();row["pid"]=qint64(QCoreApplication::applicationPid());
        row["working_set_bytes"]=process.residentBytes;
        row["cpu_one_core_percent"]=(process.cpuNanoseconds-lastCpu)*100./qMax<qint64>(1,now-lastSample);
        lastSample=now;lastCpu=process.cpuNanoseconds;
#ifdef Q_OS_WIN
        PROCESS_MEMORY_COUNTERS_EX mem{};mem.cb=sizeof(mem);
        if(GetProcessMemoryInfo(GetCurrentProcess(),reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&mem),sizeof(mem))){
            row["private_commit_bytes"]=qint64(mem.PrivateUsage);row["pagefile_bytes"]=qint64(mem.PagefileUsage);
            row["peak_working_set_bytes"]=qint64(mem.PeakWorkingSetSize);
        }
        row["handles"]=qint64(0);DWORD handles=0;if(GetProcessHandleCount(GetCurrentProcess(),&handles))row["handles"]=qint64(handles);
#endif
        row["qml_objects"]=window->findChildren<QObject*>().size();
        row["backend_objects"]=backend.findChildren<QObject*>().size();
        row["audio"]=QJsonObject::fromVariantMap(backend.host.mediaState());
        row["lyric_lines"]=music.player.lyrics.document()["lines"].toArray().size();
        if (qEnvironmentVariableIntValue("RHINE_QA_PERF_WALL") == 1) {
            QJsonObject wallStats; int tiles=0, images=0, readyImages=0, textures=0; qint64 imagePixels=0, texturePixels=0;
            const std::function<void(QQuickItem*)> inspect=[&](QQuickItem *item){
                if(item->objectName().startsWith("wallTile_"))++tiles;
                if(item->objectName()=="wallArtwork"){
                    ++images;readyImages+=item->property("status").toInt()==1;
                    const auto size=item->property("sourceSize").toSize();imagePixels+=qint64(size.width())*size.height();
                }
                if(QByteArray(item->metaObject()->className()).startsWith("QQuickShaderEffectSource")){
                    ++textures;const auto size=item->property("textureSize").toSize();texturePixels+=qint64(size.width())*size.height();
                }
                for(auto *child:item->childItems())inspect(child);
            };
            if(auto *wall=find(window->contentItem(),"songWall")){
                inspect(wall);wallStats["visible"]=wall->isVisible();
                if(auto *field=find(wall,"songWallField")){wallStats["content_x"]=field->property("contentX").toDouble();wallStats["content_y"]=field->property("contentY").toDouble();}
            }
            wallStats["tiles"]=tiles;wallStats["images"]=images;wallStats["ready_images"]=readyImages;
            wallStats["requested_image_pixels"]=imagePixels;wallStats["effect_sources"]=textures;wallStats["requested_effect_pixels"]=texturePixels;
            row["wall"]=wallStats;
        }
        if(auto *image=find(window->contentItem(),"playerBarCoverImage")){
            row["footer_decode_size"]=QJsonValue::fromVariant(image->property("sourceSize"));
        }
        QList<double> frames;{QMutexLocker lock(&mutex);frames.swap(gaps);}
        row["frame_gaps_ms"]=QJsonArray::fromVariantList([&]{QVariantList v;for(auto x:frames)v.append(x);return v;}());
        samples.write(QJsonDocument(row).toJson(QJsonDocument::Compact)+"\n");samples.flush();
    };
    QTimer sampler; sampler.setInterval(1000);QObject::connect(&sampler,&QTimer::timeout,&owner,sample);sampler.start();
    const auto mark=[&](QString name){sample();phase=name;{QMutexLocker lock(&mutex);lastFrame=0;gaps.clear();}event({{"phase",name}});qInfo()<<"Performance phase"<<name<<clock.elapsed();};
    const auto pause=[&](int ms){settle(ms);};
    const int duration=qMax(30,qEnvironmentVariableIntValue("RHINE_QA_PERF_SECONDS"));
    const bool shortRun=duration<600;
    mark("startup-stable");pause(5000);
    mark("idle");pause(shortRun?5000:300000);
    QJsonArray songs,lines;
    const bool wallRun=qEnvironmentVariableIntValue("RHINE_QA_PERF_WALL")==1;
    const int songCount=wallRun?200:20;
    for(int i=0;i<songCount;++i){
        QImage cover(1600,1600,QImage::Format_RGB32);cover.fill(QColor::fromHsv(i*17,85,170));
        {QPainter paint(&cover);paint.setPen(QPen(QColor("#e8d9bb"),16));for(int j=0;j<8;++j)paint.drawEllipse(QPointF(800,800),80+j*80,80+j*80);}
        const auto path=output+QString("/cover-%1.jpg").arg(i);cover.save(path,"JPG",90);
        auto song=MusicData::item("song",QString::number(881100+i),QStringLiteral("性能测试歌曲 %1").arg(i),"Rhine");
        song["cover"]=QUrl::fromLocalFile(path).toString();song["duration"]=240000;songs.append(song);
    }
    for(int i=0;i<60;++i){QJsonArray words;for(int j=0;j<4;++j)words.append(QJsonObject{{"startMs",i*4000+j*950},{"endMs",i*4000+(j+1)*950},{"text",QStringLiteral("寻找声音 ")}});
        lines.append(QJsonObject{{"startMs",i*4000},{"endMs",i*4000+3800},{"text",QStringLiteral("越过长夜，寻找你的声音")},{"words",words}});}
    const QJsonObject document{{"version",1},{"timing","word"},{"offsetMs",0},{"plainText",""},{"lines",lines}};
    QFile wav(output+"/audio.wav");if(!wav.open(QIODevice::WriteOnly))return 1;
    {QDataStream pcm(&wav);pcm.setByteOrder(QDataStream::LittleEndian);constexpr quint32 bytes=240*48000*4;
     wav.write("RIFF",4);pcm<<quint32(36+bytes);wav.write("WAVEfmt ",8);pcm<<quint32(16)<<quint16(1)<<quint16(2)<<quint32(48000)<<quint32(192000)<<quint16(4)<<quint16(16);wav.write("data",4);pcm<<bytes;
     QByteArray second;QDataStream tone(&second,QIODevice::WriteOnly);tone.setByteOrder(QDataStream::LittleEndian);
     for(int i=0;i<48000;++i){auto s=qint16(1000*std::sin(2*3.141592653589793*440*i/48000));tone<<s<<s;}
     for(int i=0;i<240;++i)wav.write(second);}
    wav.close();const auto audioUrl=QUrl::fromLocalFile(wav.fileName()).toString();
    backend.host.fixture=[&](QString route,QJsonObject){
        QJsonObject body{{"code",200}};
        if(route=="/native/netease/playback")body["value"]=QJsonObject{{"url",audioUrl}};
        else if(route=="/native/netease/lyrics")body["value"]=document;
        else if(route.startsWith("/comment")){QJsonArray comments;for(int i=0;i<30;++i)comments.append(QJsonObject{{"commentId",i+1},{"content",QStringLiteral("测试评论内容，保持完整的评论布局。")},{"user",QJsonObject{{"nickname","Rhine"},{"userId",42}}}});body["comments"]=comments;body["hotComments"]=comments;body["total"]=30;}
        return QJsonObject{{"body",body}};
    };
    backend.host.mediaControl("volume",0);
    const auto play=[&](int index){auto song=songs[index].toObject();music.player.play(song,songs,index);music.current=song;backend.wake();};
    const auto detail=[&]{music.selectedPhysical=backend.scene.selection();backend.scene.review("detail");hud.lyricsMode=true;backend.wake();};
    if(wallRun){
        play(0);detail();pause(3000);
        bool ok=backend.host.mediaState()["playing"].toBool();
        auto *page=find(window->contentItem(),"songDetailPage");if(!page)return 1;
        const auto choose=[&](QString tab){
            QElapsedTimer timer;timer.start();QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant(tab)));
            auto *motion=find(page,"detailContentMotion");
            while((page->property("tab").toString()!=tab||(motion&&motion->property("busy").toBool()))&&timer.elapsed()<5000)pause(10);
            const bool reached=page->property("tab").toString()==tab;ok&=reached;
            event({{"navigation",tab},{"complete_ms",timer.elapsed()},{"reached",reached}});
        };
        mark("wall-lyrics-before");pause(8000);
        mark("wall-entry");choose("wall");pause(3000);
        mark("wall-playing");pause(15000);window->grabWindow().save(output+"/wall-playing.png");
        if(qEnvironmentVariableIntValue("RHINE_QA_PERF_WALL_ATTRIBUTION")==1){
            // Destructive ablations exist only inside this isolated offline test.
            // Never disable production effects or alter saved user preferences.
            auto *wall=find(page,"songWall");if(!wall)return 1;
            QJsonArray sources;
            const std::function<void(QQuickItem*)> describe=[&](QQuickItem *item){
                const auto type=QByteArray(item->metaObject()->className());
                if(type.startsWith("QQuickShaderEffectSource")){
                    const auto size=item->property("textureSize").toSize();
                    QStringList ancestry;for(auto *p=item->parentItem();p&&p!=wall;p=p->parentItem())ancestry.append(p->objectName()+":"+p->metaObject()->className());
                    sources.append(QJsonObject{{"width",size.width()},{"height",size.height()},{"parents",ancestry.join("/")}});
                }
                for(auto *child:item->childItems())describe(child);
            };describe(wall);
            QFile sourceReport(output+"/effect-sources.json");if(sourceReport.open(QIODevice::WriteOnly))sourceReport.write(QJsonDocument(sources).toJson());
            delete find(wall,"wallHeaderFrost");delete find(wall,"wallFooterFrost");pause(3000);
            mark("attribution-no-frost");pause(12000);
            const std::function<void(QQuickItem*)> clearArt=[&](QQuickItem *item){
                if(item->objectName()=="wallArtwork"){item->setProperty("cache",false);item->setProperty("requested",false);}
                for(auto *child:item->childItems())clearArt(child);
            };clearArt(wall);pause(3000);mark("attribution-no-tile-images");pause(12000);
            // Stop the wall's row motion, leaving audio, fog and header intact.
            for(auto *object:wall->findChildren<QObject*>())
                if(QByteArray(object->metaObject()->className()).startsWith("QQuickSequentialAnimation"))object->setProperty("running",false);
            pause(3000);mark("attribution-no-row-motion");pause(12000);
            music.player.setPaused(true);pause(4000);mark("attribution-paused");pause(10000);
            choose("lyrics");pause(3000);mark("attribution-hidden-wall");pause(10000);
            event({{"check","wall-attribution-complete"},{"passed",ok}});
            QObject::disconnect(connection);sampler.stop();backend.host.fixture={};return ok?0:1;
        }
        music.player.setPaused(true);pause(4000);
        mark("wall-paused");pause(12000);window->grabWindow().save(output+"/wall-paused.png");
        mark("wall-scroll");
        auto *field=find(page,"songWallField");
        for(int i=0;i<24&&field;++i){field->setProperty("contentX",(i%8)*126.);field->setProperty("contentY",(i%4)*126.);pause(100);}
        pause(2000);window->grabWindow().save(output+"/wall-scrolled.png");
        const QPointF savedScroll(field->property("contentX").toDouble(),field->property("contentY").toDouble());
        mark("wall-lyrics-return");choose("lyrics");pause(10000);
        auto *hiddenWall=find(page,"songWall");
        const bool released=hiddenWall&&!hiddenWall->property("resourcesActive").toBool()&&!find(page,"wallFooterFrost")&&!find(page,"wallHeaderFrost");ok&=released;
        event({{"check","hidden-wall-resources-released"},{"passed",released}});
        for(int pass=0;pass<3;++pass){
            mark(QString("wall-reopen-%1").arg(pass));choose("wall");pause(2000);
            auto *restored=find(page,"songWallField");
            const bool position=restored&&qAbs(restored->property("contentX").toDouble()-savedScroll.x())<1&&qAbs(restored->property("contentY").toDouble()-savedScroll.y())<1;
            ok&=position;event({{"check","wall-scroll-restored"},{"pass",pass},{"passed",position},{"expected_x",savedScroll.x()},{"expected_y",savedScroll.y()},{"actual_x",restored?restored->property("contentX").toDouble():-1},{"actual_y",restored?restored->property("contentY").toDouble():-1}});
            choose("lyrics");pause(2000);
        }
        mark("wall-final-return");pause(10000);sample();
        event({{"check","wall-complete"},{"passed",ok},{"queue_size",music.player.queue.size()}});
        QObject::disconnect(connection);sampler.stop();backend.host.fixture={};return ok?0:1;
    }
    if(qEnvironmentVariableIntValue("RHINE_QA_PERF_RECORD")==1){
        play(0);backend.action("player:now-playing");pause(4000);
        mark("record-playing");pause(30000);
        bool ok=backend.host.mediaState()["playing"].toBool()&&music.player.lyrics.document()["lines"].toArray().size()==60;
        auto *recordPage=find(window->contentItem(),"nowPlayingPanel");
        ok&=recordPage&&recordPage->isVisible();
        window->grabWindow().save(output+"/record-playing.png");
        mark("record-track-switch-20");for(int i=0;i<20;++i){play(i);pause(1600);}
        mark("record-page-toggle");for(int i=0;i<10;++i){backend.action("back");pause(750);backend.action("player:now-playing");pause(750);}
        mark("record-final-paused");music.player.setPaused(true);pause(10000);sample();
        window->grabWindow().save(output+"/record-final.png");
        event({{"check","record-complete"},{"passed",ok}});
        QObject::disconnect(connection);sampler.stop();backend.host.fixture={};
        return ok?0:1;
    }
    mark("playback");play(0);detail();pause(shortRun?3000:30000);
    bool ok=backend.host.mediaState()["playing"].toBool();
    ok&=music.player.lyrics.document()["lines"].toArray().size()==60;
    event({{"check","real-playback-and-lyrics"},{"passed",ok},{"lyric_lines",music.player.lyrics.document()["lines"].toArray().size()}});
    qInfo()<<"Performance actual audio playing"<<ok;
    window->grabWindow().save(output+"/playback.png");
    mark("track-switch-20");for(int i=0;i<20;++i){play(i);pause(shortRun?350:1600);}
    mark("page-cycle-first");
    const auto cycle=[&](int count){for(int pass=0;pass<count;++pass){
        detail();pause(500);auto *page=find(window->contentItem(),"songDetailPage");if(!page){ok=false;continue;}
        for(const auto *tab:{"stage","queue","wall","comments","lyrics"}){
            QElapsedTimer switchClock;switchClock.start();QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant(QString(tab))));
            while(page->property("tab").toString()!=tab&&switchClock.elapsed()<2500)pause(1);
            const auto commitMs=switchClock.elapsed();
            auto *motion=find(page,"detailContentMotion");
            while(motion&&motion->property("busy").toBool()&&switchClock.elapsed()<3000)pause(1);
            const auto completeMs=switchClock.elapsed();pause(qMax(0,750-int(completeMs)));
            const bool reached=page->property("tab").toString()==tab;ok&=reached;
            event({{"navigation",tab},{"pass",pass},{"phase",phase},{"commit_ms",commitMs},{"complete_ms",completeMs},{"reached",reached}});
            qInfo()<<"Performance navigation"<<tab<<"reached"<<reached<<"elapsed"<<switchClock.elapsed();
        }
        backend.action("back");pause(750);hud.openModal("settings");backend.wake();pause(500);hud.modal.clear();hud.closing=false;backend.wake();pause(500);
    }};
    cycle(shortRun?1:4);
    mark("return-initial-warm");backend.action("back");pause(5000);
    mark("page-cycle-repeat");cycle(shortRun?1:4);
    mark("return-initial-repeat");backend.action("back");pause(5000);
    detail();pause(1500);mark("long-playback");
    qint64 nextSwitch=clock.elapsed()+60000;
    while(clock.elapsed()<duration*1000LL){
        pause(250);
        if(clock.elapsed()>=nextSwitch){play((music.player.index+1)%20);nextSwitch+=60000;}
    }
    mark("final-cycle");cycle(1);backend.action("back");music.player.setPaused(true);backend.wake();
    mark("final-return-paused");pause(10000);sample();
    window->grabWindow().save(output+"/final.png");
    event({{"check","complete"},{"passed",ok}});
    QObject::disconnect(connection);sampler.stop();backend.host.fixture={};
    qInfo()<<"Performance run"<<(ok?"passed":"FAILED")<<"duration_ms"<<clock.elapsed();
    return ok?0:1;
}

