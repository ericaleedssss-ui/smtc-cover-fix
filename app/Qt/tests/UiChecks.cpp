bool runTaskbarChecks();
#include "Engine.h"
#include "FrameProfiler.h"
#include "MusicData.h"
#include "MusicDiscover.h"
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QImage>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QQuickItem>
#include <QPointer>
#include <QThread>
#include <QQuickWindow>
#include <QQuickItemGrabResult>
#include <QDebug>
#include <QWheelEvent>
#include <QMouseEvent>
#include <QKeyEvent>
#include <QGuiApplication>
#include <QClipboard>
#include <QColor>
#include <QScreen>
#include <cstdlib>
#include <cmath>
#include <algorithm>
#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <cstdio>
#endif

/**
 * UI 核心功能回归测试
 *
 * 验证关键交互逻辑和状态管理，不依赖像素精确对比或 GPU 渲染细节。
 * 场景增强和窗口 Chrome 测试已移至可选的手动验证流程。
 */

bool runSceneEnhancementChecks(Engine &backend, QQuickWindow *window, const QString &output);

namespace {
#ifdef Q_OS_WIN
// Only installed by the visual self-test. Report module offsets on an actual
// access violation without handling it or changing the failing exit status.
LONG CALLBACK reportVisualException(EXCEPTION_POINTERS *exception) {
    if (exception->ExceptionRecord->ExceptionCode != EXCEPTION_ACCESS_VIOLATION) {
        return EXCEPTION_CONTINUE_SEARCH;
    }
    const auto report = [](const void *address) {
        HMODULE module = nullptr;
        char name[MAX_PATH] = {};
        if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                              GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                              reinterpret_cast<LPCSTR>(address), &module)) {
            GetModuleFileNameA(module, name, MAX_PATH);
        }
        std::fprintf(stderr, "Visual exception frame: %s + 0x%llx\n", name,
            static_cast<unsigned long long>(reinterpret_cast<quintptr>(address) -
                                            reinterpret_cast<quintptr>(module)));
    };
    report(exception->ExceptionRecord->ExceptionAddress);
    void *frames[32] = {};
    const auto count = CaptureStackBackTrace(0, 32, frames, nullptr);
    for (USHORT index = 0; index < count; ++index) { report(frames[index]); }
    std::fflush(stderr);
    return EXCEPTION_CONTINUE_SEARCH;
}
struct VisualExceptionReport {
    PVOID handle = AddVectoredExceptionHandler(1, reportVisualException);
    ~VisualExceptionReport() { if (handle) { RemoveVectoredExceptionHandler(handle); } }
};
#endif
void settle(int milliseconds = 150) {
    QElapsedTimer wait;
    wait.start();
    while (wait.elapsed() < milliseconds) {
        QCoreApplication::processEvents();
        QThread::msleep(1);
    }
    // 手动 processEvents 不派发 DeferredDelete；与正常 Qt 主循环一样清理关闭的 Loader 项。
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
}
}

/**
 * 比较独立 QRhi 设备的离线渲染结果。
 * 尺寸与透明度必须完全一致，仅允许极少量像素出现一个 RGB8 单位的舍入差异。
 */
bool runGpuReferenceCheck(const QImage &expected, const QImage &actual) {
    if (expected.isNull() || expected.size() != actual.size()) {
        return false;
    }
    if (expected == actual) {
        return true;
    }
    const auto first = expected.convertToFormat(QImage::Format_RGBA8888);
    const auto second = actual.convertToFormat(QImage::Format_RGBA8888);
    const qint64 limit = qMax<qint64>(1, qint64(first.width()) * first.height() / 10000);
    qint64 changedPixels = 0;
    for (int y = 0; y < first.height(); ++y) {
        const auto before = first.constScanLine(y);
        const auto after = second.constScanLine(y);
        for (int x = 0; x < first.width(); ++x) {
            bool changed = false;
            for (int channel = 0; channel < 4; ++channel) {
                const int difference = std::abs(int(before[x * 4 + channel]) - int(after[x * 4 + channel]));
                if (difference > 1 || (channel == 3 && difference != 0)) {
                    return false;
                }
                changed |= difference != 0;
            }
            if (changed && ++changedPixels > limit) {
                return false;
            }
        }
    }
    return true;
}

int runUiChecks(Engine &backend, QQuickWindow *window, const QString &output, FrameProfiler &profiler) {
    if (!window || !backend.ready() || !backend.scene.review("archive")) {
        return 1;
    }

    auto &music = backend.app->music;
    auto &hud = backend.app->hud;
    auto &player = music.player;
    bool ok = true;
    int testCount = 0;

    const auto check = [&](bool value, const char *name) {
        testCount++;
        if (!value) {
            qCritical() << "UI test failed:" << name;
            ok = false;
        }
    };

    // === 测试 1: 基础应用状态 ===
    check(backend.ready(), "engine ready");
    check(window->isVisible(), "window visible");

    // === 测试 2: 场景模式切换 ===
    backend.scene.setMode("archive");
    backend.step(50);
    settle();
    check(backend.scene.review("archive"), "archive mode");

    backend.scene.setMode("detail");
    backend.step(50);
    settle();
    check(backend.scene.review("detail"), "detail mode");

    backend.scene.setMode("archive");
    backend.step(50);
    settle();

    // === 测试 3: HUD 面板切换 ===
    hud.openModal("settings");
    backend.step(50);
    settle();
    check(hud.modal == "settings", "open settings modal");
    hud.settingsScroll = 120;
    backend.action("quality:open"); backend.step(50); settle();
    check(hud.modal == "quality", "settings can open its audio quality child panel");
    backend.key("Escape", false); backend.step(50); settle();
    check(hud.modal == "settings" && hud.settingsScroll == 120, "Escape restores the settings panel and scroll position");

    hud.modal.clear();
    backend.step(50);
    settle();
    check(hud.modal.isEmpty(), "close modal");

    {
        const auto savedQueue = player.queue;
        const auto savedModal = hud.modal;
        const auto savedOffset = hud.queueOffset;
        QJsonArray hugeQueue;
        for (int i = 0; i < 4080; ++i) {
            hugeQueue.append(QJsonObject{
                {"id", QString::number(i + 1)},
                {"title", QStringLiteral("测试队列歌曲")},
                {"artist", QStringLiteral("测试歌手")},
            });
        }
        player.queue = hugeQueue;
        hud.queueOpen = true;
        hud.queueOffset = 0;
        const auto first = hud.state();
        check(first.value("queueCount").toInt() == 4080 &&
              first.value("queueRows").toArray().size() == 40,
              "4080-song queue exports only 40 lightweight visible rows");
        hud.queueOffset = 4040;
        const auto last = hud.state().value("queueRows").toArray();
        check(last.size() == 40 && last.first().toObject().value("index").toInt() == 4040,
              "large queue end-page indexing remains exact");
        hud.queueOpen = false;
        player.queue = savedQueue;
        hud.queueOffset = savedOffset;
        hud.modal = savedModal;
    }

    // === 测试 4: 音乐播放状态 ===
    if (!player.queue.isEmpty()) {
        const auto initialPlaying = player.state.value("playing").toBool();
        player.toggle();
        backend.step(50);
        settle();
        const auto toggledPlaying = player.state.value("playing").toBool();
        check(initialPlaying != toggledPlaying, "playback toggle");

        player.toggle();
        backend.step(50);
        settle();
        const auto restoredPlaying = player.state.value("playing").toBool();
        check(restoredPlaying == initialPlaying, "playback toggle restore");
    }

    // === 测试 5: 主题切换 ===
    const bool initialDark = hud.dark;
    hud.dark = !initialDark;
    backend.step(50);
    settle();
    check(hud.dark != initialDark, "theme toggle");

    hud.dark = initialDark;
    backend.step(50);
    settle();

    // === 测试 6: 搜索面板与输入 ===
    hud.openModal("search");
    backend.step(50);
    settle();
    check(hud.modal == "search", "open search modal");

    backend.query("测试关键词");
    backend.step(50);
    check(hud.query == "测试关键词", "search query input");

    backend.query(QString());
    hud.modal.clear();
    backend.step(50);

    // === 测试 7: 性能面板基础功能 ===
    const bool initialProfiling = backend.scene.isProfiling();
    profiler.toggleVisible();
    settle();
    const bool profilingAfterToggle = backend.scene.isProfiling();
    check(initialProfiling != profilingAfterToggle, "performance panel toggle");

    if (profilingAfterToggle) {
        profiler.toggleVisible();
        settle();
        check(!backend.scene.isProfiling(), "performance panel close");
    }

    // === 测试 8: 动画状态 ===
    const bool initialReduced = hud.reduced;
    hud.reduced = !initialReduced;
    backend.step(50);
    settle();
    check(hud.reduced != initialReduced, "motion toggle");

    hud.reduced = initialReduced;
    backend.step(50);

    // === 测试 9: 帧数据完整性 ===
    backend.step(50);
    settle();
    const auto frameData = backend.frame();
    check(!frameData.isEmpty(), "frame data available");
    check(frameData.contains("stats"), "frame stats present");

    // === 测试 10: 场景增强开关 ===
    const bool initialEnhancement = hud.sceneEnhancement;
    hud.sceneEnhancement = !initialEnhancement;
    backend.step(50);
    settle();
    check(hud.sceneEnhancement != initialEnhancement, "scene enhancement toggle");

    hud.sceneEnhancement = initialEnhancement;
    backend.step(50);

    // === 测试 11: 音乐数据加载 ===
    if (!music.tracks.isEmpty()) {
        check(music.tracks.first().toObject().contains("id"), "music track data structure");
        check(!music.provider.isEmpty(), "music provider set");
    }

    // === 测试 12: 全屏切换 ===
    const auto initialVisibility = window->visibility();
    backend.toggleFullscreen();
    settle();
    const auto fullscreenVisibility = window->visibility();
    check(fullscreenVisibility != initialVisibility, "fullscreen toggle");

    backend.toggleFullscreen();
    settle();
    check(window->visibility() == initialVisibility, "fullscreen restore");

    // 场景增强使用同一真实窗口继续验收，不重复创建应用实例。
    ok &= runSceneEnhancementChecks(backend, window, output.isEmpty() ? QString() : output + "/enhancement");

    qInfo() << "UI core functionality tests:" << testCount << (ok ? "passed" : "FAILED");
    return ok ? 0 : 1;
}

