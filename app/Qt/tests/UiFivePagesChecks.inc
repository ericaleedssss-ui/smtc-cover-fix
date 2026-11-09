// This batch alone: five production panes, credits, account-stat navigation.
if(qEnvironmentVariableIntValue("RHINE_QA_UI_FIVE_PAGES")==1){
    song["artists"]=QJsonArray{QJsonObject{{"id","5512"},{"name",QStringLiteral("椎名林檎")}}};
    QStringList profileRequests;
    backend.host.fixture=[&](QString route,QJsonObject args){
        QJsonObject body{{"code",200}};
        if(route.startsWith("/user/"))profileRequests<<route+":"+args["uid"].toString();
        if(route=="/native/netease/lyrics")body["value"]=document;
        else if(route=="/user/detail")body["profile"]=QJsonObject{{"userId",42},{"nickname","Rhine QA"},{"avatarUrl",artwork},{"followeds",8},{"follows",31},{"eventCount",5}};
        else if(route=="/user/follows"||route=="/user/followeds")body[route=="/user/follows"?"follow":"followeds"]=QJsonArray{QJsonObject{{"userId",51},{"nickname",QStringLiteral("音乐里的朋友")},{"avatarUrl",artwork},{"signature",QStringLiteral("Good luck to you.")}}};
        else if(route=="/user/event"){body["events"]=QJsonArray{QJsonObject{{"id",61},{"eventTime",1700000000000.},{"user",QJsonObject{{"userId",42},{"nickname","Rhine QA"},{"avatarUrl",artwork}}},{"json",QStringLiteral("{\"msg\":\"记录今天的声音\"}")}}};body["more"]=false;}
        else if(route=="/user/playlist")body["playlist"]=QJsonArray{};
        else body["value"]=QJsonObject{};
        return QJsonObject{{"body",body}};
    };
    QStringList covers;for(int i=0;i<8;++i){QImage image=cover;QPainter paint(&image);paint.fillRect(image.rect(),QColor::fromHsv(i*45,180,200,160));paint.setPen(QPen(Qt::white,8));paint.drawLine(0,40+i*28,360,320-i*20);paint.end();auto path=output+QString("/cover-%1.png").arg(i);image.save(path);covers<<QUrl::fromLocalFile(path).toString();}
    QJsonArray queue;for(int i=0;i<64;++i){auto row=song;row["id"]=QString::number(551101+i);row["key"]="netease:song:"+row["id"].toString();row["cover"]=covers[i%8];queue.append(row);}
    music.player.current=song;music.current=song;music.player.queue=queue;music.player.index=0;music.player.changed();music.player.lyrics.sync(800);refresh();
    const auto rect=[](QQuickItem *item){return item?item->mapRectToScene(item->boundingRect()):QRectF();};
    const auto move=[&](QQuickItem *item){if(!item)return;auto p=item->mapToScene(item->boundingRect().center());QMouseEvent event(QEvent::MouseMove,p,window->mapToGlobal(p.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&event);settle(180);};
    for(const auto size:{QSize(960,640),QSize(1280,720)}){
        window->resize(size);refresh();
        for(const auto tab:{"lyrics","stage","queue","wall","comments"}){
            check(tap(find(page,QString("detailTab_")+tab)),"actual pointer switches the requested detail pane");settle(480);
            check(page->property("tab").toString()==tab,"requested detail pane is displayed after transition");
            if(QString(tab)=="comments"){
                hud.commentsLoading=false;hud.commentsError.clear();hud.commentsMore=false;hud.commentsTotal=3;
                QJsonArray comments;for(int i=0;i<3;++i)comments.append(QJsonObject{{"id",QString::number(700+i)},{"author",QStringLiteral("音乐里的朋友")},{"avatar",artwork},{"userID","51"},{"content",QStringLiteral("越过长夜，寻找你的声音。\n这首歌陪伴了很多个安静的夜晚。")},{"likes",12+i},{"date","2026.11.08"}});
                hud.commentsFeatured=QJsonArray{comments.first()};hud.commentsRows=comments;refresh();
            }
            if(QString(tab)=="lyrics"){
                auto *credits=find(page,"detailCredits");auto *heart=find(page,"detailLike");auto *more=find(page,"detailMore");
                check(credits&&heart&&more&&!rect(credits).intersects(rect(heart))&&!rect(credits).intersects(rect(more)),"credits and actions have separate space at both window sizes");
                auto *words=find(page,"detailLyricWords_0");auto *pane=find(page,"detailStandardPane");
                check(words&&pane&&std::abs(rect(words).top()-rect(pane).top())<45,"first lyric starts at the source pane inset without artificial blank space");
                auto *artist=find(credits,"creditPart_0");auto *album=find(credits,"creditPart_2");
                check(artist&&album&&!artist->property("font").value<QFont>().underline()&&!album->property("font").value<QFont>().underline(),"artist and album use plain text without an underline");
                auto idle=artist?artist->property("color").value<QColor>():QColor();move(artist);
                check(artist&&artist->property("color").value<QColor>().alphaF()>idle.alphaF()&&!artist->property("font").value<QFont>().underline(),"artist hover brightens without adding a line");
                frame(QString("credits-hover-%1").arg(size.width()));move(find(page,"detailTab_lyrics"));
                idle=album?album->property("color").value<QColor>():QColor();move(album);
                check(album&&album->property("color").value<QColor>().alphaF()>idle.alphaF()&&!album->property("font").value<QFont>().underline(),"album hover brightens without adding a line");
                move(find(page,"detailTab_lyrics"));
            }
            if(QString(tab)=="stage"){
                auto *stage=find(page,"detailStagePane");auto *footer=find(page,"detailImmersiveTransport");auto *selector=find(page,"stageStyleSelector");auto *tabItem=find(page,"detailTab_stage");
                check(stage&&stage->x()==0&&stage->width()==page->width()&&rect(stage).bottom()<=rect(footer).top()+1,"stage occupies the full source viewport above transport");
                check(selector&&tabItem&&std::abs(rect(selector).center().y()-rect(tabItem).center().y())<.1,"stage selector and tabs share one centerline");
                check(!rect(find(page,"immersiveTitle")).intersects(rect(find(page,"immersiveLike"))),"stage title and heart remain separate");
            }
            if(QString(tab)=="queue")check(find(page,"detailQueueRow_0")&&find(page,"detailQueueRow_0")->height()==58&&find(page,"detailQueueRow_0")->property("current").toBool(),"source queue row size and current-track highlight are live");
            frame(QString("%1-%2").arg(tab).arg(size.width()));
        }
    }
    tap(find(page,"detailTab_lyrics"));settle(480);auto *lyrics=find(page,"detailLyrics");
    const auto before=lyrics?lyrics->property("contentY").toDouble():0;auto point=rect(lyrics).center();
    QWheelEvent wheel(point,window->mapToGlobal(point.toPoint()),QPoint(),QPoint(0,-120),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);QCoreApplication::sendEvent(window,&wheel);settle(120);
    check(lyrics&&lyrics->property("contentY").toDouble()>before&&!page->property("following").toBool(),"mouse wheel scrolls lyrics and suspends automatic following");
    tap(find(page,"detailTab_queue"));settle(480);auto *remove=find(page,"detailQueueRemove_1");move(find(page,"detailQueueRow_1"));
    check(tap(remove),"queue remove receives actual pointer input");refresh();check(music.player.queue.size()==63&&music.player.current["id"]==song["id"],"queue remove preserves the playing track");
    check(tap(find(page,"detailQueueClear")),"clear upcoming receives actual pointer input");refresh();check(music.player.queue.size()==1&&music.player.current["id"]==song["id"],"clear upcoming preserves the playing track");
    hud.lyricsMode=false;backend.scene.review("archive");hud.modal.clear();hud.closing=false;refresh();
    auto *tools=find(window->contentItem(),"globalTools");
    for(const auto section:{"notes","follows","followers"}){
        QMetaObject::invokeMethod(tools,"pinAccount");refresh();
        check(tap(find(window->contentItem(),QString("accountStat_")+section)),"account statistic receives actual pointer input");refresh();
        check(hud.modal=="profile"&&hud.profileID=="42"&&hud.profileSection==section,"account statistic opens the correct current-user profile section");
        const auto route=QString(section)=="notes"?"/user/event":QString(section)=="follows"?"/user/follows":"/user/followeds";
        check(profileRequests.contains(QString(route)+":42"),"destination loads the corresponding API for the current user");frame(QString("account-")+section);
        hud.action("profile:close");refresh();
    }
    qInfo()<<"UI audit five pages and profile links"<<(ok?"passed":"FAILED");return ok?0:1;
}
