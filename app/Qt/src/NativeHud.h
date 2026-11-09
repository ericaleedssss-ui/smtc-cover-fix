#pragma once
#include "Glyphs.h"
#include "MusicLibrary.h"
#include "UiMotion.h"
#include <QCache>
#include <QPointF>
#include <QRectF>
#include <map>
#include <optional>

// 场景边界只传递值和原生回调；界面控制器不持有脚本对象。
struct HudSceneActions {
    std::function<void(QString)> mode;
    std::function<void(bool)> theme;
    std::function<void(bool)> reduced;

};

class NativeHud : public QObject {
    Q_OBJECT
  public:
    struct Row {
        int index = -1;
        QJsonObject value;
        QVector<int> indices;
    };
    struct Layout {
        double left = 40;
        double sidebar = 250;
        double x = 326;
        double width = 0;
        double top = 260;
        double rowsY = 434;
        double rowHeight = 54;
        int rowCount = 9;
        double bottom = 956;
    };
    NativeHud(Host *host, Glyphs *glyphs, MusicLibrary *music, HudSceneActions scene,
              QObject *parent = nullptr);
    void draw(QJsonObject frame, double width, double time);
    QJsonObject state() const;
    void action(QString action);
    void key(QString key, bool command);
    bool navigatePage(QString key);
    void hoverItem(QString action, double x, double y);
    QString focusAction, navigationSession;
    bool keyboardNavigation = false;
    double detailFlightBarOpacity = 1;
    QPointF navigationPointer{-10000, -10000};
    void wheel(double x, double y, double delta, std::optional<int> steps = std::nullopt,
               std::optional<double> distance = std::nullopt);
    void form(QJsonObject fields);
    void openModal(QString kind);
    void closeModal(bool returnToParent = true);
    void setQuery(QString value);
    void pageResults(int direction);
    bool animating(double time) const;
    bool supportsTrackList() const;
    QVector<Row> rows(int lane);
    QRectF modalBounds(double width) const;
    QRectF queueBounds(double width) const;
    QRectF detailBounds(double width) const;
    Layout containerLayout(double width) const;
    QJsonArray commands;
    QJsonArray hits;
    QJsonObject frame;
    QString tab = "overview";
    QString modal;
    QString query;
    QString formKind;
    QString formPID;
    QString confirmTitle;
    QString groupBy = "none";
    QString activeGroup;
    QString artistTab = "songs";
    bool categoryPicker = false;
    int categoryPage = 0;
    static constexpr int CategoryPageSize = 40;
    QString themeMode;
    int listOffset = 0;
    int musicCollection = 1;
    int trackOffset = 0;
    int bodyOffset = 0;
    int detailRows = 2;
    std::optional<QRectF> detailRowsBounds;
    std::optional<QRectF> readerBounds;
    QString readerText;
    QString readerSession;
    double readerFont = 16;
    double readerLeading = 31;
    bool queueOpen = false;
    double lyricScale = 1;
    bool lyricTranslation = true;
    QString stageStyle = "flow";
    bool stageSparks = false;
    bool queueCollectionOpen = false;
    int queueOffset = 0;
    QJsonArray queueCollectionTracks;
    quint64 queueCollectionAccount = 0;
    // 设置沿用原舞台坐标与行高，只在固定标题下滚动内容。
    static constexpr double SettingsViewportTop = 176;
    static constexpr double SettingsViewportBottom = 836;
    static constexpr double SettingsContentBottom = 1700;
    double settingsScroll = 0;
    double desktopSettingsScroll = 0;
    double settingsScrollMaximum() const {
        return SettingsContentBottom - SettingsViewportBottom;
    }
    bool dark = false;
    bool reduced = false;
    bool textFrosted = true;
    bool desktopLyricsEnabled = false;
    bool desktopLyricsLocked = false;
    QString desktopLyricsFont = "MiSans";
    int desktopLyricsSize = 26;
    QString desktopLyricsTone = "dark";
    QString desktopLyricsPrimaryColor;
    QString desktopLyricsSecondaryColor;
    QString desktopLyricsBackgroundColor = "#f5f0e4";
    int desktopLyricsBackgroundOpacity = 65;
    QString hoveredLink;
    QString sharedSong;
    qint64 sharedUntil = 0;
    bool closing = false;
    bool lyricsMode = false;
    double audibleVolume = .7;
    QJsonArray lyricRows;
    std::optional<QRectF> lyricBounds;
    QJsonObject profile;
    QJsonArray profileRows;
    QJsonObject profileCollections;
    quint64 profileCollectionGeneration = 0;
    quint64 profileSnapshotAccount = 0;
    QJsonArray profileHistory;
    QHash<QString, quint64> profileCollectionRequests;
    void loadProfileCollection(QString section, bool more = false);
    QString profileID, profileSection = "music", profileFilter = "created", profileError;
    QString profileRecentKind = "playlist", profileRadioID;
    QString profileRankPeriod = "all", profilePlayKey;
    bool profileSignatureSaving = false;
    QString profileSignatureError;
    quint64 profilePlayGeneration = 0;
    bool profileLoading = false, profileMore = false;
    bool profileNavigated = false;
    int profileOffset = 0;
    qint64 profileLastTime = -1;
    quint64 profileGeneration = 0;
    QHash<QString, QString> listCovers;
    QSet<QString> listCoverPending;
    QHash<QString, qint64> listCoverRetry;
    QHash<QString, int> listCoverFailures;
    int listCoverEpoch = -1;
    void openProfile(QString id);
    void loadProfileRows(bool more = false);
    bool profileAction(const QString &value);
    void resetTextMetrics() { m_fitCache.clear(); }
    void requestListCover(QString url);
    bool trackListMode = false;
    bool recommendationsOpen = false;
    int recommendationsPending = 0;
    bool recommendationsLoaded = false;
    QString recommendationsError;
    QJsonArray recommendationSongs;
    QJsonArray recommendationPlaylists;
    std::optional<QRectF> recommendationsBounds;
    bool commentsOpen = false;
    bool commentsLoading = false;
    bool commentsMore = false;
    QString commentsSort = "latest";
    QJsonArray commentsFeatured;
    std::optional<QRectF> commentsBounds;
    QString commentsError;
    QString commentsActionError;
    QString commentsPending;
    QJsonObject commentsSong;
    QJsonArray commentsRows;
    double commentsTotal = 0;
    double socialRedCount = -1;
    double socialCommentCount = -1;
    bool socialRedLoading = false;
    bool socialCommentLoading = false;
    QString m_socialSongID;
    quint64 m_socialGeneration = 0;
    void loadSocialCounts(QJsonObject song);
    double width = 1920;
    double lastTime = 0;
    UiMotion::SurfaceMotion motion;
    std::optional<QRectF> playerSeekRect;
    std::optional<QRectF> playerVolumeRect;

