#pragma once
#include "MusicLibrary.h"
#include "PlaylistMagazine.h"
#include <QObject>
#include <QImage>
#include <QSet>
#include <QVariantMap>

// Content for the existing archive reading surface; transport remains MusicPlayer.
class NowPlaying : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
    Q_PROPERTY(QVariantMap playback READ playback NOTIFY playbackChanged)
    Q_PROPERTY(QVariantList lines READ lines NOTIFY linesChanged)
    Q_PROPERTY(QVariantList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(int queueCount READ queueCount NOTIFY queueChanged)
    Q_PROPERTY(quint64 queueRevision READ queueRevision NOTIFY queueChanged)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString hotComment READ hotComment NOTIFY hotCommentChanged)
public:
    NowPlaying(MusicLibrary*,PlaylistMagazine*,QObject* parent=nullptr);
    QVariantMap info()const;
    QVariantMap playback()const;
    QVariantList lines()const;
    QVariantList queue()const;
    int queueCount()const { return m_queue.size(); }
    quint64 queueRevision()const { return m_queueRevision; }
    Q_INVOKABLE QVariantMap queueRow(int index)const;
    Q_INVOKABLE int queueIndex(QString identity)const;
    Q_INVOKABLE bool queueHasDeferred()const;
    QString status()const{return m_status;}
    QString hotComment()const{return m_hotComment;}
    Q_INVOKABLE void loadHotComment();
    Q_INVOKABLE void hydrateQueue(QVariantList indices);
    Q_INVOKABLE void operate(QString operation);
    Q_INVOKABLE void seekLine(int index,QString session);
    Q_INVOKABLE void openArtist(QString id);
signals:
    void changed();
    void playbackChanged();
    void linesChanged();
    void queueChanged();
    void followRequested();
    void hotCommentChanged();
    void navigate(QString action);
private:
    MusicLibrary *m_music;PlaylistMagazine *m_magazine;
    QJsonObject m_track,m_album,m_document;
    QJsonArray m_queue;
    quint64 m_queueRevision=0;
    QString m_key,m_cover,m_avatar,m_artistID,m_status;
    QString m_hotComment;
    bool m_hotCommentRequested=false;
    QHash<QString,QString> m_hotComments;
    quint64 m_generation=0,m_account=0;
    bool m_known=false,m_liked=false,m_write=false;
    bool m_tagsLoading=false,m_tagsFailed=false;
    int m_tagsAttempts=0;
    QHash<QString,QString> m_images,m_artists,m_pixelKeys;
    QHash<QString,QColor> m_imageTints;
    QHash<QString,QJsonObject> m_albums;
    QJsonArray m_tags;
    QHash<QString,QJsonArray> m_tagsCache;
    QSet<QString> m_imageFlights;
    QColor m_coverTint{"#787882"};
    void preparePixels(QImage image,QString cacheKey,QString role,quint64 generation,quint64 account,int side,bool fallback);
    void sync();
    void syncLyrics();
    void loadTags();
    void artist(bool fallback=false);
    void pixels(QString url,QString role,bool fallback=false);
};
