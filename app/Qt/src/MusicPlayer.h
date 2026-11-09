#pragma once
#include "LyricsController.h"
#include <QElapsedTimer>
#include <optional>

class MusicPlayer : public QObject {
    Q_OBJECT
  public:
    MusicPlayer(Host *host, MusicApi *api, QObject *parent = nullptr);
    void startHeart(const QString &uid, MusicApi::Valid accountValid, bool advance = false);
    void cancelHeart();
    void leaveHeart();
    bool heartPending = false;
    void enqueue(const QJsonObject &track, bool next = false);
    int enqueueMany(const QJsonArray &tracks);
    void play(QJsonObject track, std::optional<QJsonArray> source = std::nullopt,
              std::optional<int> queueIndex = std::nullopt, bool preview = false);
    void tick(double time, bool force = false);
    void toggle();
    void setPaused(bool paused);
    void seek(double fraction);
    void volume(double value);
    void next(int direction = 1, bool ended = false);
    void remove(int index);
    void clearUpcoming();
    void startRoam(QString uid, MusicApi::Valid accountValid);
    void leaveRoam(bool restorePrevious = true);
    void dislikeRoam();
    void retryRoam();
    bool roamActive = false;
    bool roamLoading = false;
    QString roamStatus;
    void stop();
    void setQuality(const QString &value);
    static QVector<QPair<QString, QString>> qualityOptions(const QString &provider);
    static QString localQuality(const QJsonObject &track);
    static QString sourceQuality(const QString &provider, const QJsonObject &audio, bool trial = false);
    double chorusSeconds = -1;
    static double chorusStart(const QJsonObject &reply, const QString &id);
    QString actualQuality;
    QJsonObject localCovers;
    static QString identity(const QJsonObject &track);
    void hydrateQueue(const QList<int> &indices);
    LyricsController lyrics;
    QJsonArray queue;
    QJsonArray history;
    QJsonObject current;
    QJsonObject state;
    int index = -1;
    bool loading = false;
    bool failed = false;
    bool trial = false;
    QString coverImage;
    QString mode = "all";
    bool shuffleEnabled = false;
    bool shuffled() const { return mode == "shuffle" || (mode != "heart" && !roamActive && shuffleEnabled); }
    double podcastSpeed = 1;
    void setPodcastSpeed(double value);
    static bool isEpisode(const QJsonObject &track);
    QString status;
    QString quality;
    bool alternative = false;
    bool previewRequested = false;
    std::function<void()> onEnd;
    // Supplied by the owning music library, so anonymous/other-provider plays
    // are never reported and account changes are detected per song.
    std::function<QString()> scrobbleAccountId;
    QString scrobbleStatus = "idle";

  signals:
    void changed();
    void seekRequested();
    void trackSelected(QJsonObject track);
    void roamSongStarted();

  private:
    QJsonArray m_heartSavedQueue;
    int m_heartSavedIndex=-1;
    std::optional<int> m_heartResumeIndex;
    bool m_heartHasContext=false;
    quint64 m_heartGeneration = 0;
    QString m_heartUid;
    MusicApi::Valid m_heartAccountValid;
    Host *m_host;
    MusicApi *m_api;
    quint64 m_generation = 0;
    int m_queueHydrationEpoch = -1;
    QSet<QString> m_queueHydrating;
    QHash<QString, qint64> m_queueHydrationRetry;
    quint64 m_roamGeneration = 0;
    QString m_roamUid;
    MusicApi::Valid m_roamAccountValid;
    QJsonArray m_roamSavedQueue;
    QJsonObject m_roamSavedCurrent;
    QString m_roamSavedMode;
    int m_roamSavedIndex = -1;
    std::optional<int> m_roamSavedHeartResumeIndex;
    double m_roamSavedPosition = 0;
    bool m_roamSavedPaused = false;
    bool m_roamInternalPlay = false;
    bool m_restoringRoamContext = false;
    void fetchRoam();
    qint64 m_endSerial = 0;
    double m_lastPoll = -1;
    std::optional<double> m_resumePosition;
    bool m_resumePaused = false;
    int m_recoveryAttempts = 0;
    QElapsedTimer m_scrobbleClock;
    double m_scrobbleSeconds = 0;
    QString m_scrobbleAccount;
    bool m_scrobbleAttempted = false;
    void updateScrobble(const QJsonObject &previousState);
    void recoverPlayback();
    MusicApi::Valid valid(quint64 generation);
    void prepare(QJsonObject track, quint64 generation, bool reload = false);
    void fail(QString error);
};
