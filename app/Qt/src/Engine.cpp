#include "PipelineDiagnostics.h"
#include "Engine.h"
#include "StartupMemory.h"
#include "FontCatalog.h"
#include "MusicData.h"
#include "AppStorage.h"
#include <QCoreApplication>
#include <QDir>
#include <QEvent>
#include <QMouseEvent>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QPainter>
#include <QGuiApplication>
#include <QCursor>
#include <QScreen>
#include <QFontDatabase>
#include <QColor>
#include <QThread>
#include <algorithm>
#include <cmath>
#include <cstring>
bool runNativeHostChecks(const QString &root);
bool runNativeMusicChecks(const QString &root);
bool runGpuReferenceCheck(const QImage &expected, const QImage &actual);

/** 建立纯原生音乐、HUD 和场景状态；Qt 定时器只在输入或动画尚未收束时运行。 */
Engine::Engine(QString path, bool offline, QObject *parent)
    : QObject(parent), host(startupMemoryValue("host-begin", path), offline),
      scene(startupMemoryValue("scene-begin", path)),
      m_glyphs(startupMemoryValue("glyphs-begin", path)) {
    startupMemory("application-begin");
    const auto content = QJsonDocument::fromJson(host.read("slots.json").toUtf8()).object();
    app = std::make_unique<NativeApplication>(&host, &m_glyphs, &scene, content);
    startupMemory("application-created");
    m_sleepTimer.setSingleShot(true);
    connect(&m_sleepTimer,&QTimer::timeout,this,[this]{setSleep(0);app->music.player.setPaused(true);wake();});
    app->music.player.onEnd=[this]{
        if(m_sleepMinutes==-1){setSleep(0);app->music.player.setPaused(true);}
        else app->music.player.next(1,true);
    };
    connect(&app->music, &MusicLibrary::playbackInvalidated, this, &Engine::refreshPlayback);
    connect(&app->music, &MusicLibrary::invalidated, this, &Engine::refreshTaskbar);
    connect(&app->music, &MusicLibrary::invalidated, this, [this] {
        if (m_signatureAccount != app->music.accountGeneration()) {
            m_signatureAccount = app->music.accountGeneration();
            app->hud.profileSignatureSaving = false;
            app->hud.profileSignatureError.clear();
        }
    });
    connect(&app->hud, &NativeHud::localImportRequested, this, &Engine::localImportRequested);
    m_showcase = new PlaylistShowcase(&app->music,&app->hud,this);
    connect(m_showcase,&PlaylistShowcase::navigate,this,&Engine::action);
    m_messages = new MessageCenter(&app->music,this);
    connect(m_messages,&MessageCenter::navigate,this,&Engine::action);
    m_personal = new PersonalHub(&app->music,this);
    connect(m_personal,&PersonalHub::navigate,this,&Engine::action);
    connect(m_personal,&PersonalHub::externalRequested,&host,&Host::open);
    m_magazine = new PlaylistMagazine(&app->music, &app->hud, this);
    connect(m_magazine,&PlaylistMagazine::navigate,this,&Engine::action);
    m_nowPlaying=new NowPlaying(&app->music,m_magazine,this);
    connect(m_nowPlaying,&NowPlaying::navigate,this,&Engine::action);
    app->initialize();
    startupMemory("application-initialized");
    m_soundEffects=new SoundEffects(&app->music,this);
    m_visualPreferences={{"powerSaver",false},{"liquidGlass",true},{"glassClear",.6},{"glassBend",.3},{"barSpin",true},{"npLight",true},{"glowLevel",.5},{"fog",false},{"smoke",false},{"glassPanels",true},{"motion","full"}};
    const auto savedVisual=QJsonDocument::fromJson(host.preference("visual-effects").toUtf8()).object().toVariantMap();
    for(auto it=m_visualPreferences.begin();it!=m_visualPreferences.end();++it){
        const auto value=savedVisual.value(it.key());
        if(it.key()=="motion"){if(QStringList{"full","lite","off"}.contains(value.toString()))it.value()=value;}
        else if(it.value().metaType().id()==QMetaType::Bool){if(value.metaType().id()==QMetaType::Bool)it.value()=value;}
        else if(value.canConvert<double>()&&std::isfinite(value.toDouble()))it.value()=std::clamp(value.toDouble(),0.,1.);
    }
    if(savedVisual.contains("saverBefore"))m_visualPreferences["saverBefore"]=savedVisual["saverBefore"];
    connect(&app->music.player.lyrics, &LyricsController::changed, this, &Engine::refreshDesktopLyrics);
    refreshDesktopLyrics();
    connect(&host, &Host::invalidated, this, [this] { wake(false); });
    connect(&host, &Host::mediaChanged, this, &Engine::pollMedia, Qt::QueuedConnection);
    connect(&host, &Host::mediaAction, this, [this](QString value) {
        app->mediaAction(value);
        wake();
    });
    clock.start();
    timer.setTimerType(Qt::PreciseTimer);
    connect(&timer, &QTimer::timeout, this, &Engine::tick);
    mediaTimer.setInterval(app->hud.desktopLyricsEnabled ? 80 : 1000);
    connect(&mediaTimer, &QTimer::timeout, this, &Engine::pollMedia);
    if (!offline) {
        start();
    }
}
Engine::~Engine() {
    timer.stop();
    mediaTimer.stop();
    m_taskbar.reset();
    delete m_soundEffects;m_soundEffects=nullptr;
    delete m_nowPlaying;m_nowPlaying=nullptr;
    delete m_showcase;m_showcase=nullptr;
    delete m_messages; m_messages=nullptr;
    delete m_personal; m_personal=nullptr;
    delete m_magazine; m_magazine=nullptr;
    app.reset();
    host.shutdown();
}
bool Engine::ready() const {
    return scene.ready();
}
namespace {
// 鼠标滚轮一格的距离按设置页与歌词的行高换算，约一行内容；触控板保留系统给出的连续像素距离。
constexpr double WHEEL_DISTANCE_PER_NOTCH = 80;
// 鼠标滚轮的离散事件按帧衰减送出，约 0.1 秒内收束，避免整格内容瞬间跳变。
constexpr double WHEEL_SMOOTHING = 0.5;
// 尾段直接送出，避免浮点衰减无限拖延最后一次画面更新。
constexpr double WHEEL_DISTANCE_TAIL = 6;
// 只有低于实际显示精度的浮点尾差才可视为收束，时间和诊断计数不参与画面失效。
bool equivalent(const QJsonValue &a, const QJsonValue &b) {
    if (a.type() != b.type()) {
        return false;
    }
    if (a.isDouble()) {
        return qAbs(a.toDouble() - b.toDouble()) <= 0.00001;
    }
    if (a.isArray()) {
        auto x = a.toArray();
        auto y = b.toArray();
        if (x.size() != y.size()) {
            return false;
        }
        for (int i = 0; i < x.size(); ++i) {
            if (!equivalent(x[i], y[i])) {
                return false;
            }
        }
        return true;
    }
    if (a.isObject()) {
        auto x = a.toObject();
        auto y = b.toObject();
        if (x.keys() != y.keys()) {
            return false;
        }
        for (auto it = x.begin(); it != x.end(); ++it) {
            if (!equivalent(it.value(), y[it.key()])) {
                return false;
            }
        }
        return true;
    }
    return a == b;
}

}
bool Engine::eventFilter(QObject *watched, QEvent *event) {
    // 原生文本框和滑块也属于用户输入，不能只依赖资料库 MouseArea 的事件。
    switch (event->type()) {
    case QEvent::MouseButtonPress:
        m_pressed = true;
        if (const auto *mouse = dynamic_cast<QMouseEvent*>(event)) emit pointerPressed(mouse->position().x(), mouse->position().y());
        wake();
        break;
    case QEvent::MouseButtonRelease:
        m_pressed = false;
        wake();
        break;
    case QEvent::MouseMove:
    case QEvent::Wheel:
    case QEvent::KeyPress:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
        wake();
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}
void Engine::start() {
    m_started = true;
    wake(false);
}
QVariantMap Engine::performance() const {
    return {{"idle", m_sleeping},
            {"sceneSleeping", m_sceneSleeping},
            {"visible", m_visible},
            {"steps", qulonglong(m_steps)},
            {"sceneUpdates", qulonglong(m_sceneUpdates)},
            {"hudUpdates", qulonglong(m_hudUpdates)},
            {"renderFrames", 0}, {"gpuResources", 0}, {"bindingCreations", 0},
            {"gpuMusicTextureBytes", 0}, {"coverUploads", 0}, {"gpuDrawCalls", 0},
            {"timerActive", timer.isActive()}};
}
void Engine::wake(bool input) {
    const bool wasSleeping = m_sleeping;
    const auto now = clock.elapsed();
    if (input) {
        m_lastInput = now;
        m_sceneSleeping = false;
        m_stableFrames = 0;
    } else if (scene.changed()) {
        m_sceneSleeping = false;
        m_stableFrames = 0;
    }
    m_sleeping = !m_visible;
    if (wasSleeping && !m_sleeping) {
        emit stateChanged();
    }
    if (m_started && m_visible && !timer.isActive()) {
        // 恢复时接续视觉时钟，不能把整段待机时间推进到弹簧和拖动惯性中。
        m_lastTick = now;
        timer.start(16);
    }
}
void Engine::setVisible(bool value) {
    if (m_visible == value) {
        return;
    }
    m_visible = value;
    if (!value) {
        flushPointer();
        app->pointer("pointercancel", 0, 0);
        m_pressed = m_wheelPending = false;
        m_wheelDelta = m_wheelSteps = 0;
        m_wheelDistance = 0;
        m_wheelRemainingDistance = 0;
        timer.stop();
        m_sleeping = true;
    } else {
        host.restoreMemoryBudget();
        wake(false);
        emit hudUpdated();
    }
    emit stateChanged();
}
/**
 * 隐藏窗口持续一段时间后释放可重建缓存，不改变音乐、账号或尚未完成的动画。
 */
void Engine::trimMemory() {
    if (m_visible) {
        return;
    }
    QStringList retainedImages{m_cover};
    for (const auto &value : m_commands) {
        const auto command = value.toArray();
        if (command[0].toString() == "image") {
            retainedImages << command[1].toString();
        }
    }
    host.trimMemory(retainedImages);
    scene.trimMemory();
}
/** 播放栏按需重绘时保持资源库休眠；只有可见的旋转或歌词动画需要连续调度。 */
void Engine::refreshPlayback() {
    refreshTaskbar();
    refreshDesktopLyrics();
    if (!m_visible) {
        return;
    }
    if (!m_sleeping || !m_sceneSleeping || scene.changed()) {
        wake(false);
        return;
    }
    step(m_animationTime);
    if (app->hud.animating(m_animationTime)) {
        wake(false);
    }
}

void Engine::pollMedia() {
    const bool levels=m_visible&&m_visualPreferences["motion"]=="full"&&!app->hud.reduced;
    host.enableVisualLevels(levels);
    app->poll(clock.elapsed() / 1000.0, true);
    refreshDesktopLyrics();
    const bool fullPlayer = m_visible && app->hud.frame["mode"]=="detail" && app->music.current["kind"]=="song";
    const auto interval = fullPlayer || (levels&&app->music.player.state["playing"].toBool()) ? 40 : app->hud.desktopLyricsEnabled ? 80 : 1000;
    if (mediaTimer.interval() != interval) { mediaTimer.setInterval(interval); }
    const auto &player = app->music.player;
    const bool active = player.loading || player.state["playing"].toBool();
    if (active && !mediaTimer.isActive()) {
        mediaTimer.start();
    }
    if (!active) {
        mediaTimer.stop();
    }
}
void Engine::flushPointer() {
    if (!m_pointerPending) {
        return;
    }
    m_pointerPending = false;
    app->pointer("pointermove", m_pointerX, m_pointerY);
}
/**
 * 推进本帧动画并决定是否继续调度。
 * 状态收束后允许待机，输入和后台数据失效会重新唤醒。
 */
void Engine::tick() {
    const auto now = clock.elapsed();
    m_animationTime += qMin<qint64>(now - m_lastTick, 50) / 1000.;
    m_lastTick = now;
    flushPointer();
    if(app->hud.frame["mode"]=="archive"&&!app->music.directory&&(app->music.current["kind"]=="playlist"||app->music.current["kind"]=="album")&&m_wheelY<976&&app->hud.modal.isEmpty()&&!app->hud.queueOpen&&!app->hud.lyricsMode&&!app->hud.commentsOpen&&!app->hud.frame["viewer"].toBool()){
        m_wheelRemainingDistance=0;m_wheelDistance=0;m_wheelSteps=0;m_wheelDelta=0;m_wheelPending=false;
    }
    // 鼠标滚轮一格的连续距离按帧衰减送出；列表行数仍按格立即推进。
    if (m_wheelRemainingDistance != 0) {
        const auto portion = std::abs(m_wheelRemainingDistance) < WHEEL_DISTANCE_TAIL
                                 ? m_wheelRemainingDistance
                                 : m_wheelRemainingDistance * WHEEL_SMOOTHING;
        m_wheelDistance += portion;
        m_wheelRemainingDistance -= portion;
        m_wheelPending = true;
    }
    if (m_wheelPending) {
        const int steps = int(m_wheelSteps);
        app->hud.wheel(m_wheelX, m_wheelY, m_wheelDelta, steps, m_wheelDistance);
        m_wheelSteps -= steps;
        m_wheelPending = false;
        m_wheelDelta = 0;
        m_wheelDistance = 0;
    }
    step(m_animationTime);
    timer.setInterval(16);
    if (now - m_lastInput >= 750 && !m_pressed && m_sceneSleeping && !scene.changed() &&
        !app->hud.animating(m_animationTime)) {
        timer.stop();
        m_sleeping = true;
        emit stateChanged();
    }
}
void Engine::resize(double width, double height) {
    if (height <= 0 || (m_width == width && m_height == height)) {
        return;
    }
    m_width = width;
    m_height = height;
    scene.resize(width / (height / 1080), 1080);
    wake();
}
void Engine::action(QString value) {
    if(value=="sound:effects"){m_soundEffects->open();return;}
    if (value == "interface:fonts") { app->hud.openModal("interface-fonts"); wake(); return; }
    if (value == "desktop:reset") { m_desktopPosition = {}; }
    if (value == "desktop:font" || value.startsWith("desktop:color:")) { value = "desktop:settings"; }
    if (value == "performance:toggle") {
        emit performanceRequested();
        return;
    }
    // 窗口模式由 Qt 原生窗口处理，不进入音乐状态或场景动画。
    if (value == "window:fullscreen") {
        toggleFullscreen();
        return;
    }
    app->hud.action(value);
    pollMedia();
    wake();
}
void Engine::indexApplicationFonts() const {
    if (m_fontCatalogReady) return;
    m_fontCatalogReady = true;
    for (const auto &root : {host.root + "/fonts", AppStorage::dataDirectory() + "/fonts"}) {
        const QDir directory(root);
        for (const auto &name : directory.entryList({"*.ttf", "*.otf", "*.ttc"}, QDir::Files)) {
            const auto path = directory.filePath(name);
            for (const auto &family : fontFileFamilies(path)) m_applicationFontFiles[family].append(path);
        }
    }
}
bool Engine::ensureFontFamily(const QString &family) const {
    if (family == "MiSans" && QFontDatabase::hasFamily(family)) return true;
    indexApplicationFonts();
    for (const auto &path : m_applicationFontFiles.value(family)) {
        if (!m_registeredFontFiles.contains(path)) {
            m_registeredFontFiles.insert(path);
            if (QFontDatabase::addApplicationFont(path) < 0) m_registeredFontFiles.remove(path);
        }
    }
    return QFontDatabase::hasFamily(family);
}
QStringList Engine::QFontDatabaseFamilies() const {
    indexApplicationFonts();
    auto result = QFontDatabase::families();
    for (const auto &family : m_applicationFontFiles.keys()) if (!result.contains(family)) result.append(family);
    result.sort();
    return result;
}
void Engine::initializeUiFont(QString fallback) {
    startupMemory("font-registration-begin");
    indexApplicationFonts();
    const auto saved = host.preference("ui-font");
    ensureFontFamily(saved);
    ensureFontFamily(app->hud.desktopLyricsFont);
    startupMemory("font-registration-ready");
    // Match Cloudy's Windows font chain; use the bundled family as last resort.
    const auto available = QFontDatabase::families();
    startupMemory("font-families-ready");
    if (available.contains("Noto Sans SC")) fallback = "Noto Sans SC";
    else if (available.contains("Microsoft YaHei UI")) fallback = "Microsoft YaHei UI";
    m_defaultUiFont = fallback;
    m_uiFont = QFontDatabase::families().contains(saved) ? saved : fallback;
    m_glyphs.setFamily(m_uiFont);
    startupMemory("font-family-selected");
}
void Engine::setUiFont(QString family) {
    if (!ensureFontFamily(family)) return;
    m_uiFont = family; m_fontError.clear();
    m_glyphs.setFamily(family);
    app->hud.resetTextMetrics();
    host.setPreference("ui-font", family);
    m_commands = {}; m_sceneSignature = {};
    emit uiFontChanged(); emit hudUpdated(); wake();
}
void Engine::importUiFont(QUrl file) {
    if (!file.isLocalFile()) return;
    const QFileInfo info(file.toLocalFile());
    if (!QStringList{"ttf", "otf", "ttc"}.contains(info.suffix().toLower()) || info.size() > 64*1024*1024) {
        m_fontError = "请选择小于 64 MB 的 TTF、OTF 或 TTC 字体"; emit uiFontChanged(); return;
    }
    const int id = QFontDatabase::addApplicationFont(info.absoluteFilePath());
    const auto families = QFontDatabase::applicationFontFamilies(id);
    if (families.isEmpty()) { m_fontError = "无法读取这个字体文件"; emit uiFontChanged(); return; }
    QFile input(info.absoluteFilePath());
    if (!input.open(QIODevice::ReadOnly)) return;
    const auto bytes = input.readAll();
    const auto directory = AppStorage::dataDirectory()+"/fonts";
    QDir().mkpath(directory);
    const auto target = directory+"/"+QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex()+"."+info.suffix().toLower();
    if (!QFileInfo::exists(target) && !QFile::copy(info.absoluteFilePath(),target)) {
        m_fontError="无法将字体保存到应用目录";emit uiFontChanged();return;
    }
    setUiFont(families.first());
}
void Engine::saveProfileSignature(QString signature) {
    auto &hud=app->hud; auto &music=app->music;
    if(hud.profileSignatureSaving || music.provider!="netease" || music.uid.isEmpty() || hud.profileID!=music.uid)return;
    if(signature.size()>300){hud.profileSignatureError="签名不能超过 300 个字符";wake();return;}
    auto fields=hud.profile;
    for(const auto &key:{"nickname","gender","birthday","province","city"}) {
        if(!fields.contains(key)) {hud.profileSignatureError="个人资料尚未完整加载，请稍后重试";wake();return;}
    }
    hud.profileSignatureSaving=true;hud.profileSignatureError.clear();wake();
    const auto account=music.accountGeneration();const auto uid=music.uid;
    m_signatureAccount=account;
    QJsonObject parameters{{"signature",signature}};
    for(const auto &key:{"nickname","gender","birthday","province","city"})if(fields.contains(key))parameters[key]=fields[key];
    QPointer<Engine> self(this);
    music.api.request("/user/update",parameters,[self,signature,uid](MusicReply reply){
        if(!self)return;
        auto &hud=self->app->hud;hud.profileSignatureSaving=false;
        if(!reply.ok())hud.profileSignatureError=reply.error.isEmpty()?QString("签名保存失败，请稍后重试"):reply.error;
        else{
            self->host.invalidateMetadata();
            if(hud.profileID==uid)hud.profile["signature"]=signature;
            self->m_personal->updateSignature(signature);
            self->app->music.accountDetails["signature"]=signature;
            emit self->profileSignatureSaved();
        }
        self->wake();
    },[self,account,uid]{return self&&self->app->music.accountGeneration()==account&&self->app->music.uid==uid;});
}
void Engine::hoverLink(QString value) {
    if (app->hud.hoveredLink == value) { return; }
    app->hud.hoveredLink = value;
    wake();
}
void Engine::setPlayerPreference(QString key, QString value) {
    if(key=="lyric-scale") {bool ok=false;const auto scale=value.toDouble(&ok);if(!ok||!std::isfinite(scale))return;value=QString::number(std::clamp(scale,.7,1.6));}
    else if(key=="stage-style") {if(!QStringList{"flow","steps","tilt"}.contains(value))return;}
    else if(key=="desktop-lyrics-style") {if(!QStringList{"dark","light","outline","color","plain"}.contains(value))return;}
    else if(key=="lyric-translation"||key=="stage-sparks") {if(value!="on"&&value!="off")return;}
    else if(key=="podcast-speed") {bool ok=false;const auto speed=value.toDouble(&ok);if(!ok||!QList<double>{.75,1,1.25,1.5,1.75,2}.contains(speed))return;app->music.player.setPodcastSpeed(speed);wake();return;}
    else return;
    if(key=="lyric-scale")app->hud.lyricScale=value.toDouble();
    else if(key=="stage-style")app->hud.stageStyle=value;
    else if(key=="stage-sparks")app->hud.stageSparks=value=="on";
    else if(key=="lyric-translation")app->hud.lyricTranslation=value!="off";
    m_playerPreferences.insert(key,value);host.setPreference(key,value);refreshDesktopLyrics();wake();
}
void Engine::setDetailFlightBarOpacity(double opacity) {
    if (!std::isfinite(opacity)) return;
    opacity = std::clamp(opacity, 0., 1.);
    if (app->hud.detailFlightBarOpacity == opacity) return;
    app->hud.detailFlightBarOpacity = opacity;
    wake(false);
}
void Engine::setSleep(int minutes) {
    if (!QList<int>{-1,0,15,30,45,60,90}.contains(minutes)) return;
    m_sleepTimer.stop();m_sleepMinutes=minutes;
    if(minutes>0)m_sleepTimer.start(minutes*60000);
    emit sleepChanged();
}
// Cloudy power_saver.go: restore the saved effects, but leave saver on manual enable.
void Engine::setVisualPreference(QString key,QVariant value) {
    if(!m_visualPreferences.contains(key)||key=="saverBefore")return;
    if(key=="motion") {if(!QStringList{"full","lite","off"}.contains(value.toString()))return;}
    else if(key=="glassClear"||key=="glassBend"||key=="glowLevel") {
        bool ok=false;const auto number=value.toDouble(&ok);if(!ok||!std::isfinite(number))return;value=std::clamp(number,0.,1.);
    }else if(value.metaType().id()!=QMetaType::Bool)return;
    if(m_visualPreferences.value(key)==value)return;
    const QStringList costly{"liquidGlass","barSpin","npLight","fog","smoke"};
    if(key=="powerSaver") {
        if(value.toBool()) {QVariantMap before;for(const auto &effect:costly){before[effect]=m_visualPreferences[effect];m_visualPreferences[effect]=false;}m_visualPreferences["saverBefore"]=before;}
        else {const auto before=m_visualPreferences["saverBefore"].toMap();for(const auto &effect:costly)if(before.contains(effect))m_visualPreferences[effect]=before[effect];m_visualPreferences.remove("saverBefore");}
    }else if(costly.contains(key)&&value.toBool()){m_visualPreferences["powerSaver"]=false;m_visualPreferences.remove("saverBefore");}
    m_visualPreferences[key]=value;
    host.setPreference("visual-effects",QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(m_visualPreferences)).toJson(QJsonDocument::Compact)));
    emit visualPreferencesChanged();wake();
}
void Engine::setDesktopFont(QString family, int size) {
    if (family.isEmpty() || family.size() > 128 || (family != "MiSans" && !ensureFontFamily(family))) { return; }
    app->hud.desktopLyricsFont = family;
    host.setPreference("desktop-lyrics-font", family);
    if (size > 0) {
        app->hud.desktopLyricsSize = std::clamp(size, 18, 48);
        host.setPreference("desktop-lyrics-size", QString::number(app->hud.desktopLyricsSize));
    }
    refreshDesktopLyrics();
    wake();
}
void Engine::saveDesktopPosition(double x, double y) {
    if (!std::isfinite(x) || !std::isfinite(y)) { return; }
    m_desktopPosition = {{"x", x}, {"y", y}};
    host.setPreference("desktop-lyrics-position", QString::fromUtf8(
        QJsonDocument(m_desktopPosition).toJson(QJsonDocument::Compact)));
    refreshDesktopLyrics();
}
void Engine::setDesktopWindow(QQuickWindow *window) {
    m_desktopWindow = window;
    refreshDesktopLyrics();
}
void Engine::setDesktopColor(QString target, QString value) {
    const auto color = QColor::fromString(value);
    if (!color.isValid()) { return; }
    auto &hud = app->hud;
    QString *setting = target == "primary" ? &hud.desktopLyricsPrimaryColor :
        target == "secondary" ? &hud.desktopLyricsSecondaryColor :
        target == "background" ? &hud.desktopLyricsBackgroundColor : nullptr;
    if (!setting) { return; }
    *setting = color.name();
    host.setPreference("desktop-lyrics-" + target + "-color", *setting);
    refreshDesktopLyrics();
    wake();
}
QStringList Engine::desktopFonts() const {
    auto fonts = QFontDatabaseFamilies();
    fonts.removeAll("MiSans"); fonts.removeAll("Rhine MiSans"); fonts.prepend("MiSans"); return fonts;
}
void Engine::setDesktopOpacity(int opacity) {
    app->hud.desktopLyricsBackgroundOpacity = std::clamp(opacity, 0, 100);
    host.setPreference("desktop-lyrics-background-opacity", QString::number(app->hud.desktopLyricsBackgroundOpacity));
    refreshDesktopLyrics(); wake();
}
namespace {
struct DesktopPalette { QString key, primary, secondary, background, lightPrimary, lightSecondary; };
const QList<DesktopPalette> desktopPalettes{
    {"oat", "#353b2b", "#68704c", "#f6ead4", "#f6ead4", "#d1d5b5"},
    {"rose", "#422b23", "#8b6264", "#efd8d6", "#fff3eb", "#e8c3c6"},
    {"sage", "#34453e", "#6c786e", "#eeece0", "#eeece0", "#bfd3c8"}};
}
void Engine::applyDesktopPreset(QString preset) {
    for (const auto &palette : desktopPalettes) {
        if (palette.key != preset) { continue; }
        const bool light = app->hud.desktopLyricsTone == "light";
        setDesktopColor("primary", light ? palette.lightPrimary : palette.primary);
        setDesktopColor("secondary", light ? palette.lightSecondary : palette.secondary);
        setDesktopColor("background", palette.background);
        setDesktopOpacity(65);
        return;
    }
}
void Engine::setDesktopTone(QString tone) {
    if (tone != "dark" && tone != "light") { return; }
    if (app->hud.desktopLyricsTone == tone) { return; }
    QString preset = "oat";
    for (const auto &palette : desktopPalettes) {
        if (app->hud.desktopLyricsBackgroundColor == palette.background) { preset = palette.key; break; }
    }
    app->hud.desktopLyricsTone = tone;
    host.setPreference("desktop-lyrics-tone", tone);
    applyDesktopPreset(preset);
}
void Engine::refreshDesktopLyrics() {
    const auto &hud = app->hud;
    const auto &player = app->music.player;
    const auto &lyrics = player.lyrics;
    QString primary, secondary;
    QJsonArray currentWords;
    const auto lines = lyrics.document().value("lines").toArray();
    if (!player.current.isEmpty()) {
        if (player.failed) { primary = "播放暂不可用"; }
        else if (player.loading || lyrics.status == "loading") { primary = player.current.value("title").toString(); secondary = "正在读取歌词…"; }
        else if (!lines.isEmpty()) {
            const auto index = lyrics.index;
            if (index >= 0 && index < lines.size()) {
                primary = lines.at(index).toObject().value("text").toString().trimmed();
                currentWords = lines.at(index).toObject().value("words").toArray();
                secondary = lines.at(index).toObject().value("translation").toString().trimmed();
                if (secondary == primary) { secondary.clear(); }
            }
            const int next = std::max(0, index + 1);
            for (int i = next; secondary.isEmpty() && i < lines.size(); ++i) {
                const auto text = lines.at(i).toObject().value("text").toString().trimmed();
                if (!text.isEmpty() && (index < 0 || lines.at(i).toObject().value("startMs").toDouble() > lines.at(index).toObject().value("startMs").toDouble())) {
                    secondary = text;
                    break;
                }
            }
            if (primary.isEmpty()) { primary = "♪"; }
        } else {
            primary = player.current.value("title").toString();
            secondary = lyrics.status == "error" ? "歌词暂不可用" : "暂无同步歌词";
        }
    } else { primary = "选择歌曲开始播放"; }
    const auto saved = m_desktopPosition.isEmpty()
        ? QJsonDocument::fromJson(host.preference("desktop-lyrics-position").toUtf8()).object() : m_desktopPosition;
    QRect available, screenBounds;
    const QPoint savedPoint(saved.value("x").toInt(), saved.value("y").toInt());
    for (const auto screen : QGuiApplication::screens()) {
        if (!saved.isEmpty() && screen->geometry().contains(savedPoint)) {
            available = screen->availableGeometry(); screenBounds = screen->geometry(); break;
        }
    }
    if (available.isEmpty() && QGuiApplication::primaryScreen()) {
        available = QGuiApplication::primaryScreen()->availableGeometry();
        screenBounds = QGuiApplication::primaryScreen()->geometry();
    }
    const int width = std::min(800, std::max(320, available.width() - 32));
    const int height = m_desktopWindow ? m_desktopWindow->height() : 132;
    const int x = std::clamp(saved.isEmpty() ? available.center().x() - width / 2 : savedPoint.x(), screenBounds.left(), std::max(screenBounds.left(), screenBounds.right() - width + 1));
    const int y = std::clamp(saved.isEmpty() ? available.bottom() - height - 48 : savedPoint.y(), screenBounds.top(), std::max(screenBounds.top(), screenBounds.bottom() - height + 1));
    QString hoverPrimary = hud.desktopLyricsPrimaryColor, hoverSecondary = hud.desktopLyricsSecondaryColor;
    // Light letters need a dark counterpart over the pale hover backing. Custom
    // dark colors remain intact, and dark backings keep the user's light colors.
    const auto backdrop = QColor::fromString(hud.desktopLyricsBackgroundColor);
    if (hud.desktopLyricsTone == "light" && backdrop.lightnessF() > 0.6) {
        QString darkPrimary = "#353b2b", darkSecondary = "#68704c";
        for (const auto &palette : desktopPalettes) {
            if (palette.background == hud.desktopLyricsBackgroundColor) {
                darkPrimary = palette.primary; darkSecondary = palette.secondary; break;
            }
        }
        if (QColor::fromString(hoverPrimary).lightnessF() > 0.6) { hoverPrimary = darkPrimary; }
        if (QColor::fromString(hoverSecondary).lightnessF() > 0.6) { hoverSecondary = darkSecondary; }
    }
    const QVariantMap next{{"enabled", hud.desktopLyricsEnabled}, {"locked", hud.desktopLyricsLocked},
        {"style",m_playerPreferences.value("desktop-lyrics-style",host.preference("desktop-lyrics-style")).isEmpty()?QString("outline"):m_playerPreferences.value("desktop-lyrics-style",host.preference("desktop-lyrics-style"))},
        {"words",currentWords.toVariantList()},{"positionMs",lyrics.positionMs+lyrics.document()["offsetMs"].toDouble()+lyrics.offsetMs},
        {"font", hud.desktopLyricsFont}, {"size", hud.desktopLyricsSize}, {"primary", primary},
        {"secondary", secondary}, {"x", x}, {"y", y}, {"width", width}, {"height", height}, {"reduced", hud.reduced},
        {"tone", hud.desktopLyricsTone}, {"hoverPrimaryColor", hoverPrimary}, {"hoverSecondaryColor", hoverSecondary},
        {"primaryColor", hud.desktopLyricsPrimaryColor}, {"secondaryColor", hud.desktopLyricsSecondaryColor},
        {"backgroundColor", hud.desktopLyricsBackgroundColor}, {"backgroundOpacity", hud.desktopLyricsBackgroundOpacity}};
    if (next != m_desktopLyrics) { m_desktopLyrics = next; emit desktopLyricsChanged(); }
}
/**
 * 将输入控件的原始数据转换为原生业务操作；密码不写入公开状态。
 */
