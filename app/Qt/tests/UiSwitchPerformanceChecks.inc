// Scoped real-window switch trace. No screenshot readback inside measured intervals.
if(qEnvironmentVariableIntValue("RHINE_QA_SWITCH_PERF")==1){
    window->resize(1280,720);backend.resize(1280,720);refresh();
    QJsonArray dense;for(int i=0;i<240;++i){auto row=song;row["id"]=QString::number(551101+i);row["key"]="netease:song:"+row["id"].toString();dense.append(row);}
    music.player.queue=dense;music.player.changed();music.player.play(song,dense,0);refresh();
    QElapsedTimer nativeClock;nativeClock.start();QTimer nativeTick;
    QObject::connect(&nativeTick,&QTimer::timeout,window,[&]{backend.step(90+nativeClock.elapsed()/1000.);});nativeTick.start(16);
    QJsonArray results;
    const auto measure=[&](QString label,std::function<void()> select){
        QObject sampleOwner;QList<double> gaps,beats;QElapsedTimer clock;clock.start();qint64 last=0,lastBeat=0;
        auto connection=QObject::connect(window,&QQuickWindow::frameSwapped,&sampleOwner,[&]{auto now=clock.nsecsElapsed();if(last)gaps.append((now-last)/1e6);last=now;},Qt::QueuedConnection);
        QTimer heartbeat;heartbeat.setTimerType(Qt::PreciseTimer);heartbeat.setInterval(4);
        QObject::connect(&heartbeat,&QTimer::timeout,window,[&]{auto now=clock.nsecsElapsed();if(lastBeat)beats.append((now-lastBeat)/1e6);lastBeat=now;});heartbeat.start();
        select();settle(750);heartbeat.stop();QObject::disconnect(connection);
        std::sort(gaps.begin(),gaps.end());std::sort(beats.begin(),beats.end());
        const auto percentile=[](const QList<double>&v,double p){return v.isEmpty()?0.:v[std::min(v.size()-1,qsizetype(v.size()*p))];};
        int stalls=0;for(auto gap:gaps)if(gap>33.4)++stalls;
        QJsonObject row{{"switch",label},{"frames",gaps.size()},{"p95_ms",percentile(gaps,.95)},{"max_ms",percentile(gaps,1)},{"over_33_ms",stalls},{"gui_max_ms",percentile(beats,1)}};
        results.append(row);qInfo()<<"Switch trace"<<QJsonDocument(row).toJson(QJsonDocument::Compact);
    };
    for(int pass=0;pass<2;++pass)for(auto key:{"stage","queue","wall","comments","lyrics"}){
        measure(QString("detail-%1-%2").arg(pass).arg(key),[&]{check(tap(find(page,"detailTab_"+QString(key))),"detail switch pointer accepted");});
        check(page->property("tab")==key,"detail switch reaches target");
    }
    auto *detailMotion=find(page,"detailContentMotion");
    QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("queue")));settle(45);
    check(detailMotion&&detailMotion->property("progress").toDouble()>0&&detailMotion->property("progress").toDouble()<1,"detail outgoing content visibly animates");frame("detail-outgoing");settle(120);frame("detail-incoming");settle(450);
    QPointer<QQuickItem> retainedStage=find(page,"lyricStage");
    QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("stage")));settle(30);QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("lyrics")));settle(700);
    check(page->property("tab")=="lyrics","rapid detail switch keeps latest target");
    if(qEnvironmentVariableIntValue("RHINE_QA_SWITCH_ACCEPT")==1)check(retainedStage&&retainedStage==find(page,"lyricStage")&&!retainedStage->isVisible(),"inactive detail pane retained and hidden");
    frame("detail-after-switches");
    hud.lyricsMode=false;hud.modal.clear();hud.closing=false;backend.scene.review("archive");
    hud.profileID="42";hud.profileSection="music";hud.profileFilter="all";hud.profileSnapshotAccount=music.accountGeneration();
    hud.profile=QJsonObject{{"nickname","Rhine QA"},{"avatarUrl",artwork}};
    QJsonArray playlists,albums,artists;
    for(int i=0;i<240;++i){auto row=MusicData::item("playlist",QString::number(8800+i),QString("音乐收藏 %1").arg(i),"Rhine QA");row["cover"]=artwork;row["owned"]=i<120;row["trackCount"]=24;playlists.append(row);}
    for(int i=0;i<180;++i){auto row=MusicData::item("album",QString::number(9800+i),QString("专辑 %1").arg(i),"Rhine QA");row["cover"]=artwork;albums.append(row);}
    for(int i=0;i<90;++i){auto row=MusicData::item("artist",QString::number(10800+i),QString("歌手 %1").arg(i));row["cover"]=artwork;artists.append(row);}
    hud.profileCollections={{"playlists",QJsonObject{{"rows",playlists}}},{"albums",QJsonObject{{"rows",albums}}},{"artists",QJsonObject{{"rows",artists}}}};
    hud.openModal("profile");refresh();auto *profile=find(window->contentItem(),"userProfilePage");check(profile,"profile performance fixture opens");if(!profile)return 1;
    QElapsedTimer initialCards;initialCards.start();while(!find(profile,"profileCard_playlists_0")&&initialCards.elapsed()<2500)settle(20);
    QPointer<QQuickItem> original=find(profile,"profileCard_playlists_0");
    qInfo()<<"Switch initial profile card"<<bool(original);
    for(int pass=0;pass<2;++pass)for(auto key:{"playlists","albums","artists","all"}){
        measure(QString("profile-%1-%2").arg(pass).arg(key),[&]{check(tap(find(profile,"profileSegment_"+QString(key))),"profile switch pointer accepted");});
        check(hud.profileFilter==key,"profile switch reaches target");
        qInfo()<<"Switch profile retained"<<key<<bool(original)<<(original==find(profile,"profileCard_playlists_0"));
    }
    const bool retained=original&&original==find(profile,"profileCard_playlists_0");
    qInfo()<<"Switch retained profile card"<<retained;
    if(qEnvironmentVariableIntValue("RHINE_QA_SWITCH_ACCEPT")==1)check(retained,"profile tabs retain existing card instances");
    QMetaObject::invokeMethod(profile,"change",Q_ARG(QVariant,QVariant("profile:filter:albums")));settle(45);frame("profile-outgoing");settle(120);frame("profile-incoming");settle(450);
    QMetaObject::invokeMethod(profile,"change",Q_ARG(QVariant,QVariant("profile:filter:albums")));settle(30);
    QMetaObject::invokeMethod(profile,"change",Q_ARG(QVariant,QVariant("profile:filter:all")));settle(750);check(hud.profileFilter=="all","rapid profile switch keeps latest selection");
    frame("profile-after-switches");
    auto *profileMotion=find(profile,"profileContentMotion");
    check(tap(find(profile,"profileExpand_created")),"expand retains pointer interaction");settle(110);auto *fold=find(profile,"profileSectionBody_created");const auto middle=fold?fold->height():0;settle(350);check(fold&&fold->height()>middle,"expand still animates its content height");
    auto *reading=find(profile,"profileReading");if(reading){reading->setProperty("contentY",1000);settle(400);bool later=false;for(int i=14;i<80;++i)if(auto *card=find(profile,"profileCard_playlists_"+QString::number(i));card&&card->isVisible())later=true;check(later,"scrolling incubates later visible card rows");frame("profile-scrolled");reading->setProperty("contentY",0);settle(200);}
    check(tap(find(profile,"profileExpand_created")),"collapse retains pointer interaction");settle(400);check(original&&original==find(profile,"profileCard_playlists_0"),"expand scroll collapse retain first card");
    // Search and keyboard continue to address original collection indices.
    auto *search=find(profile,"profileSearch");check(search,"profile search exists");if(search){search->setProperty("text","119");settle(400);check(find(profile,"profileCard_playlists_119"),"search keeps the original collection index");search->setProperty("text","");settle(400);}
    window->resize(960,640);backend.resize(960,640);hud.dark=true;backend.scene.theme(true);settle(450);
    measure("profile-narrow-dark-albums",[&]{tap(find(profile,"profileSegment_albums"));});frame("profile-narrow-dark");
    backend.setVisualPreference("motion","off");settle(100);QMetaObject::invokeMethod(profile,"change",Q_ARG(QVariant,QVariant("profile:filter:all")));settle(100);
    check(profileMotion&&profileMotion->property("progress").toDouble()==1&&hud.profileFilter=="all","motion off commits without transition");
    nativeTick.stop();
    QFile report(output+"/switch-trace.json");check(report.open(QIODevice::WriteOnly),"switch trace opens");report.write(QJsonDocument(results).toJson());report.close();
    qInfo()<<"UI audit switch performance"<<(ok?"passed":"FAILED");return ok?0:1;
}
