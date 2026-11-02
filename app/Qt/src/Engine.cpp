#include "Engine.h"
#include "MusicData.h"
#include "DiscGeometry.h"
#include "RhiScene.h"
#include <QCoreApplication>
#include <QDir>
#include <QEvent>
#include <QEventLoop>
#include <QFile>
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
    : QObject(parent), host(path, offline), scene(path), m_glyphs(path) {
    const auto content = QJsonDocument::fromJson(host.read("slots.json").toUtf8()).object();
    app = std::make_unique<NativeApplication>(&host, &m_glyphs, &scene, content);
    connect(&app->music, &MusicLibrary::playbackInvalidated, this, &Engine::refreshPlayback);
    connect(&app->music, &MusicLibrary::invalidated, this, &Engine::refreshTaskbar);
    connect(&app->hud, &NativeHud::localImportRequested, this, &Engine::localImportRequested);
    m_showcase = new PlaylistShowcase(&app->music,&app->hud,this);
    connect(m_showcase,&PlaylistShowcase::navigate,this,&Engine::action);
    m_messages = new MessageCenter(&app->music,this);
    connect(m_messages,&MessageCenter::navigate,this,&Engine::action);
    m_magazine = new PlaylistMagazine(&app->music, &app->hud, this);
    connect(m_magazine,&PlaylistMagazine::navigate,this,&Engine::action);
    m_nowPlaying=new NowPlaying(&app->music,m_magazine,this);
    connect(m_nowPlaying,&NowPlaying::navigate,this,&Engine::action);
    app->initialize();
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
    delete m_nowPlaying;m_nowPlaying=nullptr;
    delete m_showcase;m_showcase=nullptr;
    delete m_messages; m_messages=nullptr;
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
bool equivalent(const QByteArray &a, const QByteArray &b) {
    if (a == b) {
        return true;
    }
    if (a.size() != b.size()) {
        return false;
    }
    for (qsizetype i = 0; i + 4 <= a.size(); i += 4) {
        float x;
        float y;
        memcpy(&x, a.constData() + i, 4);
        memcpy(&y, b.constData() + i, 4);
        if (qAbs(x - y) > 0.00001f) {
            return false;
        }
    }
    return true;
}
}
bool Engine::eventFilter(QObject *watched, QEvent *event) {
    // 原生文本框和滑块也属于用户输入，不能只依赖资料库 MouseArea 的事件。
    switch (event->type()) {
    case QEvent::MouseButtonPress:
        m_pressed = true;
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
            {"renderFrames", qulonglong(m_renderFrames.load(std::memory_order_relaxed))},
            {"gpuResources", qulonglong(m_gpuResources.load(std::memory_order_relaxed) +
                                        m_opticalGpuResources.load(std::memory_order_relaxed))},
            {"bindingCreations", qulonglong(m_bindingCreations.load(std::memory_order_relaxed))},
            {"gpuMusicTextureBytes", qulonglong(m_musicTextureBytes.load(std::memory_order_relaxed) +
                                                m_opticalTextureBytes.load(std::memory_order_relaxed))},
            {"coverUploads", qulonglong(m_coverUploads.load(std::memory_order_relaxed))},
            {"gpuDrawCalls", qulonglong(m_lastDrawCalls.load(std::memory_order_relaxed))},
            {"timerActive", timer.isActive()}};
}
/**
 * 只唤醒当前选用的渲染分支
 */