  signals:
    void localImportRequested(bool folder);

  private:
    struct ModalReturn {
        QString name, target, query, group, active;
        int listOffset = 0, collection = 1;
        double scroll = 0;
        quint64 account = 0;
    };
    QList<ModalReturn> m_modalBack;
    struct ViewReturn {
        QJsonObject item;
        std::shared_ptr<MusicDirectory> directory;
        QJsonArray context;
        QString mode, modal, tab, artistTab, query, groupBy, activeGroup, focus, target;
        int trackOffset = 0, bodyOffset = 0, listOffset = 0, collection = 1, lane = 0, physical = -1;
        bool directoryInfo = false, lyrics = false;
        quint64 account = 0;
    };
    QList<ViewReturn> m_viewBack;
    QString navigationSourceName() const;
    void rememberPage();
    void browseCollection(QJsonObject item);
    bool restorePage();
    struct LyricRow {
        double top = 0;
        QStringList text;
        QStringList translation;
    };
    struct TrackRulerRow {
        double centerY = 0;
        double textRight = 0;
        double emphasis = 0;
        double opacity = 1;
    };
    struct Page {
        QString modal;
        int lane;
        quint64 generation;
        int desired;
    };
    Host *m_host;
    Glyphs *m_glyphs;
    MusicLibrary *m_music;
    HudSceneActions m_scene;
    quint64 m_searchGeneration = 0;
    quint64 m_recommendationGeneration = 0;
    QString m_recommendationKey;
    QString m_recommendationSong;
    int m_recommendationEpoch = 0;
    struct RecommendationReturn {
        QJsonObject song;
        std::shared_ptr<MusicDirectory> directory;
        QString target;
    };
    QList<RecommendationReturn> m_recommendationBack;
    void openRecommendations(bool retry = false);
    quint64 m_commentsGeneration = 0;
    int m_commentsOffset = 0;
    double m_commentsCursor = 0;
    int m_commentsEpoch = 0;
    qint64 m_commentsLoadedAt = 0;
    QString m_commentsKey;
    void openComments();
    void loadComments(bool reset);
    void closeComments();
    std::optional<Page> m_page;
    QString m_trackListScope;
    int m_trackListTarget = -1;
    std::optional<UiMotion::ReelCurve> m_trackListCurve;
    std::function<void()> m_confirm;
    QCache<QString, QString> m_fitCache{512};
    std::map<QString, UiMotion::RollingLabel> m_rolling;
    QString m_rowsKey;
    QVector<Row> m_rows;
    QString m_resultSignature;
    double m_resultStart = 0;
    bool m_modalControls = false;
    QJsonObject m_lyricsDocument;
    double m_lyricsWidth = 0;
    QVector<LyricRow> m_lyricsLayout;
    double m_lyricsScroll = 0;
    std::optional<double> m_lyricsBrowse;
    std::optional<double> m_lyricsTarget;
    std::optional<UiMotion::ReelCurve> m_lyricsCurve;
    int m_lyricsPlainOffset = 0;
    void finishPage();
    void musicAction(const QStringList &parts, const QString &action);
    void playerAction(const QStringList &parts);
    void openNowPlaying();
    void openPlayingSong(bool lyrics);
    bool returnFromLyrics();
    struct LyricsReturn {
        QJsonObject item;
        std::shared_ptr<MusicDirectory> directory;
        QString mode, modal, tab, artistTab;
        int offset = 0, physical = -1, lane = 0;
        bool directoryInfo = false;
        quint64 account = 0;
    };
    std::optional<LyricsReturn> m_lyricsReturn;
    std::optional<LyricsReturn> m_profileReturn;
    QJsonObject m_profileComments;
    bool m_profileLyrics = false;
    QString m_profileItem;
    QJsonArray ink() const;
    void op(QJsonArray command);
    void save();
    void restore();
    void alpha(double value);
    void translate(double x, double y);
    void scale(double x, double y);
    void clip(double x, double y, double width, double height);
    void fill(double x, double y, double width, double height, QJsonArray color = {});
    void text(QString value, double x, double y, double size, QString weight = "regular", double tracking = 0,
              QJsonArray color = {});
    void aligned(QString value, double x, double y, double size, QString weight = "regular",
                 double tracking = 0);
    QString fit(QString value, double size, double width, QString weight = "regular");
    void limited(QString value, double x, double y, double size, double width, QString weight = "regular");
    void link(QString value, double x, double y, double size, double width, QString action,
              QString weight = "regular");
    void centeredText(QString value, double x, double cy, double size, QString weight = "regular",
                      bool horizontal = false);
    void rollingText(QString key, QString value, double x, double y, double size, QString weight = "regular",
                     double tracking = 0, bool numeric = false);
    void roll(QString key, QString value, double x, double y, double size, double width,
              QString weight = "regular", bool numeric = false);
    void hit(double x, double y, double width, double height, QString action, QString label = {});
    void button(QString label, double x, double y, double width, double height, QString action, double size,
                QString weight = "regular");
    void control(QString label, double x, double y, double width, QString action);
    void rule(double x, double y, double width, double opacity = 0.4);
    void songHeart(QJsonObject song, double x, double y, const QString &action);
    void image(QString key, double x, double y, double width, double height);
    void brand();
    void brandLine(int index);
    void navigation(double width);
    void footer(double width);
    void empty(double width);
    void archive(double width);
    void archiveTabButton(double width);
    void archiveTrackList(double x, double width);
    double archiveTrackPosition(int selected);
    void archiveTrackRuler(double x, double centerY, const QVector<TrackRulerRow> &rows);
    void actionButton(QString label, double x, double y, double width, QString action, bool primary = false);
    std::array<double, 2> rowMotion(const QString &signature, int index);
    void modalDraw(double width);
    void loginPanel(double x, double y, double width);
    void libraryPanel(double x, double y, double width);
    void discoverPanel(double x, double y, double width);
    void localPanel(double x, double y, double width);
    void playerBar(double x, double y, double width);
    void playerPanel(double x, double y, double width);
    void platformChoices(double x, double y, double width, bool expanded = false);
    void platformPanel(double x, double y, double width);
    void settings(double x, double y, double width);
    void qualityPanel(double x, double y, double width);
    void qualityChoice(const QString &id, int number, double x, double y, double width, bool featured);
    static QString clock(double ms);
};
