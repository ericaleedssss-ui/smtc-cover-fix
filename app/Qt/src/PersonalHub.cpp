#include "PersonalHub.h"
#include "MusicData.h"
#include <QDateTime>
#include <QJsonDocument>
#include <QPointer>
#include <QUrl>
#include <QUrlQuery>

namespace {
QString id(QJsonValue v) { return v.isString()?v.toString():v.isDouble()?QString::number(v.toInteger()):QString(); }
}
PersonalHub::PersonalHub(MusicLibrary *music,QObject *parent):QObject(parent),m_music(music) {
    connect(music,&MusicLibrary::invalidated,this,&PersonalHub::syncAccount);
    syncAccount();
}
void PersonalHub::syncAccount() {
    if(m_account==m_music->accountGeneration()&&m_uid==m_music->uid&&m_provider==m_music->provider)return;
    m_account=m_music->accountGeneration();m_uid=m_music->uid;m_provider=m_music->provider;
    m_pages.clear();emit changed();
}
QVariantMap PersonalHub::state() const {
    QVariantMap result{{"supported",m_provider=="netease"&&!m_uid.isEmpty()}};
    for(auto it=m_pages.cbegin();it!=m_pages.cend();++it) {
        const auto &p=it.value();
        result[it.key()]=QVariantMap{{"rows",p.rows},{"data",p.data},{"loading",p.busy},{"loaded",p.loaded},{"error",p.error},{"more",p.more}};
    }
    return result;
}
void PersonalHub::load(QString section,bool more) {
    syncAccount();
    if(m_provider!="netease"||m_uid.isEmpty())return;
    if(!QStringList{"identity","level","vip","created","collected","albums","songs","recentAlbums","recentPlaylists"}.contains(section))return;
    auto &p=m_pages[section];
    const auto now=QDateTime::currentMSecsSinceEpoch();
    if(p.busy||(more&&!p.more)||(!more&&p.loaded&&now-p.fetched<120000))return;
    if(!more&&now-p.fetched<15000)return;
    if(!more){p.offset=0;p.rows.clear();}
    p.busy=true;p.error.clear();const auto serial=++p.serial;
    QString route;QJsonObject params;
    if(section=="identity"){route="/user/detail";params={{"uid",m_uid}};}
    else if(section=="level")route="/user/level";
    else if(section=="vip")route="/vip/info/v2";
    else if(section=="created"||section=="collected"){route="/user/playlist";params={{"uid",m_uid},{"limit",60},{"offset",p.offset}};}
    else if(section=="albums"){route="/album/sublist";params={{"limit",60},{"offset",p.offset}};}
    else {route="/record/recent/"+QString(section=="songs"?"song":section=="recentAlbums"?"album":"playlist");params={{"limit",100}};}
    p.fetched=now;emit changed();
    const auto account=m_account;const auto uid=m_uid;
    QPointer<PersonalHub> self(this);
    m_music->api.request(route,params,[self,section,serial](MusicReply r){
        if(!self)return;auto &p=self->m_pages[section];if(p.serial!=serial)return;
        p.busy=false;
        if(!r.ok()){p.error=QStringLiteral("暂时无法读取，请稍后重试");emit self->changed();return;}
        const auto b=r.value.toObject();p.loaded=true;
        if(section=="identity"){
            auto profile=b["profile"].toObject();profile["level"]=b["level"];
            // Keep only public profile fields needed by the card.
            for(const auto &k:{"nickname","avatarUrl","backgroundUrl","signature","follows","followeds","eventCount","level"})
                if(profile.contains(k))p.data[k]=profile[k].toVariant();
        } else if(section=="level"){
            const auto d=b["data"].toObject();
            for(const auto &k:{"level","progress","nextPlayCount","nextLoginCount","nowPlayCount","nowLoginCount"})if(d.contains(k))p.data[k]=d[k].toVariant();
            p.data["full"]=b["full"].toBool();
        } else if(section=="vip"){
            const auto d=b["data"].toObject();const auto now=d["now"].toInteger(QDateTime::currentMSecsSinceEpoch());
            const auto plus=d["redplus"].toObject(),normal=d["associator"].toObject();
            const auto active=plus["expireTime"].toInteger()>now?plus:normal;
            if(active["expireTime"].toInteger()>now){
                p.data["label"]=plus["expireTime"].toInteger()>now?QStringLiteral("SVIP"):QStringLiteral("黑胶 VIP");
                p.data["level"]=d["redVipLevel"].toVariant();
                p.data["expires"]=QDateTime::fromMSecsSinceEpoch(active["expireTime"].toInteger()).toLocalTime().toString("yyyy.MM.dd");
            } else p.data["label"]=QStringLiteral("普通账户");
        } else {
            QJsonArray raw;
            const bool history=section=="songs"||section=="recentAlbums"||section=="recentPlaylists";
            if(history)raw=b["data"].toObject()["list"].toArray();
            else raw=(section=="albums"?b["data"]:b["playlist"]).toArray();
            QSet<QString> seen;for(const auto &v:p.rows)seen.insert(v.toMap()["key"].toString());
            for(const auto &v:raw){
                const auto entry=v.toObject();const auto source=history?entry["data"].toObject():entry;
                if(section=="created"||section=="collected"){
                    const bool own=id(source["creator"].toObject()["userId"])==self->m_uid;
                    if((section=="created")!=own)continue;
                }
                const auto kind=section=="songs"?"song":(section=="albums"||section=="recentAlbums")?"album":"playlist";
                auto item=MusicData::parse(source,kind);if(item.isEmpty())continue;
                const auto key=item["key"].toString();if(seen.contains(key))continue;seen.insert(key);
                if(history&&entry["playTime"].toInteger()>0)item["heardAt"]=QDateTime::fromMSecsSinceEpoch(entry["playTime"].toInteger()).toLocalTime().toString("MM.dd HH:mm");
                p.rows.append(item.toVariantMap());
            }
            p.offset+=raw.size();p.more=!history&&!raw.isEmpty()&&b["more"].toBool(b["hasMore"].toBool());
        }
        emit self->changed();
    },[self,account,uid]{return self&&self->m_music->accountGeneration()==account&&self->m_music->uid==uid&&self->m_music->provider=="netease";});
}
void PersonalHub::activate(QString section,int index) {
    syncAccount();const auto rows=m_pages.value(section).rows;if(index<0||index>=rows.size())return;
    const auto item=QJsonObject::fromVariantMap(rows[index].toMap());
    if(item["provider"]!=m_music->provider)return;
    if(item["kind"]=="song"){
        // An explicit row click starts playback; merely hovering never plays or changes the page.
        QJsonArray queue;for(const auto &v:rows)queue.append(QJsonObject::fromVariantMap(v.toMap()));
        m_music->player.play(item,queue);m_music->changed();
    } else {
        emit navigate("music:collection-open:"+QString::fromUtf8(QUrl::toPercentEncoding(QString::fromUtf8(QJsonDocument(item).toJson(QJsonDocument::Compact)))));
    }
}
void PersonalHub::loadFolder(QString section,int index) {
    syncAccount();
    const auto rows=m_pages.value(section).rows;
    if(m_provider!="netease"||m_uid.isEmpty()||index<0||index>=rows.size())return;
    const auto item=rows[index].toMap();
    if(item["kind"]!="playlist")return;
    const auto key="folder:"+item["key"].toString();
    auto &p=m_pages[key];
    if(p.busy||p.loaded||QDateTime::currentMSecsSinceEpoch()-p.fetched<15000)return;
    p.busy=true;p.error.clear();p.fetched=QDateTime::currentMSecsSinceEpoch();
    const auto serial=++p.serial;const auto account=m_account;const auto uid=m_uid;
    QPointer<PersonalHub> self(this);emit changed();
    m_music->api.request("/playlist/detail",{{"id",item["id"].toString()},{"s",0}},[self,key,serial](MusicReply r){
        if(!self)return;
        auto &p=self->m_pages[key];if(p.serial!=serial)return;
        p.busy=false;
        if(!r.ok()){p.error=QStringLiteral("歌曲预览暂时无法读取");emit self->changed();return;}
        const auto raw=r.value.toObject()["playlist"].toObject()["tracks"].toArray();
        for(const auto &entry:raw){auto song=MusicData::parse(entry.toObject(),"song");if(!song.isEmpty())p.rows.append(song.toVariantMap());if(p.rows.size()==4)break;}
        p.loaded=true;emit self->changed();
    },[self,account,uid]{return self&&self->m_music->accountGeneration()==account&&self->m_music->uid==uid&&self->m_music->provider=="netease";});
}
QString PersonalHub::previewCover(QString source) const {
    return sizedCover(source,320);
}
// Cloudy ui_kit.go cover() requests Sized(url, px) before entering its art cache.
// Match the requested decode size at the CDN too, rather than downloading an
// original artwork for a 40px row. Other providers/local URLs stay intact.
QString PersonalHub::sizedCover(QString source,int pixels) const {
    QUrl url(source);
    if(url.scheme()!="http"&&url.scheme()!="https")return source;
    url.setScheme("https");
    if(url.host()=="music.126.net"||url.host().endsWith(".music.126.net")){
        QUrlQuery query(url);query.removeAllQueryItems("param");
        const auto size=QString::number(qBound(64,pixels,1024));
        query.addQueryItem("param",size+"y"+size);url.setQuery(query);
    }
    return url.toString();
}
void PersonalHub::updateSignature(QString signature) {
    syncAccount();
    auto &page = m_pages["identity"];
    page.data["signature"] = signature;
    emit changed();
}
void PersonalHub::openMembership() {
    syncAccount();if(m_provider=="netease"&&!m_uid.isEmpty())emit externalRequested("https://music.163.com/#/member");
}
void PersonalHub::openOriginal(QString section,int index) {
    syncAccount();const auto rows=m_pages.value(section).rows;
    if(index<0||index>=rows.size())return;
    const auto item=QJsonObject::fromVariantMap(rows[index].toMap());
    if(item["provider"]=="netease"&&QStringList{"playlist","album","song"}.contains(item["kind"].toString()))
        emit externalRequested("https://music.163.com/#/"+item["kind"].toString()+"?id="+item["id"].toString());
}