void Engine::notifySceneRenderers(bool visualChanged) {
    const bool enhanced = app->hud.sceneEnhancement;
    if (enhanced) {
        m_originalSceneDirty |= visualChanged;
        // 进入资料库时预热一次原版管线，避免抽取末尾才同步编译和分配整套资源。
        const bool prewarm = !m_originalSceneWarm && m_frame["mode"] != "boot";
        if ((prewarm || m_frame["originalActorBlend"].toDouble() > 0) && m_originalSceneDirty) {
            m_originalSceneDirty = false;
            m_originalSceneWarm = true;
            emit sceneUpdated();
        }
        if (visualChanged || !m_sceneEnhancement) {
            emit opticalSceneUpdated();
        }
    } else if (visualChanged || (m_sceneEnhancement && m_originalSceneDirty)) {
        m_originalSceneDirty = false;
        m_originalSceneWarm = true;
        emit sceneUpdated();
    }
    m_sceneEnhancement = enhanced;
}
void Engine::wake(bool input) {
    const bool wasSleeping = m_sleeping;
    const auto now = clock.elapsed();
    if (input) {
        m_lastInput = now;
        m_sceneSleeping = false;
        m_stableFrames = 0;
        scene.energyIdle(false);
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
        m_originalSceneWarm = false;
        wake(false);
        notifySceneRenderers(true);
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
    if (m_discRotating || app->hud.animating(m_animationTime)) {
        wake(false);
    }
}

void Engine::pollMedia() {
    app->poll(clock.elapsed() / 1000.0, true);
    refreshDesktopLyrics();
    const auto interval = app->hud.desktopLyricsEnabled ? 80 : 1000;
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
    if (now - m_lastInput >= 750 && !m_pressed) {
        scene.energyIdle(true);
    }
    step(m_animationTime);
    // 只有盘面在运动时以 30Hz 刷新；交互和原有动画仍使用原频率。
    timer.setInterval(m_discRotating && m_sceneSleeping && !app->hud.animating(m_animationTime) &&
                              now - m_lastInput >= 750 && !m_pressed
                          ? 33
                          : 16);
    if (now - m_lastInput >= 750 && !m_pressed && m_sceneSleeping && !scene.changed() &&
        !app->hud.animating(m_animationTime) && !m_discRotating && m_frame["mode"] != "boot") {
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
void Engine::hoverLink(QString value) {
    if (app->hud.hoveredLink == value) { return; }
    app->hud.hoveredLink = value;
    wake();
}
void Engine::setDesktopFont(QString family, int size) {
    if (family.isEmpty() || family.size() > 128 || (family != "MiSans" && !QFontDatabase::families().contains(family))) { return; }
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
    auto fonts = QFontDatabase::families();
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
    const auto lines = lyrics.document().value("lines").toArray();
    if (!player.current.isEmpty()) {
        if (player.failed) { primary = "播放暂不可用"; }
        else if (player.loading || lyrics.status == "loading") { primary = player.current.value("title").toString(); secondary = "正在读取歌词…"; }
        else if (!lines.isEmpty()) {
            const auto index = lyrics.index;
            if (index >= 0 && index < lines.size()) {
                primary = lines.at(index).toObject().value("text").toString().trimmed();
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
    const auto previousDiscAngle = m_frame["discAngle"].toDouble();
    m_frame = scene.frame;
    m_frame["originalActorBlend"] = scene.originalActorBlend();
    if(m_magazine && m_magazine->active() && !m_frame["viewer"].toBool()){
        QJsonArray room;
        for(const auto &v:m_frame["draws"].toArray())if(!v.toObject()["musicSelected"].toBool())room.append(v);
        m_frame["draws"]=room;m_frame["originalActorBlend"]=0;
    }

    auto signature = m_frame;
    for (const auto &key : {"time", "stats", "labels", "boot", "pointerCursor", "originalActorBlend"}) {
        signature.remove(key);
    }
    bool stable =
        equivalent(signature, m_sceneSignature) && m_previousBuffers.size() == scene.drawBuffers.size();
    for (auto it = scene.drawBuffers.begin(); stable && it != scene.drawBuffers.end(); ++it) {
        const auto old = m_previousBuffers.value(it.key());
        stable = equivalent(it->matrices, old.matrices) && equivalent(it->themes, old.themes);
    }
    m_stableFrames = stable ? m_stableFrames + 1 : 0;
    if (!stable) {
        ++m_geometryRevision;
    }
    if (!stable || scene.changed()) {
        m_sceneSleeping = false;
    }
    m_sceneSignature = signature;
    m_previousBuffers = scene.drawBuffers;
    if (m_stableFrames >= 4 && !scene.changed() && m_frame["mode"] != "boot" &&
        !m_frame["pendingAnimations"].toBool()) {
        m_sceneSleeping = true;
    }
    const auto current = object["current"].toObject();
    const auto cover = object["cover"].toString();
    const auto coverRevision = host.image(cover).cacheKey();
    const auto &player = app->music.player;
    const auto identity = MusicPlayer::identity(player.current);
    if (identity != m_discIdentity) {
        m_discIdentity = identity;
        m_discAngle = 0;
    }
    const bool wasRotating = m_discRotating;
    m_discRotating = m_visible && app->hud.discRotation && !app->hud.reduced && app->hud.modal.isEmpty() &&
                     m_frame["mode"] == "detail" && !m_frame["viewer"].toBool() &&
                     current["kind"] == "song" && MusicPlayer::identity(current) == identity &&
                     !player.loading && !player.failed && player.state["playing"].toBool();
    if (wasRotating && m_discRotating) {
        // 20 秒一圈；接续可见视觉时钟，暂停或隐藏期间不补转。
        m_discAngle = std::fmod(m_discAngle + std::clamp(time - m_discTime, 0., .05) *
                                                  (2 * 3.14159265358979323846 / 20),
                                2 * 3.14159265358979323846);
    }
    m_discTime = time;
    const bool showDiscAngle = current["kind"] == "song" && MusicPlayer::identity(current) == identity;
    m_frame["discAngle"] = showDiscAngle ? m_discAngle : 0;
    const bool discChanged = m_discRotating || previousDiscAngle != m_frame["discAngle"].toDouble();
    const bool visualChanged = discChanged || !stable || current != m_current || cover != m_cover ||
                               coverRevision != m_coverRevision;
    m_coverRevision = coverRevision;
    m_current = current;
    m_cover = object["cover"].toString();
    // 图形设备在后台可销毁；仅保存当前与可见归位卡片的图片，供恢复时重建纹理。
    const auto musicKey = current["key"].toString("empty");
    m_musicTextures[musicKey] = {current, host.image(m_cover)};
    QSet<QString> retainedKeys{musicKey};
    for (const auto &key : m_frame["returningMusicKeys"].toArray()) {
        retainedKeys.insert(key.toString());
    }
    for (const auto &value : m_frame["draws"].toArray()) {
        const auto key = value.toObject()["musicKey"].toString();
        if (!key.isEmpty()) {
            retainedKeys.insert(key);
        }
    }
    for (auto it = m_musicTextures.begin(); it != m_musicTextures.end();) {
        if (!retainedKeys.contains(it.key())) {
            it = m_musicTextures.erase(it);
        } else {
            ++it;
        }
    }
    auto commands = object["commands"].toArray();
    if (commands != m_commands) {
        m_commands = commands;
        ++m_hudUpdates;
        emit hudUpdated();
    }
    if (visualChanged) {
        ++m_sceneUpdates;
    }
    notifySceneRenderers(visualChanged);
    auto state = object["state"].toObject().toVariantMap();
    state["originalActorVisible"] = m_frame["originalActorBlend"].toDouble() > 0;
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
    auto metal = renderReference(root(), m_frame, m_current, cover(), size, scene.drawBuffers);
    saveImageNative(metal, path + "/qt-metal.png");
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
/** 独立包离线验收直接检查原生状态、原始模型与实际 QRhi 输出，不创建脚本引擎。 */
int Engine::selfTest() {
    bool ok =
        ready() && DiscGeometry::validate() && runNativeHostChecks(root()) && runNativeMusicChecks(root());
    scene.review("archive");
    step(2.101);
    ok &= !m_frame["draws"].toArray().isEmpty() && m_frame["stats"].toObject()["archiveCount"].toInt() > 0;
    QFile fixture(root() + "/scene-fixture.json");
    if (!fixture.open(QIODevice::ReadOnly)) {
        qCritical() << "Missing offline scene fixture";
        return 1;
    }
    const auto expected = QJsonDocument::fromJson(fixture.readAll()).object();
    const auto legacy = expected["frame"].toObject();
    ok &= equivalent(m_frame["view"], legacy["view"]) &&
          equivalent(m_frame["projection"], legacy["projection"]);
    for (const auto &entry : expected["rays"].toArray()) {
        const auto ray = entry.toObject();
        const auto hit = scene.pick(ray["x"].toDouble(), ray["y"].toDouble());
        const auto cell = ray["hit"].toObject();
        if (cell.isEmpty()) {
            ok &= !hit;
        } else {
            ok &= hit && hit->lane == cell["lane"].toInt() && hit->row == cell["row"].toInt();
        }
    }
    if (qEnvironmentVariableIntValue("RHINE_GPU_TEST") == 1) {
        const QSize size(960, 540);
        const auto actual =
            renderReference(root(), m_frame, m_current, host.image(m_cover), size, scene.drawBuffers);
        const auto original = renderReference(root(), legacy, m_current, host.image(m_cover), size);
        ok &= runGpuReferenceCheck(original, actual);
        if (!ok) {
            qCritical() << "Native GPU frame differs from original fixture";
        }
    }
    qInfo() << "Qt native scene, Host, music, playback and offline package checks:"
            << (ok ? "passed" : "FAILED");
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