// 使用真正的 QML 场景验收毛玻璃；离线数据不会接触用户账号。
int runFrostedChecks(Engine &backend, QQuickWindow *window, const QString &output) {
#ifdef Q_OS_WIN
    VisualExceptionReport exceptionReport;
#endif
    if (!window || output.isEmpty()) {
        return 1;
    }
    // Optional test placement keeps every QA window on the requested monitor.
    // Normal application startup and tests without this option are unchanged.
    QScreen *qaScreen = nullptr;
    const auto qaScreenName = qEnvironmentVariable("RHINE_QA_SCREEN");
    if (!qaScreenName.isEmpty()) {
        for (auto *screen : QGuiApplication::screens()) {
            if (screen->name() == qaScreenName) { qaScreen = screen; break; }
        }
        if (!qaScreen) { qCritical() << "QA screen not found:" << qaScreenName; return 1; }
        window->setScreen(qaScreen);
        window->setPosition(qaScreen->geometry().topLeft() + QPoint(60, 60));
    }
    QElapsedTimer ready;
    ready.start();
    while (!backend.ready() && ready.elapsed() < 10000) {
        settle(50);
    }
    if (!backend.ready() || !backend.scene.review("archive")) {
        qCritical() << "Frosted UI: scene not ready";
        return 1;
    }
    auto &hud = backend.app->hud;
    auto &music = backend.app->music;
    const auto track = MusicData::item("song", "22693408", "宇宙船はどこへいった?", "Serani Poji");
    music.current = track;
    music.selectedLane = 1;
    music.lists[1] = QJsonArray{track};
    music.totals[1] = 1;
    hud.modal.clear();
    hud.closing = false;
    hud.lyricsMode = false;
    hud.trackListMode = false;
    hud.themeMode = "light";
    hud.dark = false;
    backend.scene.theme(false);
    hud.sceneEnhancement = true;
    window->resize(1280, 720);
    QDir().mkpath(output);
    const auto refresh = [&] {
        // 固定离线歌曲与当前场景的物理选中位置，避免首帧重新选择空栏目。
        music.selectedPhysical = backend.scene.selection();
        backend.step(90);
        settle(500);
    };
    bool ok = true;
    const auto check = [&](bool value, const char *label) {
        qInfo() << "Frosted UI checkpoint:" << label << value;
        if (!value) {
            qCritical() << "Frosted UI failed:" << label;
            ok = false;
        }
    };
    auto *loader = window->findChild<QQuickItem *>("textFrostedLoader");
    check(loader != nullptr, "loader exists");
    if (!loader) {
        return 1;
    }
    if (hud.textFrosted) {
        backend.action("text-frosted");
    }
    refresh();
    check(!loader->property("active").toBool(), "off disables background sampling");
    check(loader->property("item").value<QObject *>() == nullptr, "off releases effect item");
    const auto off = window->grabWindow();
    check(!off.isNull() && off.save(output + "/frosted-off.png"), "off screenshot");
    backend.action("text-frosted");
    refresh();
    check(music.current.value("title") == track.value("title"), "fixture song remains selected");
    check(loader->property("active").toBool(), "on activates background sampling");
    check(loader->property("item").value<QObject *>() != nullptr, "on creates effect item");
    check(window->findChild<QObject *>("textFrostedEffect") != nullptr, "real blur effect exists");
    auto *glassMaterial = window->findChild<QObject *>("liquidGlassMaterial");
    check(glassMaterial && glassMaterial->property("status").toInt() != 2, "liquid glass shader loads without errors");
    const auto on = window->grabWindow();
    check(!on.isNull() && on.save(output + "/frosted-on.png"), "on screenshot");
    on.scaled(800, 450, Qt::KeepAspectRatio, Qt::SmoothTransformation)
        .save(output + "/preview-on.png");
    if (!on.isNull() && !off.isNull() && on.size() == off.size()) {
        const auto region = QRect(int(on.width() * 0.52), int(on.height() * 0.43),
                                  int(on.width() * 0.42), int(on.height() * 0.28));
        qint64 difference = 0;
        for (int y = region.top(); y <= region.bottom(); y += 3) {
            for (int x = region.left(); x <= region.right(); x += 3) {
                const auto a = on.pixelColor(x, y);
                const auto b = off.pixelColor(x, y);
                difference += std::abs(a.red() - b.red()) + std::abs(a.green() - b.green()) +
                              std::abs(a.blue() - b.blue());
            }
        }
        check(difference > 10000, "glass visibly changes the reading area");
    }
    hud.trackListMode = true;
    refresh();
    check(loader->property("active").toBool(), "song list keeps glass enabled");
    check(backend.state().value("readingPanel").toMap().value("y").toInt() == 205,
          "song list expands reading area");
    hud.trackListMode = false;
    hud.sceneEnhancement = false;
    refresh();
    check(loader->property("active").toBool(), "works without scene enhancement");
    hud.dark = true;
    hud.themeMode = "dark";
    backend.scene.theme(true);
    refresh();
    check(loader->property("active").toBool(), "works in dark theme");
    hud.openModal("settings");
    refresh();
    {
        auto *material=loader->property("item").value<QObject*>();
        check(!loader->isVisible()&&material&&material->property("background").value<QObject*>()==nullptr,
              "settings retains its own surface");
    }
    hud.modal.clear();
    backend.scene.setMode("detail");
    refresh();
    {
        auto *material=loader->property("item").value<QObject*>();
        check(!loader->isVisible()&&material&&material->property("background").value<QObject*>()==nullptr,
              "detail retains its existing background");
    }
    // 接真实的原生控制器与 QML 滚动区，离线响应只替换网络边界。
    QJsonObject preview;
    QFile fixtureFile(output + "/comments-fixture.json");
    if (fixtureFile.open(QIODevice::ReadOnly)) {
        preview = QJsonDocument::fromJson(fixtureFile.readAll()).object();
    }
    const auto waitComments = [&] {
        QElapsedTimer elapsed;
        elapsed.start();
        while (hud.commentsLoading && elapsed.elapsed() < 10000) { settle(30); }
        refresh();
        check(!hud.commentsLoading, "comment response completes before checking results");
    };
    bool failNext = false;
    QStringList commentRequests;
    QImage artwork(128, 128, QImage::Format_RGB32);
    for (int y = 0; y < 128; ++y) {
        for (int x = 0; x < 128; ++x) {
            artwork.setPixelColor(x, y, QColor(110 + x / 3, 120 + y / 3, 92 + (x + y) / 5));
        }
    }
    artwork.save(output + "/artwork-fixture.png");
    const auto artworkURL = QUrl::fromLocalFile(output + "/artwork-fixture.png").toString();
    backend.host.fixture = [&](QString route, QJsonObject parameters) {
        if (route == "/artist/detail")return QJsonObject{{"body",QJsonObject{{"code",200},{"data",QJsonObject{{"artist",QJsonObject{{"avatar",artworkURL}}}}}}}};
        if (route.endsWith("/detail")) {
            auto item = parameters.value("args").toArray().first().toObject();
            item["date"] = "2026-09-15";
            item["description"] = QStringLiteral("十首歌，十次心动。\n无数个清晨、无数个深夜、无数个黄昏，记录一路走来的声音。\n").repeated(item["kind"] == "album" ? 80 : 8);
            item["trackCount"] = 10;
            if(item["kind"]=="album")item["artists"]=QJsonArray{QJsonObject{{"id","91001"},{"name","Actual test artist"}}};
            if(item["kind"]=="playlist")item["creatorAvatar"]=artworkURL;
            QJsonArray songs, ids;
            for (int i = 0; i < 10; ++i) {
                auto song = MusicData::item("song", QString::number(8000 + i), "专辑歌曲 " + QString::number(i + 1), "吴琳珂Moske");
                song["albumID"] = item["id"]; song["album"] = item["title"]; song["duration"] = 180000;
                song["cover"] = artworkURL;
                songs.append(song); ids.append(song["id"]);
            }
            if(item["kind"]=="album"&&item["id"]=="81001")ids={};
            return QJsonObject{{"body", QJsonObject{{"code", 200}, {"value", QJsonArray{item, songs, ids}}}}};
        }
        if (route.startsWith("/simi/")) {
            const bool lists = route.endsWith("playlist");
            QJsonArray rows;
            for (int i = 0; i < (lists ? 3 : 5); ++i) {
                rows.append(QJsonObject{{"id", 6000 + i}, {"name", lists ? QStringLiteral("煽情的扭曲爱与和平 · 日语独立音乐的漫长旅途") + QString::number(i) : QStringLiteral("相似歌曲与比较长的标题测试 ") + QString::number(i)},
                    {"artists", QJsonArray{QJsonObject{{"id", 7}, {"name", "betcover!!"}}}},
                    {"album", QJsonObject{{"id", 7}, {"name", "勇気"}}}, {"duration", 180000},
                    {"trackCount", 120}, {"creator", QJsonObject{{"nickname", "测试听众"}}}});
            }
            return QJsonObject{{"body", QJsonObject{{"code", 200}, {lists ? "playlists" : "songs", rows}}}};
        }
        if (!route.startsWith("/comment/")) { return QJsonObject{{"body", QJsonObject{{"code", 200}}}}; }
        commentRequests.append(route + ":" + QString::number(parameters.value("type").toInt()));
        if (failNext && route == "/comment/music") {
            failNext = false;
            return QJsonObject{{"body", QJsonObject{{"code", 503}, {"message", "测试重试"}}}};
        }
        const bool hot = route == "/comment/hot";
        const int offset = parameters.value("offset").toInt();
        const auto entries = preview.value(hot ? "hot" : "latest").toObject().value("rows").toArray();
        QJsonArray batch;
        for (int i = offset; i < offset + (hot ? 5 : 4) && i < 8; ++i) {
            const auto item = entries.isEmpty() ? QJsonObject{} : entries.at(i % entries.size()).toObject();
            batch.append(QJsonObject{{"commentId", i + (hot ? 900 : 100)},
                {"user", QJsonObject{{"userId", 42}, {"avatarUrl", artworkURL}, {"nickname", item.value("author").toString("离线测试听众")}}},
                {"content", parameters.value("id") == "2085028155" ? item.value("content").toString("这是用于验证评论换行和分页的离线测试文字。") : "歌曲 " + parameters.value("id").toString()},
                {"time", item.value("time").toDouble(1700000000000.)}, {"likedCount", item.value("likes").toDouble(12)}});
        }
        return QJsonObject{{"body", QJsonObject{{"code", 200}, {hot ? "hotComments" : "comments", batch},
            {"total", 8}, {"more", offset < 4}, {"hasMore", false}}}};
    };
    auto song = MusicData::item("song", "2085028155", "Sure Enough", "Two Door Cinema Club");
    song["artists"] = QJsonArray{QJsonObject{{"id", "120831"}, {"name", "Two Door Cinema Club"}}};
    song["album"] = "Sure Enough";
    song["duration"] = 171000;
    music.current = song;
    hud.themeMode = "light";
    hud.dark = false;
    hud.sceneEnhancement = true;
    backend.scene.theme(false);
    backend.scene.review("detail");
    backend.action("tab:comments");
    refresh();
    waitComments();
    check(hud.commentsRows.size() == 4 && hud.commentsFeatured.size() == 5, "five featured plus four recent comments");
    auto *commentsLoader = window->findChild<QQuickItem *>("commentsLoader");
    check(commentsLoader && commentsLoader->property("active").toBool(), "inline comments loader");
    auto *reading = window->findChild<QQuickItem *>("commentsReading");
    check(reading && reading->width() < window->width() * 0.5, "comments stay inside the detail card");
    auto *commentPage = commentsLoader ? commentsLoader->property("item").value<QObject *>() : nullptr;
    // Repeater 的委托由模型持有，沿实际可视树查找，不能假定它们属于页面的 QObject 子树。
    const std::function<QQuickItem *(QQuickItem *, const QString &)> findVisual =
        [&](QQuickItem *item, const QString &name) -> QQuickItem * {
            if (!item) { return nullptr; }
            if (item->objectName() == name) { return item; }
            for (auto *child : item->childItems()) {
                if (auto *found = findVisual(child, name)) { return found; }
            }
            return nullptr;
        };
    auto *author = findVisual(qobject_cast<QQuickItem *>(commentPage), "commentAuthor");
    auto *date = findVisual(qobject_cast<QQuickItem *>(commentPage), "commentDate");
    check(author && date && date->x() >= author->x() + author->width() && date->x() - author->x() - author->width() < 25,
          "comment date follows the author instead of the far edge");
    auto *avatar = findVisual(qobject_cast<QQuickItem *>(commentPage), "commentAvatarImage");
    QElapsedTimer avatarWait; avatarWait.start();
    while (avatar && avatar->property("status").toInt() == 2 && avatarWait.elapsed() < 5000) { settle(20); }
    check(avatar && avatar->property("status").toInt() == 1 &&
          hud.commentsFeatured.first().toObject()["avatar"].toString() == artworkURL,
          "comment author avatar is preserved and actually loads in QML");
    const auto commentsImage = window->grabWindow();
    check(!commentsImage.isNull() && commentsImage.save(output + "/comments-on.png"), "comments screenshot");
    commentsImage.scaled(1000, 650, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-comments.png");
    if (reading) {
        const auto local = reading->mapToScene(QPointF(reading->width() / 2, reading->height() / 2));
        QWheelEvent wheel(local, window->mapToGlobal(local.toPoint()), QPoint(), QPoint(0, -120),
                          Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(window, &wheel);
        settle(400);
        check(reading->property("contentY").toDouble() > 0, "mouse wheel scrolls comments without a scrollbar");
    }
    failNext = true;
    backend.action("comments:more");
    waitComments();
    check(hud.commentsRows.size() == 4 && !hud.commentsError.isEmpty(), "failed page preserves existing rows");
    backend.action("comments:retry");
    waitComments();
    check(hud.commentsRows.size() == 8 && hud.commentsError.isEmpty() && !hud.commentsMore, "retry appends next page and respects end");
    if (reading) { check(reading->property("contentY").toDouble() > 0, "appending preserves scroll position"); }
    backend.action("tab:overview");
    refresh();
    check(!hud.commentsOpen && commentsLoader && !commentsLoader->property("active").toBool(), "other tabs release comments UI");
    // 发起请求后立即切歌，旧响应必须丢弃。
    music.current = MusicData::item("song", "123456", "旧请求", "测试歌手");
    backend.action("tab:comments");
    music.selectedPhysical = backend.scene.selection();
    backend.step(90);
    auto nextSong = MusicData::item("song", "186016", "下一首", "测试歌手");
    music.current = nextSong;
    music.selectedPhysical = backend.scene.selection();
    backend.step(90);
    waitComments();
    check(hud.commentsSong.value("id") == "186016", "comments follow the inspected song");
    check(!hud.commentsRows.isEmpty() && hud.commentsRows.first().toObject().value("content") == "歌曲 186016", "new song comments reject stale data");
    backend.action("back");
    refresh();
    check(!hud.commentsOpen, "returning to archive closes comments");
    // 简介、歌曲正文和专辑页沿用真实窗口，验证滚轮、留白及返回路径。
    hud.reduced = true;
    backend.scene.reduced(true);
    const auto scrollText = [&] {
        // Loader 关闭的旧项可能仍在等待 DeferredDelete；只检查当前加载的可见实例。
        auto *loader = window->findChild<QQuickItem *>("readerLoader");
        auto *reader = loader ? qobject_cast<QQuickItem *>(loader->property("item").value<QObject *>()) : nullptr;
        check(reader != nullptr, "text reading overlay exists");
        if (!reader) { return; }
        if (reader->property("contentHeight").toDouble() <= reader->height()) {
            qWarning() << "Reader dimensions" << reader->width() << reader->height()
                       << reader->property("contentHeight") << backend.state().value("readerText").toString().size();
        }
        check(reader->property("contentHeight").toDouble() > reader->height(), "full long text remains available below the viewport");
        const auto local = reader->mapToScene(QPointF(reader->width() / 2, reader->height() / 2));
        const auto global = window->mapToGlobal(local.toPoint());
        // 实际打开专辑时鼠标先经过专辑行，再回到简介；不能把上个页面同坐标的滚轮目标当作当前项。
        const QPointF outside(window->width() - 100, 100);
        QMouseEvent leave(QEvent::MouseMove, outside, window->mapToGlobal(outside.toPoint()),
                          Qt::NoButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(window, &leave);
        settle(50);
        QMouseEvent move(QEvent::MouseMove, local, global, Qt::NoButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(window, &move);
        settle(100);
        qInfo() << "Reader wheel" << backend.state().value("readerSession") << local
                << reader->property("contentY") << reader->property("contentHeight") << reader->height();
        const auto previousWheelEvents = reader->property("wheelEvents").toInt();
        QWheelEvent wheel(local, window->mapToGlobal(local.toPoint()), QPoint(), QPoint(0, -120),
                          Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(window, &wheel);
        settle(400);
        qInfo() << "Reader wheel result" << backend.state().value("readerSession") << reader->property("contentY")
                << "events" << reader->property("wheelEvents") << "receivedY" << reader->property("lastWheelY");
        check(reader->property("wheelEvents").toInt() > previousWheelEvents, "current text reader receives the wheel event");
        check(reader->property("contentY").toDouble() > 0, "text reader scrolls with mouse wheel");
    };
    song["albumID"] = "186016";
    song["description"] = QStringLiteral("十首歌，十次心动。无数个清晨、无数个深夜、无数个黄昏。\n").repeated(30);
    song["date"] = "2026-09-15";
    music.current = song;
    music.albumLoaded = true;
    backend.scene.review("detail");
    song["wiki"] = song["description"];
    music.current = song;
    hud.tab = "overview";
    refresh();
    check(hud.readerBounds && hud.readerBounds->height() >= 180 && hud.readerBounds->bottom() == 880,
          "song information uses more lines while preserving footer space");
    auto *discGlass = window->findChild<QQuickItem *>("discGlassLoader");
    check(discGlass && discGlass->property("active").toBool() && discGlass->property("item").value<QObject *>(),
          "song details show the glass backing behind the lower-left metadata");
    window->grabWindow().save(output + "/song-info-on.png");
    scrollText();
    music.tracks = {};
    for (int i = 0; i < 10; ++i) { music.tracks.append(song); }
    hud.tab = "history";
    refresh();
    check(hud.detailRows >= 3 && hud.detailRows <= 5, "same album shows a balanced number of rows");
    if (hud.detailRowsBounds) {
        hud.wheel(hud.detailRowsBounds->center().x(), hud.detailRowsBounds->center().y(), -120, 1);
        check(hud.trackOffset == 1, "same album can scroll beyond the first rows");
    }
    window->grabWindow().save(output + "/same-album-on.png");
    auto artist = MusicData::item("artist", "29051651", "吴琳珂Moske");
    artist["description"] = QStringLiteral("用音乐记录生活，在一次次创作里留下沿途的故事。\n").repeated(30);
    auto parent = std::make_shared<MusicDirectory>();
    parent->item = artist;
    parent->songs = music.tracks;
    for (int i = 0; i < 12; ++i) {
        auto album = MusicData::item("album", i == 3 ? "186016" : QString::number(9000 + i),
            i == 3 ? "吴琳珂" : "专辑 " + QString::number(i + 1), "吴琳珂Moske");
        album["date"] = "2026-09-15";
        parent->albums.append(album);
    }
    music.directory = parent;
    music.directoryInfo = true;
    music.current = artist;
    hud.artistTab = "albums";
    hud.trackOffset = 3;
    refresh();
    window->grabWindow().save(output + "/artist-albums-on.png");
    scrollText();
    const auto playbackBefore = music.player.current;
    parent->albumsLoading = true;
    backend.action("music:artist-album:3");
    QElapsedTimer folderWait;
    folderWait.start();
    while (music.directoryLoading && folderWait.elapsed() < 10000) { settle(30); }
    refresh();
    check(!music.directoryLoading && music.directoryInfo && music.current["kind"] == "album",
          "album opens directly as a detail page instead of selecting its first song");
    check(music.player.current == playbackBefore, "browsing an album does not change playback");
    check(findVisual(window->contentItem(),"playlistMagazinePage")&&findVisual(window->contentItem(),"magazineHeat_0"),
          "G90 ordinary artist-album route renders the shared magazine and heat column");
    {
        QElapsedTimer avatarWait;avatarWait.start();
        while(avatarWait.elapsed()<2000){auto *avatar=findVisual(window->contentItem(),"magazineArtistAvatar");if(avatar&&avatar->property("status").toInt()==1&&avatar->property("source").toUrl().toString().startsWith("data:image/png;base64,"))break;settle(30);}
        auto *avatar=findVisual(window->contentItem(),"magazineArtistAvatar");
        check(avatar&&avatar->isVisible()&&avatar->property("status").toInt()==1&&avatar->property("source").toUrl().toString().startsWith("data:image/png;base64,"),"G91 album artist portrait loads through actual API, Host cache and QML decoding");
    }
    check(music.directory && music.directory->songs.size() == 10, "album track list loads fully");
    const auto albumImage = window->grabWindow();
    albumImage.save(output + "/album-on.png");
    albumImage.scaled(1000, 650, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-album-page.png");
    {
        const auto clickAlbumControl=[&](QQuickItem *item){
            if(!item||!item->isVisible())return false;
            const auto point=item->mapToScene(QPointF(item->width()/2,item->height()/2));
            QMouseEvent move(QEvent::MouseMove,point,window->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&move);
            for(const auto type:{QEvent::MouseButtonPress,QEvent::MouseButtonRelease}){
                QMouseEvent event(type,point,window->mapToGlobal(point.toPoint()),Qt::LeftButton,type==QEvent::MouseButtonPress?Qt::LeftButton:Qt::NoButton,Qt::NoModifier);
                QCoreApplication::sendEvent(window,&event);
            }
            settle(230);return true;
        };
        check(clickAlbumControl(findVisual(window->contentItem(),"playlistDescriptionOpen")),"G90 album description opens through its real magazine entry");
        auto *reader=findVisual(window->contentItem(),"playlistDescriptionReader");
        auto *text=findVisual(window->contentItem(),"playlistDescriptionText");
        check(reader&&reader->isVisible()&&text&&text->property("text").toString()==music.current.value("description").toString(),"G90 album popup displays the actual complete description");
        if(reader){
            check(reader->property("contentHeight").toDouble()>reader->height(),"G90 long album description retains overflow content");
            const auto point=reader->mapToScene(QPointF(reader->width()/2,reader->height()/2));
            const auto before=reader->property("contentY").toDouble();
            QMouseEvent move(QEvent::MouseMove,point,window->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&move);settle(80);
            QWheelEvent wheel(point,window->mapToGlobal(point.toPoint()),QPoint(),QPoint(0,-120),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);
            QCoreApplication::sendEvent(window,&wheel);settle(230);
            check(reader->property("contentY").toDouble()>before,"G90 album description scrolls with the actual mouse wheel");
        }
        check(clickAlbumControl(findVisual(window->contentItem(),"playlistDescriptionClose")),"G90 album description closes before reading comments");
        check(!reader||!reader->isVisible(),"G90 album description releases the comment interaction area");
    }
    backend.action("tab:comments");
    refresh();
    waitComments();
    check(hud.commentsSong["kind"] == "album" && hud.commentsRows.size() == 4 && hud.commentsFeatured.size() == 5,
          "album comments are isolated from song comments with the same numeric ID");
    check(commentRequests.contains("/comment/album:0") && commentRequests.contains("/comment/hot:1"),
          "album comments use album resource endpoints");
    const auto albumCommentsImage = window->grabWindow();
    albumCommentsImage.save(output + "/album-comments-on.png");
    albumCommentsImage.scaled(1000, 650, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-album.png");
    qInfo() << "G66 lifecycle: leaving album comments";
    backend.action("tab:overview"); refresh();
    qInfo() << "G66 lifecycle: album comments released";
    backend.action("music:track:5"); refresh();
    qInfo() << "G66 lifecycle: album track navigation completed";
    check(music.current["kind"] == "song", "album track opens its song detail");
    backend.action("back"); refresh();
    check(music.directoryInfo && music.current["kind"] == "album", "song detail returns to its album");
    backend.action("back"); refresh();
    check(music.directory == parent && music.directoryInfo && hud.artistTab == "albums" && hud.trackOffset == 3 && !parent->albumsLoading,
          "album returns to the artist album list at its previous position");
    // 歌单详情入口位于歌单选择页，返回与旧的直接选歌路径各自保留。
    music.directory.reset(); music.directoryInfo = false;
    auto playlistChoice = MusicData::item("playlist", "6001", "日语独立音乐 · 沿途的声音", "测试听众");
    music.choose(playlistChoice, false, false); backend.scene.review("archive"); refresh();
    const auto selectionPhysical = music.selectedPhysical >= 0 ? music.selectedPhysical :
        music.frame.value("selected").toInt(music.physicalSlots[music.selectedLane].value(0, -1));
    const auto selectionLane = music.selectedLane;
    const auto hasHudAction = [&](const QString &action) {
        for (const auto &value : hud.hits) { if (value.toObject().value("action") == action) { return true; } }
        return false;
    };
    check(findVisual(window->contentItem(),"showcasePlay") && findVisual(window->contentItem(),"showcaseMore"),
          "playlist selection offers the existing library action and a separate detail entry");
    window->grabWindow().scaled(1280, 900, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-playlist-entry.png");
    {
        music.archiveNowPlaying=false;music.changed();refresh();
        auto *showcase=qobject_cast<PlaylistShowcase*>(backend.showcase());
        QElapsedTimer showcaseWait;showcaseWait.start();
        while(showcase&&showcase->busy()&&showcaseWait.elapsed()<5000)settle(20);
        check(showcase&&showcase->info()["kind"].toString()=="playlist"&&showcase->songs().size()==10,"G79 archive showcase reads real playlist metadata and complete song IDs without entering its directory");
        auto *archivePage=findVisual(window->contentItem(),"playlistShowcase");
        auto *archiveStack=findVisual(window->contentItem(),"showcaseRecordStack");
        check(archivePage&&archiveStack&&archiveStack->x()>archivePage->width()*.6,"G79 archive cover stack is on the right of the information panel");
        const auto archivePosition=archivePage?archivePage->mapToScene(QPointF(0,0)):QPointF();
        qInfo()<<"G80 archive window bounds"<<archivePosition<<(archivePage?archivePage->size():QSizeF())<<"window"<<window->size();
        check(archivePage&&archivePosition.x()>window->width()*.45&&archivePage->width()<window->width()*.55&&archivePosition.y()>window->height()*.36&&archivePage->height()<window->height()*.42,"G80 archive panel stays in the original right reading region and leaves room above for future modules");
        auto *reading=findVisual(window->contentItem(),"archiveReading");
        QPointer<QObject> originalMaterial=findVisual(window->contentItem(),"textFrostedPanel");
        const auto savedArchiveSelection=music.current;
        const auto savedArchiveDirectory=music.directory;
        const QJsonValue savedArchiveMode=music.frame["mode"];
        music.player.trackSelected(MusicData::item("song","85101","Playback should not navigate","Fixture"));
        refresh();
        check(music.current==savedArchiveSelection&&music.directory==savedArchiveDirectory&&music.frame["mode"]==savedArchiveMode&&!findVisual(window->contentItem(),"nowPlayingPanel")&&findVisual(window->contentItem(),"textFrostedPanel")==originalMaterial.data(),"G87 transport retains archive browsing selection and does not enter now-playing");
        check(findVisual(window->contentItem(),"archiveNavigator")&&findVisual(window->contentItem(),"archiveColumnPrevious")&&findVisual(window->contentItem(),"archiveColumnNext")&&!findVisual(window->contentItem(),"archiveBrowseNext"),"G85 archive has one compact column controller without the separate next-item arrow");
        if(showcase){
            showcase->playSong(0);refresh();
            check(music.archiveNowPlaying&&findVisual(window->contentItem(),"nowPlayingPanel"),"G87 explicit home track selection enters actual shared now-playing content");
            music.enterDirectory(savedArchiveSelection);refresh();
            QElapsedTimer directoryPlayWait;directoryPlayWait.start();
            while(music.directoryLoading&&directoryPlayWait.elapsed()<5000)settle(20);
            music.playDirectory();refresh();
            check(music.directory&&!findVisual(window->contentItem(),"nowPlayingPanel"),"G87 opening a playlist keeps its list above pending now-playing content");
            music.leaveDirectory();refresh();
            check(!music.directory&&music.frame["mode"]=="archive"&&findVisual(window->contentItem(),"nowPlayingPanel"),"G87 leaving a played playlist returns home to actual rotating-record content");
        }
        music.archiveNowPlaying=false;music.changed();refresh();
        const auto savedTrackMode=hud.trackListMode;hud.trackListMode=false;
        for(const QString &kind:QStringList{"song","album","empty","playlist"}){
            music.current=kind=="playlist"?savedArchiveSelection:kind=="empty"?QJsonObject{}:MusicData::item(kind,"81001","Shared glass identity test","Fixture");
            music.changed();refresh();
            if(kind=="album")check(showcase&&showcase->songs().size()==10&&!showcase->info().contains("durationLabel"),"G90 album songs provide real archive rows without restoring removed total duration");
            if(kind=="playlist"){
                QElapsedTimer avatarWait;avatarWait.start();
                while(showcase&&showcase->info()["identityAvatar"].toString().isEmpty()&&avatarWait.elapsed()<3000)settle(20);
                const auto avatar=showcase?showcase->info()["identityAvatar"].toString():QString();
                check(avatar.startsWith("data:image/png;base64,")&&!QImage::fromData(QByteArray::fromBase64(avatar.section(',',1).toLatin1())).isNull(),"G84 archive creator avatar passes real native download and pixel decode");
            }
            check(reading&&findVisual(window->contentItem(),"archiveReading")==reading&&originalMaterial&&findVisual(window->contentItem(),"textFrostedPanel")==originalMaterial.data(),"G81 songs, albums, empty sources and playlists retain the same reading unit and original glass object");
        }
        hud.trackListMode=savedTrackMode;
        if(showcase){showcase->operate("copy");check(QGuiApplication::clipboard()->text().contains("6001"),"G79 showcase more/share action copies the selected playlist's real link");}
    }
    const auto playlistPlayback = music.player.current;
    backend.action("music:playlist-info");
    folderWait.restart();
    while (music.directoryLoading && folderWait.elapsed() < 10000) { settle(30); }
    refresh();
    check(music.directory && music.directoryInfo && music.current.value("kind") == "playlist" &&
          music.directory->songs.size() == 10 && findVisual(window->contentItem(),"globalBack") && findVisual(window->contentItem(),"globalBack")->isVisible(),
          "new entry opens the loaded playlist detail with a return-to-selection action");
    check(music.player.current == playlistPlayback, "opening playlist details keeps playback unchanged");
    settle(150); refresh();
    auto *magazinePage = findVisual(window->contentItem(),"playlistMagazinePage");
    auto *magazineRow = findVisual(window->contentItem(),"magazineRow_0");
    check(magazinePage && magazineRow && backend.magazine()->property("active").toBool(), "playlist virtual table renders actual track artwork delegates");
    // G69: actual shared menu, captured target, record navigation and queue overlay.
    {
        auto *model=qobject_cast<PlaylistMagazine*>(backend.magazine());
        check(model && model->rowCount()==10, "G69 playlist controller exposes real directory rows");
        const auto originalDirectory=music.directory;
        const auto originalItem=music.current;
        const auto originalPlay=music.player.current;
        const auto originalQueue=music.player.queue;
        const auto originalIndex=music.player.index;
        check(findVisual(window->contentItem(),"globalSearch") && findVisual(window->contentItem(),"globalProfile") && findVisual(window->contentItem(),"globalSettings"),
            "G71 shared account bar exposes profile, search and settings");
        if(model && !originalDirectory->songs.isEmpty()){
            const auto clickVisual=[&](QQuickItem *item){
                if(!item||!item->isVisible())return false;
                const auto point=item->mapToScene(QPointF(item->width()/2,item->height()/2));
                QMouseEvent move(QEvent::MouseMove,point,window->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&move);
                for(const auto type:{QEvent::MouseButtonPress,QEvent::MouseButtonRelease}){
                    QMouseEvent event(type,point,window->mapToGlobal(point.toPoint()),Qt::LeftButton,type==QEvent::MouseButtonPress?Qt::LeftButton:Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&event);
                }settle(230);return true;
            };
            const auto inputKey=[&](int key,Qt::KeyboardModifiers modifiers=Qt::NoModifier,QString text={}){
                QKeyEvent press(QEvent::KeyPress,key,modifiers,text),release(QEvent::KeyRelease,key,modifiers,text);
                QCoreApplication::sendEvent(window,&press);QCoreApplication::sendEvent(window,&release);settle(40);refresh();
            };
            // G77 uses the real Engine/Host/controller/QML chain with explicit offline replies.
            {
                const auto previousFixture=backend.host.fixture;const auto previousUID=music.uid;
                music.uid="42";music.changed();
                int writes=0;
                backend.host.fixture=[previousFixture,&writes,artworkURL](QString route,QJsonObject values){
                    const QJsonObject user{{"userId","7"},{"nickname","消息测试听众"},{"avatarUrl",artworkURL},{"authStatus",1}};
                    QJsonObject body{{"code",200}};
                    if(route=="/pl/count")body={{"code",200},{"msg",505},{"comment",2},{"forward",1},{"notice",0}};
                    else if(route=="/msg/private")body["msgs"]=QJsonArray{QJsonObject{{"fromUser",user},{"lastMsg","{\"msg\":\"测试私信摘要\"}"},{"lastMsgTime",1700000000000.},{"newMsgCount",63}}};
                    else if(route=="/msg/private/history")body["msgs"]=QJsonArray{QJsonObject{{"id","1"},{"fromUser",user},{"msg","{\"msg\":\"真实传输链的离线会话\"}"},{"time",1700000000000.}}};
                    else if(route=="/send/text"){++writes;if(values["user_ids"]!="7"||values["msg"]!="G77 offline send")body["code"]=400;}
                    else if(route=="/msg/comments")body["comments"]=QJsonArray{QJsonObject{{"id","2"},{"user",user},{"content","测试评论"},{"updateTime",1700000000000.}}};
                    else if(route=="/msg/forwards")body["forwards"]=QJsonArray{QJsonObject{{"id","3"},{"user",user},{"json","{\"msg\":\"测试提及\"}"},{"time",1700000000000.}}};
                    else if(route=="/msg/notices")body["notices"]=QJsonArray{QJsonObject{{"id","4"},{"notice","{\"content\":\"测试通知\"}"},{"time",1700000000000.}}};
                    else return previousFixture(route,values);
                    return QJsonObject{{"body",body}};
                };
                auto *messages=qobject_cast<MessageCenter*>(backend.messages());
                check(messages&&clickVisual(findVisual(window->contentItem(),"globalInbox")),"G77 existing inbox opens the real message drawer");
                QElapsedTimer messageWait;messageWait.start();
                while(messages&&messageWait.elapsed()<5000&&(!messages->state()["open"].toBool()||messages->state()["loading"].toBool()||messages->rowCount()!=1||messages->state()["counts"].toList().value(0).toInt()!=505))settle(20);
                if(messages)qInfo()<<"G77 first-open diagnostics: open"<<messages->state()["open"].toBool()<<"loading"<<messages->state()["loading"].toBool()<<"rows"<<messages->rowCount()<<"unread"<<messages->state()["counts"].toList().value(0).toInt()<<"waitMs"<<messageWait.elapsed();
                check(messages&&messages->state()["open"].toBool()&&messages->rowCount()==1&&messages->state()["counts"].toList().value(0).toInt()==505,"G77 drawer loads real Host fixture messages and unread counts");
                if(messages){
                    for(int t=1;t<4;++t){messages->selectTab(t);settle(80);check(messages->rowCount()==1&&messages->state()["tab"].toInt()==t,"G77 all four message tabs load their own endpoint");}
                    messages->selectTab(0);settle(60);messages->activate(0);settle(100);
                    check(messages->history().size()==1&&findVisual(window->contentItem(),"messageComposer"),"G77 conversation and history render through the production drawer");
                    // G78 compares the actual popup surface with the queue's canonical bounds.
                    const auto drawerRect=hud.queueBounds(hud.width);
                    const double drawerScale=window->height()/1080.;
                    auto *drawerTint=findVisual(window->contentItem(),"drawerFrostTint");
                    const auto drawerPoint=drawerTint?drawerTint->mapToScene(QPointF{}):QPointF{};
                    check(drawerTint&&std::abs(drawerPoint.x()-drawerRect.x()*drawerScale)<2&&std::abs(drawerPoint.y()-drawerRect.y()*drawerScale)<2&&std::abs(drawerTint->width()-drawerRect.width()*drawerScale)<2&&std::abs(drawerTint->height()-drawerRect.height()*drawerScale)<2,"G78 messages use the exact queue frame after conversation navigation");
                    auto *blockedSearch=findVisual(window->contentItem(),"globalSearch");
                    check(blockedSearch&&!blockedSearch->isEnabled()&&findVisual(window->contentItem(),"messageClose")->isEnabled(),"G78 background input is disabled while conversation controls remain enabled");
                    window->grabWindow().save(output+"/preview-message-conversation.png");
                    messages->setDraft("G77 offline send");messages->send();messages->send();settle(120);
                    check(writes==1&&messages->draft().isEmpty(),"G77 text send is confirmed by Host and duplicate submits are suppressed");
                    messages->leaveConversation();messages->allRead();settle(50);
                    check(messages->state()["counts"].toList().value(0).toInt()==505&&!messages->state()["allReadSupported"].toBool(),"G77 unsupported batch-read preserves server unread counts");
                    window->grabWindow().save(output+"/preview-message-center.png");
                    check(clickVisual(findVisual(window->contentItem(),"messageClose")),"G77 close button dismisses only the message overlay");settle(230);
                    check(!messages->state()["open"].toBool()&&music.directory==originalDirectory&&music.current==originalItem&&music.player.queue==originalQueue&&music.player.current==originalPlay,"G77 opening and closing messages retains underlying playlist and playback");
                }
                if(messages){
                    const auto priorModal=hud.modal;
                    clickVisual(findVisual(window->contentItem(),"globalInbox"));settle(300);
                    clickVisual(findVisual(window->contentItem(),"globalSearch"));settle(230);
                    check(!messages->state()["open"].toBool()&&hud.modal==priorModal&&music.directory==originalDirectory,"G78 outside click closes messages without triggering the search underneath");
                }
                backend.host.fixture=previousFixture;music.uid=previousUID;music.changed();refresh();
            }
            clickVisual(findVisual(window->contentItem(),"playlistSearch"));
            QPointer<QQuickItem> editor=findVisual(window->contentItem(),"playlistSearchInput");
            inputKey(Qt::Key_A,Qt::NoModifier,"a");inputKey(Qt::Key_B,Qt::NoModifier,"b");inputKey(Qt::Key_Backspace);
            check(editor&&editor->hasActiveFocus()&&editor==findVisual(window->contentItem(),"playlistSearchInput")&&editor->property("text")=="a"&&model->query()=="a",
                "G70 typing and deleting retain the same focused search editor across real model resets");
            inputKey(Qt::Key_A,Qt::ControlModifier);QGuiApplication::clipboard()->setText("G70-no-match");inputKey(Qt::Key_V,Qt::ControlModifier);
            check(model->rowCount()==0&&editor&&editor->hasActiveFocus(),"G70 paste updates results immediately and zero results cannot lock the editor");
            auto *searchItem=findVisual(window->contentItem(),"playlistSearch");
            if(searchItem)QMetaObject::invokeMethod(searchItem,"dismiss");refresh();
            check(searchItem&&!searchItem->property("expanded").toBool()&&model->query()=="G70-no-match","G71 collapsed search retains its query and filtering state");
            clickVisual(searchItem);
            clickVisual(findVisual(window->contentItem(),"playlistSearchClear"));
            check(model->query().isEmpty()&&model->rowCount()==originalDirectory->songs.size()&&editor&&editor->hasActiveFocus(),"G70 clear restores the complete playlist while keeping input available");
            const auto clicked=originalDirectory->songs.first().toObject();
            auto *row=findVisual(window->contentItem(),"magazineRow_0");
            if(row){const auto point=row->mapToScene(QPointF(row->width()*.37,row->height()/2));
                for(const auto type:{QEvent::MouseButtonPress,QEvent::MouseButtonRelease}){
                    QMouseEvent mouse(type,point,window->mapToGlobal(point.toPoint()),Qt::RightButton,type==QEvent::MouseButtonPress?Qt::RightButton:Qt::NoButton,Qt::NoModifier);
                    QCoreApplication::sendEvent(window,&mouse);
                }
                refresh();
            }
            check(model->songMenu().value("visible").toBool() && music.player.current==originalPlay,"G69 real right-click opens shared song menu without starting playback");
            model->songAction("copy");
            check(QGuiApplication::clipboard()->text()==music.sourceURL(clicked),"G69 context copy uses the clicked song ID");
            model->showSongMenu("directory",0,MusicPlayer::identity(clicked),20,20);model->songAction("next");
            check(music.player.current==originalPlay && MusicData::indexOfId(music.player.queue,clicked["id"].toString())>=0,"G69 next-play context action queues the captured song");
            check(clickVisual(findVisual(window->contentItem(),"playlistDescriptionOpen"))&&findVisual(window->contentItem(),"playlistDescriptionClose"),"G71 long description opens a bounded readable popup");
            clickVisual(findVisual(window->contentItem(),"playlistDescriptionClose"));
            const auto accountUid=music.uid,accountName=music.nickname;const auto accountDetails=music.accountDetails;
            music.uid="42";music.nickname="Offline account fixture";music.accountDetails={{"avatar",artworkURL},{"vipType",11}};refresh();
            clickVisual(findVisual(window->contentItem(),"globalProfile"));
            check(hud.modal=="profile"&&hud.profileID=="42","G71 avatar opens the actual account profile independently of the arrow");backend.action("back");refresh();
            clickVisual(findVisual(window->contentItem(),"globalAccountArrow"));
            check(clickVisual(findVisual(window->contentItem(),"accountMenuPlaylists"))&&hud.modal=="profile"&&hud.profileFilter=="created","G71 account menu opens the existing created-playlist profile view");backend.action("back");refresh();
            music.uid=accountUid;music.nickname=accountName;music.accountDetails=accountDetails;refresh();
            const auto likedBefore=music.likedIDs;const auto shelfBefore=music.lists[1];const auto totalBefore=music.totals[1];
            const auto likeFixture=backend.host.fixture;const auto likeUid=music.uid;music.uid="42";bool rejectLike=true;QString likeID;
            backend.host.fixture=[likeFixture,&rejectLike,&likeID](QString route,QJsonObject args){if(route=="/like"){likeID=args["id"].toString();return QJsonObject{{"body",QJsonObject{{"code",rejectLike?500:200}}}};}return likeFixture(route,args);};
            music.likedIDs=QJsonArray{};music.lists[1]={};model->sync();refresh();
            clickVisual(findVisual(window->contentItem(),"magazineHeart_0"));
            check(likeID==clicked["id"].toString()&&music.likedIDs->isEmpty(),"G70 failed heart action targets the clicked row and keeps its confirmed state");
            rejectLike=false;clickVisual(findVisual(window->contentItem(),"magazineHeart_0"));
            check(MusicData::indexOf(*music.likedIDs,clicked["id"])>=0&&model->data(model->index(0),PlaylistMagazine::Heart).toBool(),"G70 successful heart click updates real liked IDs and the rendered model");
            clickVisual(findVisual(window->contentItem(),"magazineHeart_0"));
            check(music.likedIDs->isEmpty()&&!model->data(model->index(0),PlaylistMagazine::Heart).toBool(),"G70 second heart click confirms unlike and clears the row state");
            backend.host.fixture=likeFixture;music.uid=likeUid;music.likedIDs=likedBefore;music.lists[1]=shelfBefore;music.totals[1]=totalBefore;model->sync();
            model->rowAction("play",MusicPlayer::identity(clicked));refresh();
            check(music.directory==originalDirectory && music.directoryInfo && music.current==originalItem && music.player.current["id"]==clicked["id"],
                "G69 cover playback plays the song without navigating away from the playlist");
            music.player.queue=originalQueue;music.player.current=originalPlay;music.player.index=originalIndex;
            model->savePosition(model->session(),75);refresh();
            auto *page=findVisual(window->contentItem(),"playlistMagazinePage");
            backend.action("player:open");refresh();
            check(page && findVisual(window->contentItem(),"playlistMagazinePage")==page && model->scrollPosition()==75 && music.current==originalItem,
                "G69 queue retains the magazine instance, scroll and browsed playlist");
            backend.action("queue-close");refresh();
            const auto previousFixture=backend.host.fixture;
            const auto previousCollections=music.lists[2];
            auto next=MusicData::item("playlist","690002","翻阅到的真实测试歌单","测试听众");next["cover"]=artworkURL;
            // Distinct real collection identity/cover URL; no random placeholders are installed.
            QImage sleeveFixture(320,320,QImage::Format_RGB32);sleeveFixture.fill(QColor("#7b8264"));sleeveFixture.save(output+"/g69-record-fixture.png");
            next["cover"]=QUrl::fromLocalFile(output+"/g69-record-fixture.png").toString();music.lists[2]=QJsonArray{next};model->sync();
            backend.host.fixture=[previousFixture,next](QString route,QJsonObject values){
                if(route=="/native/netease/detail" && values["args"].toArray().first().toObject()["id"]=="690002"){
                    auto song=MusicData::item("song","690003","新歌单曲目","测试歌手");
                    return QJsonObject{{"body",QJsonObject{{"code",200},{"value",QJsonArray{next,QJsonArray{song},QJsonArray{"690003"}}}}}};
                }return previousFixture(route,values);
            };
            auto *sleeve=findVisual(window->contentItem(),"recordSleeve_"+next["key"].toString());
            if(sleeve){const auto point=sleeve->mapToScene(QPointF(sleeve->width()/2,sleeve->height()/2));
                QMouseEvent move(QEvent::MouseMove,point,window->mapToGlobal(point.toPoint()),Qt::NoButton,Qt::NoButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&move);settle(300);}
            auto *preview=findVisual(window->contentItem(),"recordPreview_"+next["key"].toString());
            check(clickVisual(preview),"G70 visible record thumbnail selects its exact real collection");settle(650);refresh();
            check(music.directory && music.directory->item["id"]=="690002" && music.player.current==originalPlay && music.player.queue==originalQueue,
                "G69 record browsing changes the real directory without playback or queue replacement");
            backend.action("back");refresh();
            check(music.directory==originalDirectory->parent,"G71 one back exits the cover browsing session to its original entry");
            music.directory=originalDirectory;music.showDirectoryInfo();model->sync();model->savePosition(model->session(),75);refresh();
            backend.host.fixture=previousFixture;music.lists[2]=previousCollections;model->savePosition(model->session(),0);model->sync();
        }
    }
    const auto beforeNavigation = music.current;
    const auto playingBeforeNavigation = music.player.current;
    hud.hoverItem("music:track:0", 500, 450); refresh();
    backend.key("ArrowDown", false); refresh();
    check(hud.focusAction == "music:track:1" && hud.frame["mode"] == "detail" &&
          music.current == beforeNavigation && music.player.current == playingBeforeNavigation,
          "playlist arrows move only the row focus and keep details and playback intact");
    hud.hoverItem("music:track:0", 500, 450);
    check(hud.keyboardNavigation && hud.focusAction == "music:track:1", "stationary mouse cannot steal keyboard row focus");
    backend.hoverItem("music:track:0", 600, 450);
    check(hud.keyboardNavigation && hud.focusAction == "music:track:1", "synthetic delegate hover coordinates do not count as physical mouse motion");
    hud.hoverItem("music:track:0", 507, 450);
    check(!hud.keyboardNavigation && hud.focusAction == "music:track:0", "real mouse movement takes row focus back");
    for (int i = 0; i < 10; ++i) { backend.key("ArrowDown", false); refresh(); }
    check(hud.trackOffset > 0 && hud.focusAction == "music:track:9", "keyboard row focus scrolls into view at the bottom");
    hud.trackOffset = 0; hud.focusAction.clear(); refresh();
    hud.requestListCover(artworkURL);
    settle(150);
    const auto thumbnailKey = hud.listCovers.value(artworkURL);
    QImage pressure(1024, 1024, QImage::Format_RGBA8888); pressure.fill(Qt::blue);
    for (int i = 0; i < 12; ++i) { backend.host.fixtureImage("pressure:" + QString::number(i), pressure); }
    check(!backend.host.hasImage(thumbnailKey), "cache pressure evicts an old list thumbnail in the regression fixture");
    hud.requestListCover(artworkURL);
    QElapsedTimer coverReload; coverReload.start();
    while (hud.listCoverPending.contains(artworkURL) && coverReload.elapsed() < 5000) { settle(20); }
    check(!hud.listCovers.value(artworkURL).isEmpty() && backend.host.hasImage(hud.listCovers.value(artworkURL)),
          "returning to an evicted cover reloads it instead of trusting a stale successful key");
    const QString transientURL = "https://music.126.net/retry-fixture.png";
    hud.requestListCover(transientURL);
    for (int i = 0; i < 20; ++i) { hud.requestListCover(transientURL); }
    check(hud.listCoverFailures.value(transientURL) == 1 && !hud.listCovers.contains(transientURL),
          "temporary artwork failure is not cached as success and repeated frames respect backoff");
    backend.host.fixtureImage(transientURL + "?param=160y160", artwork);
    hud.listCoverRetry[transientURL] = 0; hud.requestListCover(transientURL);
    check(backend.host.hasImage(hud.listCovers.value(transientURL)), "a failed thumbnail can recover on a later retry");
    refresh();
    window->grabWindow().scaled(1280, 900, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-playlist-detail.png");
    backend.action("music:track:2"); refresh();
    check(music.current.value("kind") == "song", "playlist detail can open a song");
    backend.action("back"); refresh();
    check(music.directoryInfo && music.current.value("kind") == "playlist", "song returns to its source playlist detail");
    backend.action("back"); refresh();
    check(!music.directory && music.current.value("id") == playlistChoice.value("id") &&
          music.selectedPhysical == selectionPhysical && music.selectedLane == selectionLane,
          "playlist detail returns to the original selected playlist and position");
    backend.action("open");
    folderWait.restart();
    while (music.directoryLoading && folderWait.elapsed() < 10000) { settle(30); }
    settle(100);
    // Test the first track at a known list viewport; earlier focus tests
    // intentionally scroll the playlist and navigation may retain that offset.
    hud.trackOffset = 0;
    hud.focusAction.clear();
    refresh();
    qInfo() << "G57 playlist reentry diagnostics:"
            << "directory" << bool(music.directory)
            << "directoryInfo" << music.directoryInfo
            << "currentKind" << music.current.value("kind")
            << "currentID" << music.current.value("id")
            << "mode" << hud.frame.value("mode")
            << "tracks" << (music.directory ? music.directory->songs.size() : -1)
            << "hasFirstTrack" << hasHudAction("music:track:0");
    check(music.directory && music.directoryInfo && music.current.value("kind") == "playlist" &&
          findVisual(window->contentItem(),"magazineRow_0"),
          "the main playlist entry opens its detail page consistently with navigation and discovery");
    backend.action("back"); refresh();
    // Render the new navigation and discover surface in the same real Qt window.
    auto *sideNav = window->findChild<QQuickItem *>("sideNavigationRoot");
    check(sideNav != nullptr, "side navigation is available in the main window");
    if (sideNav) {
        sideNav->setProperty("expanded", true); settle(300); refresh();
        window->grabWindow().scaled(1280, 900, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-side-navigation.png");
        sideNav->setProperty("expanded", false); settle(250);
    }
    backend.action("discover"); settle(200); refresh();
    const auto discoveryPlaying = music.player.current;
    const auto discoveryQueue = music.player.queue;
    const auto discoveryItems = music.discover->items;
    const auto discoveryTab = music.discover->tab;
    const auto testRecommendation = song;
    music.discover->items = {};
    for (int i = 0; i < 12; ++i) { music.discover->items.append(testRecommendation); }
    music.discover->tab = "daily"; hud.listOffset = 4; refresh();
    backend.action("discover:item:0"); settle(400); refresh();
    check(music.player.current["id"]==testRecommendation["id"]&&hud.modal.isEmpty()&&hud.frame["mode"]=="archive"&&music.archiveNowPlaying,
          "G86 daily recommendation starts playback in the shared now-playing surface");
    check(findVisual(window->contentItem(),"nowPlayingPanel"),"G86 discovery uses actual now-playing QML content");
    window->requestActivate(); settle(100);
    QKeyEvent escapePress(QEvent::KeyPress, Qt::Key_Escape, Qt::NoModifier);
    QKeyEvent escapeRelease(QEvent::KeyRelease, Qt::Key_Escape, Qt::NoModifier);
    QCoreApplication::sendEvent(window, &escapePress); QCoreApplication::sendEvent(window, &escapeRelease);
    settle(200); refresh();
    check(hud.modal == "discover" && music.discover->tab == "daily" && hud.listOffset == 4,
          "Escape returns to the originating discovery tab and list position");
    music.discover->items = QJsonArray{playlistChoice}; music.discover->tab = "playlists"; refresh();
    backend.action("discover:item:0");
    folderWait.restart();
    while (music.directoryLoading && folderWait.elapsed() < 10000) { settle(30); }
    settle(400); refresh();
    check(music.directoryInfo && music.current["kind"] == "playlist", "discovery playlist opens its detail page");
    backend.key("Escape", false); refresh();
    check(hud.modal == "discover", "Escape from a discovery playlist restores discovery");
    music.discover->items = discoveryItems; music.discover->tab = discoveryTab; refresh();
    window->grabWindow().scaled(1280, 900, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-discover-glass.png");
    backend.action("close-modal"); settle(400); refresh();
    // 新标签顺序、推荐曲目与相关歌单、局部滚轮和返回源歌曲。
    music.directory.reset();
    music.directoryInfo = false;
    music.current = song;
    hud.tab = "recommendations";
    backend.scene.review("detail");
    refresh();
    QElapsedTimer recWait; recWait.start();
    while (hud.recommendationsPending > 0 && recWait.elapsed() < 10000) { settle(30); }
    refresh();
    check(hud.recommendationSongs.size() == 5 && hud.recommendationPlaylists.size() == 3, "similar songs and three related playlists");
    QStringList tabs;
    for (const auto &value : hud.hits) {
        const auto action = value.toObject().value("action").toString();
        if (action.startsWith("tab:")) { tabs.append(action); }
    }
    check(tabs == QStringList{"tab:overview", "tab:history", "tab:comments", "tab:recommendations"}, "song tabs follow the requested order");
    auto *recLoader = window->findChild<QQuickItem *>("recommendationsLoader");
    auto *recPage = recLoader ? recLoader->property("item").value<QObject *>() : nullptr;
    auto *recReading = recPage ? recPage->findChild<QQuickItem *>("recommendationsReading") : nullptr;
    check(recReading && recReading->property("contentHeight").toDouble() > recReading->height(), "recommendations use a local scroll region");
    window->grabWindow().scaled(1000, 650, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-recommendations.png");
    if (recReading) {
        const auto local = recReading->mapToScene(QPointF(recReading->width()/2, recReading->height()/2));
        QWheelEvent wheel(local, window->mapToGlobal(local.toPoint()), QPoint(), QPoint(0, -120), Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(window, &wheel); settle(400);
        check(recReading->property("contentY").toDouble() > 0, "recommendations scroll with mouse wheel");
    }
    backend.action("music:recommend-song:0"); refresh();
    check(music.current.value("id") == "6000", "recommendation opens its song detail");
    backend.action("back"); refresh();
    check(music.current.value("id") == song.value("id") && hud.tab == "recommendations", "recommended song returns to its source song");
    backend.action("music:recommend-playlist:0"); refresh();
    QElapsedTimer listWait; listWait.start();
    while (music.directoryLoading && listWait.elapsed() < 10000) { settle(30); }
    refresh();
    check(music.directory && music.directoryInfo && music.current.value("kind") == "playlist", "related playlist opens directly as a detail page");
    backend.action("back"); refresh();
    check(music.current.value("id") == song.value("id") && hud.tab == "recommendations", "related playlist returns to its source song detail");
    // 分享只复制当前详情歌曲，歌手名与专辑名直接命中各自入口。
    auto shareSong = song;
    shareSong["artists"] = QJsonArray{QJsonObject{{"id", "7"}, {"name", "betcover!!"}}, QJsonObject{{"id", "8"}, {"name", "另一位歌手"}}};
    // 用真实选择入口作废返回流程尚未完成的元数据请求，避免手动替换 current 后又被异步结果覆盖。
    music.details[shareSong.value("key").toString()] = shareSong;
    music.choose(shareSong, false, true);
    hud.tab = "overview";
    refresh();
    bool artistLink = false, secondArtistLink = false, albumLink = false, shareButton = false;
    for (const auto &entry : hud.hits) {
        const auto hit = entry.toObject();
        if (hit.value("action") == "music:artist:0") { artistLink = hit.value("link").toBool(); }
        if (hit.value("action") == "music:artist:1") { secondArtistLink = hit.value("link").toBool(); }
        if (hit.value("action") == "music:song-album") { albumLink = hit.value("link").toBool(); }
        if (hit.value("action") == "music:share") { shareButton = true; }
    }
    qInfo() << "Share and metadata links:" << artistLink << secondArtistLink << albumLink << shareButton;
    check(artistLink && secondArtistLink && albumLink && shareButton, "individual artist and album links replace the artist button with share");
    const auto clipboard = QGuiApplication::clipboard()->text();
    backend.action("music:share");
    check(QGuiApplication::clipboard()->text() == song.value("title").toString() + " — " + song.value("artist").toString() + "\nhttps://music.163.com/song?id=" + song.value("id").toString(), "share copies the viewed song with its public link");
    QGuiApplication::clipboard()->setText(clipboard);
    backend.hoverLink("music:song-album");
    refresh();
    check(hud.hoveredLink == "music:song-album", "album hover feedback is retained without changing navigation");
    backend.hoverLink("");

    // 使用真正的歌词控制器，检查时间切换、主窗口最小化、透明窗口和锁定恢复。
    const auto originalFixture = backend.host.fixture;
    backend.host.fixture = [originalFixture](QString route, QJsonObject parameters) {
        if (route == "/native/netease/lyrics") {
            const QJsonObject document{{"version", 1}, {"timing", "line"}, {"plainText", "桌面歌词测试"}, {"offsetMs", 0},
                {"lines", QJsonArray{QJsonObject{{"startMs", 0}, {"text", "星のない夜でも、君の声が聞こえる"}},
                    QJsonObject{{"startMs", 1000}, {"text", "戸惑うほどのことではない"}, {"translation", "并不是什么值得困惑的事情"}},
                    QJsonObject{{"startMs", 2000}, {"text", "桌面歌词会跟随正在播放的歌曲"}}}}};
            return QJsonObject{{"body", QJsonObject{{"code", 200}, {"value", document}}}};
        }
        return originalFixture(route, parameters);
    };
    auto &player = music.player;
    player.current = MusicData::item("song", "990099", "桌面歌词测试", "测试歌手");
    player.loading = false; player.failed = false;
    player.lyrics.load(player.current, true);
    QElapsedTimer lyricWait; lyricWait.start();
    while (player.lyrics.status == "loading" && lyricWait.elapsed() < 10000) { settle(30); }
    const auto placeQaLyrics = [&] {
        if (qaScreen) {
            const auto bounds = qaScreen->availableGeometry();
            backend.saveDesktopPosition(bounds.left() + 100, bounds.bottom() - 200);
        }
    };
    placeQaLyrics();
    if (!hud.desktopLyricsEnabled) { backend.action("desktop:toggle"); }
    settle(300);
    QQuickWindow *desktop = nullptr;
    for (auto *candidate : QGuiApplication::allWindows()) {
        if (candidate->objectName() == "desktopLyricsWindow") { desktop = qobject_cast<QQuickWindow *>(candidate); }
    }
    check(desktop && desktop->isVisible(), "desktop lyrics open as an independent window");
    check(backend.desktopLyrics().value("primary").toString() == "星のない夜でも、君の声が聞こえる", "desktop lyrics show the active timed line");
    check(backend.desktopLyrics().value("secondary").toString() == "戸惑うほどのことではない", "missing translation falls back to the next original line");
    player.lyrics.sync(1100);
    check(backend.desktopLyrics().value("primary").toString() == "戸惑うほどのことではない", "desktop lyrics advance through the shared timing controller");
    check(backend.desktopLyrics().value("secondary").toString() == "并不是什么值得困惑的事情", "desktop lyrics prefer the current line translation over the next line");
    if (desktop) {
        check(desktop->flags().testFlag(Qt::WindowStaysOnTopHint) && !desktop->transientParent(), "lyrics stay on top without following main-window minimization");
        window->showMinimized(); settle(300);
        player.lyrics.sync(2200);
        check(desktop->isVisible() && backend.desktopLyrics().value("primary").toString() == "桌面歌词会跟随正在播放的歌曲", "lyrics continue updating while the player is minimized");
        check(backend.desktopLyrics().value("secondary").toString().isEmpty(), "moving to an untranslated final line clears the previous translation");
        window->showNormal(); settle(300);
        player.lyrics.sync(1100);
        QMouseEvent leave(QEvent::MouseMove, QPointF(-30, -30), QPointF(-30, -30), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(desktop, &leave); settle(300);
        auto *backing = desktop->findChild<QQuickItem *>("desktopLyricsBacking");
        const auto backingColor = backing ? backing->property("color").value<QColor>() : QColor();
        check(backingColor.red() >= 240 && backingColor.green() >= 230 && backingColor.blue() >= 220 && backingColor.alpha() < 180,
              "hover backing uses a more transparent warm cream tint");
        check(backing && backing->opacity() == 0, "lyrics have no backing outside hover");
        const auto transparent = desktop->grabWindow();
        check(!transparent.isNull() && transparent.save(output + "/preview-desktop-lyrics.png"), "transparent desktop lyrics render");
        QMouseEvent enter(QEvent::MouseMove, QPointF(100, 80), QPointF(100, 80), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(desktop, &enter); settle(300);
        check(backing && backing->opacity() == 1, "hover reveals the thin backing and controls");
        desktop->grabWindow().save(output + "/preview-desktop-lyrics-hover.png");
        auto *primaryLabel = desktop->findChild<QQuickItem *>("desktopLyricsPrimary");
        auto *secondaryLabel = desktop->findChild<QQuickItem *>("desktopLyricsSecondary");
        backend.setDesktopColor("primary", "#334455");
        backend.setDesktopColor("secondary", "#667744");
        backend.setDesktopColor("background", "#e8dfc6");
        backend.action("desktop:more-transparent"); settle(150);
        check(primaryLabel && primaryLabel->property("color").value<QColor>().name() == "#334455" &&
              secondaryLabel && secondaryLabel->property("color").value<QColor>().name() == "#667744", "custom original and translated lyric colors update the window");
        check(backing && backing->property("color").value<QColor>().name() == "#e8dfc6" &&
              std::abs(backing->property("color").value<QColor>().alphaF() - 0.60) < 0.01,
              "custom backing tint and transparency update independently");
        const auto screen = desktop->screen() ? desktop->screen()->geometry() : QGuiApplication::primaryScreen()->geometry();
        const auto edgeX = screen.left() + (screen.width() - desktop->width()) / 2;
        const auto edgeY = screen.bottom() - desktop->height() + 1;
        desktop->setPosition(edgeX, edgeY);
        backend.saveDesktopPosition(edgeX, edgeY); settle(200);
        backend.setDesktopColor("primary", "#334455"); settle(100);
        check(desktop->y() == edgeY && backend.desktopLyrics().value("y").toInt() == edgeY,
              "releasing at the screen bottom keeps the actual window edge without an upward snap");
        backend.action("desktop:reset"); placeQaLyrics(); settle(150);
        backend.action("desktop:lock"); settle(200);
        check(desktop->flags().testFlag(Qt::WindowTransparentForInput), "locking enables native mouse click-through");
        backend.action("desktop:lock"); settle(200);
        check(!desktop->flags().testFlag(Qt::WindowTransparentForInput), "player controls can unlock a click-through window");
        backend.action("desktop:larger");
        check(backend.desktopLyrics().value("size").toInt() == 28, "desktop font size setting updates the independent window");
        backend.action("desktop:reset"); placeQaLyrics();
        check(hud.desktopLyricsSize == 26 && hud.desktopLyricsFont == "MiSans" && !hud.desktopLyricsLocked &&
              hud.desktopLyricsPrimaryColor.isEmpty() && hud.desktopLyricsSecondaryColor.isEmpty() &&
              hud.desktopLyricsBackgroundColor == "#f5f0e4" && hud.desktopLyricsBackgroundOpacity == 65,
              "desktop settings restore default typography, adaptive colors, opacity and unlock");
        hud.openModal("settings"); hud.settingsScroll = 180;
        backend.action("desktop:settings"); refresh();
        auto *settingsLoader = window->findChild<QQuickItem *>("desktopSettingsLoader");
        auto *settingsPage = settingsLoader ? settingsLoader->property("item").value<QObject *>() : nullptr;
        check(hud.modal == "desktop-settings" && settingsPage, "settings entry opens an independent desktop lyric configuration page");
        backend.applyDesktopPreset("rose"); settle(100);
        check(hud.desktopLyricsPrimaryColor == "#422b23" && hud.desktopLyricsSecondaryColor == "#8b6264" &&
              hud.desktopLyricsBackgroundColor == "#efd8d6", "preset updates all three lyric colors together");
        if (settingsPage) {
            settingsPage->setProperty("fontOpen", true); settle(100);
            check(settingsPage->findChild<QQuickItem *>("desktopSettingsFontMenu")->isVisible(), "integrated font chooser opens inside the configuration page");
            settingsPage->setProperty("fontOpen", false);
            settingsPage->setProperty("colorTarget", "primary"); settle(100);
            check(settingsPage->findChild<QQuickItem *>("desktopSettingsColorMenu")->isVisible(), "integrated color chooser opens inside the configuration page");
            settingsPage->setProperty("colorTarget", "");
        }
        backend.setDesktopTone("light"); settle(100);
        check(hud.desktopLyricsTone == "light" && hud.desktopLyricsPrimaryColor == "#fff3eb" &&
              hud.desktopLyricsSecondaryColor == "#e8c3c6", "tone switch retains the rose palette and applies its light colors");
        backend.applyDesktopPreset("sage"); settle(100);
        check(hud.desktopLyricsPrimaryColor == "#eeece0" && hud.desktopLyricsSecondaryColor == "#bfd3c8",
              "preset selection preserves the active light tone");
        backend.setDesktopTone("invalid");
        check(hud.desktopLyricsTone == "light", "invalid tone does not change stored settings");
        backend.setDesktopTone("dark"); settle(100);
        check(hud.desktopLyricsPrimaryColor == "#34453e" && hud.desktopLyricsSecondaryColor == "#6c786e",
              "dark tone restores the matching sage palette");
        backend.applyDesktopPreset("oat"); backend.setDesktopTone("light"); refresh();
        QMouseEvent leaveLyrics(QEvent::MouseMove, QPointF(-30, -30), QPointF(-30, -30), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(desktop, &leaveLyrics); settle(300);
        check(primaryLabel && primaryLabel->property("color").value<QColor>().name() == "#f6ead4" &&
              secondaryLabel && secondaryLabel->property("color").value<QColor>().name() == "#d1d5b5",
              "transparent light lyrics use the approved oat colors");
        check(primaryLabel && primaryLabel->property("style").toInt() == 0 &&
              secondaryLabel && secondaryLabel->property("style").toInt() == 0,
              "both lyric lines render clean text without a raised outline");
        desktop->grabWindow().save(output + "/preview-desktop-lyrics.png");
        QCoreApplication::sendEvent(desktop, &enter); settle(300);
        check(primaryLabel && primaryLabel->property("color").value<QColor>().name() == "#353b2b" &&
              secondaryLabel && secondaryLabel->property("color").value<QColor>().name() == "#68704c",
              "light lyrics switch to matching dark text over the pale hover backing");
        desktop->grabWindow().save(output + "/preview-desktop-lyrics-hover.png");
        if (settingsPage) { settingsPage->setProperty("hoverPreview", false); settle(100); }
        window->grabWindow().scaled(1280, 900, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(output + "/preview-desktop-settings.png");
        backend.action("desktop:back"); refresh();
        check(hud.modal == "settings" && hud.settingsScroll == 180, "configuration back restores the parent settings scroll position");
        hud.modal.clear();
        backend.action("desktop:close"); settle(100);
        check(!desktop->isVisible(), "desktop lyrics close without closing the player");
    }
    check(runTaskbarChecks(), "Windows taskbar integration regression");
    backend.host.fixture = originalFixture;
    {
        Host heartHost(backend.host.root,true);
        MusicLibrary heartMusic(&heartHost,{});
        heartMusic.provider=heartMusic.api.provider="netease";
        PlaylistShowcase heartShowcase(&heartMusic,&hud);
        auto &player=heartMusic.player;
        bool rejectHeart = false;
        heartHost.fixture = [&](QString route, QJsonObject) {
            if (route == "/user/playlist") {
                return QJsonObject{{"body", QJsonObject{{"code", 200}, {"playlist", QJsonArray{QJsonObject{{"id", 123}, {"specialType", 5}}}}}}};
            }
            QJsonArray rows;
            if (!rejectHeart) {
                const auto raw = QJsonObject{{"id", 9001}, {"name", "心动推荐"}, {"ar", QJsonArray{}}, {"al", QJsonObject{}}};
                rows = QJsonArray{QJsonObject{{"songInfo", raw}}, QJsonObject{{"songInfo", raw}}};
            }
            return QJsonObject{{"body", QJsonObject{{"code", 200}, {"data", rows}}}};
        };
        player.current = song; player.queue = QJsonArray{song}; player.index = 0; player.mode = "shuffle";
        player.startHeart("42", [] { return true; }); settle(500);
        check(player.mode == "heart" && player.queue.size() == 2 && player.index == 0 && player.current == song,
              "heart replaces the queue, deduplicates recommendations and preserves current playback");
        const auto heartQueue = player.queue;
        player.leaveHeart();
        check(player.queue==QJsonArray{song}&&player.index==0&&player.current==song&&player.mode=="off",
              "G98 exiting heart restores original queue and keeps current audio");
        player.mode="shuffle";player.startHeart("42", []{return true;});settle(500);
        rejectHeart = true;
        player.startHeart("42", [] { return true; }); settle(500);
        check(player.queue == heartQueue && !player.heartPending, "empty heart responses preserve the previous queue");
        rejectHeart = false;
        player.mode = "shuffle";
        player.startHeart("42", [] { return true; }); player.cancelHeart(); settle(500);
        check(player.mode == "shuffle" && player.queue == heartQueue, "cancelled heart responses cannot change the mode or queue");
        player.startHeart("", [] { return true; });
        check(!player.heartPending && player.queue == heartQueue, "heart requires a logged-in NetEase account");
        player.leaveHeart();
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
        // Exit helper simulates hearing a recommendation outside the source.
        const auto exitFrom=[&](int seed){
            // Each scenario starts a new session, including its private resume anchor.
            player.stop();
            player.current=ordered.at(seed).toObject();player.queue=ordered;player.index=seed;player.mode="shuffle";
            player.startHeart("42",[]{return true;});settle(500);
            player.current=player.queue.last().toObject();player.index=player.queue.size()-1;
            player.leaveHeart();
        };
        exitFrom(1);const auto atEnd=player.current;
        player.next();
        check(player.current==atEnd&&player.index==-1&&player.queue==ordered,
              "G98 source end does not replay its final song after leaving heart");
        exitFrom(0);player.remove(0);player.next();
        check(player.current["id"]==second["id"]&&player.index==0,
              "G98 deleting the resume seed keeps the next original song");
        exitFrom(0);auto inserted=MusicData::item("song","g98-inserted","Inserted song");player.enqueue(inserted,true);player.next();
        check(player.current["id"]=="g98-inserted"&&player.index==1,
              "G98 play-next insertion uses restored source position");
        exitFrom(0);const auto keepOnly=player.current;player.clearUpcoming();
        check(player.queue==QJsonArray{keepOnly}&&player.index==0,
              "G98 clear-upcoming clears the detached source resume position");
        exitFrom(0);const auto detached=player.current;
        player.startRoam("42",[]{return true;});player.leaveRoam(true);
        check(player.queue==ordered&&player.current==detached&&player.index==-1,
              "G98 FM preserves a restored source with an out-of-source current song");
        player.next();check(player.current["id"]==second["id"],"G98 FM return preserves the original resume position");
        exitFrom(0);const QJsonArray newSource{inserted};player.play(inserted,newSource);
        player.leaveHeart();
        check(player.queue==newSource&&player.current["id"]=="g98-inserted",
              "G98 explicit new playlist discards old heart context");
        player.stop();player.leaveHeart();
        check(player.queue.isEmpty()&&player.current.isEmpty(),"G98 stopping cannot resurrect a heart source queue");

        player.stop();
    }
    {
        const QJsonObject chorusReply{{"chorus", QJsonArray{QJsonObject{{"id", 3447996825.}, {"startTime", 69500}, {"endTime", 81500}}}}};
        check(MusicPlayer::chorusStart(chorusReply, "3447996825") == 69.5, "real NetEase chorus milliseconds become seconds");
        check(MusicPlayer::chorusStart(chorusReply, "1") < 0 && MusicPlayer::chorusStart({}, "3447996825") < 0,
              "missing or mismatched chorus data does not create a marker");
        hud.queueOpen = false; hud.queueCollectionOpen = false;
        hud.modal.clear(); hud.closing = false;
        music.player.state["position"] = 172000.; music.player.state["duration"] = 198640.;
        music.player.state["seekable"] = true; music.player.chorusSeconds = 69.5;
        refresh();
        // Repeater delegates belong to the visual tree, not the QObject parent tree.
        std::function<QQuickItem *(QQuickItem *)> findSeek;
        findSeek = [&](QQuickItem *item) -> QQuickItem * {
            if (item->objectName() == "playbackSeekArea") { return item; }
            for (auto *child : item->childItems()) { if (auto *found = findSeek(child)) { return found; } }
            return nullptr;
        };
        auto *area = findSeek(window->contentItem());
        check(area != nullptr, "new progress bar interaction area exists");
        if (area) {
            const auto move = [&](QPointF point) {
                QMouseEvent event(QEvent::MouseMove, point, window->mapToGlobal(point.toPoint()), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
                QCoreApplication::sendEvent(window, &event); settle(200);
            };
            auto *thumb = area->findChild<QQuickItem *>("playbackSeekThumb");
            auto *time = area->findChild<QQuickItem *>("playbackSeekTime");
            auto *marker = area->findChild<QQuickItem *>("playbackChorusMarker");
            move(QPointF(20,20));
            check(thumb && !thumb->isVisible() && time && !time->isVisible(), "normal progress line hides the thumb and time pill");
            move(area->mapToScene(QPointF(area->width()*.85, area->height()/2)));
            check(thumb && thumb->isVisible() && time && time->isVisible() && marker && marker->isVisible(),
                  "hover reveals progress controls and only the actual chorus marker");
            auto *timeText = area->findChild<QObject *>("playbackSeekTimeText");
            check(std::abs(area->property("duration").toDouble() - 198.64) < .001 && timeText &&
                  timeText->property("text").toString() == "02:52 / 03:18", "actual millisecond playback values format correctly");
            check(marker && std::abs(marker->x() + marker->width()/2 - area->width()*69.5/198.64) < 1,
                  "chorus marker occupies the correct proportional position with millisecond playback data");
            music.player.state["position"] = 127176.; music.player.state["duration"] = 385370.; refresh();
            check(timeText && timeText->property("text").toString() == "02:07 / 06:25", "reported 2119-minute regression now shows two minutes seven seconds");
            window->grabWindow().save(output + "/preview-progress-hover.png");
            music.player.chorusSeconds = -1; refresh();
            check(marker && !marker->isVisible(), "songs without chorus data hide the marker");
            move(QPointF(20,20));
            check(thumb && !thumb->isVisible() && time && !time->isVisible(), "leaving restores the unobtrusive progress line");
        }
    }
    {
        const auto oldDirectory = music.directory; const auto oldUid = music.uid;
        music.uid = "42"; music.directory = std::make_shared<MusicDirectory>();
        music.directory->item = MusicData::item("playlist", "123", "测试歌单");
        music.directory->item["creatorID"] = "42";
        music.directory->songs = {song}; music.directory->ids = {song["id"]};
        music.directory->item["trackCount"] = 1;
        music.directoryInfo = false; music.current = song; hud.tab = "overview";
        backend.scene.review("detail"); refresh();
        QJsonObject queueHit, removeHit; bool oldQueue = false, official = false;
        for (const auto &value : hud.hits) {
            const auto hit = value.toObject(); const auto action = hit.value("action").toString();
            if (action == "music:play-next") queueHit = hit;
            if (action == "music:remove-track") removeHit = hit;
            oldQueue |= action == "music:enqueue"; official |= action == "music:official";
        }
        check(!queueHit.isEmpty() && !removeHit.isEmpty() && !oldQueue && !official,
              "song details retain next-in-queue and remove actions without duplicate queue or official client controls");
        check(queueHit.value("y") == removeHit.value("y") && queueHit.value("x").toDouble() < removeHit.value("x").toDouble(),
              "queue and remove occupy the middle and right cells of the same action row");
        window->grabWindow().save(output + "/preview-song-actions.png");
        const auto playlist = music.directory;
        const auto fixture = backend.host.fixture;
        bool rejectWrite = false; QStringList operations;
        backend.host.fixture = [fixture, &rejectWrite, &operations](QString route, QJsonObject parameters) {
            if (route == "/playlist/tracks") {
                operations.append(parameters["op"].toString());
                return QJsonObject{{"body", QJsonObject{{"code", rejectWrite ? 500 : 200}}}};
            }
            return fixture(route, parameters);
        };
        const auto waitWrite = [&] {
            QElapsedTimer wait; wait.start();
            while (music.writeLoading && wait.elapsed() < 5000) { settle(20); }
            refresh();
        };
        backend.action("music:remove-track"); waitWrite();
        check(!music.playlistContains(*playlist, song) && hasHudAction("music:add-current-playlist") &&
              music.current["id"] == song["id"] && playlist->item["trackCount"].toInt() == 0,
              "successful removal keeps the song open and changes the action to add to this playlist");
        window->grabWindow().save(output + "/preview-song-add.png");
        backend.action("music:add-current-playlist"); waitWrite();
        check(music.playlistContains(*playlist, song) && hasHudAction("music:remove-track") &&
              playlist->ids.size() == 1 && playlist->item["trackCount"].toInt() == 1,
              "successful re-add restores membership IDs, count and the remove action");
        rejectWrite = true;
        backend.action("music:remove-track"); waitWrite();
        check(music.playlistContains(*playlist, song) && hasHudAction("music:remove-track"),
              "a rejected playlist write preserves membership and its action");
        rejectWrite = false;
        const auto outsider = MusicData::item("song", "991234", "偶遇的新歌", "测试歌手");
        auto playbackFolder = std::make_shared<MusicDirectory>();
        playbackFolder->item = MusicData::item("playlist", "", "播放队列");
        playbackFolder->parent = playlist; playbackFolder->songs = {outsider};
        music.directory = playbackFolder; music.current = outsider; refresh();
        check(hasHudAction("music:add-current-playlist") && !hasHudAction("music:remove-track"),
              "a new song in the playback queue is recognized as absent from its owning playlist");
        backend.action("music:add-current-playlist"); waitWrite();
        check(music.playlistContains(*playlist, outsider) && hasHudAction("music:remove-track") &&
              operations == QStringList{"del", "add", "del", "add"},
              "queue context writes to the owning playlist and updates the toggle only after success");
        backend.host.fixture = fixture;

        music.current = song; music.directory = playlist;
        music.player.current = song; music.player.queue = {song};
        hud.tab = "history"; backend.scene.review("detail"); refresh();
        check(hasHudAction("player:song-lyrics") && hasHudAction("player:song-detail") &&
              hasHudAction("player:song-artist:0"), "cover, title and artist expose separate playback-bar destinations");
        backend.action("player:song-lyrics"); refresh();
        check(hud.lyricsMode && music.current["id"] == song["id"], "playback cover opens the playing song lyrics directly");
        backend.action("player:lyrics"); refresh();
        check(!hud.lyricsMode && hud.tab == "history" && music.directory == playlist,
              "pressing lyrics again restores the previous song tab and playlist context");
        backend.action("player:song-detail"); refresh();
        check(!hud.lyricsMode && music.current["id"] == song["id"] && hud.tab == "overview",
              "playback title opens song details without opening lyrics");
        backend.scene.review("archive"); refresh();
        backend.action("player:lyrics"); refresh(); backend.action("player:lyrics"); refresh();
        check(!hud.lyricsMode && hud.frame["mode"] == "archive",
              "lyrics toggle also restores an archive page rather than leaving it in song details");
        backend.action("player:song-artist:0");
        QElapsedTimer artistWait; artistWait.start();
        while (music.directoryLoading && artistWait.elapsed() < 5000) { settle(20); }
        check(music.directory && music.directory->item["kind"] == "artist" &&
              music.player.current["id"] == song["id"], "playback artist opens their page without changing playback");
        music.directory = oldDirectory; music.uid = oldUid;
    }
    {
        const auto fixture = backend.host.fixture; const auto uid = music.uid;
        const auto beforePlayback = music.player.current;
        music.uid = "42"; music.current = song; music.directory.reset(); music.directoryInfo = false;
        hud.tab = "comments"; backend.scene.review("detail"); refresh(); waitComments();
        const auto commentCount = hud.commentsRows.size();
        QImage cover(320,320,QImage::Format_RGB32); cover.fill(QColor("#a5ad94"));
        cover.save(output + "/profile-fixture-cover.png");
        const auto coverURL = QUrl::fromLocalFile(output + "/profile-fixture-cover.png").toString();
        backend.host.fixture = [fixture, coverURL](QString route, QJsonObject parameters) {
            if (route == "/native/netease/lyrics") {
                const auto document = QJsonObject{{"version",1},{"timing","line"},{"plainText","歌词界面测试"},{"offsetMs",0},{"lines",QJsonArray{
                    QJsonObject{{"startMs",0},{"text","星のない夜でも、君の声が聞こえる"},{"translation","没有星星的夜里，也能听见你的声音"}},
                    QJsonObject{{"startMs",15000},{"text","戸惑うほどのことではない"},{"translation","并不是什么值得困惑的事情"}},
                    QJsonObject{{"startMs",60000},{"text","次の季節へ歩いてゆこう"},{"translation","一起走向下一个季节"}}}}};
                return QJsonObject{{"body",QJsonObject{{"code",200},{"value",document}}}};
            }
            QJsonObject body{{"code",200}};
            if (route == "/user/detail") {
                body["level"] = 10;
                body["listenSongs"] = 30590;
                body["profile"] = QJsonObject{{"nickname","Erica_P"},{"avatarUrl",coverURL},
                    {"signature","Good luck to you."},{"follows",35},{"followeds",8},{"artistId",123}};
            } else if (route == "/user/playlist") {
                QJsonArray rows;
                for (int i=0;i<7;++i) {
                    const auto creator = QJsonObject{{"userId",i<5?42:99},{"nickname","测试创建者"}};
                    rows.append(QJsonObject{{"id",700+i},{"name",QString("测试歌单 %1").arg(i+1)},
                        {"coverImgUrl",coverURL},{"trackCount",20+i},{"creator",creator}});
                }
                body["playlist"] = rows; body["more"] = false;
            } else if (route == "/user/record") {
                const auto song = QJsonObject{{"id", 955}, {"name", "听歌排行测试"},
                    {"ar", QJsonArray{}}, {"al", QJsonObject{{"picUrl", coverURL}}}};
                const auto ranked = QJsonArray{QJsonObject{{"song", song}, {"playCount", parameters["type"].toInt() == 1 ? 7 : 32}}};
                body[parameters["type"].toInt() == 1 ? "weekData" : "allData"] = ranked;
            } else if (route.startsWith("/record/recent/")) {
                const auto raw = QJsonObject{{"id",800},{"name","最近收听"},{"picUrl",coverURL},
                    {"ar",QJsonArray{}},{"al",QJsonObject{{"picUrl",coverURL}}}};
                const auto rows = QJsonArray{QJsonObject{{"data",raw}}};
                body["data"] = QJsonObject{{"list",rows}};
            } else if (route == "/user/event") {
                const auto json = QString::fromUtf8(QJsonDocument(QJsonObject{{"msg","听到一首喜欢的歌，记下这一刻。"}}).toJson(QJsonDocument::Compact));
                body["events"] = QJsonArray{QJsonObject{{"id",900},{"json",json},{"eventTime",1700000000000.}}};
                body["more"] = false;
            } else if (route == "/user/audio") {
                body["djRadios"] = QJsonArray{QJsonObject{{"id",901},{"name","测试播客"},{"picUrl",coverURL},{"programCount",1}}};
            } else if (route == "/dj/program") {
                const auto raw = QJsonObject{{"id",902},{"name","第一期"}};
                body["programs"] = QJsonArray{QJsonObject{{"name","第一期"},{"coverUrl",coverURL},{"mainSong",raw}}};
            } else { return fixture(route,parameters); }
            return QJsonObject{{"body",body}};
        };
        const auto waitProfile = [&] { QElapsedTimer wait; wait.start(); while(hud.profileLoading && wait.elapsed()<10000) { settle(20); } refresh(); };
        backend.action("profile:open:42"); waitProfile();
        check(hud.profileFilter == "recent" && hud.profileRows.size() == 2 &&
              hud.profileRows.first().toObject()["kind"] == "ranking" && hud.profileRows.last().toObject()["kind"] == "playlist",
              "own profile defaults to listening rank entry and recent playlist cards");
        window->grabWindow().save(output + "/preview-profile-recent.png");
        backend.key("ArrowDown", false); refresh();
        check(hud.focusAction == "profile:item:0", "profile grid accepts arrow focus without operating the record shelf");
        backend.key("Enter", false); waitProfile();
        check(hud.profileRecentKind == "ranking" && hud.profileRows.first().toObject()["listeningCount"] == 32,
              "listening rank entry reads all-time ranking data");
        backend.action("profile:rank-period:week"); waitProfile();
        check(hud.profileRows.first().toObject()["listeningCount"] == 7, "listening rank can switch to the last week");
        window->grabWindow().save(output + "/preview-profile-ranking.png");
        backend.action("profile:filter:created"); waitProfile();
        check(hud.modal == "profile" && hud.profile["nickname"] == "Erica_P" && hud.profileRows.size()==5,
              "profile loads real metadata and filters created playlists by owner");
        auto *profileLoader = window->findChild<QQuickItem *>("userProfileLoader");
        check(profileLoader && profileLoader->property("active").toBool() && profileLoader->property("item").value<QObject *>(),
              "personal profile QML renders with cover cards and creation control");
        auto *profileItem = profileLoader ? profileLoader->property("item").value<QObject *>() : nullptr;
        auto *nickname = profileItem ? profileItem->findChild<QQuickItem *>("profileNickname") : nullptr;
        check(nickname && nickname->property("text").toString()=="Erica_P","profile header renders the loaded nickname rather than a loading placeholder");
        backend.action("profile:focus:0"); refresh();
        auto *cardPlay = findVisual(qobject_cast<QQuickItem *>(profileItem), "profileCardPlay");
        check(cardPlay && cardPlay->opacity() > 0.9, "focused profile cover reveals its separate play control");
        window->grabWindow().save(output + "/preview-user-profile.png");
        backend.action("profile:item:0");
        QElapsedTimer opened; opened.start();
        while(music.directoryLoading && opened.elapsed()<10000) { settle(20); }
        refresh();
        check(music.directoryInfo && music.current["kind"]=="playlist","profile cover opens playlist details directly");
        backend.action("back"); refresh();
        check(hud.modal=="profile","playlist details return to the user's profile");
        backend.action("profile:filter:collected"); waitProfile();
        check(hud.profileRows.size()==2,"profile separates collected playlists from creations");
        backend.action("profile:filter:recent"); waitProfile();
        backend.action("profile:recent-kind:song"); waitProfile();
        check(hud.profileRows.size()==1 && hud.profileRows.first().toObject()["kind"]=="song","recent songs use listening history rather than ranking data");
        backend.action("profile:recent-kind:album"); waitProfile();
        check(hud.profileRows.size()==1 && hud.profileRows.first().toObject()["kind"]=="album","recent albums retain album navigation identities");
        backend.action("profile:section:notes"); waitProfile();
        check(hud.profileRows.size()==1 && hud.profileRows.first().toObject()["title"].toString().contains("喜欢"),"notes parse the actual event JSON payload");
        backend.action("profile:section:podcasts"); waitProfile();
        check(hud.profileRows.size()==1 && hud.profileRows.first().toObject()["kind"]=="radio","podcast tab reads the user's created radios");
        backend.action("profile:item:0"); waitProfile();
        check(hud.profileSection=="programs" && hud.profileRows.size()==1,"podcasts open a program list");
        backend.action("profile:close"); refresh();
        check(hud.modal.isEmpty() && hud.tab=="comments" && hud.commentsRows.size()==commentCount && music.player.current==beforePlayback,
              "closing a comment author profile preserves comments and playback");
        music.player.lyrics.load(music.player.current,true);
        QElapsedTimer lyricWait; lyricWait.start();
        while(music.player.lyrics.status=="loading" && lyricWait.elapsed()<10000) { settle(20); }
        backend.action("player:lyrics"); refresh();
        check(!hud.lyricRows.isEmpty() && window->findChild<QQuickItem *>("lyricsReadingLoader"),
              "timed lyric text renders through the continuous edge mask");
        auto *lyricsLoader = window->findChild<QQuickItem *>("lyricsReadingLoader");
        auto *lyricsPage = lyricsLoader ? lyricsLoader->property("item").value<QObject *>() : nullptr;
        auto *edge = lyricsPage ? lyricsPage->findChild<QQuickItem *>("lyricsEdgeEffect") : nullptr;
        QImage lyricShaderPixels;
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
              "spatial lyric blur shader compiles and renders on the packaged Windows backend");
        // No media is loaded in this offline GUI run. Model a seekable recording explicitly.
        music.player.state["seekable"] = true;
        music.player.state["duration"] = 180000.;
        music.player.state["playing"] = false;
        hud.wheel(hud.width*0.8,500,-240,2); refresh();
        bool timestamp = false;
        for(const auto &value : hud.hits) { timestamp |= value.toObject()["label"].toString().startsWith("▶ "); }
        check(timestamp,"scrolling timed lyrics exposes an actionable timestamp");
        window->grabWindow().save(output + "/preview-lyrics-browse.png");
        backend.action("player:lyrics"); refresh();
        backend.host.fixture = fixture; music.uid = uid;
    }
    {
        auto &discover = *music.discover;
        const auto previousItems = discover.items;
        const auto previousModal = hud.modal;
        const auto previousOffset = hud.listOffset;
        auto list = MusicData::item("playlist", "6001", "沿途的声音 · 推荐歌单", "测试听众");
        list["cover"] = artworkURL;
        discover.items = QJsonArray{list}; hud.listOffset = 0;
        hud.openModal("discover"); refresh();
        settle(100);
        // Repeater delegates follow the visual tree, not QObject ownership.
        const auto *card = findVisual(window->contentItem(), "discoverCardImage");
        const auto discoverCovers = card && !card->property("source").toUrl().isEmpty();
        check(discoverCovers, "discovery cards expose artwork rather than a text-only list");
        window->grabWindow().save(output + "/preview-discover-covers.png");
        discover.items = previousItems; hud.modal = previousModal; hud.listOffset = previousOffset;
    }
    // G67: keep the actual Following Loader, data and scroll alive throughout queue/picker use.
    {
        auto &discover = *music.discover;
        const auto oldItems = discover.items; const auto oldTab = discover.tab;
        const auto oldCategory = discover.category; const auto oldModal = hud.modal;
        const auto oldQuery = hud.query; const auto oldOffset = hud.listOffset;
        const auto oldQueue = player.queue; const auto oldCurrent = player.current; const auto oldIndex = player.index;
        const auto oldUid = music.uid;
        QJsonArray cards;
        for (int i=0; i<90; ++i) cards.append(MusicData::item("playlist", QString::number(67000+i), "关注歌单 " + QString::number(i), "听众"));
        discover.items = cards; discover.tab = "following"; discover.category = "测试筛选";
        hud.openModal("discover"); hud.query = "保留查询"; hud.listOffset = 7; music.uid = "67";
        auto song = MusicData::item("song", "670001", "队列叠加测试", "歌手");
        player.queue = QJsonArray{song, MusicData::item("song", "670002", "第二首", "歌手")};
        player.current = song; player.index=0; refresh();
        auto *loader = findVisual(window->contentItem(), "discoverGlassLoader");
        QPointer<QObject> page = loader ? loader->property("item").value<QObject *>() : nullptr;
        auto *scroll = findVisual(window->contentItem(), "discoverScroll");
        if (scroll) {
            const auto point = scroll->mapToScene(QPointF(80, scroll->height()/2));
            QWheelEvent wheel(point, window->mapToGlobal(point.toPoint()), QPoint(), QPoint(0,-480), Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
            QCoreApplication::sendEvent(window,&wheel); settle(400);
        }
        const auto y = scroll ? scroll->property("contentY").toDouble() : 0.;
        check(page && scroll && y>0, "Following page actually scrolls before opening the queue");
        check(scroll && !scroll->property("moving").toBool(), "Following wheel is settled before recording the retained position");
        const auto reportRetention = [&] (const char *phase) {
            qInfo() << "G68 retention" << phase << "queue" << hud.queueOpen << "picker" << hud.queueCollectionOpen
                    << "modal" << hud.modal << "samePage" << (page && loader->property("item").value<QObject *>()==page.data())
                    << "scroll" << (scroll ? scroll->property("contentY").toDouble() : -1.) << "expectedScroll" << y
                    << "moving" << (scroll && scroll->property("moving").toBool())
                    << "sameData" << (discover.items==cards) << "tab" << discover.tab << "category" << discover.category
                    << "query" << hud.query << "offset" << hud.listOffset << "samePlayback" << (player.current==song)
                    << "queueSize" << player.queue.size();
        };
        const auto clickQueueButton = [&] {
            auto *button = findVisual(window->contentItem(), "nativeHit_player:open");
            if (!button || !button->isVisible()) { check(false, "actual footer queue button is visible"); return; }
            const auto point = button->mapToScene(QPointF(button->width()/2, button->height()/2));
            QMouseEvent move(QEvent::MouseMove, point, window->mapToGlobal(point.toPoint()), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
            QCoreApplication::sendEvent(window, &move); settle(100);
            for (const auto type : {QEvent::MouseButtonPress, QEvent::MouseButtonRelease}) {
                QMouseEvent mouse(type, point, window->mapToGlobal(point.toPoint()), Qt::LeftButton,
                    type == QEvent::MouseButtonPress ? Qt::LeftButton : Qt::NoButton, Qt::NoModifier);
                QCoreApplication::sendEvent(window, &mouse);
            }
            refresh();
        };
        for (int i=0; i<3; ++i) {
            clickQueueButton();
            reportRetention("opened");
            check(findVisual(window->contentItem(),"globalSearch")&&!findVisual(window->contentItem(),"globalSearch")->isEnabled()&&findVisual(window->contentItem(),"queueClose")&&findVisual(window->contentItem(),"queueClose")->isEnabled(),"G78 queue input stays active and background hover/click surfaces are disabled");
            check(hud.queueOpen && hud.modal=="discover" && page && loader->property("item").value<QObject *>()==page.data() &&
                scroll->property("contentY").toDouble()==y && discover.items==cards && discover.tab=="following" &&
                discover.category=="测试筛选" && hud.query=="保留查询" && hud.listOffset==7,
                "queue retains the same Following instance, scroll, filter, query and loaded data");
            if (i==0) {
                backend.action("player:queue-collect:1:netease%3A670002"); refresh();
                check(hud.queueCollectionOpen && hud.modal=="discover" && page && loader->property("item").value<QObject *>()==page.data(),
                    "queue collection overlays Following without replacing its Loader");
                backend.action("queue-collection-close"); refresh();
                reportRetention("picker closed");
                check(hud.queueOpen && !hud.queueCollectionOpen && scroll->property("contentY").toDouble()==y,
                    "closing collection returns to the same open queue and Following scroll");
            }
            clickQueueButton();
            reportRetention("closed");
            check(!hud.queueOpen && hud.modal=="discover" && page && loader->property("item").value<QObject *>()==page.data() &&
                scroll->property("contentY").toDouble()==y && player.current==song && player.queue.size()==2,
                "ordinary queue close changes neither navigation, playback nor queue contents");
        }
        clickQueueButton();
        window->grabWindow().save(output + "/preview-g67-following-queue.png");
        backend.action("back"); refresh();
        check(!hud.queueOpen && hud.modal=="discover" && page, "Escape/back dismisses only the foreground queue");
        discover.items=oldItems; discover.tab=oldTab; discover.category=oldCategory;
        hud.modal=oldModal; hud.query=oldQuery; hud.listOffset=oldOffset;
        player.queue=oldQueue; player.current=oldCurrent; player.index=oldIndex; music.uid=oldUid;
        refresh();
    }
    // G65: dispatch real window mouse/wheel events through Main.qml, not
    // backend.action shortcuts. In G64 the queue was trapped below inputLayer.
    {
        const auto savedFixture = backend.host.fixture;
        const auto savedUid = music.uid;
        const auto savedQueue = player.queue;
        const auto savedCurrent = player.current;
        const auto savedIndex = player.index;
        const auto savedPlaylists = music.lists[2];
        const auto savedSelected = music.current;
        const auto savedDirectory = music.directory;
        QString writtenIds;
        QStringList successfulIds;
        QVector<int> successfulBatchSizes;
        int writeRequests = 0;
        bool correctWriteTarget = true;
        bool rejectQueueWrite = false;
        backend.host.fixture = [savedFixture, &writtenIds, &successfulIds, &successfulBatchSizes,
                                &writeRequests, &correctWriteTarget, &rejectQueueWrite](QString route, QJsonObject args) {
            if (route == "/playlist/tracks") {
                ++writeRequests;
                writtenIds = args["tracks"].toString();
                correctWriteTarget &= args["pid"] == "6501" && args["op"] == "add";
                if (!rejectQueueWrite) {
                    const auto batch = writtenIds.split(',');
                    successfulIds.append(batch);
                    successfulBatchSizes.append(batch.size());
                }
                return QJsonObject{{"body", QJsonObject{{"code", rejectQueueWrite ? 500 : 200}}}};
            }
            return savedFixture(route, args);
        };
        const auto waitQueueWrite = [&] {
            QElapsedTimer timer; timer.start();
            while (music.writeLoading && timer.elapsed() < 5000) { settle(20); }
            refresh();
            check(!music.writeLoading, "queue playlist mutation completes within fixture deadline");
        };
        music.uid = "42";
        auto target = MusicData::item("playlist", "6501", "队列收藏测试");
        target["creatorID"] = "42";
        music.lists[2] = QJsonArray{target};
        QJsonArray huge;
        for (int i = 0; i < 4080; ++i) {
            auto song = MusicData::item("song", QString::number(650000 + i), "队列歌曲 " + QString::number(i), "测试歌手");
            song["cover"] = artworkURL; song["duration"] = 180000;
            song["queueSource"] = target;
            huge.append(song);
        }
        player.queue = huge; player.current = huge.first().toObject(); player.index = 0;
        hud.lyricsMode = false; hud.queueOffset = 0;
        hud.openModal("player"); refresh();
        const auto move = [&](QQuickItem *item) {
            if (!item) { return; }
            const auto point = item->mapToScene(QPointF(item->width()/2, item->height()/2));
            QMouseEvent event(QEvent::MouseMove, point, window->mapToGlobal(point.toPoint()), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
            QCoreApplication::sendEvent(window, &event); settle(150);
        };
        const auto click = [&](const QString &name) {
            auto *item = findVisual(window->contentItem(), name);
            if (!item || !item->isVisible() || !item->isEnabled()) { return false; }
            move(item);
            const auto point = item->mapToScene(QPointF(item->width()/2, item->height()/2));
            for (const auto type : {QEvent::MouseButtonPress, QEvent::MouseButtonRelease}) {
                QMouseEvent event(type, point, window->mapToGlobal(point.toPoint()), Qt::LeftButton,
                    type == QEvent::MouseButtonPress ? Qt::LeftButton : Qt::NoButton, Qt::NoModifier);
                QCoreApplication::sendEvent(window, &event);
            }
            refresh(); return true;
        };
        auto *queueLoader = findVisual(window->contentItem(), "glassQueueLoader");
        check(queueLoader && queueLoader->parentItem() == window->contentItem(), "queue is a root sibling above the full-page input layer");
        auto *row = findVisual(window->contentItem(), "queueRow_1");
        move(row);
        check(row && row->property("hovered").toBool(), "real mouse movement highlights a queue row");
        window->grabWindow().save(output + "/preview-player-queue.png");
        check(click("queueRowPlay_1") && player.index == 1, "real row click switches current queue track");
        check(click("queueCoverPlay_2") && player.index == 2, "cover overlay click plays its own song");
        // Clickable source navigates without replacing or starting playback.
        const auto beforeSource = player.current.value("id");
        move(findVisual(window->contentItem(), "queueRow_1"));
        check(click("queueSource_1") && music.directory && music.directory->item.value("id") == "6501" &&
              player.current.value("id") == beforeSource, "source opens its playlist and preserves playback");
        music.directory.reset(); // collection target need not be the browsed source
        hud.openModal("player"); refresh();
        auto *list = findVisual(window->contentItem(), "playerQueueList");
        if (list) {
            const auto point = list->mapToScene(QPointF(list->width()/2,list->height()/2));
            QWheelEvent wheel(point, window->mapToGlobal(point.toPoint()), QPoint(), QPoint(0,-240), Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
            QCoreApplication::sendEvent(window, &wheel); settle(400);
        }
        check(list && list->property("contentY").toDouble() > 0, "wheel scrolls the real queue ListView");
        check(click("queueNext") && hud.state().value("queueRows").toArray().first().toObject().value("index").toInt() == 40,
              "next page exports global indices starting at 40");
        check(click("queueRowPlay_41") && player.index == 41, "second-page row plays absolute index 41, not local index 1");
        move(findVisual(window->contentItem(), "queueRow_42"));
        const auto oldSize = player.queue.size();
        check(click("queueRemove_42") && player.queue.size() == oldSize-1 && player.index == 41 &&
              player.queue.at(42).toObject().value("id") == "650043", "remove click changes queue data and preserves the current track");
        // A rendered identity from before removal cannot act on the next song.
        backend.action("player:queue-play:42:netease%3A650042"); refresh();
        check(player.index == 41, "stale queue identity cannot play a shifted row");
        move(findVisual(window->contentItem(), "queueRow_43"));
        writtenIds.clear();
        check(click("queueCollect_43") && hud.queueCollectionOpen, "row collection click opens existing playlist picker");
        const auto chosenId = player.queue.at(43).toObject().value("id").toString();
        music.current = huge.first().toObject(); // browsing selection deliberately differs
        backend.action("music:playlist-pick:6501"); waitQueueWrite();
        check(writtenIds == chosenId, "playlist write uses the queue selection, not the browsed or playing song");
        hud.openModal("player"); refresh();
        check(click("queueCollectAll") && hud.queueCollectionOpen && hud.queueCollectionTracks.size() == player.queue.size(),
              "collect-all click captures the complete queue across all pages");
        const auto snapshotSize = hud.queueCollectionTracks.size();
        QStringList expectedIds;
        for (const auto &value : hud.queueCollectionTracks) { expectedIds.append(value.toObject()["id"].toString()); }
        successfulIds.clear(); successfulBatchSizes.clear(); writeRequests = 0;
        rejectQueueWrite = true;
        backend.action("music:playlist-pick:6501"); waitQueueWrite();
        check(hud.queueCollectionOpen && hud.queueCollectionTracks.size() == snapshotSize &&
              writeRequests == 1 && successfulIds.isEmpty(),
              "failed collection stops later batches and keeps the full picker snapshot for retry");
        rejectQueueWrite = false; writeRequests = 0;
        backend.action("music:playlist-pick:6501"); waitQueueWrite();
        check(successfulIds == expectedIds && QSet<QString>(successfulIds.begin(), successfulIds.end()).size() == snapshotSize &&
              correctWriteTarget && hud.queueCollectionTracks.isEmpty() && !hud.queueCollectionOpen,
              "bulk collection writes all unique queue IDs through the existing mutation API");
        check(writeRequests == (snapshotSize + 99) / 100 &&
              std::all_of(successfulBatchSizes.begin(), successfulBatchSizes.end(), [](int size) { return size > 0 && size <= 100; }),
              "bulk collection verifies every ordered batch with at most 100 IDs per request");
        hud.openModal("player"); hud.queueOffset = std::max(0, int(player.queue.size())-40); refresh();
        check(click("queuePrevious") && hud.queueOffset == int(player.queue.size())-80, "previous-page click works from the final page");
        check(click("queueClear") && player.queue.size() == 1 && player.index == 0 && hud.queueOffset == 0,
              "clear click removes queued tracks, keeps current playback and resets the page");
        check(click("queueClose") && !hud.queueOpen, "close click actually dismisses the queue");
        settle(300);
        player.queue = savedQueue; player.current = savedCurrent; player.index = savedIndex;
        music.current = savedSelected; music.directory = savedDirectory;
        music.lists[2] = savedPlaylists; music.uid = savedUid;
        backend.host.fixture = savedFixture;
        hud.queueOpen = false; hud.queueCollectionOpen = false;
        hud.modal.clear(); hud.closing = false; hud.queueOffset = 0; refresh();
    }
    // G66: real source records survive queue operations and navigate internally.
    {
        const auto savedQueue = player.queue; const auto savedCurrent = player.current;
        const auto savedIndex = player.index; const auto savedMode = player.mode; player.mode = "all";
        const auto savedDirectory = music.directory;
        const auto savedSelection = music.current; const auto savedContext = music.playContext;
        const auto savedUid = music.uid; const auto savedKeyword = music.keyword;
        const auto savedDetails = music.details;
        const auto fixture = backend.host.fixture;
        auto song = MusicData::item("song", "660001", "来源回归测试", "测试歌手");
        song["duration"] = 180000; song["albumID"] = "660200";
        auto second = MusicData::item("song", "660002", "追加歌曲", "测试歌手");
        music.uid = "42";
        auto listA = MusicData::item("playlist", "660101", "歌单 A");
        auto listB = MusicData::item("playlist", "660102", "歌单 B");
        const auto sourceA = MusicData::queueSource(listA), sourceB = MusicData::queueSource(listB);
        check(MusicData::queueSource(song).isEmpty(), "a song's album ID never becomes an inferred queue origin");
        auto folder = std::make_shared<MusicDirectory>();
        folder->item = listA; folder->songs = QJsonArray{song}; folder->ids = QJsonArray{song.value("id")};
        music.directory = folder; music.playContext = {};
        music.playDirectory();
        check(player.queue.size() == 1 && player.queue.first().toObject().value("queueSource").toObject() == sourceA,
              "one-click playlist playback stamps every queued entry's actual origin");
        music.current = MusicData::withQueueSource(second, listB);
        backend.action("music:enqueue");
        check(player.queue.size() == 2 && player.queue.at(0).toObject().value("queueSource").toObject() == sourceA &&
              player.queue.at(1).toObject().value("queueSource").toObject() == sourceB,
              "single-song append preserves distinct sources on adjacent queue entries");
        music.directory.reset(); music.playContext = player.queue;
        music.current = MusicData::withQueueSource(song, listA);
        music.play(true);
        check(player.queue.at(0).toObject().value("queueSource").toObject() == sourceA &&
              player.queue.at(1).toObject().value("queueSource").toObject() == sourceB,
              "replaying a mixed queue must not stamp one song's origin onto every entry");
        player.play(MusicData::withQueueSource(song, listB));
        check(player.queue.first().toObject().value("queueSource").toObject() == sourceB,
              "manually selecting the same song from another playlist records the new entry context");
        player.next(1); player.next(-1);
        check(player.current.value("queueSource").toObject() == sourceB,
              "next and previous retain each entry's stored origin");
        music.details[song.value("key").toString()] = MusicData::withQueueSource(song, listA);
        music.choose(MusicData::withQueueSource(song, listB), false, false);
        check(music.current.value("queueSource").toObject() == sourceB,
              "metadata cache cannot overwrite the newly selected source with an older song context");
        backend.host.fixture = [fixture, song](QString route, QJsonObject args) {
            if (route == "/native/netease/songs") {
                return QJsonObject{{"body", QJsonObject{{"code", 200}, {"value", QJsonArray{song}}}}};
            }
            return fixture(route, args);
        };
        auto deferred = MusicData::withQueueSource(song, listA); deferred["deferred"] = true;
        player.play(deferred, QJsonArray{deferred});
        QElapsedTimer deferredWait; deferredWait.start();
        while (player.current.value("deferred").toBool() && deferredWait.elapsed() < 5000) { settle(20); }
        check(!player.current.value("deferred").toBool(), "deferred metadata actually completes before source verification");
        check(player.current.value("queueSource").toObject() == sourceA &&
              player.queue.first().toObject().value("queueSource").toObject() == sourceA,
              "asynchronous song metadata enrichment retains queue origin");
        backend.host.fixture = fixture;
        for (const auto &kind : {QString("playlist"), QString("album"), QString("artist")}) {
            auto origin = MusicData::item(kind, "660111", "真实来源 " + kind);
            if (kind == "playlist") { origin["originType"] = "chart"; }
            const auto entry = MusicData::withQueueSource(song, origin);
            player.queue = QJsonArray{entry}; player.current = entry; player.index = 0;
            const auto before = player.queue; const auto playing = player.current;
            backend.action("player:queue-source:0:netease%3A660001");
            check(music.directory && music.directory->item.value("id") == "660111" &&
                  music.directory->item.value("kind") == kind && player.queue == before && player.current == playing,
                  "source action navigates to the real playlist/chart/album/artist without changing playback");
        }
        player.queue = QJsonArray{song}; player.current = song;
        const auto beforeFolder = music.directory;
        backend.action("player:queue-source:0:netease%3A660001");
        check(music.directory == beforeFolder && !hud.state().value("queueRows").toArray().size(),
              "missing provenance cannot navigate to an invented album or platform page");
        const QJsonObject search{{"route", "search"}, {"type", "search"}, {"id", "音乐"},
            {"query", "音乐"}, {"searchKind", "song"}, {"title", "搜索：音乐"}, {"provider", "netease"}};
        player.queue = QJsonArray{MusicData::withQueueSource(song, search)};
        backend.action("player:queue-source:0:netease%3A660001");
        check(hud.modal == "search" && hud.query == "音乐" && player.current.value("id") == song.value("id"),
              "search origin restores the saved query without replaying a song");
        const QJsonObject daily{{"route", "discover"}, {"type", "daily"}, {"id", "daily"},
            {"tab", "daily"}, {"title", "每日推荐"}, {"provider", "netease"}};
        player.queue = QJsonArray{MusicData::withQueueSource(song, daily)};
        backend.action("player:queue-source:0:netease%3A660001");
        check(hud.modal == "discover" && music.discover->tab == "daily", "daily source returns to its actual discovery list");
        // Glass visibility and Loader identity remain stable under queue toggles.
        music.directory.reset(); music.current = song; hud.modal.clear(); hud.closing = false;
        hud.lyricsMode = false; hud.commentsOpen = false; hud.tab = "overview";
        backend.scene.setMode("archive"); hud.textFrosted = true; refresh();
        auto *glass = findVisual(window->contentItem(), "textFrostedLoader");
        auto *rail = findVisual(window->contentItem(), "sideNavigationRail");
        auto *material = glass ? glass->property("item").value<QObject *>() : nullptr;
        check(material && rail && rail->isVisible(), "page glass and navigation glass are present before queue opens");
        hud.openModal("player"); refresh();
        check(glass && glass->property("item").value<QObject *>() == material && rail && rail->isVisible(),
              "queue does not destroy or hide either underlying glass panel");
        auto *queue = findVisual(window->contentItem(), "glassQueueLoader");
        check(queue && queue->property("active").toBool() && queue->z() > 300,
              "queue remains foreground above navigation and page glasses");
        window->grabWindow().save(output + "/preview-g66-layered-glass.png");
        backend.action("queue-close"); refresh();
        check(glass && glass->property("item").value<QObject *>() == material,
              "closing queue keeps the original page glass instance");
        music.directory = savedDirectory; music.current = savedSelection; music.playContext = savedContext;
        music.details = savedDetails; music.keyword = savedKeyword; music.uid = savedUid;
        player.queue = savedQueue; player.current = savedCurrent; player.index = savedIndex; player.mode = savedMode;
        hud.queueOpen = false; hud.queueCollectionOpen = false;
        hud.modal.clear(); hud.closing = false;
    }
    // G70: enter FM from a retained playlist through the actual dispatcher.
    {
        auto &player=music.player;const auto fixture=backend.host.fixture;const auto uid=music.uid;
        const auto queue=player.queue;const auto playing=player.current;const int index=player.index;
        const auto folder=music.directory;const auto selection=music.current;const bool info=music.directoryInfo;
        int picks=0,trash=0;backend.host.fixture=[fixture,&picks,&trash](QString route,QJsonObject args){
            if(route=="/personal/fm/mode")return QJsonObject{{"body",QJsonObject{{"code",200},{"data",QJsonArray{QJsonObject{{"id",707000+(++picks)},{"name","FM station fixture"},{"artists",QJsonArray{}},{"album",QJsonObject{}}}}}}}};
            if(route=="/fm_trash"){++trash;return QJsonObject{{"body",QJsonObject{{"code",200}}}};}
            return fixture(route,args);
        };
        music.uid="42";music.directory=std::make_shared<MusicDirectory>();music.directory->item=MusicData::item("playlist","707099","Retained FM origin");music.directoryInfo=true;music.current=music.directory->item;
        hud.modal.clear();hud.lyricsMode=false;backend.scene.setMode("detail");refresh();
        backend.action("discover:tab:roam");settle(450);refresh();
        check(player.roamActive&&hud.lyricsMode&&music.current["id"]=="707001"&&hud.modal!="discover", "G70 roam entry uses personalized FM and the current-song lyric page from a playlist");
        backend.action("player:next");settle(450);refresh();check(picks==2&&trash==0&&player.current["id"]=="707002","G70 FM skip fetches a fresh station pick without dislike feedback");
        backend.action("roam:dislike");settle(450);refresh();check(trash==1&&picks==3&&player.current["id"]=="707003","G70 FM dislike submits real feedback before continuing recommendations");
        backend.action("roam:exit");settle(150);refresh();
        qInfo()<<"G70 FM restore"<<"sameQueue"<<(player.queue==queue)<<"sameSong"<<(player.current==playing)<<"sameIndex"<<(player.index==index)<<"roamActive"<<player.roamActive<<"lyrics"<<hud.lyricsMode;
        check(!player.roamActive&&!hud.lyricsMode&&player.queue==queue&&player.current==playing&&player.index==index,"G70 leaving FM restores the original ordinary playback context");
        backend.host.fixture=fixture;music.uid=uid;music.directory=folder;music.directoryInfo=info;music.current=selection;
    }
    {
        // Exercise the actual footer QML button, including from a separate modal.
        const auto savedPlaying=music.player.current;
        const auto savedQueue=music.player.queue;
        const auto savedIndex=music.player.index;
        const auto savedMode=music.player.mode;
        auto currentSong=MusicData::withQueueSource(song,playlistChoice);
        music.player.current=currentSong;music.player.queue={currentSong};music.player.index=0;
        music.player.roamActive=false;music.player.changed();
        hud.openModal("settings");refresh();
        auto *entry=findVisual(window->contentItem(),"globalNowPlaying");
        check(entry&&entry->isVisible()&&entry->isEnabled(),"G88 global now-playing entry remains available from settings");
        if(entry){
            const auto point=entry->mapToScene(QPointF(entry->width()/2,entry->height()/2));
            for(const auto type:{QEvent::MouseButtonPress,QEvent::MouseButtonRelease}){
                QMouseEvent mouse(type,point,window->mapToGlobal(point.toPoint()),Qt::LeftButton,type==QEvent::MouseButtonPress?Qt::LeftButton:Qt::NoButton,Qt::NoModifier);
                QCoreApplication::sendEvent(window,&mouse);
            }
            refresh();
        }
        check(hud.modal.isEmpty()&&hud.frame["mode"]=="archive"&&!music.directory&&findVisual(window->contentItem(),"nowPlayingPanel"),"G88 footer click opens the current song in the existing home glass");
        check(music.player.current==currentSong&&music.player.queue==QJsonArray{currentSong}&&music.player.index==0,"G88 global entry never restarts playback or replaces its queue");
        auto *desktop=findVisual(window->contentItem(),"nativeHit_desktop:toggle");
        const auto volumeBounds=backend.state().value("volume").toMap();const auto stageUnit=window->height()/1080.;
        check(desktop&&entry&&(volumeBounds.value("x").toDouble()+volumeBounds.value("width").toDouble())*stageUnit<desktop->mapToScene(QPointF()).x()&&desktop->mapToScene(QPointF(desktop->width(),0)).x()<entry->mapToScene(QPointF()).x(),"G88 volume, desktop lyrics and global now-playing have separate aligned hit regions");
        auto *field=findVisual(window->contentItem(),"nowDiscField");auto *page=findVisual(window->contentItem(),"nowPlayingPanel");auto *disc=findVisual(window->contentItem(),"nowRecord");
        check(field&&field->clip()&&page&&disc&&disc->width()>page->width()*.45,"G88 immersive disc is enlarged inside its bounded fading field");
        if(page&&disc&&field){
            const auto expected=std::min(490*stageUnit,page->width()*.60);
            check(std::abs(disc->width()-expected)<.01&&std::abs(disc->mapToItem(page,QPointF()).x()-(page->width()-expected+38*stageUnit))<.01,"G92 record restores exact G88 size and rightward placement without fitting its rim inward");
            check(std::abs(field->width()-page->width())<.01&&std::abs(field->height()-page->height())<.01,"G92 visual field has unchanged glass bounds");
        }
        // Exercise intermediate arm poses through the actual player adapter,
        // not just the final angle. Ordinary state notifications cannot rewind it.
        if(page&&!backend.state().value("reduced").toBool()){
            const auto savedState=music.player.state;
            const bool savedLoading=music.player.loading,savedFailed=music.player.failed;
            auto waitMotion=[&](auto predicate,int timeout=5000){
                QElapsedTimer clock;clock.start();
                while(!predicate()&&clock.elapsed()<timeout)settle(20);
                return predicate();
            };
            check(waitMotion([&]{return !page->property("recordTransitioning").toBool();}),"G97 initial record preparation completes");
            auto *arm=findVisual(window->contentItem(),"nowTonearmPlane");
            music.player.loading=false;music.player.failed=false;music.player.state["playing"]=true;music.player.changed();settle(550);
            check(arm&&arm->property("pose").toDouble()<.01,"G97 playing arm settles inward");
            if(arm){
                music.player.state["playing"]=false;music.player.changed();settle(140);
                const double middle=arm->property("pose").toDouble();
                check(middle>.02&&middle<.98,"G97 pause has visible intermediate motion");
                bool monotonic=true;double prior=middle;
                for(int tick=0;tick<12;++tick){
                    music.player.changed();settle(30);
                    const double current=arm->property("pose").toDouble();
                    monotonic=monotonic&&current>=prior-.002;prior=current;
                }
                check(monotonic&&prior>.99,"G97 playback notifications never restart the pause animation");
                music.player.state["playing"]=true;music.player.changed();settle(140);
                const double inward=arm->property("pose").toDouble();
                check(inward>.02&&inward<.98,"G97 resume has visible intermediate motion");
                music.player.state["playing"]=false;music.player.changed();
                check(std::abs(arm->property("pose").toDouble()-inward)<.02,"G97 reversal starts at the current pose");
                settle(550);
                music.player.state["playing"]=true;music.player.changed();settle(550);
                music.player.loading=true;music.player.changed();settle(500);
                check(arm->property("pose").toDouble()<.01,"G97 buffering does not pose as user pause");
                music.player.loading=false;music.player.changed();
                auto nextSong=currentSong;nextSong["id"]="9911101";nextSong["key"]="netease:song:9911101";
                music.player.current=nextSong;music.player.changed();settle(120);
                const double lifting=arm->property("pose").toDouble();
                nextSong["id"]="9911102";nextSong["key"]="netease:song:9911102";
                music.player.current=nextSong;music.player.changed();
                check(std::abs(arm->property("pose").toDouble()-lifting)<.02,"G97 rapid track selection never resets the arm");
                check(waitMotion([&]{return page->property("swapStage").toString()=="swapping";}),"G97 prepared artwork starts the record swap");
                check(arm->property("pose").toDouble()>.99,"G97 arm clears before records move");
                check(waitMotion([&]{return !page->property("recordTransitioning").toBool();}),"G97 latest rapid track completes its swap");
                auto *front=findVisual(window->contentItem(),"nowRecord");
                check(front&&front->property("visualSession").toString()==MusicPlayer::identity(nextSong),"G97 latest track owns the displayed record");
                settle(550);
                check(arm->property("pose").toDouble()<.01,"G97 arm returns smoothly after the swap");
            }
            music.player.state=savedState;music.player.loading=savedLoading;music.player.failed=savedFailed;
            music.player.current=currentSong;music.player.changed();
        }
        hud.openModal("player");refresh();entry=findVisual(window->contentItem(),"globalNowPlaying");
        check(entry&&!entry->isEnabled(),"G88 queue modal blocks the now-playing shortcut with all other background controls");
        backend.action("queue-close");refresh();
        window->grabWindow().save(output+"/preview-g88-immersive-now-playing.png");
        music.player.current=savedPlaying;music.player.queue=savedQueue;music.player.index=savedIndex;music.player.mode=savedMode;
        music.player.changed();
    }
    qInfo() << "Frosted UI rendering and settings:" << (ok ? "passed" : "FAILED");
    return ok ? 0 : 1;
}
