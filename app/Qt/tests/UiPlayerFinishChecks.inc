// Only the changed rail, glass handles, quote and track-change handoff.
if(qEnvironmentVariableIntValue("RHINE_QA_PLAYER_FINISH")==1){
    backend.setVisualPreference("motion","full");hud.reduced=false;
    window->resize(1280,900);backend.resize(1280,900);hud.modal.clear();hud.closing=false;
    backend.host.fixture=[](QString route,QJsonObject){QJsonObject body{{"code",200}};if(route=="/comment/hot")body["hotComments"]=QJsonArray{QJsonObject{{"content",QStringLiteral("把这一刻留在歌声里")}}};return QJsonObject{{"body",body}};};
    QFile wav(output+"/seek.wav");check(wav.open(QIODevice::WriteOnly),"visual fixture opens");
    constexpr quint32 bytes=160*8000*2;QDataStream pcm(&wav);pcm.setByteOrder(QDataStream::LittleEndian);wav.write("RIFF",4);pcm<<quint32(36+bytes);wav.write("WAVEfmt ",8);pcm<<quint32(16)<<quint16(1)<<quint16(1)<<quint32(8000)<<quint32(16000)<<quint16(2)<<quint16(16);wav.write("data",4);pcm<<bytes;wav.write(QByteArray(bytes,'\0'));wav.close();
    backend.host.mediaControl("volume",0);backend.host.mediaLoad(QUrl::fromLocalFile(wav.fileName()).toString());settle(500);backend.host.mediaControl("pause");backend.host.mediaControl("seek",64000);settle(150);
    QImage cover(400,400,QImage::Format_RGB32);cover.fill(QColor("#798b73"));{QPainter p(&cover);p.setPen(QPen(QColor("#e8d9bb"),8));for(int i=0;i<6;++i)p.drawEllipse(QPointF(200,200),24+i*27,24+i*27);}cover.save(output+"/cover.png");
    auto song=MusicData::item("song","551102",QStringLiteral("把这一刻留在歌声里"),"Rhine");song["cover"]=QUrl::fromLocalFile(output+"/cover.png").toString();song["duration"]=160000;
    music.player.current=song;music.player.queue={song};music.player.index=0;music.player.loading=false;music.player.failed=false;music.player.tick(10000,true);music.player.changed();backend.action("player:now-playing");refresh();settle(1200);
    QElapsedTimer mediaWait;mediaWait.start();while(!backend.host.mediaState()["seekable"].toBool()&&mediaWait.elapsed()<5000)settle(30);
    backend.host.mediaControl("pause");backend.host.mediaControl("seek",64000);settle(200);music.player.tick(11000,true);music.player.changed();capture("quote-and-bar-light");
    const auto hover=[&](QQuickItem *item){const auto p=item?item->mapToScene(item->boundingRect().center()):QPointF(400,120);QMouseEvent e(QEvent::MouseMove,p,window->mapToGlobal(p.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&e);};
    auto *thumb=find(window->contentItem(),"playbackSeekThumb");auto *area=find(window->contentItem(),"playbackSeekArea");auto *rail=find(window->contentItem(),"playbackSeekTrack");
    check(thumb&&thumb->opacity()<.01&&rail&&rail->isVisible()&&rail->opacity()>.99,"idle shows the rail without a glass thumb");
    hover(area);settle(450);check(thumb&&thumb->isVisible()&&thumb->opacity()>.99,"real rail hover reveals glass capsule");capture("bar-hover-light");
    check(thumb&&std::abs(thumb->property("displayFraction").toDouble()-.4)<.02,"glass thumb follows actual media position");
    hud.dark=true;backend.scene.theme(true);capture("bar-hover-dark");hud.dark=false;backend.scene.theme(false);
    // Regression: the old implementation showed a white pill while idle and
    // reset it visibly before the 1270ms perimeter animation had completed.
    backend.host.mediaControl("seek",3200);song["id"]="551103";song["key"]="netease:song:551103";music.player.current=song;music.player.changed();backend.step(90);settle(45);
    auto *trail=find(window->contentItem(),"capsuleEdgeTrail");check(trail&&trail->isVisible(),"original track-change perimeter animation remains active");
    check(thumb&&thumb->opacity()<.01,"hovered thumb hides before progress resets");
    settle(600);check(trail&&trail->isVisible()&&thumb->opacity()<.01,"thumb stays hidden throughout the bar animation");
    QElapsedTimer trailWait;trailWait.start();while(trail&&trail->isVisible()&&trailWait.elapsed()<2000)settle(5);
    check(thumb->opacity()<.95,"thumb starts fading in only after perimeter animation ends");settle(350);
    check(thumb->opacity()>.99&&thumb->property("displayFraction").toDouble()<.03,"still-hovered thumb returns at the new progress after animation");
    hover(nullptr);settle(250);check(thumb->opacity()<.01&&rail->opacity()>.99,"leaving rail hides only thumb and keeps progress visible");capture("bar-idle");
    song["id"]="551104";song["key"]="netease:song:551104";music.player.current=song;music.player.changed();backend.step(90);settle(300);hover(area);settle(150);
    check(trail->isVisible()&&thumb->opacity()<.01,"entering rail during track animation cannot reveal thumb early");
    hover(nullptr);settle(1500);check(thumb->opacity()<.01,"non-hovered thumb remains hidden after track animation");
    music.current=song;music.selectedPhysical=backend.scene.selection();backend.scene.review("detail");hud.lyricsMode=true;refresh();settle(1600);capture("detail-glass-thumb");
    auto *page=find(window->contentItem(),"songDetailPage");auto *standard=find(page,"detailSeekThumb");check(standard&&standard->opacity()<.01,"standard detail thumb is hidden without hover");hover(find(page,"detailSeek"));settle(300);check(standard&&standard->opacity()>.99,"standard detail thumb appears on real hover");capture("detail-hover");hover(nullptr);
    // Regression: Qt's default handle travel is shorter than the rail, so the
    // white fill overtook the lens center as progress passed halfway.
    auto *detailSlider=find(page,"detailSeek");
    for(double fraction:{.1,.5,.9}){
        backend.host.mediaControl("seek",fraction*160000);settle(80);music.player.tick(13000+fraction,true);music.player.changed();refresh();hover(detailSlider);settle(200);
        auto *detailRail=detailSlider?detailSlider->property("background").value<QQuickItem*>():nullptr;
        if(detailRail&&standard){
            const auto center=standard->mapToItem(detailRail,QPointF(standard->width()/2,standard->height()/2));
            check(std::abs(center.x()-detailRail->width()*detailRail->property("fraction").toDouble())<.5,"detail fill endpoint stays at lens center across progress");
            check(detailRail->property("featherWidth").toDouble()==0&&detailRail->height()==4,"detail rail remains a solid four-DIP line without feathering");
        }else check(false,"detail rail available for focused regression");
        capture(QString("detail-progress-%1").arg(int(fraction*100)));
    }
    hover(nullptr);
    if(page)QMetaObject::invokeMethod(page,"choose",Q_ARG(QVariant,QVariant("stage")));settle(700);capture("immersive-glass-thumb");
    auto *immersive=find(page,"detailImmersiveSeekThumb");check(immersive&&immersive->opacity()<.01,"immersive thumb is hidden without hover");hover(find(page,"detailImmersiveSeek"));settle(300);check(immersive&&immersive->opacity()>.99,"immersive thumb appears on real hover");capture("immersive-hover");
    backend.host.mediaControl("stop");backend.host.fixture={};qInfo()<<"UI audit player finish"<<(ok?"passed":"FAILED");return ok?0:1;
}
