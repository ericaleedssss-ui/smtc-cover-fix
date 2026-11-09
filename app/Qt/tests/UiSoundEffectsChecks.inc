if(qEnvironmentVariableIntValue("RHINE_QA_SOUND_EFFECTS")==1){
    auto *fx=qobject_cast<SoundEffects*>(backend.soundEffects());
    hud.modal.clear();hud.closing=false;window->resize(1280,900);hud.dark=false;refresh();
    auto song=MusicData::item("song","sound-qa",QStringLiteral("苏州夜曲"),QStringLiteral("安佐里"),"local");song["duration"]=12000;music.player.current=song;music.current=song;music.player.queue={song};music.player.index=0;music.player.changed();refresh();
    QFile wav(output+"/effects-tone.wav");check(wav.open(QIODevice::WriteOnly),"sound fixture opens");QDataStream pcm(&wav);pcm.setByteOrder(QDataStream::LittleEndian);constexpr int n=48000*60;wav.write("RIFF",4);pcm<<quint32(36+n*4);wav.write("WAVEfmt ",8);pcm<<quint32(16)<<quint16(1)<<quint16(2)<<quint32(48000)<<quint32(192000)<<quint16(4)<<quint16(16);wav.write("data",4);pcm<<quint32(n*4);for(int i=0;i<n;++i){auto s=qint16(1500*std::sin(2*3.141592653589793*440*i/48000));pcm<<s<<s;}wav.close();
    backend.host.mediaControl("volume",0);check(backend.host.mediaLoad(QUrl::fromLocalFile(wav.fileName()).toString()),"production audio loads real local PCM");settle(400);
    auto *magazine=qobject_cast<PlaylistMagazine*>(backend.magazine());magazine->showSongMenu("playing",0,{},300,180);refresh();
    auto *menuEffect=find(window->contentItem(),"songMenu_effects");
    if(!menuEffect)menuEffect=find(window->contentItem(),"songMenuAction_effects");
    if(menuEffect)check(click(menuEffect),"song menu opens sound effects by real pointer");else magazine->songAction("effects");
    refresh();check(fx&&fx->opened(),"song menu routes to actual sound dialog");
    auto *dialog=window->findChild<QObject*>("soundEffectsDialog");check(dialog&&dialog->property("visible").toBool(),"production sound effects dialog is visible");
    capture("sound-presets-light");
    check(click(find(window->contentItem(),"soundEffectsPreset_bass")),"real pointer selects bass preset");
    check(fx->info()["on"].toBool()&&fx->info()["preset"]=="bass"&&fx->info()["bands"].toList()[0].toDouble()==6,"preset applies upstream gains");settle(700);
    auto state=backend.host.mediaState();check(state["effectActive"].toBool()&&state["effectFrames"].toLongLong()>0,"real decoder feeds processed audio sink");capture("sound-bass-selected");
    check(click(find(window->contentItem(),"soundEffectsPreset_8d")),"8D button receives pointer");check(fx->info()["spatial"]=="8d","spatial layer coexists with bass preset");
    check(click(find(window->contentItem(),"soundEffectsPage1")),"custom page receives pointer");capture("sound-custom-light");
    auto *band=find(window->contentItem(),"soundEffectsBand3");check(band,"ten band slider exists");
    if(band){auto p=band->mapToScene(QPointF(band->width()/2,band->height()*.18));QMouseEvent down(QEvent::MouseButtonPress,p,window->mapToGlobal(p.toPoint()),Qt::LeftButton,Qt::LeftButton,Qt::NoModifier),up(QEvent::MouseButtonRelease,p,window->mapToGlobal(p.toPoint()),Qt::LeftButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);refresh();}
    check(fx->info()["preset"]=="custom"&&fx->info()["bands"].toList()[3].toDouble()>3,"slider updates live custom gains");
    backend.host.mediaControl("pause");settle(250);auto paused=backend.host.mediaState()["effectFrames"].toLongLong();settle(300);check(!backend.host.mediaState()["playing"].toBool()&&backend.host.mediaState()["effectFrames"].toLongLong()<=paused+4096,"pause stops processed playback");
    backend.host.mediaControl("seek",4000);backend.host.mediaControl("resume");settle(800);state=backend.host.mediaState();check(state["effectActive"].toBool()&&state["effectFrames"].toLongLong()>0&&state["position"].toLongLong()>=4000,"seek and resume restart processed output");
    fx->setValue("room","church");fx->setValue("vocal",.4);refresh();
    window->resize(960,640);hud.dark=true;refresh();capture("sound-custom-narrow-dark");
    check(click(find(window->contentItem(),"soundEffectsDone")),"done receives pointer");check(!fx->opened(),"done closes dialog");fx->open();refresh();check(fx->info()["room"]=="church"&&fx->info()["vocal"].toDouble()==.4,"reopening retains room and manual gains");
    fx->setValue("on",false);refresh();check(!backend.host.mediaState()["effectActive"].toBool()&&backend.host.mediaState()["playing"].toBool(),"disabling effects restores regular playback");
    fx->usePreset("smart");settle(7000);check(fx->info()["note"].toString().startsWith(QStringLiteral("按声音特点：")),"smart mode falls back to measured PCM");
    fx->usePreset("mood");settle(7000);check(fx->info()["note"].toString().startsWith(QStringLiteral("当前情绪：")),"mood mode falls back to measured PCM");
    fx->close();
    const auto tagBody=[](QString genre){
        QJsonObject title;title["title"]=genre;QJsonObject ui;ui["mainTitle"]=title;QJsonObject resource;resource["uiElement"]=ui;
        QJsonArray resources;resources.append(resource);QJsonObject creative;creative["creativeType"]="songTag";creative["resources"]=resources;
        QJsonArray creatives;creatives.append(creative);QJsonObject block;block["code"]="SONG_PLAY_ABOUT_SONG_BASIC";block["creatives"]=creatives;
        QJsonArray blocks;blocks.append(block);QJsonObject data;data["blocks"]=blocks;QJsonObject body;body["data"]=data;return body;
    };
    backend.host.fixture=[&](QString route,QJsonObject args){if(route=="/song/wiki/summary")return QJsonObject{{"body",tagBody(QStringLiteral("摇滚-另类摇滚"))}};return QJsonObject{{"body",QJsonObject{{"code",200}}}};};
    auto tagged=song;tagged["id"]="7739001";tagged["provider"]="netease";tagged["key"]="netease:song:7739001";music.player.current=tagged;fx->usePreset("smart");refresh();
    check(fx->info()["note"].toString().contains(QStringLiteral("已识别曲风：摇滚")),"smart tuning reads actual wiki response structure");
    backend.host.mediaControl("seek",2000);backend.host.mediaControl("rate",1.25);settle(600);state=backend.host.mediaState();check(state["effectActive"].toBool()&&state["effectFrames"].toLongLong()>0&&state["rate"].toDouble()==1.25,"playback speed keeps processed route active");
    fx->setValue("on",false);backend.host.mediaControl("rate",1);fx->usePreset("rock");check(backend.host.mediaLoad(QUrl::fromLocalFile(wav.fileName()).toString()),"switching source recreates decoder");settle(700);check(backend.host.mediaState()["effectActive"].toBool()&&backend.host.mediaState()["effectFrames"].toLongLong()>0,"effects survive actual source recreation");
    fx->setValue("room","hall");fx->setBand(4,-3.5);
    {auto settings=AppStorage::settings();const bool existed=settings.contains("panel/sound-effects");const auto previous=settings.value("panel/sound-effects");const bool wasOffline=backend.host.offline;backend.host.offline=false;fx->close();
        {SoundEffects restored(&music);check(restored.info()["room"]=="hall"&&restored.info()["bands"].toList()[4].toDouble()==-3.5&&restored.info()["preset"]=="custom","fresh controller restores persisted sound settings");}
        backend.host.offline=wasOffline;if(existed)settings.setValue("panel/sound-effects",previous);else settings.remove("panel/sound-effects");settings.sync();}
    backend.host.mediaControl("stop");backend.host.fixture={};
    qInfo()<<"UI audit sound effects"<<(ok?"passed":"failed");return ok?0:1;
}
