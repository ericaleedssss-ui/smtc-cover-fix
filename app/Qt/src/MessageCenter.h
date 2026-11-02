#pragma once
#include "MusicLibrary.h"
#include <QAbstractListModel>
#include <QVariantMap>
#include <QTimer>

// One account-scoped store; opening a drawer never replaces the current music page.
class MessageCenter : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QVariantMap state READ state NOTIFY changed)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(QString draft READ draft WRITE setDraft NOTIFY draftChanged)
public:
    enum { Row = Qt::UserRole+1 };
    explicit MessageCenter(MusicLibrary *music, QObject *parent=nullptr);
    int rowCount(const QModelIndex &p={}) const override;
    QVariant data(const QModelIndex &,int role) const override;
    QHash<int,QByteArray> roleNames() const override {return {{Row,"message"}};}
    QVariantMap state() const;
    QVariantList history() const;
    QString draft() const;
    Q_INVOKABLE void setDraft(QString);
    Q_INVOKABLE void setOpen(bool);
    Q_INVOKABLE void selectTab(int);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void more();
    Q_INVOKABLE void activate(int);
    Q_INVOKABLE void startConversation(QString uid, QString name={});
    Q_INVOKABLE void leaveConversation();
    Q_INVOKABLE void older();
    Q_INVOKABLE void send();
    Q_INVOKABLE void allRead();
    Q_INVOKABLE void openResource(int historyIndex);
signals:
    void changed();
    void historyChanged();
    void draftChanged();
    void navigate(QString action);
private:
    struct Page {QVariantList rows; bool loaded=false,busy=false,more=false;int offset=0; qint64 before=-1;QString error;quint64 serial=0;};
    struct Chat {QVariantList rows;QString draft,error;bool busy=false,sending=false,more=false; qint64 before=0;quint64 serial=0;};
    MusicLibrary *m_music;
    quint64 m_account=0;
    QString m_uid,m_peer,m_peerName,m_feedback;
    bool m_open=false,m_countBusy=false;
    int m_tab=0;
    Page m_pages[4];
    QVariantList m_counts;
    QHash<QString,Chat> m_chats;
    QTimer m_poll;
    void syncAccount();
    bool supported() const;
    void load(int,bool reset);
    void loadHistory(bool reset);
    void counts();
    void request(QString,QJsonObject,std::function<void(MusicReply)>);
    static QVariantMap normalize(QJsonObject,int,bool chat=false,QString own={});
    QString chatKey() const;
};
