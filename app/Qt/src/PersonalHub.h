#pragma once
#include "MusicLibrary.h"
#include <QVariantMap>

// Read-only account-scoped snapshots. Browsing these panels leaves the music page intact.
class PersonalHub : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap state READ state NOTIFY changed)
public:
    explicit PersonalHub(MusicLibrary *music, QObject *parent=nullptr);
    QVariantMap state() const;
    Q_INVOKABLE void load(QString section, bool more=false);
    Q_INVOKABLE void activate(QString section, int index);
    Q_INVOKABLE void loadFolder(QString section, int index);
    Q_INVOKABLE QString previewCover(QString source) const;
    Q_INVOKABLE QString sizedCover(QString source, int pixels) const;
    Q_INVOKABLE void openMembership();
    void updateSignature(QString signature);
    Q_INVOKABLE void openOriginal(QString section, int index);
signals:
    void changed();
    void navigate(QString action);
    void externalRequested(QString url);
private:
    struct Page { QVariantList rows; QVariantMap data; QString error; bool busy=false, loaded=false, more=false; int offset=0; qint64 fetched=0; quint64 serial=0; };
    MusicLibrary *m_music;
    quint64 m_account=0;
    QString m_uid, m_provider;
    QHash<QString,Page> m_pages;
    void syncAccount();
};
