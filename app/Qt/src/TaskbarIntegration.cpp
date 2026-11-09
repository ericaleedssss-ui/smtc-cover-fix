#include "TaskbarIntegration.h"
#include <QCoreApplication>
#include <QEvent>
#include <QGuiApplication>
#include <QPainter>
#include <QPainterPath>
#include <QStyleHints>
#include <QTimer>
#include <algorithm>
#include <array>
#include <cstring>
#include <vector>
#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>
#include <commctrl.h>
#include <shobjidl.h>
#endif

struct TaskbarIntegration::Native {
#ifdef Q_OS_WIN
    TaskbarIntegration *owner;
    HWND hwnd = nullptr;
    ITaskbarList3 *taskbar = nullptr;
    std::array<HICON, 4> icons{};
    UINT createdMessage = RegisterWindowMessageW(L"TaskbarButtonCreated");
    bool ready = false;
    bool apartment = false;
    int attempts = 0;
    HRESULT thumbnailResult = S_FALSE;
    void configureFrame() {
        if (!hwnd || !owner->m_window || !(owner->m_window->flags() & Qt::FramelessWindowHint)) return;
        const bool full = owner->m_window->windowState() == Qt::WindowFullScreen;
        const auto oldStyle = GetWindowLongPtrW(hwnd, GWL_STYLE);
        auto style = oldStyle;
        if (full) style &= ~(WS_CAPTION | WS_THICKFRAME);
        else style |= WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
        if (style != oldStyle) {
            SetWindowLongPtrW(hwnd, GWL_STYLE, style);
            SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
        }
        const BOOL disabled = FALSE;
        DwmSetWindowAttribute(hwnd, DWMWA_TRANSITIONS_FORCEDISABLED, &disabled, sizeof(disabled));
    }
    static constexpr UINT FirstButton = 0x5201;