void Engine::submitForm(QString account, QString password) {
    QJsonObject values;
    if (app->hud.modal == "login") {
        values = {{"account", account}, {"password", password}};
    } else {
        values = {{"name", account}};
    }
    app->hud.form(values);
    wake();
}
void Engine::setWindow(QQuickWindow *window) {
    m_window = window;
#ifdef Q_OS_WIN
    m_taskbar.reset();
    if (window && !host.offline) {
        m_taskbar = std::make_unique<TaskbarIntegration>(window, [this](QString command) {
            refreshTaskbar();
            action(command);
        });
        refreshTaskbar();
    }
#endif
}
void Engine::refreshTaskbar() {
    if (!m_taskbar || !app) { return; }
    auto &music = app->music;
    const auto &player = music.player;
    const auto track = player.current;
    const bool song = track.value("kind") == "song" && !track.value("id").toString().isEmpty();
    const bool sameProvider = track.value("provider").toString("netease") == music.provider;
    const auto account = music.accountKey() + ":" + QString::number(music.accountGeneration());
    if (song && sameProvider && music.provider == "netease" && !music.uid.isEmpty() &&
        !music.likedIDs && m_taskbarLikeKey != account) {
        m_taskbarLikeKey = account;
        const auto generation = music.accountGeneration();
        const QPointer<Engine> owner(this);
        music.api.call("likedIDs", {music.uid}, [owner, account](MusicReply reply) {
            if (!owner || !owner->app) { return; }
            auto &current = owner->app->music;
            if (current.accountKey() + ":" + QString::number(current.accountGeneration()) != account) { return; }
            if (reply.ok() && !current.likedIDs) { current.likedIDs = reply.value.toArray(); current.changed(); }
        }, [owner, generation] { return owner && owner->app && owner->app->music.accountGeneration() == generation; });
    }
    TaskbarPlayback state;
    state.identity = song ? MusicPlayer::identity(track) : QString();
    state.title = song ? track.value("title").toString() : QString();
    state.artist = song ? track.value("artist").toString() : QString();
    state.artwork = song ? host.image(player.coverImage) : QImage();
    state.playing = player.state.value("playing").toBool();
    state.playable = song && !player.loading && !player.failed;
    state.previous = state.next = song && !player.queue.isEmpty();
    const auto subscription = music.subscriptionStates.value(track.value("key").toString(), "unknown");
    const bool known = music.provider == "netease" ? music.likedIDs.has_value() : subscription != "unknown";
    state.canLike = song && sameProvider && known && !music.uid.isEmpty() && !music.writeLoading && music.canMutate("/like");
    state.liked = sameProvider && (music.provider == "qq" ? subscription == "subscribed" :
        (music.likedIDs && MusicData::indexOf(*music.likedIDs, track.value("id")) >= 0) ||
        MusicData::indexOfId(music.lists[1], track.value("id").toString()) >= 0);
    m_taskbar->update(state);
}
void Engine::toggleFullscreen() {
    if (!m_window) {
        return;
    }
    if (m_window->visibility() == QWindow::FullScreen) {
        m_window->setVisibility(m_windowedVisibility);
    } else {
        m_windowedVisibility =
            m_window->visibility() == QWindow::Maximized ? QWindow::Maximized : QWindow::Windowed;
        m_window->showFullScreen();
    }
}
bool Engine::keyEvent(int keyCode, int modifiers, QString text) {
    switch (keyCode) {
    case Qt::Key_MediaTogglePlayPause:
    case Qt::Key_MediaPlay:
    case Qt::Key_MediaPause:
        action("player:toggle");
        return true;
    case Qt::Key_MediaNext:
        action("player:next");
        return true;
    case Qt::Key_MediaPrevious:
        action("player:prev");
        return true;
    case Qt::Key_Left:
        text = "ArrowLeft";
        break;
    case Qt::Key_Right:
        text = "ArrowRight";
        break;
    case Qt::Key_Up:
        text = "ArrowUp";
        break;
    case Qt::Key_Down:
        text = "ArrowDown";
        break;
    case Qt::Key_Return:
    case Qt::Key_Enter:
        text = "Enter";
        break;
    case Qt::Key_Escape:
        text = "Escape";
        break;
    case Qt::Key_Tab:
        text = "Tab";
        break;
    default:
        break;
    }
    if (text.isEmpty()) {
        return false;
    }
    // Qt 在 macOS 将 ControlModifier 映射到命令键。
    key(text, modifiers & Qt::ControlModifier);
    return true;
}
void Engine::searchAccepted(QString text, int modifiers) {
    if (modifiers & Qt::ControlModifier) {
        key("Enter", true);
    } else {
        query(text);
    }
}
void Engine::wheelInput(double x, double y, double pixelDelta, double angleDelta) {
    wheel(x, y, pixelDelta != 0 ? pixelDelta : angleDelta / 8, pixelDelta != 0);
}
void Engine::adjustPlayer(QString control, double x, double width) {
    if (width <= 0 || (control != "seek" && control != "volume")) {
        return;
    }
    action("player:" + control + "-fraction:" + QString::number(std::clamp(x / width, 0., 1.), 'g', 16));
}
void Engine::query(QString value) {
    app->hud.setQuery(value);
    wake();
}
void Engine::key(QString value, bool command) {
    if (!command && (value.startsWith("Arrow") || value == "Enter")) {
        m_keyboardCursor = QCursor::pos();
        m_keyboardMouseGuard = true;
    }
    app->hud.key(value, command);
    if (!command && (value.startsWith("Arrow") || value == "Enter")) {
        emit pageNavigation(value);
    }
    wake();
}
void Engine::hoverItem(QString value, double x, double y) {
    if (app->hud.keyboardNavigation && m_keyboardMouseGuard) {
        // Delegate recreation can emit hover events while the physical cursor
        // has not moved. Such layout events must never cancel keyboard focus.
        if ((QCursor::pos() - m_keyboardCursor).manhattanLength() <= 2) { return; }
        app->hud.navigationPointer = QPointF(x - 3, y);
    }
    app->hud.hoverItem(value, x, y);
}
void Engine::pointer(QString type, double x, double y) {
    if (type == "pointermove") {
        if (m_pointerX == x && m_pointerY == y && !m_pointerPending) {
            return;
        }
        m_pointerX = x;
        m_pointerY = y;
        m_pointerPending = true;
    } else {
        flushPointer();
        app->pointer(type, x, y);
        if (type == "pointerdown") {
            m_pressed = true;
        }
        if (type == "pointerup" || type == "pointercancel" || type == "pointerleave") {
            m_pressed = false;
        }
    }
    wake();
}
void Engine::wheel(double x, double y, double delta, bool pixels) {
    if (!std::isfinite(delta) || delta == 0) {
        return;
    }
    m_wheelX = x;
    m_wheelY = y;
    m_wheelDelta += delta;
    if (pixels) {
        m_wheelSteps += -delta / 15.;
        // 单独保留连续舞台位移，避免触控板不足一行的输入被整数行索引吞掉。
        m_wheelDistance += -delta / (m_height / 1080.);
    } else {
        // 列表按格立即推进一行，只有设置页和歌词需要平滑的连续距离。
        m_wheelSteps += delta < 0 ? 1 : -1;
        const auto distance = -delta / 15. * WHEEL_DISTANCE_PER_NOTCH;
        if (app->hud.reduced) {
            m_wheelDistance += distance;
        } else {
            m_wheelRemainingDistance += distance;
        }
    }
    m_wheelPending = true;
    wake();
}
/**
 * 按顺序同步场景、音乐和 HUD 帧数据，保持绘制与命中区域一致。
 */
