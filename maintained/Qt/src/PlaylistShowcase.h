#pragma once
#include "MusicLibrary.h"
#include "NativeHud.h"
#include <QObject>
#include <QVariantMap>

// Archive presentation adapter. Metadata and queue writes use the existing domain objects.
class PlaylistShowcase : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
    Q_PROPERTY(QVariantList covers READ covers NOTIFY changed)
    Q_PROPERTY(QVariantList songs READ songs NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
public:
    PlaylistShowcase(MusicLibrary*,NativeHud*,QObject* parent=nullptr);
    QVariantMap info() const;
    QVariantList covers() const;
    bool busy()const{return m_loading||m_music->writeLoading;}
    QString status()const{return m_status;}
    Q_INVOKABLE QVariantMap recordNeighbour(int) const;
    Q_INVOKABLE void prepareRecords();
    Q_INVOKABLE void openCover(QString);
    Q_INVOKABLE void operate(QString);
    Q_INVOKABLE void confirmUnsubscribe();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void preview(int index);
    Q_INVOKABLE void playSong(int index);
    QVariantList songs()const;
signals:
    void changed();
    void navigate(QString);
private:
    MusicLibrary *m_music;NativeHud *m_hud;
    QString m_key,m_status,m_pending,m_unsubscribe,m_heartQuery;
    QJsonObject m_item;QJsonArray m_songs,m_ids;
    quint64 m_account=0,m_token=0,m_revision=0;
    bool m_previewLoading=false,m_durationFailed=false;
    void completeDuration();
    void subscribe(bool);
    bool m_loading=false,m_loaded=false,m_directory=false;
    void sync();
    void syncHeart();
    void load();
    void execute(QString);
    bool subscribed()const;
    QJsonArray queue() const;
};
