// Focused follow-up only: production QML, real pointer input, actual D3D frames.
if(qEnvironmentVariableIntValue("RHINE_QA_UI_FOLLOWUP")==1){
    backend.setVisualPreference("motion","full");hud.reduced=false;
    const auto tap=[&](QQuickItem *item){
        if(!item||!item->isVisible()||!item->isEnabled())return false;
        const auto p=item->mapToScene(item->boundingRect().center());
        QMouseEvent move(QEvent::MouseMove,p,window->mapToGlobal(p.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&move);
        QMouseEvent down(QEvent::MouseButtonPress,p,window->mapToGlobal(p.toPoint()),Qt::LeftButton,Qt::LeftButton,Qt::NoModifier);
        QMouseEvent up(QEvent::MouseButtonRelease,p,window->mapToGlobal(p.toPoint()),Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
        QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);return true;
    };
    const auto frame=[&](QString name){check(window->grabWindow().save(output+"/"+name+".png"),"saved focused production frame");};
    QImage cover(360,360,QImage::Format_RGB32);QPainter painter(&cover);QLinearGradient gradient(0,0,360,360);gradient.setColorAt(0,QColor("#ac777b"));gradient.setColorAt(1,QColor("#343b67"));painter.fillRect(cover.rect(),gradient);painter.setPen(QPen(QColor("#e9cdab"),6));for(int i=0;i<5;++i)painter.drawEllipse(QPointF(180,180),30+i*27,30+i*27);painter.end();cover.save(output+"/art.png");
    const auto artwork=QUrl::fromLocalFile(output+"/art.png").toString();
    QFile wav(output+"/deferred-playback.wav");check(wav.open(QIODevice::WriteOnly),"focused playback fixture opens");
    const quint32 bytes=30*8000*2;QDataStream pcm(&wav);pcm.setByteOrder(QDataStream::LittleEndian);wav.write("RIFF",4);pcm<<quint32(36+bytes);wav.write("WAVEfmt ",8);pcm<<quint32(16)<<quint16(1)<<quint16(1)<<quint32(8000)<<quint32(16000)<<quint16(2)<<quint16(16);wav.write("data",4);pcm<<bytes;wav.write(QByteArray(bytes,'\0'));wav.close();
    backend.host.mediaControl("volume",0);
    auto song=MusicData::item("song","551101",QStringLiteral("孤独のあかつき / A long title for the narrow player"),QStringLiteral("椎名林檎"));song["cover"]=artwork;song["album"]=QStringLiteral("いろはにほへと／孤独のあかつき — 長いアルバム名");song["albumID"]="5511";song["duration"]=180000;
    QJsonArray lines;for(int i=0;i<16;++i)lines.append(QJsonObject{{"startMs",i*5000},{"endMs",i*5000+4500},{"text",QStringLiteral("長い夜を越えて 君の声を探して")},{"translation",QStringLiteral("越过长夜，寻找你的声音")}});
    const QJsonObject document{{"version",1},{"timing","line"},{"offsetMs",0},{"plainText",""},{"lines",lines}};
    int likes=0,loads=0;
    backend.host.fixture=[&](QString route,QJsonObject args){
        QJsonValue value;
        if(route=="/native/netease/lyrics")value=document;
        else if(route=="/native/netease/playback")value=QJsonObject{{"url",QUrl::fromLocalFile(wav.fileName()).toString()}};
        else if(route=="/like"){++likes;return QJsonObject{{"body",QJsonObject{{"code",200}}}};}
        else if(route=="/native/netease/songs"){
            ++loads;QJsonArray loaded;for(auto id:args["args"].toArray().first().toArray()){auto row=song;row["id"]=id;row["key"]="netease:song:"+id.toString();loaded.append(row);}value=loaded;
        }
        return QJsonObject{{"body",QJsonObject{{"code",200},{"value",value}}}};
    };
    music.likedIDs=QJsonArray{};music.player.current=song;music.player.queue={song};music.player.index=0;music.player.loading=false;music.player.failed=false;music.player.changed();music.player.lyrics.load(song,true);
    music.current=song;music.selectedPhysical=backend.scene.selection();backend.scene.review("detail");hud.lyricsMode=true;hud.modal.clear();hud.closing=false;refresh();
    auto *page=find(window->contentItem(),"songDetailPage");check(page,"follow-up detail is the production page");if(!page)return 1;
    page->setProperty("tab","lyrics");
    #include "UiSwitchPerformanceChecks.inc"
    #include "UiPlaybackDetailsChecks.inc"
    #include "UiFivePagesChecks.inc"
    for(const auto size:{QSize(960,640),QSize(1280,720)}){
        window->resize(size);refresh();auto *title=find(page,"detailTitle");auto *credits=find(page,"detailCredits");auto *heart=find(page,"detailLike");auto *more=find(page,"detailMore");
        const auto box=[](QQuickItem *item){return item?item->mapRectToScene(item->boundingRect()):QRectF();};
        check(title&&credits&&heart&&more&&!box(title).intersects(box(heart))&&!box(credits).intersects(box(heart))&&!box(credits).intersects(box(more)),"narrow title, credits and song actions never overlap");
        frame(QString("metadata-%1").arg(size.width()));
    }
    auto *motion=find(page,"detailContentMotion");
    check(tap(find(page,"detailTab_stage")),"real pointer selects stage");settle(48);
    check(motion&&(motion->property("waiting").toBool()||(motion->property("progress").toDouble()>0&&motion->property("progress").toDouble()<1))&&page->property("tab").toString()=="lyrics","old content remains alive while target incubates and during outgoing animation");frame("detail-switch-out");
    settle(120);check(page->property("tab").toString()=="stage"&&motion->property("progress").toDouble()<1,"stage content enters gradually after tab commit");frame("detail-switch-in");settle(300);
    backend.setPlayerPreference("stage-style","steps");refresh();
    auto shortSong=song;shortSong["title"]=QStringLiteral("暗礁");music.current=shortSong;music.player.current=shortSong;music.player.changed();refresh();
    auto *stageTitle=find(page,"immersiveTitle");auto *stageHeart=find(page,"immersiveLike");
    check(stageTitle&&stageHeart&&stageHeart->mapToScene(QPointF()).x()-stageTitle->mapToScene(QPointF(stageTitle->width(),0)).x()>=10&&stageHeart->mapToScene(QPointF()).x()-stageTitle->mapToScene(QPointF(stageTitle->width(),0)).x()<=24,"short stage title keeps song actions immediately alongside it");
    auto *selector=find(page,"stageStyleSelector");auto *tab=find(page,"detailTab_stage");
    check(selector&&tab&&selector->height()==tab->height()&&std::abs(selector->mapToScene(selector->boundingRect().center()).y()-tab->mapToScene(tab->boundingRect().center()).y())<.1,"stage selector shares the tab height and centerline");
    frame("stage-alignment-actions");
    check(tap(find(page,"immersiveLike")),"stage heart receives real pointer input");refresh();check(likes==1&&backend.nowPlaying()->property("info").toMap()["liked"].toBool(),"stage heart writes the actual current-song like");
    check(tap(find(page,"immersiveMore")),"stage more receives real pointer input");refresh();auto *magazine=qobject_cast<PlaylistMagazine*>(backend.magazine());check(magazine->songMenu()["visible"].toBool(),"stage more opens the captured song menu");frame("stage-menu");escape();
    // Rapid changes retain only the latest target; no stale completion callback.
    QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("wall")));settle(30);QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("lyrics")));
    QElapsedTimer tabWait;tabWait.start();while((page->property("tab").toString()!="lyrics"||motion->property("busy").toBool())&&tabWait.elapsed()<1200)settle(10);
    check(page->property("tab").toString()=="lyrics"&&motion->property("progress").toDouble()==1,"rapid tab changes settle on the latest selection within 1.2 seconds");
    QJsonArray queue{song};for(int i=1;i<120;++i){auto row=MusicData::item("song",QString::number(551101+i),"Loading cover","");row["deferred"]=true;row["queueSource"]=QJsonObject{{"id","followup-origin"}};queue.append(row);}music.player.queue=queue;music.player.changed();refresh();
    page->setProperty("tab","wall");settle(40);backend.step(90);settle(20);
    auto *wall=find(page,"songWall");auto *field=find(wall,"songWallField");QQuickItem *deferred=nullptr;
    loads=0;music.player.queue=queue;music.player.changed();backend.step(90);settle(5);
    if(field)for(int i=1;i<120;++i){auto *tile=find(wall,QString("wallTile_%1").arg(i));if(!tile)continue;const auto p=tile->mapToItem(field,tile->boundingRect().center());if(p.y()>50&&p.y()<field->height()-120&&p.x()>60&&p.x()<field->width()-60){deferred=tile;break;}}
    const auto deferredIndex=deferred?deferred->property("modelData").toInt():-1;
    check(deferred&&deferred->isEnabled()&&deferred->property("track").toMap()["deferred"].toBool(),"a cover-loading wall tile is enabled before its artwork or metadata completes");
    check(tap(deferred),"real pointer selects a deferred wall song");
    QElapsedTimer selectionWait;selectionWait.start();while((music.player.index!=deferredIndex||loads==0)&&selectionWait.elapsed()<1000)settle(10);
    qInfo()<<"UI audit deferred selection"<<deferredIndex<<music.player.index<<loads<<selectionWait.elapsed();
    check(deferredIndex>0&&music.player.index==deferredIndex&&music.player.current["id"]==queue[deferredIndex].toObject()["id"]&&loads>0,"deferred click immediately selects playback and requests metadata");
    QElapsedTimer audioWait;audioWait.start();while(!backend.host.mediaState()["playing"].toBool()&&audioWait.elapsed()<4000)settle(20);
    check(!music.player.failed&&!music.player.loading&&backend.host.mediaState()["playing"].toBool(),"deferred wall click completes real audio playback without waiting for artwork");backend.host.mediaControl("stop");
    // Dense, distinct local covers cross the actual footer sampling band.
    QStringList localCovers;for(int i=0;i<10;++i){QImage image=cover;QPainter art(&image);art.setCompositionMode(QPainter::CompositionMode_SourceAtop);art.fillRect(image.rect(),QColor::fromHsv(i*36,160,220,155));art.setPen(QPen(Qt::white,10));art.drawLine(0,30+i*26,360,330-i*22);art.end();auto path=output+QString("/wall-art-%1.png").arg(i);image.save(path);localCovers<<QUrl::fromLocalFile(path).toString();}
    QJsonArray dense;for(int i=0;i<120;++i){auto row=song;row["id"]=QString::number(551101+i);row["key"]="netease:song:"+row["id"].toString();row["cover"]=localCovers[i%10];dense.append(row);}
    music.player.current=song;music.player.queue=dense;music.player.index=0;music.player.loading=false;music.player.changed();refresh();
    if(field){field->setProperty("contentX",0);field->setProperty("contentY",0);}settle(300);
    check(find(page,"wallLike")&&find(page,"wallMore"),"wall title exposes shared like and more controls");frame("wall-actions-footer");
    check(tap(find(page,"wallMore")),"wall more receives real pointer input");refresh();check(magazine->songMenu()["visible"].toBool(),"wall more opens the actual song menu");escape();
    hud.lyricsMode=false;backend.scene.review("archive");hud.modal.clear();hud.closing=false;hud.profileID="42";hud.profileSection="music";hud.profileFilter="all";hud.profile=QJsonObject{{"nickname","Rhine QA"},{"avatarUrl",artwork}};
    QJsonArray playlists;for(int i=0;i<12;++i){auto row=MusicData::item("playlist",QString::number(8800+i),QString("声音与记忆 %1").arg(i+1),"Rhine QA");row["cover"]=localCovers[i%10];row["owned"]=true;row["trackCount"]=24;row["playCount"]=28000;playlists.append(row);}hud.profileCollections=QJsonObject{{"playlists",QJsonObject{{"rows",playlists},{"loading",false},{"more",false}}},{"albums",QJsonObject{{"rows",playlists}}}};hud.openModal("profile");refresh();
    auto *profile=find(window->contentItem(),"userProfilePage");auto *body=find(profile,"profileSectionBody_created");auto *reading=find(profile,"profileReading");
    if(reading)reading->setProperty("contentY",280);refresh();const auto collapsed=body?body->height():0;QPointer<QQuickItem> retainedCard=find(profile,"profileCard_playlists_0");
    check(tap(find(profile,"profileExpand_created")),"real pointer expands profile cards");settle(110);const auto midway=body?body->height():0;frame("profile-expand-mid");settle(300);const auto expanded=body?body->height():0;
    qInfo()<<"UI audit fold dimensions"<<collapsed<<midway<<expanded;
    check(collapsed>0&&midway>collapsed&&midway<expanded,"card expansion animates actual content height");
    tap(find(profile,"profileExpand_created"));settle(110);check(body&&body->height()>collapsed&&body->height()<expanded,"card collapse animates instead of removing rows immediately");frame("profile-collapse-mid");settle(300);check(body&&std::abs(body->height()-collapsed)<1,"collapse finishes at one complete row");
    check(retainedCard&&retainedCard==find(profile,"profileCard_playlists_0")&&retainedCard->opacity()==1,"expand and collapse preserve the first-row delegate without restarting its fade");
    frame("profile-source-cards");check(tap(find(profile,"profileOrder_created")),"source sort chip opens by actual pointer input");refresh();frame("profile-sort-menu");escape();
    auto *profileMotion=find(profile,"profileContentMotion");QMetaObject::invokeMethod(profile,"change",Q_ARG(QVariant,QVariant("profile:filter:albums")));settle(48);check(profileMotion&&profileMotion->property("progress").toDouble()<1&&hud.profileFilter=="all","profile switch fades the old album and playlist content before replacement");settle(130);check(hud.profileFilter=="albums"&&profileMotion->property("progress").toDouble()<1,"profile switch animates incoming content as well as its pill");frame("profile-switch-in");settle(300);
    frame("profile-source-albums");
    qInfo()<<"UI audit focused follow-up"<<(ok?"passed":"FAILED");return ok?0:1;
}

