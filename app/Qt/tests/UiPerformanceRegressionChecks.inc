// Reuse the existing G97 intermediate-pose checks in the focused player run.
if(qEnvironmentVariableIntValue("RHINE_QA_ANIMATION_REGRESSION")==1){
    const auto settleAnimation=[](int milliseconds){
        QEventLoop loop;QTimer::singleShot(milliseconds,&loop,&QEventLoop::quit);loop.exec();
        QCoreApplication::sendPostedEvents(nullptr,QEvent::DeferredDelete);
    };
    backend.setVisualPreference("motion","full");hud.reduced=false;
    window->resize(1280,720);backend.resize(1280,720);hud.dark=false;backend.scene.theme(false);
    music.player.current=song;music.player.loading=false;music.player.failed=false;music.player.changed();
    backend.action("player:now-playing");refresh();
    page=find("nowPlayingPanel");check(page,"performance regression uses the production record page");if(!page)return 1;
    const auto waitMotion=[&](auto predicate,int timeout=6000){QElapsedTimer clock;clock.start();while(!predicate()&&clock.elapsed()<timeout)settleAnimation(10);return predicate();};
    check(waitMotion([&]{return !page->property("recordTransitioning").toBool();}),"record preparation finishes");
    auto *arm=find("nowTonearmPlane");check(arm,"production tonearm exists");if(!arm)return 1;
    music.player.state["playing"]=true;music.player.changed();settleAnimation(600);
    check(arm->property("pose").toDouble()<.01,"playing tonearm settles inward");
    const double spin=page->property("spinPhase").toDouble();settleAnimation(150);
    check(page->property("spinPhase").toDouble()>spin,"record rotation advances continuously");
    music.player.state["playing"]=false;music.player.changed();settleAnimation(140);
    double prior=arm->property("pose").toDouble();check(prior>.02&&prior<.98,"pause has an intermediate tonearm pose");
    QJsonArray pausePoses{prior};QElapsedTimer pauseSamples;pauseSamples.start();
    // Keep the normal event dispatcher running for animation timing. Check
    // every notification for backwards movement and bound the completion wait.
    bool monotonic=true;for(int i=0;i<12||(prior<=.99&&pauseSamples.elapsed()<1000);++i){music.player.changed();settleAnimation(30);const auto pose=arm->property("pose").toDouble();monotonic&=pose>=prior-.002;prior=pose;pausePoses.append(pose);}
    qInfo()<<"Tonearm pause samples"<<pauseSamples.elapsed()<<"ms; monotonic"<<monotonic<<pausePoses;
    check(monotonic&&prior>.99,"repeated playback notifications never rewind the tonearm");
    const double pausedSpin=page->property("spinPhase").toDouble();settleAnimation(100);check(std::abs(page->property("spinPhase").toDouble()-pausedSpin)<.00001,"paused record preserves its rotation phase");
    music.player.state["playing"]=true;music.player.changed();settleAnimation(140);
    const auto inward=arm->property("pose").toDouble();check(inward>.02&&inward<.98,"resume has an intermediate tonearm pose");
    music.player.state["playing"]=false;music.player.changed();check(std::abs(arm->property("pose").toDouble()-inward)<.02,"rapid reversal starts from the current pose");settleAnimation(550);
    music.player.state["playing"]=true;music.player.changed();settleAnimation(550);
    music.player.loading=true;music.player.changed();settleAnimation(500);check(arm->property("pose").toDouble()<.01,"buffering does not move the arm into a paused pose");music.player.loading=false;
    auto nextSong=song;nextSong["id"]="9911101";nextSong["key"]="netease:song:9911101";music.player.current=nextSong;music.player.changed();settleAnimation(120);
    const auto lifting=arm->property("pose").toDouble();nextSong["id"]="9911102";nextSong["key"]="netease:song:9911102";music.player.current=nextSong;music.player.changed();
    check(std::abs(arm->property("pose").toDouble()-lifting)<.02,"rapid song selection never resets the tonearm");
    check(waitMotion([&]{return page->property("swapStage").toString()=="swapping";}),"ready cover starts the record swap");
    check(arm->property("pose").toDouble()>.99,"tonearm clears before the records move");
    check(waitMotion([&]{return !page->property("recordTransitioning").toBool();}),"latest song completes its record swap");
    auto *front=find("nowRecord");check(front&&front->property("visualSession").toString()==MusicPlayer::identity(nextSong),"latest song owns the displayed record");settleAnimation(550);
    check(arm->property("pose").toDouble()<.01,"tonearm returns after the record swap");
    check(window->grabWindow().save(output+"/record-animation.png"),"saved production record animation result");
    music.player.state["playing"]=false;music.player.changed();backend.action("back");refresh();
    for(const auto size:{QSize(960,640),QSize(1280,720),QSize(1920,1080)}){
        window->resize(size);backend.resize(size.width(),size.height());refresh();
        auto *cover=find("playerBarCoverImage");check(cover,"footer cover remains present");
        if(cover){const auto decoded=cover->property("sourceSize").toSize();check(decoded.width()>=std::ceil(cover->width()*window->devicePixelRatio())&&decoded.width()<=512,"footer decodes enough physical pixels without retaining the original large image");}
    }
}