void Engine::step(double time) {
    PipelineDiagnostics::Scope trace("engine.step");
    if (!ready()) {
        return;
    }
    QElapsedTimer frameTimer;
    if (scene.isProfiling()) {
        frameTimer.start();
        // 复用睡眠场景的帧不能沿用上次模拟耗时，否则现场日志会误报瓶颈。
        scene.timings = {};
    }
    ++m_steps;
    const bool reuse = m_sceneSleeping && !scene.changed();
    const auto object = app->step(time, m_width / (m_height / 1080), reuse);
    if (object.isEmpty()) {
        return;
    }
    m_frame = scene.frame;
    const bool stable = equivalent(m_frame, m_sceneSignature);
    m_sceneSignature = m_frame;
    m_stableFrames = stable ? m_stableFrames + 1 : 0;
    m_sceneSleeping = m_stableFrames >= 2 && !m_frame["pendingAnimations"].toBool();
    m_current = object["current"].toObject();
    m_cover = object["cover"].toString();
    auto commands = object["commands"].toArray();
    if (commands != m_commands) {
        m_commands = commands;
        ++m_hudUpdates;
        emit hudUpdated();
    }
    auto state = object["state"].toObject().toVariantMap();
    state["originalActorVisible"] = false;
    // Collection data is independent of hover, playback and tab animation.
    // QML must not re-filter/serialize hundreds of cards on every state tick.
    QVariantMap profileContent;
    for (const auto *key : {"profileCollections", "profileRows", "artistSongs", "artistAlbums"})
        profileContent.insert(QString::fromLatin1(key), state.value(QString::fromLatin1(key)));
    if (profileContent != m_profileContent) {
        m_profileContent = std::move(profileContent);
        emit profileContentChanged();
    }
    // PlaylistMagazine syncs from MusicLibrary::invalidated; never rescan it per render step.
    if (state != m_state) {
        m_state = state;
        const auto loginMethod = m_state.value("loginMethod").toString();
        if (loginMethod != m_loginMethod) {
            m_loginMethod = loginMethod;
            emit clearCredentials();
        }
        emit stateChanged();
    }
    auto hits = object["hits"].toArray().toVariantList();
    if (hits != m_hits) {
        m_hits = hits;
        emit hitsChanged();
    }
    if (scene.isProfiling()) {
        scene.timings.engineMs = frameTimer.nsecsElapsed() / 1000000.;
    }
    emit updated();
}
void Engine::snapshot(QString path) {
    if (m_frame.isEmpty()) {
        return;
    }
    QDir().mkpath(path);
    const QSize size(1920, 1080);
    QImage metal(size, QImage::Format_RGBA8888_Premultiplied);
    QPainter background(&metal);
    QLinearGradient gradient(0, 0, 0, size.height());
    gradient.setColorAt(0, QColor(app->hud.dark ? "#252a23" : "#f7f4ed"));
    gradient.setColorAt(1, QColor(app->hud.dark ? "#20251e" : "#efebe1"));
    background.fillRect(metal.rect(), gradient);
    background.end();
    saveImageNative(metal, path + "/qt-background.png");
    QImage hud(size, QImage::Format_RGBA8888_Premultiplied);
    hud.fill(Qt::transparent);
    QPainter hudPainter(&hud);
    m_glyphs.commands(hudPainter, m_commands, [this](QString key) { return host.image(key); });
    hudPainter.end();
    saveImageNative(hud, path + "/qt-panel.png");
    QPainter painter(&metal);
    painter.drawImage(0, 0, hud);
    painter.end();
    metal.save(path + "/qt-composite.png");
    QFile file(path + "/qt-state.json");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_frame).toJson());
    }
}
/** Offline package checks cover the remaining navigation and music paths. */
int Engine::selfTest() {
    bool ok = ready() && runNativeHostChecks(root()) && runNativeMusicChecks(root());
    scene.review("archive"); step(2.101);
    ok &= m_frame["mode"] == "archive" && !m_frame.contains("draws");
    scene.navigate("row", 1);
    const auto selected = scene.selection();
    scene.navigate("row", -1);
    ok &= scene.selection() == 0 && selected != 0;
    scene.setMode("detail"); step(2.2);
    ok &= m_frame["mode"] == "detail" && !m_frame["viewer"].toBool();
    scene.setMode("boot"); step(2.3);
    ok &= m_frame["mode"] == "archive";
    qInfo() << "Qt 2D navigation, Host, music and playback:" << (ok ? "passed" : "FAILED");
    return ok ? 0 : 1;
}

