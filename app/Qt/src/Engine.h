#pragma once
#include "Glyphs.h"
#include "PipelineDiagnostics.h"
#include "PlaylistMagazine.h"
#include "MessageCenter.h"
#include "PersonalHub.h"
#include "PlaylistShowcase.h"
#include "NowPlaying.h"
#include "Host.h"
#include "TaskbarIntegration.h"
#include "NativeApplication.h"
#include "SoundEffects.h"
#include <QElapsedTimer>
#include <QVariantMap>
#include <QUrl>
#include <QQuickWindow>
#include <QPointer>
class Engine : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject *nowPlaying READ nowPlaying CONSTANT)
    Q_PROPERTY(QObject *soundEffects READ soundEffects CONSTANT)
    Q_PROPERTY(QObject *showcase READ showcase CONSTANT)
    Q_PROPERTY(QObject *messages READ messages CONSTANT)
    Q_PROPERTY(QObject *personal READ personal CONSTANT)
    Q_PROPERTY(QObject *magazine READ magazine CONSTANT)
    Q_PROPERTY(Glyphs *glyphs READ glyphs CONSTANT)
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap profileContent READ profileContent NOTIFY profileContentChanged)
    Q_PROPERTY(QVariantList hits READ hits NOTIFY hitsChanged)
    Q_PROPERTY(QVariantMap performance READ performance NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap desktopLyrics READ desktopLyrics NOTIFY desktopLyricsChanged)
    Q_PROPERTY(QString uiFont READ uiFont NOTIFY uiFontChanged)
    Q_PROPERTY(QStringList uiFonts READ uiFonts NOTIFY uiFontChanged)
    Q_PROPERTY(QString fontError READ fontError NOTIFY uiFontChanged)
    Q_PROPERTY(QVariantMap visualPreferences READ visualPreferences NOTIFY visualPreferencesChanged)
    Q_PROPERTY(int sleepMinutes READ sleepMinutes NOTIFY sleepChanged)
  public:
    Q_INVOKABLE void tracePipeline(QString stage) { PipelineDiagnostics::qml(stage); }
    Engine(QString root, bool offline = false, QObject *parent = nullptr);
    ~Engine() override;
    QObject *nowPlaying() const {return m_nowPlaying;}
    QObject *soundEffects() const {return m_soundEffects;}
    QObject *showcase() const {return m_showcase;}
    QObject *messages() const {return m_messages;}
    QObject *personal() const {return m_personal;}
    QObject *magazine() const { return m_magazine; }
    QVariantMap state() const {
        return m_state;
    }
    QVariantMap profileContent() const { return m_profileContent; }
    QVariantList hits() const {
        return m_hits;
    }
    QJsonObject frame() const {
        return m_frame;
    }
    QJsonObject current() const {
        return m_current;
    }
    QImage cover() const {
        return host.image(m_cover);
    }
    QJsonArray commands() const {
        return m_commands;
    }
    Glyphs *glyphs() {
        return &m_glyphs;
    }
    QString root() const {
        return host.root;
    }
    Q_INVOKABLE void importLocal(QList<QUrl> urls);
    Q_INVOKABLE void resize(double width, double height);
    Q_INVOKABLE void action(QString action);
    Q_INVOKABLE void hoverLink(QString action);
    Q_INVOKABLE void hoverItem(QString action, double x, double y);
    Q_INVOKABLE void setDesktopFont(QString family, int size = 0);
    Q_INVOKABLE void setPlayerPreference(QString key, QString value);
    Q_INVOKABLE void setDetailFlightBarOpacity(double opacity);
    Q_INVOKABLE QVariantList audioOutputs() const { return host.outputDevices(); }
    Q_INVOKABLE void selectAudioOutput(QString id) { host.selectOutput(id); wake(); }
    int sleepMinutes() const { return m_sleepMinutes; }
    Q_INVOKABLE void setSleep(int minutes);
    QVariantMap visualPreferences() const { return m_visualPreferences; }
    Q_INVOKABLE void setVisualPreference(QString key, QVariant value);
    Q_INVOKABLE void setDesktopColor(QString target, QString color);
    Q_INVOKABLE QStringList desktopFonts() const;
    QString uiFont() const { return m_uiFont; }
    QStringList uiFonts() const { return QFontDatabaseFamilies(); }
    QString fontError() const { return m_fontError; }
    Q_INVOKABLE void setUiFont(QString family);
    Q_INVOKABLE QString preparedFont(QString family) const { ensureFontFamily(family); return family; }
    Q_INVOKABLE void resetUiFont() { setUiFont(m_defaultUiFont); }
    Q_INVOKABLE void importUiFont(QUrl file);
    Q_INVOKABLE void saveProfileSignature(QString signature);
    void initializeUiFont(QString fallback);
    Q_INVOKABLE void setDesktopOpacity(int opacity);
    Q_INVOKABLE void applyDesktopPreset(QString preset);
    Q_INVOKABLE void setDesktopTone(QString tone);
    Q_INVOKABLE void saveDesktopPosition(double x, double y);
    Q_INVOKABLE void setDesktopWindow(QQuickWindow *window);
    QVariantMap desktopLyrics() const { return m_desktopLyrics; }
    Q_INVOKABLE void submitForm(QString account, QString password);
    Q_INVOKABLE bool keyEvent(int key, int modifiers, QString text);
    Q_INVOKABLE void searchAccepted(QString text, int modifiers);
    Q_INVOKABLE void wheelInput(double x, double y, double pixelDelta, double angleDelta);
    Q_INVOKABLE void adjustPlayer(QString control, double x, double width);
    Q_INVOKABLE void toggleFullscreen();
    void setWindow(QQuickWindow *window);
    Q_INVOKABLE void query(QString query);
    Q_INVOKABLE void key(QString key, bool command);
    Q_INVOKABLE void pointer(QString type, double x, double y);
    Q_INVOKABLE void wheel(double x, double y, double delta, bool pixels = false);
    Q_INVOKABLE void snapshot(QString path);
    void step(double time);
    QVariantMap performance() const;
    void trimMemory();
    Q_INVOKABLE void setVisible(bool value);
    void wake(bool input = true);
    void start();
    bool ready() const;
    int selfTest();
    int renderFixtures(QString source, QString output);
    Host host;
    NativeScene scene;
    std::unique_ptr<NativeApplication> app;
    QString failure;
  signals:
    void updated();
    void hudUpdated();
    void stateChanged();
    void profileContentChanged();
    void hitsChanged();
    void clearCredentials();
    void performanceRequested();
    void localImportRequested(bool folder);
    void desktopLyricsChanged();
    void uiFontChanged();
    void visualPreferencesChanged();
    void sleepChanged();
    void profileSignatureSaved();
    void pointerPressed(double x, double y);
    void desktopFontRequested();
    void desktopColorRequested(QString target);
    void pageNavigation(QString key);

  protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

  private:
    SoundEffects *m_soundEffects=nullptr;
    PlaylistMagazine *m_magazine = nullptr;
    QStringList QFontDatabaseFamilies() const;
    void indexApplicationFonts() const;
    bool ensureFontFamily(const QString &family) const;
    mutable bool m_fontCatalogReady = false;
    mutable QHash<QString, QStringList> m_applicationFontFiles;
    mutable QSet<QString> m_registeredFontFiles;
    QString m_uiFont, m_defaultUiFont, m_fontError;
    quint64 m_signatureAccount = 0;
    MessageCenter *m_messages = nullptr;
    PersonalHub *m_personal = nullptr;
    NowPlaying *m_nowPlaying=nullptr;
    PlaylistShowcase *m_showcase=nullptr;
    QPoint m_keyboardCursor;
    bool m_keyboardMouseGuard = false;
    void refreshTaskbar();
    std::unique_ptr<TaskbarIntegration> m_taskbar;
    QString m_taskbarLikeKey;
    Glyphs m_glyphs;
    QTimer timer, mediaTimer;
    QTimer m_sleepTimer;
    int m_sleepMinutes = 0;
    bool m_started = false;
    bool m_visible = true;
    bool m_sleeping = false;
    bool m_sceneSleeping = false;
    bool m_pointerPending = false;
    bool m_pressed = false;
    bool m_wheelPending = false;
    double m_pointerX = 0;
    double m_pointerY = 0;
    double m_wheelX = 0;
    double m_wheelY = 0;
    double m_wheelDelta = 0;
    double m_wheelSteps = 0;
    double m_wheelDistance = 0;
    // 鼠标滚轮一格的距离，按帧衰减送入，触控板不经过这里。
    double m_wheelRemainingDistance = 0;
    qint64 m_lastTick = 0, m_lastInput = 0;
    double m_animationTime = 0;
    quint64 m_steps = 0, m_sceneUpdates = 0, m_hudUpdates = 0;
    int m_stableFrames = 0;
    QJsonObject m_sceneSignature;
    void tick();
    void flushPointer();
    void pollMedia();
    void refreshPlayback();
    void refreshDesktopLyrics();
    QVariantMap m_desktopLyrics;
    QHash<QString,QString> m_playerPreferences;
    QVariantMap m_visualPreferences;
    QJsonObject m_desktopPosition;
    QElapsedTimer clock;
    double m_width = 1280;
    double m_height = 720;
    QVariantMap m_state;
    QVariantMap m_profileContent;
    QVariantList m_hits;
    QJsonObject m_frame, m_current;
    QJsonArray m_commands;
    QPointer<QQuickWindow> m_window;
    QPointer<QQuickWindow> m_desktopWindow;
    QWindow::Visibility m_windowedVisibility = QWindow::Windowed;
    QString m_loginMethod;
    QString m_cover;
};
