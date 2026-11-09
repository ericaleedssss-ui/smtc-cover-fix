// Reproduce the actual 4950px account-avatar allocation through the production popup.
if(qEnvironmentVariableIntValue("RHINE_QA_AVATAR_ONLY")==1) {
    for(const auto family:{QString(),backend.uiFont()}) {
        Glyphs reference(backend.root()), threaded(backend.root());
        reference.setFamily(family);threaded.setFamily(family);
        // Warm a face on the GUI thread, then encounter new glyphs while painting.
        threaded.width(QString::fromUtf8("GUI 预热 Ω"),24);
        const auto text=QString::fromUtf8("新字形 / Ψ / Ж / 音乐 / ♬");
        const auto expectedWidth=reference.width(text,24);
        QImage expected(600,70,QImage::Format_ARGB32_Premultiplied);
        expected.fill(Qt::transparent);
        {QPainter painter(&expected);reference.text(painter,text,0,0,24,"regular",0,Qt::black);}
        QImage actual(expected.size(),expected.format());actual.fill(Qt::transparent);
        double actualWidth=0;
        auto *worker=QThread::create([&]{
            actualWidth=threaded.width(text,24);
            QPainter painter(&actual);threaded.text(painter,text,0,0,24,"regular",0,Qt::black);
        });
        worker->start();worker->wait();delete worker;
        check(qAbs(expectedWidth-actualWidth)<.00001&&expected==actual,
              "GUI-warmed fonts and render-thread cache misses preserve exact glyph pixels and metrics");
    }
    const auto path=output+"/avatar-4950.jpg";
    {
        QImage image(4950,4950,QImage::Format_RGB32);
        QPainter painter(&image);
        QLinearGradient gradient(0,0,4950,4950);
        gradient.setColorAt(0,QColor("#f0ede5"));gradient.setColorAt(1,QColor("#4b6652"));
        painter.fillRect(image.rect(),gradient);painter.setPen(QPen(QColor("#d3b787"),12));
        for(int i=0;i<30;++i)painter.drawEllipse(QPointF(2475,2475),100+i*75,100+i*75);
        painter.end();check(image.save(path,"JPG",94),"saved original-size avatar fixture");
    }
    const auto source=QUrl::fromLocalFile(path);
    music.uid="42";music.nickname="Offline avatar fixture";
    music.accountDetails={{"avatar",source.toString()}};
    backend.host.fixture=[](QString,QJsonObject){return QJsonObject{{"body",QJsonObject{{"code",200}}}};};
    music.changed();refresh();
    auto *avatar=window->findChild<QQuickItem*>("accountMenuAvatarImage");
    auto *popup=window->findChild<QObject*>("globalAccountMenu");
    check(avatar&&popup,"production account popup and avatar exist");
    QJsonArray observations;
    if(avatar&&popup) {
        window->showNormal();settle(250);
        for(const auto size:{QSize(960,640),QSize(1707,960),QSize(2400,1350)}) {
            window->resize(size);backend.resize(size.width(),size.height());refresh();
            QMetaObject::invokeMethod(popup,"open");settle(250);
            QElapsedTimer wait;wait.start();
            while(avatar->property("status").toInt()==2&&wait.elapsed()<5000)settle(20);
            const auto decoded=avatar->property("sourceSize").toSize();
            const auto needed=std::ceil(qMax(avatar->width(),avatar->height())*window->devicePixelRatio());
            const bool valid=avatar->property("status").toInt()==1&&avatar->isVisible()&&
                avatar->property("source").toUrl()==source&&decoded.width()>=needed&&
                decoded.width()<=2*qMax(128.,needed);
            check(valid,"original avatar loads at sufficient physical resolution across window sizes");
            observations.append(QJsonObject{{"window_width",size.width()},{"window_height",size.height()},
                {"dpr",window->devicePixelRatio()},{"required_side",needed},{"decode_side",decoded.width()},{"passed",valid}});
            check(window->grabWindow().save(output+QString("/avatar-popup-%1.png").arg(size.width())),"saved actual avatar popup");
            QMetaObject::invokeMethod(popup,"close");settle(200);
        }
        for(int i=0;i<10;++i) {
            QMetaObject::invokeMethod(popup,"open");settle(200);
            check(avatar->isVisible()&&avatar->property("status").toInt()==1,"reopening retains ready avatar");
            QMetaObject::invokeMethod(popup,"close");settle(200);
            check(!popup->property("visible").toBool(),"account popup closes after repeated openings");
        }
        check(window->findChildren<QQuickItem*>("accountMenuAvatarImage").size()==1,"reopening does not accumulate avatar objects");
    }
    backend.host.fixture={};
    QFile result(output+"/avatar-regression.json");
    if(result.open(QIODevice::WriteOnly))result.write(QJsonDocument(QJsonObject{{"passed",ok},
        {"source_side",4950},{"reopen_count",10},{"observations",observations}}).toJson());
    return ok?0:1;
}