    explicit Native(TaskbarIntegration *value) : owner(value) {
        apartment = SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED));
        retry();
    }
    ~Native() {
        if (hwnd && IsWindow(hwnd)) {
            RemoveWindowSubclass(hwnd, windowProcedure, reinterpret_cast<UINT_PTR>(this));
            const BOOL disabled = FALSE;
            DwmSetWindowAttribute(hwnd, DWMWA_HAS_ICONIC_BITMAP, &disabled, sizeof(disabled));
            DwmSetWindowAttribute(hwnd, DWMWA_FORCE_ICONIC_REPRESENTATION, &disabled, sizeof(disabled));
        }
        for (auto icon : icons) { if (icon) { DestroyIcon(icon); } }
        if (taskbar) { taskbar->Release(); }
        if (apartment) { CoUninitialize(); }
    }
    static HBITMAP bitmap(const QImage &source) {
        const auto image = source.convertToFormat(QImage::Format_ARGB32_Premultiplied);
        BITMAPINFO info{};
        info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        info.bmiHeader.biWidth = image.width();
        info.bmiHeader.biHeight = -image.height();
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        info.bmiHeader.biCompression = BI_RGB;
        void *pixels = nullptr;
        const auto result = CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &pixels, nullptr, 0);
        if (result && pixels) { std::memcpy(pixels, image.constBits(), image.sizeInBytes()); }
        return result;
    }
    HICON icon(int button) const {
        const auto scale = owner->m_window ? owner->m_window->devicePixelRatio() : 1.0;
        const int side = std::clamp(qRound(20 * scale), 20, 80);
        QImage image(side, side, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter p(&image); p.setRenderHint(QPainter::Antialiasing);
        p.scale(side / 24., side / 24.);
        const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
        const auto tint = button == 3 && owner->m_playback.liked ? QColor("#cf4955") :
            QColor(dark ? "#eeeadd" : "#74795f");
        p.setPen(Qt::NoPen); p.setBrush(tint);
        if (button == 0 || button == 2) {
            if (button == 2) { p.translate(24, 0); p.scale(-1, 1); }
            p.drawRect(QRectF(5, 5, 2.5, 14));
            QPainterPath path; path.moveTo(18, 5); path.lineTo(8, 12); path.lineTo(18, 19); path.closeSubpath(); p.drawPath(path);
        } else if (button == 1) {
            if (owner->m_playback.playing) { p.drawRect(QRectF(6, 5, 4, 14)); p.drawRect(QRectF(14, 5, 4, 14)); }
            else { QPainterPath path; path.moveTo(7, 4); path.lineTo(20, 12); path.lineTo(7, 20); path.closeSubpath(); p.drawPath(path); }
        } else {
            QPainterPath path; path.moveTo(12, 20); path.cubicTo(9, 17, 3, 13, 3, 8);
            path.cubicTo(3, 2, 10, 2, 12, 7); path.cubicTo(14, 2, 21, 2, 21, 8);
            path.cubicTo(21, 13, 15, 17, 12, 20); path.closeSubpath();
            if (!owner->m_playback.liked) { p.setBrush(Qt::NoBrush); p.setPen(QPen(tint, 1.8)); }
            p.drawPath(path);
        }
        p.end();
        const auto color = bitmap(image);
        std::vector<BYTE> maskData(((side + 15) / 16) * 2 * side, 0);
        const auto mask = CreateBitmap(side, side, 1, 1, maskData.data());
        ICONINFO info{}; info.fIcon = TRUE; info.hbmColor = color; info.hbmMask = mask;
        const auto result = color && mask ? CreateIconIndirect(&info) : nullptr;
        if (color) { DeleteObject(color); } if (mask) { DeleteObject(mask); }
        return result;
    }
    void buttons(bool add) {
        if (!taskbar || !hwnd) { return; }
        const auto &state = owner->m_playback;
        const std::array<bool, 4> enabled{state.previous, state.playable, state.next, state.canLike};
        const std::array<QString, 4> tips{QStringLiteral("上一首"), state.playing ? QStringLiteral("暂停") : QStringLiteral("播放"),
            QStringLiteral("下一首"), !state.canLike ? QStringLiteral("登录后可收藏；当前歌曲或服务也可能不支持收藏") :
            state.liked ? QStringLiteral("取消喜欢") : QStringLiteral("喜欢这首歌")};
        std::array<THUMBBUTTON, 4> values{};
        std::array<HICON, 4> nextIcons{};
        for (int i = 0; i < 4; ++i) {
            nextIcons[i] = icon(i);
            auto &value = values[i];
            value.dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
            value.iId = FirstButton + i; value.hIcon = nextIcons[i];
            value.dwFlags = enabled[i] ? THBF_ENABLED : THBF_DISABLED;
            tips[i].toWCharArray(value.szTip); value.szTip[tips[i].size()] = L'\0';
        }
        const auto result = add ? taskbar->ThumbBarAddButtons(hwnd, UINT(values.size()), values.data()) :
            taskbar->ThumbBarUpdateButtons(hwnd, UINT(values.size()), values.data());
        if (SUCCEEDED(result)) { ready = true; }
        for (auto old : icons) { if (old) { DestroyIcon(old); } }
        icons = nextIcons;
    }
    static LRESULT CALLBACK windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam,
                                            UINT_PTR id, DWORD_PTR data) {
        auto *self = reinterpret_cast<Native *>(data);
        // Keep the native caption style for DWM minimize/restore transitions,
        // but leave all client pixels to Qt's existing custom chrome.
        if (message == WM_NCCALCSIZE && wParam && self->owner->m_window &&
            (self->owner->m_window->flags() & Qt::FramelessWindowHint)) {
            if (IsZoomed(window) && self->owner->m_window->windowState() != Qt::WindowFullScreen) {
                MONITORINFO monitor{sizeof(MONITORINFO)};
                if (GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor))
                    reinterpret_cast<NCCALCSIZE_PARAMS *>(lParam)->rgrc[0] = monitor.rcWork;
            }
            return 0;
        }
        if (message == WM_NCDESTROY) { RemoveWindowSubclass(window, windowProcedure, id); }
        MSG event{}; event.hwnd = window; event.message = message; event.wParam = wParam; event.lParam = lParam;
        qintptr result = 0;
        if (self->nativeEventFilter({}, &event, &result)) { return LRESULT(result); }
        return DefSubclassProc(window, message, wParam, lParam);
    }
    bool attach() {
        if (!owner->m_window) { return false; }
        const auto handle = reinterpret_cast<HWND>(owner->m_window->winId());
        if (!handle || !IsWindow(handle)) { return false; }
        if (hwnd != handle) { hwnd = handle; ready = false; }
        if (!SetWindowSubclass(hwnd, windowProcedure, reinterpret_cast<UINT_PTR>(this), reinterpret_cast<DWORD_PTR>(this))) { return false; }
        configureFrame();
        const BOOL enabled = TRUE;
        DwmSetWindowAttribute(hwnd, DWMWA_FORCE_ICONIC_REPRESENTATION, &enabled, sizeof(enabled));
        DwmSetWindowAttribute(hwnd, DWMWA_HAS_ICONIC_BITMAP, &enabled, sizeof(enabled));
        if (!taskbar) {
            if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&taskbar)))) { return false; }
            if (FAILED(taskbar->HrInit())) { taskbar->Release(); taskbar = nullptr; return false; }
        }
        if (!ready) { buttons(true); }
        return ready;
    }
    void retry() {
        if (attach() || ++attempts >= 20) { return; }
        QTimer::singleShot(250, owner, [this] { retry(); });
    }
    void changed(bool artwork, bool controls) {
        if (!attach()) { return; }
        if (controls) { buttons(false); }
        if (artwork) { DwmInvalidateIconicBitmaps(hwnd); }
    }
    bool nativeEventFilter(const QByteArray &, void *message, qintptr *result) {
        auto *event = static_cast<MSG *>(message);
        if (!hwnd || event->hwnd != hwnd) { return false; }
        if (createdMessage && event->message == createdMessage) {
            ready = false; attempts = 0;
            if (taskbar) { taskbar->Release(); taskbar = nullptr; }
            retry(); return false;
        }
        if (event->message == WM_NCDESTROY) { hwnd = nullptr; ready = false; return false; }
        if (event->message == WM_THEMECHANGED || event->message == WM_SETTINGCHANGE || event->message == WM_DPICHANGED) {
            QTimer::singleShot(0, owner, [this] { changed(false, true); }); return false;
        }
        if (event->message == WM_COMMAND && HIWORD(event->wParam) == THBN_CLICKED) {
            const int button = int(LOWORD(event->wParam)) - int(FirstButton);
            if (button < 0 || button >= 4) { return false; }
            const auto identity = owner->m_playback.identity;
            QTimer::singleShot(0, owner, [this, button, identity] {
                if (owner->m_playback.identity == identity) { owner->trigger(button); }
            });
            *result = 0; return true;
        }
        if (event->message == WM_DWMSENDICONICTHUMBNAIL || event->message == WM_DWMSENDICONICLIVEPREVIEWBITMAP) {
            const bool thumbnail = event->message == WM_DWMSENDICONICTHUMBNAIL;
            const QSize bounds = thumbnail ? QSize(HIWORD(event->lParam), LOWORD(event->lParam)) :
                QSize(qRound(owner->m_window->width() * owner->m_window->devicePixelRatio()),
                      qRound(owner->m_window->height() * owner->m_window->devicePixelRatio()));
            const auto image = bitmap(owner->thumbnail(bounds));
            if (image) {
                thumbnailResult = thumbnail ? DwmSetIconicThumbnail(hwnd, image, 0) : DwmSetIconicLivePreviewBitmap(hwnd, image, nullptr, 0);
                DeleteObject(image);
            }
            *result = 0; return true;
        }
        return false;
    }
