#include "TaskbarIntegration.h"
#include <QCoreApplication>
#include <QGuiApplication>
#include <QScreen>
#include <QDebug>
#include <QElapsedTimer>
#include <QThread>
#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>
#include <shobjidl.h>
#endif

bool runTaskbarChecks() {
    bool ok = true;
    const auto check = [&](bool result, const char *message) {
        if (!result) { qCritical() << "Taskbar check failed:" << message; ok = false; }
    };
    const auto settle = [] {
        QElapsedTimer time; time.start();
        while (time.elapsed() < 100) { QCoreApplication::processEvents(); QThread::msleep(5); }
    };
    QWindow window; window.setTitle("Taskbar integration regression"); window.resize(320, 320);
    const auto qaScreenName = qEnvironmentVariable("RHINE_QA_SCREEN");
    if (!qaScreenName.isEmpty()) {
        QScreen *qaScreen = nullptr;
        for (auto *screen : QGuiApplication::screens()) {
            if (screen->name() == qaScreenName) { qaScreen = screen; break; }
        }
        if (!qaScreen) { qCritical() << "QA screen not found:" << qaScreenName; return false; }
        window.setScreen(qaScreen);
        window.setPosition(qaScreen->geometry().topLeft() + QPoint(100, 100));
    }
    window.show();
    QStringList commands;
    {
        TaskbarIntegration integration(&window, [&](QString command) { commands.append(command); });
        TaskbarPlayback song;
        song.identity = "netease:1"; song.title = "第一首"; song.artist = "测试歌手";
        song.playable = song.previous = song.next = song.canLike = true;
        song.artwork = QImage(48, 48, QImage::Format_ARGB32); song.artwork.fill(QColor("#f6ead4"));
        integration.update(song); settle();
        check(integration.windowTitle() == "第一首 — 测试歌手", "taskbar title uses the playing song and artist");
        const auto first = integration.thumbnail(QSize(320, 180));
        check(first.size() == QSize(180, 180) && first.pixelColor(90, 90).name() == "#f6ead4", "thumbnail respects native bounds and uses decoded cover art");
        const auto revision = integration.diagnostics().value("artworkRevision").toInt();
        integration.update(song);
        check(integration.diagnostics().value("artworkRevision").toInt() == revision, "unchanged playback does not regenerate cover bitmaps");
        song.playing = true; integration.update(song);
        check(integration.diagnostics().value("artworkRevision").toInt() == revision, "pause state refreshes controls without re-encoding artwork");
        for (int i = 0; i < 4; ++i) { check(integration.trigger(i), "enabled thumbnail control dispatches"); }
        check(commands == QStringList{"player:prev", "player:toggle", "player:next", "music:like-current"}, "all four buttons use existing player commands");
        song.canLike = false; integration.update(song);
        check(!integration.trigger(3) && !integration.trigger(-1) && !integration.trigger(4), "disabled and invalid buttons cannot dispatch");
        song.identity = "netease:2"; song.title = "第二首"; song.artwork = {}; integration.update(song);
        check(integration.thumbnail(QSize(200, 200)).pixelColor(100, 100).name() != "#f6ead4", "new song with pending artwork clears the previous cover");
        song.artwork = QImage(48, 48, QImage::Format_ARGB32); song.artwork.fill(QColor("#bfd3c8")); integration.update(song);
        check(integration.thumbnail(QSize(200, 200)).pixelColor(100, 100).name() == "#bfd3c8", "late artwork updates on the same track");
        song.liked = true; song.canLike = true; integration.update(song);
        window.showMinimized(); settle();
        song.playing = false; integration.update(song);
        check(window.visibility() == QWindow::Minimized, "playback updates keep a minimized window minimized");
#ifdef Q_OS_WIN
        commands.clear();
        const auto handle = reinterpret_cast<HWND>(window.winId());
        for (int i = 0; i < 4; ++i) { SendMessageW(handle, WM_COMMAND, MAKEWPARAM(0x5201 + i, THBN_CLICKED), 0); settle(); }
        check(commands == QStringList{"player:prev", "player:toggle", "player:next", "music:like-current"}, "real Windows thumbnail messages reach the application commands");
        commands.clear(); song.canLike = false; integration.update(song);
        SendMessageW(handle, WM_COMMAND, MAKEWPARAM(0x5204, THBN_CLICKED), 0); settle();
        check(commands.isEmpty(), "native disabled heart ignores stale shell clicks");
        // A shell click queued just before a track change must never like the next track.
        song.canLike = true; integration.update(song);
        SendMessageW(handle, WM_COMMAND, MAKEWPARAM(0x5204, THBN_CLICKED), 0);
        song.identity = "netease:3"; integration.update(song); settle();
        check(commands.isEmpty(), "queued clicks do not affect a different song");
        SendMessageW(handle, WM_DWMSENDICONICTHUMBNAIL, 0, MAKELPARAM(180, 240));
        qInfo() << "Windows taskbar native availability:" << integration.diagnostics();
#endif
        integration.update({});
        check(!integration.trigger(1) && integration.windowTitle() == "RHINE MUSIC DATABASE", "empty player disables controls and resets title");
    }
    check(window.title() == "Taskbar integration regression", "adapter releases its window title on shutdown");
    window.close();
    qInfo() << "Taskbar cover, commands, state isolation and minimized updates:" << (ok ? "passed" : "FAILED");
    return ok;
}
