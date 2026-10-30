#pragma once
#include "MusicLibrary.h"
#include "PlaylistMagazine.h"
#include <QObject>
#include <QVariantMap>

// Content for the existing archive reading surface; transport remains MusicPlayer.
class NowPlaying : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
    Q_PROPERTY(QVariantMap playback READ playback NOTIFY playbackChanged)
    Q_PROPERTY(QVariantList lines READ lines NOTIFY linesChanged)
    Q_PROPERTY(QString status READ status NOTIFY changed)
public:
    NowPlaying(MusicLibrary*,PlaylistMagazine*,QObject* parent=nullptr);
    QVariantMap info()const;
    QVariantMap playback()const;
    QVariantList lines()const;
    QString status()const{return m_status;}
    Q_INVOKABLE void operate(QString operation);
    Q_INVOKABLE void seekLine(int index,QString session);
    Q_INVOKABLE void openArtist(QString id);
signals:
    void changed();
    void playbackChanged();
    void linesChanged();
    void navigate(QString action);
private:
    MusicLibrary *m_music;PlaylistMagazine *m_magazine;
    QJsonObject m_track,m_album,m_document;
    QVariantMap m_lastPlayback;
    QString m_key,m_cover,m_avatar,m_artistID,m_status;
    quint64 m_generation=0,m_account=0;
    quint64 m_coverRequest=0,m_avatarRequest=0,m_artistRequest=0;
    bool m_known=false,m_liked=false,m_write=false,m_coverLoading=false;
    QHash<QString,QString> m_images,m_artists;
    QHash<QString,QJsonObject> m_albums;
    QJsonArray m_tags;
    QHash<QString,QJsonArray> m_tagsCache;
    void sync();
    void syncLyrics();
    void loadTags();
    void artist(bool fallback=false);
    void pixels(QString url,QString role,bool fallback=false);
};