#endif
};

TaskbarIntegration::TaskbarIntegration(QWindow *window, std::function<void(QString)> command)
    : m_window(window), m_command(std::move(command)), m_originalTitle(window ? window->title() : QString()) {
    if (window) { window->installEventFilter(this); }
#ifdef Q_OS_WIN
    m_native = std::make_unique<Native>(this);
#endif
}
TaskbarIntegration::~TaskbarIntegration() {
    m_native.reset();
    if (m_window) { m_window->removeEventFilter(this); m_window->setTitle(m_originalTitle); }
}
QString TaskbarIntegration::windowTitle() const {
    return m_playback.title.isEmpty() ? QStringLiteral("RHINE MUSIC DATABASE") :
        m_playback.title + (m_playback.artist.isEmpty() ? QString() : QStringLiteral(" — ") + m_playback.artist);
}
void TaskbarIntegration::update(const TaskbarPlayback &value) {
    auto next = value;
    if (next.identity.isEmpty()) { next.artwork = {}; }
    const bool artwork = next.identity != m_playback.identity || next.title != m_playback.title ||
        next.artist != m_playback.artist || next.artwork.cacheKey() != m_playback.artwork.cacheKey();
    const bool controls = next.playing != m_playback.playing || next.playable != m_playback.playable ||
        next.previous != m_playback.previous || next.next != m_playback.next || next.canLike != m_playback.canLike || next.liked != m_playback.liked;
    m_playback = next;
    if (artwork) { ++m_artworkRevision; }
    if (controls) { ++m_buttonRevision; }
#ifdef Q_OS_WIN
    if (m_window && artwork) { m_window->setTitle(windowTitle()); }
    if (m_native && (artwork || controls)) { m_native->changed(artwork, controls); }
#endif
}
QImage TaskbarIntegration::thumbnail(QSize bounds) const {
    const int side = std::clamp(std::min(bounds.width(), bounds.height()), 1, 1024);
    QImage image(side, side, QImage::Format_ARGB32_Premultiplied); image.fill(QColor("#f5f0e4"));
    QPainter p(&image); p.setRenderHint(QPainter::SmoothPixmapTransform); p.setRenderHint(QPainter::Antialiasing);
    if (!m_playback.artwork.isNull()) {
        const auto cover = m_playback.artwork.scaled(side, side, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
        p.drawImage(QPoint((side - cover.width()) / 2, (side - cover.height()) / 2), cover);
    } else {
        p.setPen(Qt::NoPen); p.setBrush(QColor("#dcd8c9")); p.drawEllipse(QRectF(side*.17, side*.17, side*.66, side*.66));
        p.setBrush(QColor("#7b8065")); p.drawEllipse(QRectF(side*.44, side*.44, side*.12, side*.12));
    }
    return image;
}
bool TaskbarIntegration::trigger(int button) {
    const std::array<bool, 4> enabled{m_playback.previous, m_playback.playable, m_playback.next, m_playback.canLike};
    const std::array<QString, 4> commands{"player:prev", "player:toggle", "player:next", "music:like-current"};
    if (button < 0 || button >= 4 || !enabled[button] || !m_command) { return false; }
    m_command(commands[button]); return true;
}
QVariantMap TaskbarIntegration::diagnostics() const {
    QVariantMap result{{"artworkRevision", m_artworkRevision}, {"buttonRevision", m_buttonRevision}, {"title", windowTitle()}};
#ifdef Q_OS_WIN
    result["nativeReady"] = m_native && m_native->ready;
    result["thumbnailResult"] = m_native ? qlonglong(m_native->thumbnailResult) : qlonglong(-1);
#endif
    return result;
}
bool TaskbarIntegration::eventFilter(QObject *watched, QEvent *event) {
#ifdef Q_OS_WIN
    if (watched == m_window && m_native && (event->type() == QEvent::Show || event->type() == QEvent::WinIdChange || event->type() == QEvent::WindowStateChange)) {
        QTimer::singleShot(0, this, [this] { if (m_native) { m_native->attempts = 0; m_native->retry(); } });
    }
#endif
    return QObject::eventFilter(watched, event);
}
