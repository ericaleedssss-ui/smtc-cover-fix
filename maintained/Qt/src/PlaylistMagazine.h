#pragma once
#include "MusicLibrary.h"
#include "NativeHud.h"
#include <QAbstractListModel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QSaveFile>
#include <QVariantList>

// One persistent controller/model. Modal and queue state never own this page.
class PlaylistMagazine : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
    Q_PROPERTY(QVariantList covers READ covers NOTIFY changed)
    Q_PROPERTY(QVariantList socialRows READ socialRows NOTIFY changed)
    Q_PROPERTY(QString session READ session NOTIFY changed)
    Q_PROPERTY(QString query READ query NOTIFY changed)
    Q_PROPERTY(QString filter READ filter NOTIFY changed)
    Q_PROPERTY(QString tab READ tab NOTIFY changed)
    Q_PROPERTY(double scrollPosition READ scrollPosition NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool downloading READ downloading NOTIFY changed)
    Q_PROPERTY(QVariantMap songMenu READ songMenu NOTIFY menuChanged)
public:
    enum Role { Track=Qt::UserRole+1, SourceIndex, Chosen, Heart };
    PlaylistMagazine(MusicLibrary *music, NativeHud *hud, QObject *parent=nullptr);
    ~PlaylistMagazine() override;
    int rowCount(const QModelIndex &parent={}) const override;
    QVariant data(const QModelIndex &, int role) const override;
    QHash<int,QByteArray> roleNames() const override;
    bool active() const;
    QVariantMap info() const;
    QVariantList covers() const { return m_covers; }
    QVariantList socialRows() const { return m_social; }
    QString session() const;
    QString query() const;
    QString filter() const;
    QString tab() const;
    double scrollPosition() const;
    QString status() const { return m_status; }
    bool downloading() const { return m_downloading; }
    Q_INVOKABLE void cancelDownload();
    bool busy() const { return !m_pending.isEmpty() || m_mutating; }
    int selectedCount() const { return m_selected.size(); }
    QVariantMap songMenu() const;
    void sync();
    Q_INVOKABLE int viewRow(int sourceIndex) const { return m_rows.indexOf(sourceIndex); }
    Q_INVOKABLE void search(QString text);
    Q_INVOKABLE void setFilter(QString filter);
    Q_INVOKABLE void setTab(QString tab);
    Q_INVOKABLE void savePosition(QString key, double y);
    Q_INVOKABLE void more();
    Q_INVOKABLE void openCover(QString key);
    Q_INVOKABLE void prepareRecords();
    Q_INVOKABLE void rowAction(QString op, QString key);
    Q_INVOKABLE void selectAll(bool selected);
    Q_INVOKABLE void bulk(QString operation);
    Q_INVOKABLE void showSongMenu(QString scope, int index, QString key, double x, double y);
    Q_INVOKABLE void showHitMenu(QString hit, double x, double y);
    Q_INVOKABLE void songAction(QString operation);
    Q_INVOKABLE void closeMenu();
    Q_INVOKABLE void share();
    Q_INVOKABLE void setSubscribed(QString sessionKey, bool subscribed);
    Q_INVOKABLE void removeConfirmed();
    Q_INVOKABLE void cancelRemoval();
    Q_PROPERTY(int removalCount READ removalCount NOTIFY changed)
    int removalCount() const { return m_remove.size(); }
signals:
    void changed();
    void menuChanged();
    void navigate(QString action);
private:
    MusicLibrary *m_music;
    NativeHud *m_hud;
    std::shared_ptr<MusicDirectory> m_folder, m_menuFolder, m_removeFolder;
    QJsonArray m_songs;
    QVector<int> m_rows;
    QSet<QString> m_selected, m_unavailableCovers, m_likedKeys;
    QVariantList m_covers, m_social;
    QJsonArray m_recordSequence;
    QJsonObject m_recordAnchor;
    std::array<QJsonArray,3> m_recordInputs;
    QString m_recordKey;
    int m_recordIndex=-1;
    bool m_recordsComplete=false;
    QString m_status, m_pending, m_modelQuery, m_modelFilter;
    QJsonArray m_likedSnapshot;
    bool m_downloading=false;
    QJsonArray m_remove;
    QJsonObject m_menuSong;
    QString m_menuScope;
    double m_menuX=0, m_menuY=0;
    int m_menuComments=-1, m_menuIndex=-1;
    quint64 m_downloadSerial=0;
    void scheduleDownload();
    quint64 m_account=0, m_socialToken=0, m_menuToken=0;
    int m_socialOffset=0, m_socialTotal=0, m_waitCursor=-1;
    bool m_socialLoading=false, m_mutating=false, m_syncing=false, m_searchRequested=false;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    std::unique_ptr<QSaveFile> m_file;
    QJsonArray m_downloads;
    int m_saved=0, m_failed=0, m_existing=0;
    quint64 m_downloadAccount=0;
    void rebuild(bool reset);
    void refreshCovers();
    void loadSocial(bool reset);
    void beginAll(QString operation);
    void finishAll();
    void apply(QString operation, QJsonArray songs);
    void mutateChunks(QString pid, QJsonArray songs, bool remove, int offset=0);
    void download(QJsonArray songs);
    void nextDownload();
    QJsonObject findSong(QString key, int *source=nullptr) const;
    QJsonArray selectedSongs() const;
    void report(QString text);
};
