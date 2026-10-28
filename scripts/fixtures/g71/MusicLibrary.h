#pragma once
#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QSet>
#include <QTimer>
#include <QPointer>
#include <functional>
#include <optional>
#include <memory>
#include <array>
struct MusicReply {QJsonValue value;QString error;bool ok()const{return error.isEmpty();}};
struct Host {QString copied;std::function<void()> wake;void copy(QString s){copied=s;}void invalidate(){if(wake)wake();}};
struct MusicApi {
    QString provider="netease";
    using Reply=std::function<void(MusicReply)>;using Valid=std::function<bool()>;
    std::function<MusicReply(QString,QJsonObject)> fixture;
    QList<QPair<QString,QJsonObject>> requests;
    void call(QString operation,QJsonArray args,Reply reply,Valid valid=[] {return true;}){request("/fixture/"+operation,{{"uid",args.first()}},reply,valid);}
    void request(QString route,QJsonObject values,Reply reply,Valid valid=[] {return true;}){
        requests.append({route,values});const auto response=fixture?fixture(route,values):MusicReply{QJsonObject{{"total",0}}, {}};
        QTimer::singleShot(0,[reply,valid,response]{if(valid())reply(response);});
    }
};
class MusicPlayer:public QObject {
    Q_OBJECT
public:
    MusicApi *m_api=nullptr;QJsonArray queue;QJsonObject current;int index=-1;bool roamActive=false;int plays=0;
    static QString identity(QJsonObject s){return s["provider"].toString("netease")+":"+s["id"].toString();}
    int enqueueMany(const QJsonArray &tracks);
    void enqueue(QJsonObject song,bool next=false){queue.insert(next?std::max(0,index+1):queue.size(),song);emit changed();}
    void remove(int i){if(i>=0&&i<queue.size()&&i!=index)queue.removeAt(i);}
    void play(QJsonObject song,std::optional<QJsonArray> source=std::nullopt,std::optional<int> at=std::nullopt){++plays;current=song;if(source)queue=*source;if(at)index=*at;emit changed();}
signals:void changed();
};
struct MusicDirectory {
    QJsonObject item;QJsonArray songs,ids;std::shared_ptr<MusicDirectory> parent;int cursor=0,page=0,anchor=0;
    bool recordBrowse=false;double magazineScroll=0;QString magazineQuery,magazineFilter="all",magazineTab="songs";
};
class MusicDiscover {public:QJsonArray items;};
class MusicLibrary:public QObject {
    Q_OBJECT
public:
    using Completion=std::function<void(bool)>;
    Host *host;MusicApi api;MusicPlayer player;std::unique_ptr<MusicDiscover> discover;
    QSet<QString> subscriptions;std::array<int,5> totals{};
    std::array<QJsonArray,5> lists;std::array<int,5> offsets{};int selectedLane=2;
    std::optional<QJsonArray> likedIDs;std::shared_ptr<MusicDirectory> directory;
    std::array<bool,5> hasMore{};int collectionLoads=0,lastCollectionLane=-1;bool personalLoading=false;
    bool directoryInfo=true,directoryLoading=false,writeLoading=false;QString provider="netease",uid="42",status;
    QJsonObject current;QJsonArray tracks;quint64 account=1;int pageRequests=0;
    explicit MusicLibrary(Host *h):host(h),discover(std::make_unique<MusicDiscover>()){player.m_api=&api;}
    quint64 accountGeneration()const{return account;}
    bool canEditPlaylist(QJsonObject s)const{return provider=="netease"&&!uid.isEmpty()&&s["creatorID"]==uid;}
    QJsonArray libraryItems()const{return directory?directory->songs:lists[selectedLane];}
    QJsonObject sourceOrigin(int)const{return {};}
    QString sourceURL(QJsonObject s)const{return "https://music.163.com/#/"+s["kind"].toString()+"?id="+s["id"].toString();}
    void like(QJsonObject s){if(!likedIDs)likedIDs=QJsonArray();likedIDs->append(s["id"]);emit invalidated();}
    void loadMoreSource(int lane){++collectionLoads;lastCollectionLane=lane;}
    quint64 &m_accountGeneration=account;quint64 m_likedIDsAccount=0;
    bool m_likedIDsLoading=false;QString m_likedIDsError;QVector<Completion> m_likedIDWaiters;
    void changed(){emit invalidated();}
    bool likedIDsLoading()const{return m_likedIDsAccount==account&&m_likedIDsLoading;}
    QString likedIDsError()const{return m_likedIDsAccount==account?m_likedIDsError:QString();}
    void ensureLikedIDs(Completion done={});
    QJsonArray directoryQueue()const;
    void playDirectory(){const auto q=directoryQueue();if(!q.isEmpty())player.play(q.first().toObject(),q);}
    void loadDirectoryPage(){
        if(!directory||directoryLoading)return;directoryLoading=true;++pageRequests;emit invalidated();const auto f=directory;const auto generation=account;
        api.request("/fixture/page",{{"cursor",f->cursor}},[this,f](MusicReply r){directoryLoading=false;if(r.ok()){for(const auto &v:r.value.toArray())f->songs.append(v);f->cursor=std::min(f->cursor+100,int(f->ids.size()));}emit invalidated();},[this,f,generation]{return directory==f&&account==generation;});
    }
    void mutate(QString route,QJsonObject values,std::function<void(QJsonObject)> success,Completion done){
        if(writeLoading){if(done)done(false);return;}writeLoading=true;emit invalidated();
        const auto generation=account;
        api.request(route,values,[this,success,done](MusicReply r){if(r.ok())success(r.value.toObject());status=r.error;writeLoading=false;emit invalidated();if(done)done(r.ok());},[this,generation]{return account==generation;});
    }
signals:void invalidated();
};
