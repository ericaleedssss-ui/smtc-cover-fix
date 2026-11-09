// Actual production scene audit. Isolated --frosted-self-test, no account data.
static int runUiAudit(Engine &backend,QQuickWindow *window,const QString &output) {
    auto &hud=backend.app->hud;auto &music=backend.app->music;
    backend.resetUiFont();
#ifdef Q_OS_WIN
    // Offline Engine intentionally skips taskbar registration. Exercise the
    // production native integration on this isolated test window as well.
    TaskbarIntegration nativeFrame(window,{});
#endif
    qInfo()<<"UI audit font"<<backend.uiFont()<<QFontDatabase::styles(backend.uiFont());
    bool ok=true;
    const auto check=[&](bool value,const char *label){qInfo()<<"UI audit:"<<label<<value;if(!value)ok=false;};
    const auto refresh=[&]{backend.step(90);settle(450);};
    const auto capture=[&](QString name){refresh();check(window->grabWindow().save(output+"/"+name+".png"),"saved actual window frame");};
    music.uid="42";music.nickname="Rhine QA";
    music.lists[2]=QJsonArray{MusicData::item("playlist","123","我的收藏歌单")};
    hud.confirmTitle="从音乐资料库中移除这条记录？";
    hud.formKind="create";
    const std::function<QQuickItem*(QQuickItem*,QString)> find=[&](QQuickItem *item,QString name)->QQuickItem*{if(!item)return nullptr;if(item->objectName()==name)return item;for(auto *child:item->childItems())if(auto *found=find(child,name))return found;return nullptr;};
    const auto click=[&](QQuickItem *item,Qt::MouseButton button=Qt::LeftButton){if(!item||!item->isVisible())return false;const auto p=item->mapToScene(item->boundingRect().center());QMouseEvent down(QEvent::MouseButtonPress,p,window->mapToGlobal(p.toPoint()),button,button,Qt::NoModifier);QMouseEvent up(QEvent::MouseButtonRelease,p,window->mapToGlobal(p.toPoint()),button,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);refresh();return true;};
    const auto escape=[&]{QKeyEvent key(QEvent::KeyPress,Qt::Key_Escape,Qt::NoModifier);QCoreApplication::sendEvent(window,&key);refresh();};
    #include "UiPlayerFinishChecks.inc"
    #include "UiSoundEffectsChecks.inc"
    #include "UiFollowupChecks.inc"
    if(qEnvironmentVariableIntValue("RHINE_QA_UI_SURFACES")==1){
        backend.host.fixture=[](QString,QJsonObject){return QJsonObject{{"body",QJsonObject{{"code",200},{"value",QJsonObject{}}}}};};
        hud.modal.clear();hud.closing=false;backend.scene.review("detail");refresh();
        auto *tools=find(window->contentItem(),"globalTools");check(tools,"production global tools are present");
        for(const auto size:{QSize(960,540),QSize(1280,720)})for(bool dark:{false,true}){
            window->resize(size);hud.dark=dark;refresh();
            const auto prefix=QString("surfaces-%1-%2-").arg(size.width()).arg(dark?"dark":"light");
            QMetaObject::invokeMethod(tools,"pinAccount");capture(prefix+"account");
            check(find(window->contentItem(),"accountMenuProfile"),"account menu exposes its real action rows");
            QMetaObject::invokeMethod(tools,"dismiss");refresh();
            QMetaObject::invokeMethod(tools,"openVip");capture(prefix+"membership");
            check(tools->property("membershipVisible").toBool(),"membership surface opens in production");
            escape();check(!tools->property("membershipVisible").toBool(),"Escape dismisses the membership surface");
            check(click(find(window->contentItem(),"globalFavorites")),"real pointer opens personal collections");capture(prefix+"library");
            check(tools->property("personalDrawerVisible").toBool(),"personal collection drawer opens in production");
            escape();check(!tools->property("personalDrawerVisible").toBool(),"Escape dismisses the collection drawer");
            check(click(find(window->contentItem(),"globalInbox")),"real pointer opens messages");capture(prefix+"messages");
            check(tools->property("messageDrawerVisible").toBool(),"message drawer opens in production");
            escape();check(!tools->property("messageDrawerVisible").toBool(),"Escape dismisses the message drawer");
        }
        qInfo()<<"UI audit surfaces"<<(ok?"passed":"FAILED");return ok?0:1;
    }
    if(qEnvironmentVariableIntValue("RHINE_QA_UI_SETTINGS")==1){
        for(const auto size:{QSize(960,540),QSize(1280,720),QSize(1920,1080)})for(bool dark:{false,true}){
            window->resize(size);hud.dark=dark;hud.themeMode=dark?"dark":"light";backend.scene.theme(dark);hud.modal.clear();hud.openModal("settings");refresh();
            auto *panel=find(window->contentItem(),"settingsPage");auto *settings=panel?panel->parentItem():nullptr;
            check(settings,"settings root loads for the size and theme");
            for(const auto category:{"account","playback","lyrics","podcast","appearance","effects","storage","window","about"}){
                if(settings)QMetaObject::invokeMethod(settings,"choose",Q_ARG(QVariant,QVariant(QString(category))));refresh();
                check(panel&&panel->width()>0&&panel->height()>0,"settings panel has valid live dimensions");
                capture(QString("settings-%1-%2-%3").arg(size.width()).arg(dark?"dark":"light").arg(category));
            }
            hud.modal.clear();hud.closing=false;refresh();
        }
        qInfo()<<"UI audit settings"<<(ok?"passed":"FAILED");return ok?0:1;
    }
    if(qEnvironmentVariableIntValue("RHINE_QA_UI_COMPONENTS")!=1)for(const auto size:{QSize(960,540),QSize(1280,720),QSize(1920,1080)}) {
        window->resize(size);refresh();
        for(bool dark:{false,true}) {
            hud.dark=dark;hud.themeMode=dark?"dark":"light";backend.scene.theme(dark);
            const auto prefix=QString::number(size.width())+(dark?"-dark-":"-light-");
            for(const auto &modal:QStringList{"settings","desktop-settings","interface-fonts","provider","quality","confirm","disc-rotation-warning","playlist-form","playlist-picker","lyrics-source","search","saved","local","login"}) {
                if(size.width()!=1280 && !QStringList{"settings","desktop-settings","interface-fonts","confirm","provider"}.contains(modal))continue;
                hud.modal.clear();hud.closing=false;hud.openModal(modal);refresh();
                capture(prefix+modal);
                check(hud.modal==modal,"requested production modal remains open");
                hud.modal.clear();hud.closing=false;refresh();
            }
        }
    }
    window->resize(1280,720);hud.dark=false;hud.modal.clear();hud.closing=false;refresh();
    hud.openModal("confirm");refresh();
    auto *cancel=find(window->contentItem(),"dialogCancel");
    check(cancel&&cancel->hasActiveFocus(),"short confirmation initially focuses the safe cancel action");
    check(click(cancel),"shared confirmation cancel receives a real pointer click");
    check(hud.modal.isEmpty(),"cancel closes only the confirmation without executing its destructive action");
    hud.openModal("desktop-settings");refresh();
    auto *preferences=find(window->contentItem(),"desktopLyricsSettingsPage");
    check(preferences,"desktop preferences is the production component");
    const auto oldColor=backend.desktopLyrics()["primaryColor"].toString();
    if(preferences)QMetaObject::invokeMethod(preferences,"openColor",Q_ARG(QVariant,QVariant("primary")));refresh();
    auto *hex=find(window->contentItem(),"colorHex");check(hex,"application color picker opens inside the Qt scene");
    if(hex)hex->setProperty("text","#a1b2c3");
    capture("color-picker");escape();
    check(backend.desktopLyrics()["primaryColor"].toString()==oldColor,"Escape cancels draft color without changing preferences");
    if(preferences)QMetaObject::invokeMethod(preferences,"openColor",Q_ARG(QVariant,QVariant("primary")));refresh();
    hex=find(window->contentItem(),"colorHex");if(hex)hex->setProperty("text","#a1b2c3");
    check(click(find(window->contentItem(),"colorApply")),"real pointer activates apply color");
    check(backend.desktopLyrics()["primaryColor"].toString()=="#a1b2c3","explicit apply saves the selected HEX color");
    backend.setDesktopColor("primary",oldColor);hud.modal.clear();hud.closing=false;refresh();
    QImage cover(400,400,QImage::Format_RGB32);cover.fill(QColor("#677d91"));QPainter art(&cover);art.setPen(QPen(QColor("#e7d2a7"),8));for(int i=0;i<5;++i)art.drawEllipse(QPointF(200,200),40+i*28,40+i*28);art.end();cover.save(output+"/collection-fixture.png");
    const auto artwork=QUrl::fromLocalFile(output+"/collection-fixture.png").toString();
    auto *model=qobject_cast<PlaylistMagazine*>(backend.magazine());
    music.likedIDs=QJsonArray{};
    backend.host.fixture=[](QString,QJsonObject){return QJsonObject{{"body",QJsonObject{{"code",200},{"value",QJsonArray{}}}}};};
    for(const auto kind:{"playlist","album"}){
        auto folder=std::make_shared<MusicDirectory>();
        folder->item=MusicData::item(kind,QString(kind)=="album"?"7071":"7070",QStringLiteral("夜行与回声 / After Hours"),"Rhine Artist");
        folder->item["cover"]=artwork;folder->item["description"]=QStringLiteral("夜晚的风，城市里的灯。把沿途听到的声音收在这里，慢慢听完这段旅程。").repeated(8);folder->item["creatorID"]="99";folder->item["date"]="2026-11-08";
        for(int i=0;i<36;++i){auto song=MusicData::item("song",QString::number(8000+i),QString("Track %1").arg(36-i,2,10,QChar('0')),"Rhine Artist");song["cover"]=artwork;song["duration"]=100000+i*1000;song["album"]="After Hours";folder->songs.append(song);folder->ids.append(song["id"]);}
        folder->cursor=folder->ids.size();folder->item["trackCount"]=folder->songs.size();
        music.directory=folder;music.directoryInfo=true;music.current=folder->item;hud.lyricsMode=false;hud.modal.clear();hud.closing=false;music.directoryLoading=false;backend.scene.review("detail");model->sync();refresh();
        for(const auto size:{QSize(960,540),QSize(1280,720),QSize(1920,1080)})for(bool dark:{false,true}){
            window->resize(size);hud.dark=dark;hud.themeMode=dark?"dark":"light";refresh();
            auto *page=find(window->contentItem(),"playlistMagazinePage");auto *header=find(page,"collectionHeaderCover");auto *title=find(page,"playlistTitle");
            check(page&&header&&title&&header->isVisible()&&title->width()>100,"collection cover and title fit the live responsive header");
            if(title&&size.width()==1280&&!dark){const auto font=title->property("font").value<QFont>();const QFontInfo actual(font);qInfo()<<"UI audit title font"<<font<<actual.family()<<actual.weight()<<actual.styleName();}
            capture(QString("%1-%2-%3").arg(kind).arg(size.width()).arg(dark?"dark":"light"));
        }
        window->resize(1280,720);hud.dark=false;refresh();
        model->setSort(1);check(model->data(model->index(0),PlaylistMagazine::SourceIndex).toInt()==35,"title sort retains original song identities");
        model->setSort(3);check(model->data(model->index(0),PlaylistMagazine::SourceIndex).toInt()==35,"duration sort uses descending source order");
        model->setSort(0);refresh();
        QPointer<QQuickItem> page=find(window->contentItem(),"playlistMagazinePage");
        auto *sort=find(page,"collectionSort");
        check(click(sort),"real pointer opens the shared sort combo");
        capture(QString(kind)+"-sort-menu");
        {for(const auto key:{Qt::Key_Down,Qt::Key_Return}){QKeyEvent press(QEvent::KeyPress,key,Qt::NoModifier);QCoreApplication::sendEvent(window,&press);QKeyEvent release(QEvent::KeyRelease,key,Qt::NoModifier);QCoreApplication::sendEvent(window,&release);settle(50);}}refresh();
        check(model->sort()==1,"keyboard selection in shared combo updates collection sort");
        model->setSort(0);refresh();
        check(click(find(page,"magazineRow_0"),Qt::RightButton)&&model->songMenu()["visible"].toBool(),"a real right click opens the captured collection song menu");
        capture(QString(kind)+"-context-menu");const auto playerBefore=music.player.current;escape();
        check(!model->songMenu()["visible"].toBool()&&music.player.current==playerBefore,"Escape closes the menu without dispatching playback");
        check(page&&model->active(),"closing a song menu preserves the underlying collection page");
        if(!page)continue;
        model->search("no-matching-song");refresh();check(model->rowCount()==0&&find(page,"playlistSearchInput"),"empty results retain the collection search control");model->search("");refresh();
        auto *list=find(page,"magazineTrackList");if(list)list->setProperty("contentY",list->property("originY").toDouble()+440);refresh();
        check(find(page,"playlistStickyHeader")&&find(page,"playlistStickyHeader")->isVisible(),"scrolling reveals the collection identity and actions");capture(QString(kind)+"-sticky");
    }
    const auto geometry=window->geometry();window->showMinimized();settle(300);check(window->visibility()==QWindow::Minimized,"native app window minimizes");window->showNormal();refresh();check(window->size()==geometry.size(),"native restore preserves the application window size");
#ifdef Q_OS_WIN
    const auto handle=reinterpret_cast<HWND>(window->winId());const auto style=GetWindowLongPtrW(handle,GWL_STYLE);
    check((style&WS_CAPTION)==WS_CAPTION&&(style&WS_THICKFRAME)!=0&&(style&WS_MINIMIZEBOX)!=0,"custom chrome retains native DWM transition window styles");
#endif
    qInfo()<<"UI audit baseline"<<(ok?"passed":"FAILED");
    return ok?0:1;
}
