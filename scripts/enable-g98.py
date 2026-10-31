"""G98: restore playlist order after heart mode, warm likes and balance footer."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]

def edit(name, old, new):
    p=Path(name);s=p.read_text(encoding='utf-8')
    if s.count(old)!=1:raise RuntimeError(f'G98 anchor changed: {name}: {old[:100]}')
    p.write_text(s.replace(old,new,1),encoding='utf-8')

edit('Qt/src/MusicPlayer.h','    void cancelHeart();','''    void cancelHeart();
    void leaveHeart();''')
edit('Qt/src/MusicPlayer.h','    quint64 m_heartGeneration = 0;','''    QJsonArray m_heartSavedQueue;
    int m_heartSavedIndex=-1;
    std::optional<int> m_heartResumeIndex;
    bool m_heartHasContext=false;
    quint64 m_heartGeneration = 0;''')
edit('Qt/src/MusicPlayer.cpp','void MusicPlayer::startHeart(','''// Restore queue ownership without restarting the currently audible track.
void MusicPlayer::leaveHeart() {
    cancelHeart();
    if(m_heartHasContext){
        queue=m_heartSavedQueue;
        index=-1;
        // Prefer the exact original occurrence if an entry appears twice.
        if(m_heartSavedIndex>=0&&m_heartSavedIndex<queue.size()&&identity(queue.at(m_heartSavedIndex).toObject())==identity(current))index=m_heartSavedIndex;
        else for(int i=0;i<queue.size();++i)if(identity(queue.at(i).toObject())==identity(current)){index=i;break;}
        // A recommendation can be outside the original playlist. Keep playing
        // it, then resume after the seed without inserting it into the list.
        if(index<0)m_heartResumeIndex=m_heartSavedIndex;else m_heartResumeIndex.reset();
    }
    m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;
    mode="off";
    emit changed();
}

void MusicPlayer::startHeart(''')
edit('Qt/src/MusicPlayer.cpp','                    queue = replacement; index = 0; mode = "heart";','''                    if(!m_heartHasContext){m_heartSavedQueue=queue;m_heartSavedIndex=m_heartResumeIndex.value_or(index);m_heartHasContext=true;}
                    m_heartResumeIndex.reset();
                    queue = replacement; index = 0; mode = "heart";''')
edit('Qt/src/MusicPlayer.cpp','        if (advance || mode == "shuffle") { mode = "off"; }','''        // Failed refill preserves the context for an explicit exit or retry.
        if (!advance && mode == "shuffle") { mode = "off"; }''')
edit('Qt/src/MusicPlayer.cpp','''        if (source) {
            cancelHeart();''','''        if (source) {
            m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;m_heartResumeIndex.reset();
            cancelHeart();''')
edit('Qt/src/MusicPlayer.cpp','    const auto generation = ++m_generation;\n    // A manual replay','    if(!m_restoringRoamContext)m_heartResumeIndex.reset();\n    const auto generation = ++m_generation;\n    // A manual replay')
edit('Qt/src/MusicPlayer.cpp','''    if (direction > 0 && mode == "heart" && index + 1 >= queue.size()) {''','''    if(m_heartResumeIndex){
        if(ended&&mode=="one"){m_host->mediaControl("seek",0);m_host->mediaControl("resume");return;}
        int target=*m_heartResumeIndex+direction;
        if(mode=="shuffle")target=QRandomGenerator::global()->bounded(int(queue.size()));
        if(target>=queue.size()&&mode=="off"){
            status=QStringLiteral("队列已播放完");emit changed();return;
        }
        target=((target%queue.size())+queue.size())%queue.size();
        m_heartResumeIndex.reset();
        play(queue.at(target).toObject(),std::nullopt,target);return;
    }
    if (direction > 0 && mode == "heart" && index + 1 >= queue.size()) {''')
edit('Qt/src/MusicPlayer.cpp','void MusicPlayer::stop() {','''void MusicPlayer::stop() {
    m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;m_heartResumeIndex.reset();''')
edit('Qt/src/MusicPlayer.cpp','    queue.removeAt(selected);','''    if(m_heartResumeIndex&&selected<=*m_heartResumeIndex)--*m_heartResumeIndex;
    queue.removeAt(selected);''')
edit('Qt/src/MusicPlayer.cpp','void MusicPlayer::clearUpcoming() {','''void MusicPlayer::clearUpcoming() {
    m_heartResumeIndex.reset();''')
edit('Qt/src/MusicPlayer.cpp','''    queue.insert(next ? std::max(0, index + 1) : queue.size(), track);''','''    const int insertion=next?std::max(0,m_heartResumeIndex.value_or(index)+1):int(queue.size());
    queue.insert(insertion,track);''')
edit('Qt/src/MusicPlayer.cpp','''            queue.removeAt(i);
            if (i < index) {''','''            if(m_heartResumeIndex&&i<=*m_heartResumeIndex)--*m_heartResumeIndex;
            queue.removeAt(i);
            if (i < index) {''')
edit('Qt/src/MusicPlayer.h','    int m_roamSavedIndex = -1;','    int m_roamSavedIndex = -1;\n    std::optional<int> m_roamSavedHeartResumeIndex;')
edit('Qt/src/MusicPlayer.cpp','    m_roamSavedQueue = queue;','''    cancelHeart();
    m_roamSavedHeartResumeIndex=m_heartResumeIndex;
    m_heartResumeIndex.reset();
    m_roamSavedQueue = queue;''')
edit('Qt/src/MusicPlayer.cpp','    const auto previousQueue = m_roamSavedQueue;','''    const auto previousHeartResumeIndex=m_roamSavedHeartResumeIndex;
    m_roamSavedHeartResumeIndex.reset();
    const auto previousQueue = m_roamSavedQueue;''')
edit('Qt/src/MusicPlayer.cpp','''            m_restoringRoamContext = false;
            m_roamInternalPlay = false;''','''            m_restoringRoamContext = false;
            m_roamInternalPlay = false;
            m_heartResumeIndex=previousHeartResumeIndex;''')
edit('Qt/src/MusicPlayer.cpp','''    mode = previousMode.isEmpty() ? "all" : previousMode;
    if (restorePrevious) {''','''    mode = previousMode.isEmpty() ? "all" : previousMode;
    if(!restorePrevious){
        m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;m_heartResumeIndex.reset();
        if(mode=="heart")mode="off";
    }
    if (restorePrevious) {''')
edit('Qt/src/NativeHudController.cpp','''            player.cancelHeart(); player.mode = "off";''','''            player.leaveHeart();
        } else if (player.mode == "heart") {
            player.leaveHeart();''')

# Warm the shared authoritative state in parallel with playlist requests.
edit('Qt/src/MusicAccount.cpp','''                rememberIdentityName(provider, nickname);''','''                rememberIdentityName(provider, nickname);
                if(provider=="netease")ensureLikedIDs();''')

# Hit boxes and drawing share the same positions.
p=Path('Qt/src/NativeHudPlayer.cpp');s=p.read_text(encoding='utf-8')
a=s.index('void NativeHud::playerBar(');b=s.index('\nvoid NativeHud::',a+10)
bar=s[a:b]
for old,new in [('center - 156','center - 144'),('center - 81','center - 72'),('center + 81','center + 72'),('center + 155','center + 144'),('center + 218','center + 208'),('center+218','center+208'),('width - 310','width - 278'),('vx - 25','vx - 32'),('width - 148','width - 132')]:bar=bar.replace(old,new)
s=s[:a]+bar+s[b:];p.write_text(s,encoding='utf-8')
edit('Qt/qml/Main.qml','x:root.width-98*root.stageScale;y:1011*root.stageScale','x:root.width-86*root.stageScale;y:1012*root.stageScale')
edit('Qt/qml/Main.qml','x:root.width/2-168*root.stageScale;y:1017*root.stageScale','x:root.width/2-156*root.stageScale;y:1017*root.stageScale')
print('G98: heart queue restoration, account-time likes and balanced footer installed.')

edit('Qt/src/Host.h','#include <QQueue>','#include <QQueue>\n#include <QSet>\n#include <QElapsedTimer>')
edit('Qt/src/Host.h','    int interval = 1200;','    int interval = 250;')
edit('Qt/src/Host.h','    QString active;','    QSet<QString> active;\n    bool pumpScheduled=false;')
edit('Qt/src/Host.h','    qint64 lastStart = 0;','    QElapsedTimer lastStart;')
p=Path('Qt/src/Host.cpp');s=p.read_text(encoding='utf-8')
a=s.index('void Host::pump() {');b=s.index('void Host::send(',a)
s=s[:a]+(root/'maintained/G98-host-pump.cppfrag').read_text(encoding='utf-8')+'\n'+s[b:]
old='''    if (active == key) {
        active.clear();
        pump();
    }'''
assert s.count(old)==1,'G98 Host finish anchor changed'
s=s.replace(old,'''    active.remove(key);
    pump();''',1)
p.write_text(s,encoding='utf-8')
edit('Qt/src/Host.cpp','''            if (fixture) {
                finish(key, fixture(work.route, work.params));''','''            // Measure dispatch spacing with the same monotonic clock as the
            // live scheduler, at service entry rather than timer submission.
            if(active.contains(key)){lastStart.start();pump();}
            if (fixture) {
                finish(key, fixture(work.route, work.params));''')
edit('Qt/src/Host.cpp','    queue.clear();','    queue.clear();active.clear();pumpScheduled=false;')

edit('Qt/tests/NativeHostChecks.cpp','#include <QElapsedTimer>','#include <QElapsedTimer>\n#include <QEventLoop>\n#include <QPointer>\n#include <QVector>')
edit('Qt/tests/NativeHostChecks.cpp','    const auto originalEpoch = host.epoch;',
     (root/'maintained/G98-host-checks.cppfrag').read_text(encoding='utf-8')+'\n    const auto originalEpoch = host.epoch;')
edit('Qt/tests/NativeHostChecks.cpp','''    const auto originalEpoch = host.epoch;''','''    // Simulate a slow wiki response with a nested event loop at the service
    // boundary. A distinct detail request must finish before wiki releases.
    bool detailFinished=false,wikiFinished=false,detailOvertookWiki=false;
    host.fixture=[&](QString route,QJsonObject){
        if(route=="/song/wiki/summary"){
            QEventLoop serviceWait;
            QPointer<QEventLoop> loop(&serviceWait);
            QTimer::singleShot(0,&host,[&,loop]{
                host.requestJson("/album",{{"id","g98-fast"}},[&,loop](QJsonObject,QString error){
                    detailFinished=error.isEmpty();detailOvertookWiki=!wikiFinished;
                    if(loop)loop->quit();
                });
            });
            QTimer::singleShot(800,&serviceWait,&QEventLoop::quit);
            serviceWait.exec();
        }
        return QJsonObject{{"body",QJsonObject{{"code",200}}}};
    };
    host.requestJson("/song/wiki/summary",{{"id","g98-slow"}},[&](QJsonObject,QString error){wikiFinished=error.isEmpty();});
    const bool overtook=waitFor([&]{return wikiFinished&&detailFinished;})&&detailOvertookWiki;
    qInfo()<<"G98 metadata detail overtakes slow wiki"<<overtook;
    ok &= overtook;
    host.fixture=[&](QString,QJsonObject parameters){++requests;return QJsonObject{{"body",QJsonObject{{"code",200},{"query",parameters["keywords"]}}}};};

    const auto originalEpoch = host.epoch;''')

edit('Qt/tests/UiChecks.cpp','''        const auto heartQueue = player.queue;''','''        const auto heartQueue = player.queue;
        player.leaveHeart();
        check(player.queue==QJsonArray{song}&&player.index==0&&player.current==song&&player.mode=="off",
              "G98 exiting heart restores original queue and keeps current audio");
        player.mode="shuffle";player.startHeart("42", []{return true;});settle(500);''')
edit('Qt/tests/UiChecks.cpp','''        player.cancelHeart(); player.current = previousCurrent; player.queue = previousQueue;''','''        player.leaveHeart();
        auto second=MusicData::item("song","g98-next","Next original song");
        const QJsonArray ordered{song,second};
        player.current=song;player.queue=ordered;player.index=0;player.mode="shuffle";
        player.startHeart("42",[]{return true;});settle(500);
        player.current=player.queue.last().toObject();player.index=player.queue.size()-1;
        const auto recommendation=player.current;
        player.leaveHeart();
        check(player.queue==ordered&&player.current==recommendation&&player.index==-1,
              "G98 out-of-playlist recommendation finishes without polluting restored queue");
        player.next();
        check(player.current["id"]=="g98-next"&&player.index==1&&player.queue==ordered,
              "G98 next resumes original playlist after seed");
        player.current=song;player.queue=ordered;player.index=0;player.mode="shuffle";
        player.startHeart("42",[]{return true;});player.leaveHeart();settle(500);
        check(player.queue==ordered&&player.current==song&&player.mode=="off"&&!player.heartPending,
              "G98 late heart responses after exit cannot replace original queue");
        player.cancelHeart(); player.current = previousCurrent; player.queue = previousQueue;''')
edit('Qt/tests/UiChecks.cpp','        player.cancelHeart(); player.current = previousCurrent; player.queue = previousQueue;',
     (root/'maintained/G98-heart-checks.cppfrag').read_text(encoding='utf-8')+'\n        player.cancelHeart(); player.current = previousCurrent; player.queue = previousQueue;')

# Exercise the production player and its synchronous UI observer on a separate
# offline domain. play/stop also change media, lyrics, requests and browse state;
# restoring only four public fields leaks those effects into later GUI checks.
edit('Qt/tests/UiChecks.cpp','''        auto previousFixture = backend.host.fixture;
        auto &player = music.player;
        const auto previousCurrent = player.current;
        const auto previousQueue = player.queue;
        const auto previousMode = player.mode;
        const auto previousIndex = player.index;
        bool rejectHeart = false;
        backend.host.fixture = [&](QString route, QJsonObject) {''','''        Host heartHost(backend.host.root,true);
        MusicLibrary heartMusic(&heartHost,{});
        heartMusic.provider=heartMusic.api.provider="netease";
        PlaylistShowcase heartShowcase(&heartMusic,&hud);
        auto &player=heartMusic.player;
        bool rejectHeart = false;
        heartHost.fixture = [&](QString route, QJsonObject) {''')
edit('Qt/tests/UiChecks.cpp','''        player.cancelHeart(); player.current = previousCurrent; player.queue = previousQueue;
        player.index = previousIndex; player.mode = previousMode;
        backend.host.fixture = previousFixture;''','''        player.stop();''')

# Pre-baked QSB shaders can render while status remains Uncompiled (0).
# Verify actual shader output as well as the resource and diagnostic state.
edit('Qt/tests/UiChecks.cpp','#include <QQuickWindow>','#include <QQuickWindow>\n#include <QQuickItemGrabResult>')
edit('Qt/tests/UiChecks.cpp','''        check(edge && edge->property("status").toInt() == 1,
              "spatial lyric blur shader compiles and renders on the packaged Windows backend");''','''        QImage lyricShaderPixels;
        const auto capture=edge?edge->grabToImage():QSharedPointer<QQuickItemGrabResult>{};
        if(capture){
            QElapsedTimer renderWait;renderWait.start();
            while(capture->image().isNull()&&renderWait.elapsed()<3000)settle(20);
            lyricShaderPixels=capture->image();
        }
        int lyricInk=0;
        for(int y=0;y<lyricShaderPixels.height();++y)for(int x=0;x<lyricShaderPixels.width();++x)
            lyricInk+=qAlpha(lyricShaderPixels.pixel(x,y))>8;
        if(edge)qInfo()<<"Lyric shader status/log/painted pixels"<<edge->property("status")<<edge->property("log")<<lyricInk;
        check(edge && edge->property("status").toInt()!=2 && edge->property("log").toString().isEmpty() &&
              QFile::exists(":/shaders/lyricsEdge.frag.qsb") && lyricInk>50,
              "spatial lyric blur shader compiles and renders on the packaged Windows backend");''')
