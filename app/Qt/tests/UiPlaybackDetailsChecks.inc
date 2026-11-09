if(qEnvironmentVariableIntValue("RHINE_QA_UI_PLAYBACK_DETAILS")==1){
    // Offline runs advance the native renderer explicitly. Synchronize resize
    // before stepping; the queued production resize handler runs during settle.
    const auto refresh=[&]{backend.resize(window->width(),window->height());backend.step(90);settle(450);};
    window->resize(1280,720);refresh();settle(350);
    auto *motion=find(page,"detailContentMotion");
    auto *stageTab=find(page,"detailTab_stage");auto *selector=find(stageTab,"stageStyleSelector");
    check(selector&&!selector->isVisible(),"stage arrow is absent outside stage");const auto originalWidth=stageTab->width();
    const auto choose=[&](QString name){check(tap(find(page,"detailTab_"+name)),"real pointer selects detail tab");};
    for(const auto tab:{"stage","queue","wall","comments","lyrics"}){
        const auto previous=page->property("tab").toString();choose(tab);settle(48);
        check(motion->property("progress").toDouble()>0&&motion->property("progress").toDouble()<1&&page->property("tab").toString()==previous,"whole outgoing content animates before replacement");
        if(QString(tab)=="stage")frame("detail-outgoing");
        settle(125);check(page->property("tab").toString()==tab&&motion->property("progress").toDouble()>0&&motion->property("progress").toDouble()<1,"whole incoming content animates after replacement");
        if(QString(tab)=="stage")frame("detail-incoming");settle(350);
        check(std::abs(find(page,"detailTabIndicator")->x()-find(page,"detailTab_"+QString(tab))->x())<1,"tab indicator settles with the new content without a trailing second capsule");
    }
    choose("stage");settle(450);check(selector&&selector->isVisible()&&stageTab->width()==originalWidth,"stage arrow appears inside its tab without moving later tabs");
    check(!find(page,"stageStyleLabel"),"separate current-mode label is removed");
    check(tap(stageTab),"selected stage tab receives second click");refresh();frame("stage-integrated-menu");
    auto *steps=find(window->contentItem(),"stageMode_steps");check(steps&&steps->isVisible(),"second stage click opens its attached mode options");
    check(steps&&std::abs(steps->mapToScene(QPointF()).x()-stageTab->mapToScene(QPointF()).x())<15,"mode menu opens directly beneath its stage tab");
    check(tap(steps),"real pointer selects cloud steps");refresh();check(hud.state()["playerPreferences"].toObject()["stageStyle"]=="steps","mode menu updates the existing stage preference");
    frame("stage-integrated");
    window->resize(960,640);refresh();check(tap(stageTab),"narrow stage tab opens its mode menu");refresh();frame("stage-menu-narrow");check(find(window->contentItem(),"stageMode_steps")->mapToScene(QPointF()).x()>=0,"narrow stage menu stays in the window");check(tap(find(window->contentItem(),"stageMode_steps")),"narrow mode option receives pointer");settle(450);window->resize(1280,720);refresh();
    QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("wall")));settle(30);QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("lyrics")));settle(450);
    check(page->property("tab").toString()=="lyrics"&&motion->property("progress").toDouble()==1,"rapid content switches finish at the most recent target");
    // Muted production playback: modulated broadband PCM, no platform writes.
    QFile audio(output+"/spectrum.wav");check(audio.open(QIODevice::WriteOnly),"spectrum audio fixture opens");QDataStream pcm(&audio);pcm.setByteOrder(QDataStream::LittleEndian);constexpr int rate=48000,frames=rate*20;audio.write("RIFF",4);pcm<<quint32(36+frames*2);audio.write("WAVEfmt ",8);pcm<<quint32(16)<<quint16(1)<<quint16(1)<<quint32(rate)<<quint32(rate*2)<<quint16(2)<<quint16(16);audio.write("data",4);pcm<<quint32(frames*2);
    quint32 seed=17;for(int i=0;i<frames;++i){seed=seed*1664525+1013904223;const auto envelope=.2+.8*(.5+.5*std::sin(2*3.141592653589793*i/rate*2));pcm<<qint16((double(seed)/4294967295.*2-1)*22000*envelope);}audio.close();
    backend.host.mediaControl("volume",0);backend.host.enableVisualLevels(true);check(backend.host.mediaLoad(QUrl::fromLocalFile(audio.fileName()).toString()),"muted real PCM fixture loads through production player");backend.host.mediaControl("play");
    QElapsedTimer wait;wait.start();bool measured=false;while(wait.elapsed()<4000&&!measured){settle(40);for(auto value:backend.host.mediaState()["visualBands"].toList())if(value.toDouble()>.3)measured=true;}
    check(measured,"real decoded audio exposes nonzero timestamp-matched spectrum bands");
    const auto signalState=backend.host.mediaState();music.player.state=QJsonObject::fromVariantMap(signalState);music.player.changed();refresh();
    choose("queue");settle(450);auto *queueRow=find(page,"detailQueueRow_0");auto *queueBars=find(queueRow,"playingBars");
    check(queueBars&&queueBars->property("energy").toDouble()>.01,"production queue indicator responds to decoded audio");frame("queue-spectrum");
    choose("wall");settle(450);auto *wallBars=find(find(page,"wallTile_0"),"playingBars");check(wallBars&&wallBars->isVisible(),"current wall tile uses shared spectrum bars");frame("wall-spectrum");
    hud.lyricsMode=false;hud.modal.clear();hud.closing=false;backend.scene.review("detail");
    for(const auto kind:{"playlist","album"}){
        auto folder=std::make_shared<MusicDirectory>();folder->item=MusicData::item(kind,"9201",QStringLiteral("播放状态与声音"),"Rhine QA");folder->item["cover"]=artwork;for(int i=0;i<3;++i){auto row=song;row["id"]=QString::number(551101+i);row["key"]="netease:song:"+row["id"].toString();folder->songs.append(row);folder->ids.append(row["id"]);}folder->cursor=3;music.directory=folder;music.directoryInfo=true;music.current=folder->item;music.invalidated();refresh();
        auto *list=find(window->contentItem(),"playlistMagazinePage");auto *indicator=find(find(list,"magazinePlaying_0"),"playingBars");
        check(list&&indicator&&indicator->isVisible(),"playlist and album current song use the shared source indicator");frame(QString(kind)+"-spectrum");
        if(QString(kind)=="album"){window->resize(960,640);refresh();frame("album-spectrum-narrow");check(indicator->isVisible(),"narrow album keeps the current-song indicator visible");window->resize(1280,720);refresh();}
    }
    music.directory.reset();music.directoryInfo=false;music.current=song;backend.scene.review("archive");refresh();
    auto *shortcut=find(window->contentItem(),"globalNowPlaying");auto *shortcutBars=find(shortcut,"playingBars");
    check(shortcutBars&&shortcutBars->isVisible(),"playback bar uses the shared spectrum component");
    if(shortcut){auto p=shortcut->mapToScene(shortcut->boundingRect().center());QMouseEvent move(QEvent::MouseMove,p,window->mapToGlobal(p.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&move);}settle(750);frame("playback-hover-no-tip");
    hud.queueOpen=true;refresh();auto *drawerBars=find(find(window->contentItem(),"queueRow_0"),"playingBars");check(drawerBars&&drawerBars->isVisible(),"queue drawer current song uses shared spectrum bars");frame("drawer-spectrum");hud.queueOpen=false;refresh();
    backend.host.mediaControl("pause");music.player.state=QJsonObject::fromVariantMap(backend.host.mediaState());music.player.changed();refresh();settle(1000);
    check(shortcutBars&&shortcutBars->property("energy").toDouble()<.02,"paused playback returns spectrum bars to rest instead of looping");frame("playback-paused");
    backend.host.fixture=[&](QString route,QJsonObject){QJsonObject body{{"code",200}};if(route=="/user/detail")body["profile"]=QJsonObject{{"userId",42},{"nickname","Rhine QA"},{"avatarUrl",artwork},{"artistId",5512}};else if(route=="/record/recent/playlist")body["data"]=QJsonObject{{"list",QJsonArray{}}};return QJsonObject{{"body",body}};};
    backend.action("profile:open:42");refresh();auto *profile=find(window->contentItem(),"userProfilePage");auto *artist=find(profile,"profileArtistEntry");auto *history=find(profile,"profileHistoryEntry");
    check(artist&&history&&artist->property("iconName")=="cloudyUser"&&history->property("iconName")=="userRanking","profile entries use upstream artist SVG and user-supplied ranking SVG");frame("profile-entry-icons");
    check(tap(history),"history icon entry receives real pointer click");refresh();check(hud.profileFilter=="recent","history icon entry preserves its destination");frame("profile-history");
    hud.profileRecentKind="song";hud.profileRows={song};hud.profileLoading=false;refresh();auto *historyBars=find(find(window->contentItem(),"profileCard_legacy_0"),"playingBars");check(historyBars&&historyBars->isVisible(),"history current song uses shared spectrum bars");frame("history-spectrum");
    window->resize(960,640);refresh();frame("profile-icons-narrow");check(artist&&history&&artist->isVisible()&&history->isVisible()&&artist->mapToScene(QPointF(artist->width(),0)).x()<=history->mapToScene(QPointF()).x(),"narrow profile icons and labels remain separate");
    backend.host.mediaControl("stop");qInfo()<<"UI audit playback details"<<(ok?"passed":"FAILED");return ok?0:1;
}