int Engine::renderFixtures(QString source, QString output) {
    for (const auto &name : QDir(source).entryList({"*.json"}, QDir::Files, QDir::Name)) {
        QFile input(source + "/" + name);
        if (!input.open(QIODevice::ReadOnly)) {
            return 1;
        }
        const auto fixture = QJsonDocument::fromJson(input.readAll()).object();
        const auto store = fixture["store"].toObject();
        const auto settings = fixture["hud"].toObject();
        app->music.current = store["current"].toObject();
        const auto lists = store["lists"].toArray();
        const auto totals = store["totals"].toArray();
        const auto more = store["hasMore"].toArray();
        for (int lane = 0; lane < 5; ++lane) {
            app->music.lists[lane] = lists.at(lane).toArray();
            app->music.totals[lane] = totals.at(lane).toInt();
            app->music.hasMore[lane] = more.at(lane).toBool();
        }
        app->music.keyword = store["keyword"].toString();
        app->music.status = store["status"].toString();
        app->hud.modal = settings["modal"].toString();
        app->hud.dark = settings["dark"].toBool();
        app->hud.themeMode = settings["themeMode"].toString();
        app->hud.reduced = settings["reduced"].toBool();
        app->hud.motion.set(true, 0, true);
        m_frame = fixture["frame"].toObject();
        app->hud.draw(m_frame, 1920, 50);
        m_commands = app->hud.commands;
        m_current = app->music.current;
        m_cover.clear();
        const auto folder = output + "/" + fixture["name"].toString();
        snapshot(folder);
        QFile hitsFile(folder + "/qt-hits.json");
        if (hitsFile.open(QIODevice::WriteOnly)) {
            hitsFile.write(QJsonDocument(app->hud.hits).toJson());
        }
    }
    return failure.isEmpty() ? 0 : 1;
}

void Engine::importLocal(QList<QUrl> urls) {
    QStringList paths;
    for (const auto &url : urls) {
        if (url.isLocalFile()) {
            paths.append(url.toLocalFile());
        }
    }
    app->music.importLocal(paths);
    wake();
}
