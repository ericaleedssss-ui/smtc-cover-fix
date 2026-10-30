#include "PlaylistShowcase.h"
#include "MusicData.h"
#include <QJsonDocument>
#include <QBuffer>
#include <QPointer>
#include <QRandomGenerator>
#include <QUrl>
#include <QTimer>
#include <algorithm>

namespace {QString key(QJsonObject o){return o["key"].toString();} bool container(QJsonObject o){return o["kind"]=="playlist"||o["kind"]=="album";} QString textID(QJsonValue v){return v.isString()?v.toString():QString::number(v.toInteger());}}
PlaylistShowcase::PlaylistShowcase(MusicLibrary *music,NativeHud *hud,QObject *parent):QObject(parent),m_music(music),m_hud(hud){
    connect(music,&MusicLibrary::invalidated,this,&PlaylistShowcase::sync);
    connect(&music->player,&MusicPlayer::changed,this,&PlaylistShowcase::syncHeart);
    sync();
}
void PlaylistShowcase::syncHeart(){
    const auto heart=m_music->provider+":"+m_music->uid+":"+key(m_music->player.current)+":"+QString::number(m_music->accountGeneration());
    if(heart!=m_heartQuery){m_heartQuery=heart;if(m_music->player.current["kind"]=="song"&&!m_music->likedIDs&&m_music->provider=="netease"&&!m_music->uid.isEmpty())m_music->ensureLikedIDs();}
}
void PlaylistShowcase::sync(){
    syncHeart();
    prepareInitialRecords();
    const auto account=m_music->accountGeneration();const auto current=m_music->current;
    if(m_account!=account||m_key!=key(current)||m_directory!=bool(m_music->directory)){
        m_directory=bool(m_music->directory);
        ++m_token;m_account=account;m_key=key(current);m_item=current;m_songs={};m_ids={};m_loading=false;m_previewLoading=false;m_loadFailed=false;m_identityAvatar.clear();m_avatarRetried=false;m_identityPending=false;m_loaded=false;m_pending.clear();m_unsubscribe.clear();m_status.clear();
        if(container(current)&&!m_music->directory){loadIdentity();load();}
        emit changed();return;
    }
    if(m_revision!=m_music->revision){m_revision=m_music->revision;if(container(m_item))emit changed();}
}
void PlaylistShowcase::refresh(){if(!m_loading){++m_token;m_identityPending=false;m_loaded=false;m_previewLoading=false;m_loadFailed=false;m_pending.clear();m_music->host->invalidateMetadata();load();}}
void PlaylistShowcase::load(){
    if(m_loading||!container(m_item)||m_music->directory)return;
    m_loading=true;m_loadFailed=false;m_status.clear();emit changed();const auto token=m_token;const auto account=m_account;const auto k=m_key;QPointer<PlaylistShowcase> self(this);
    m_music->api.call("detail",{m_item},[self](MusicReply r){
        if(!self)return;self->m_loading=false;
        const auto a=r.value.toArray();
        if(!r.ok()||a.size()<3||!a[1].isArray()||!a[2].isArray()||key(a[0].toObject())!=self->m_key){self->m_loadFailed=true;self->m_status="资料读取失败，请重试";self->m_pending.clear();emit self->changed();return;}
        auto updated=a[0].toObject();if(updated["cover"].toString().isEmpty())updated["cover"]=self->m_item["cover"];if(updated["artists"].toArray().isEmpty())updated["artists"]=self->m_item["artists"];self->m_item=updated;self->m_songs=a[1].toArray();self->m_ids=a[2].toArray();
        // /album returns songs, while playlist detail supplies trackIds. Some
        // providers omit the third tuple entry's IDs for albums entirely.
        if(self->m_item["kind"]=="album"&&self->m_ids.isEmpty())for(const auto &v:self->m_songs){const QJsonValue id=v.toObject()["id"];if(!textID(id).isEmpty()&&textID(id)!="0")self->m_ids.append(textID(id));}
        if(self->m_ids.isEmpty()&&self->m_item["trackCount"].toInt()>0){self->m_loadFailed=true;self->m_status="曲目未读取完整，请重新读取资料";self->m_pending.clear();emit self->changed();return;}
        self->m_loaded=true;self->loadIdentity();
        self->m_music->details[self->m_key]=self->m_item;
        const auto pending=self->m_pending;self->m_pending.clear();emit self->changed();if(!pending.isEmpty())self->execute(pending);
    },[self,token,account,k]{return self&&self->m_token==token&&self->m_music->accountGeneration()==account&&key(self->m_music->current)==k&&!self->m_music->directory;});
}
bool PlaylistShowcase::subscribed()const{
    if(m_music->subscriptions.contains(m_key))return true;
    for(const auto &v:m_music->lists[m_item["kind"]=="album"?4:3])if(key(v.toObject())==m_key)return true;
    return m_item["subscribed"].toBool();
}
QVariantMap PlaylistShowcase::info()const{
    auto i=m_item.toVariantMap();i["sourceLabel"]=m_music->libraryName();i["recordLane"]=m_music->selectedLane;i["loading"]=m_loading;i["subscribed"]=subscribed();i["editable"]=m_music->canEditPlaylist(m_item);
    i["canSubscribe"]=m_music->provider=="netease"&&!m_music->uid.isEmpty()&&!m_item["virtual"].toBool()&&!m_music->canEditPlaylist(m_item);
    QVariantList people;
    if(m_item["kind"]=="album"){for(const auto &v:m_item["artists"].toArray()){const auto artist=v.toObject();if(!artist["id"].toString().isEmpty())people.append(QVariantMap{{"id",artist["id"].toString()},{"name",artist["name"].toString()}});}}
    else if(!m_item["creatorID"].toString().isEmpty())people.append(QVariantMap{{"id",m_item["creatorID"].toString()},{"name",m_item["artist"].toString()}});
    i["identities"]=people;
    i["loadFailed"]=m_loadFailed;i["loaded"]=m_loaded;i["identityAvatar"]=m_identityAvatar;
    i["identityCanOpen"]=m_item["kind"]=="album"?!m_item["artists"].toArray().isEmpty():!m_item["creatorID"].toString().isEmpty();
    i["total"]=std::max(m_item["trackCount"].toInt(),int(m_ids.size()));
    const auto all=records();int pos=0;for(int n=0;n<all.size();++n)if(key(all[n].toObject())==m_key){pos=n;break;}
    bool more=false;for(int lane:{2,3,4})more|=m_music->hasMore[lane];
    i["recordsLoading"]=m_music->personalLoading;i["recordsMore"]=more;i["recordPosition"]=pos+1;i["recordCount"]=all.size();
    i["session"]=m_key;return i;
}
QJsonArray PlaylistShowcase::records()const{
    QJsonArray out;QSet<QString> seen;
    // Account collections form one ordered sequence. Retain search selections as well.
    if(m_music->selectedLane<2)for(const auto &v:m_music->libraryItems()){auto o=v.toObject();if(container(o)&&!seen.contains(key(o))){seen.insert(key(o));out.append(o);}}
    for(int lane:{2,3,4})for(const auto &v:m_music->lists[lane]){auto o=v.toObject();if(container(o)&&!seen.contains(key(o))){seen.insert(key(o));out.append(o);}}
    if(container(m_music->current)&&!seen.contains(key(m_music->current)))out.append(m_music->current);
    return out;
}
QVariantMap PlaylistShowcase::recordNeighbour(int step)const{
    const auto a=records();int pos=-1;for(int n=0;n<a.size();++n)if(key(a[n].toObject())==m_key){pos=n;break;}
    if(pos<0||a.size()<2)return{};
    const int at=((pos+step)%a.size()+a.size())%a.size();
    auto o=a[at].toObject();if(key(o)==m_key)return{};o["side"]=step<0?-1:1;return o.toVariantMap();
}
QVariantList PlaylistShowcase::covers()const{QVariantList out;for(int d:{-1,1}){auto o=recordNeighbour(d);if(!o.isEmpty())out.append(o);}return out;}
void PlaylistShowcase::prepareInitialRecords(){
    const auto account=m_music->accountGeneration();if(m_prefetchAccount!=account){m_prefetchAccount=account;m_requestedLanes.clear();}
    if(m_music->directory||!container(m_music->current)||m_music->uid.isEmpty()||m_music->personalLoading)return;
    for(int lane:{2,3,4})if(m_music->lists[lane].isEmpty()&&m_music->hasMore[lane]&&!m_requestedLanes.contains(lane)){
        m_requestedLanes.insert(lane);if(lane==2||lane==3){m_requestedLanes.insert(2);m_requestedLanes.insert(3);}
        m_music->loadMoreSource(lane);return;
    }
}
void PlaylistShowcase::prepareRecords(){
    prepareInitialRecords();if(m_music->personalLoading)return;
    const auto lane=m_music->selectedLane;
    if(lane>=2&&m_music->hasMore[lane])m_music->loadMoreSource(lane);
}
void PlaylistShowcase::openCover(QString k){
    if(k==m_key)return;
    for(int lane:{2,3,4,0})for(int n=0;n<m_music->lists[lane].size();++n){const auto o=m_music->lists[lane][n].toObject();if(key(o)==k&&container(o)){m_music->selectResult(n,lane,false);return;}}
}
QJsonArray PlaylistShowcase::queue()const{
    QJsonArray out;QHash<QString,QJsonObject> known;
    for(const auto &v:m_songs)known[v.toObject()["id"].toString()]=v.toObject();
    for(const auto &v:m_ids){const auto id=v.isString()?v.toString():QString::number(v.toInteger());auto song=known.value(id);
        if(song.isEmpty()){song=MusicData::item("song",id,"待读取曲目",{},m_music->provider);song["deferred"]=true;}
        if(!song["unavailable"].toBool())out.append(MusicData::withQueueSource(song,m_item));
    }
    return out;
}
void PlaylistShowcase::operate(QString op){
    if(!container(m_item)||m_music->directory)return;
    if(op=="details"){emit navigate(m_item["kind"]=="album"?"music:directory":"music:playlist-info");return;}
    if(op=="creator"){if(m_item["kind"]=="album"){if(!m_item["artists"].toArray().isEmpty()){m_music->current["artists"]=m_item["artists"];emit navigate("music:artist:0");}return;}const auto uid=m_item["creatorID"].toString();if(!uid.isEmpty())emit navigate("profile:open:"+uid);return;}
    if(op=="copy"){const auto url=m_music->sourceURL(m_item);if(url.isEmpty())m_status="当前项目没有可分享的链接";else{m_music->host->copy(m_item["title"].toString()+"\n"+url);m_status="已复制分享链接";}emit changed();return;}
    if(op=="subscribe"){
        if(!info()["canSubscribe"].toBool()||m_music->writeLoading)return;
        if(subscribed()){m_unsubscribe=m_key;return;}
        subscribe(true);return;
    }
    if(!QStringList{"play","shuffle","append"}.contains(op))return;
    if(m_music->player.roamActive&&op=="append"){m_status="请先退出漫游再添加到播放列表";emit changed();return;}
    if(!m_pending.isEmpty())return;
    if(!m_loaded){m_pending=op;load();return;}execute(op);
}
void PlaylistShowcase::confirmUnsubscribe(){if(m_unsubscribe!=m_key||!subscribed())return;m_unsubscribe.clear();subscribe(false);}
void PlaylistShowcase::execute(QString op){
    const auto tracks=queue();if(tracks.isEmpty()){m_status="没有可播放的歌曲";emit changed();return;}
    if(op=="append"){const auto n=m_music->player.enqueueMany(tracks);m_status=QString("已添加 %1 首歌曲").arg(n);}
    else{const int at=op=="shuffle"?QRandomGenerator::global()->bounded(int(tracks.size())):0;m_music->player.mode=op=="shuffle"?"shuffle":"all";m_music->archiveNowPlaying=true;m_music->archivePlayingDirectory=m_music->directory;m_music->archiveReturnItem=m_item;m_music->player.play(tracks[at].toObject(),tracks,at);m_music->changed();if(m_music->player.mode!=(op=="shuffle"?"shuffle":"all")){m_music->player.mode=op=="shuffle"?"shuffle":"all";m_music->player.changed();}m_status=op=="shuffle"?"已开始随机播放":"已开始播放";}
    emit changed();
}

QVariantList PlaylistShowcase::songs()const{return queue().toVariantList();}
void PlaylistShowcase::preview(int at){
    if(!m_loaded||m_previewLoading||at<0||at>=m_ids.size())return;
    const auto id=textID(m_ids[at]);for(const auto &v:m_songs)if(v.toObject()["id"]==id&&v.toObject()["duration"].toInteger()>0)return;
    m_previewLoading=true;const auto token=m_token;const auto account=m_account;QPointer<PlaylistShowcase> self(this);
    const auto ids=MusicData::slice(m_ids,at/100*100,100);
    m_music->api.call("songs",{ids},[self,ids,token](MusicReply r){
        if(!self)return;self->m_previewLoading=false;
        if(r.ok()){
            for(const auto &value:r.value.toArray()){const auto song=value.toObject();const int at=MusicData::indexOfId(self->m_songs,song["id"].toString());if(at>=0)self->m_songs.replace(at,song);else self->m_songs.append(song);}
        }else self->m_status="部分曲目信息读取失败，可重新读取资料";
        emit self->changed();
    },[self,token,account]{return self&&self->m_token==token&&self->m_music->accountGeneration()==account;});
}
void PlaylistShowcase::playSong(int at){const auto tracks=queue();if(at>=0&&at<tracks.size()){m_music->archiveNowPlaying=true;m_music->archivePlayingDirectory=m_music->directory;m_music->archiveReturnItem=m_item;m_music->player.play(tracks[at].toObject(),tracks,at);m_music->changed();}}
void PlaylistShowcase::subscribe(bool enabled){
    if(!info()["canSubscribe"].toBool()||m_music->writeLoading)return;
    const auto item=m_item;const auto k=m_key;const int lane=item["kind"]=="album"?4:3;QPointer<PlaylistShowcase> self(this);
    m_music->mutate(item["kind"]=="album"?"/album/sub":"/playlist/subscribe",{{"id",item["id"]},{"t",enabled?1:2}},[self,item,k,enabled,lane](QJsonObject){
        if(!self)return;auto updated=item;updated["subscribed"]=enabled;self->m_music->details[k]=updated;
        if(self->m_key==k)self->m_item=updated;
        if(key(self->m_music->current)==k)self->m_music->current["subscribed"]=enabled;
        if(enabled){self->m_music->subscriptions.insert(k);self->m_music->lists[lane]=MusicData::unique(self->m_music->lists[lane],{updated});}
        else{self->m_music->subscriptions.remove(k);QJsonArray kept;for(const auto &v:self->m_music->lists[lane])if(key(v.toObject())!=k)kept.append(v);self->m_music->lists[lane]=kept;}
        self->m_music->totals[lane]=self->m_music->lists[lane].size();
    },[self,k,enabled](bool ok){if(self&&self->m_key==k){self->m_status=ok?(enabled?"已收藏":"已取消收藏"):"收藏失败，请重试";emit self->changed();}});
}

void PlaylistShowcase::openIdentity(QString id){
    if(id.isEmpty())return;
    if(m_item["kind"]=="album"){
        const auto artists=m_item["artists"].toArray();for(int n=0;n<artists.size();++n)if(artists[n].toObject()["id"]==id){m_music->current["artists"]=artists;emit navigate("music:artist:"+QString::number(n));return;}
    }else if(id==m_item["creatorID"].toString())emit navigate("profile:open:"+id);
}
void PlaylistShowcase::retryIdentityAvatar(){
    if(m_avatarRetried)return;m_avatarRetried=true;m_identityAvatar.clear();loadIdentity(false);emit changed();
}
void PlaylistShowcase::loadIdentity(bool fallback){
    const bool album=m_item["kind"]=="album";const auto artist=m_item["artists"].toArray().isEmpty()?QJsonObject{}:m_item["artists"].toArray().first().toObject();
    const auto id=album?artist["id"].toString():m_item["creatorID"].toString();
    const auto cacheKey=m_music->provider+":"+(album?"artist:":"user:")+id;
    if(cacheKey!=m_identityKey){m_identityKey=cacheKey;++m_identityRequest;m_identityPending=false;m_identityAvatar.clear();}
    if(m_identityPending)return;
    const auto direct=album?artist["avatar"].toString():m_item["creatorAvatar"].toString();
    if(!fallback&&!m_avatarRetried&&!direct.isEmpty()&&!album){displayIdentity(direct,cacheKey,false);return;}
    if(!fallback&&!m_avatarRetried&&m_avatarCache.contains(cacheKey)){m_identityAvatar=m_avatarCache[cacheKey];return;}
    if(id.isEmpty()||id=="0"||m_music->provider!="netease")return;
    const auto token=m_token;const auto account=m_account;const auto request=++m_identityRequest;QPointer<PlaylistShowcase> self(this);
    const QString route=album?(fallback?"/artists":"/artist/detail"):"/user/detail";
    m_identityPending=true;
    m_music->api.request(route,{{album?"id":"uid",id}},[self,album,fallback,cacheKey,request](MusicReply r){
        if(!self||self->m_identityRequest!=request||self->m_identityKey!=cacheKey)return;self->m_identityPending=false;const auto body=r.value.toObject();const auto person=album?(fallback?body["artist"].toObject():body["data"].toObject()["artist"].toObject()):body["profile"].toObject();
        QString url;
        for(const auto &name:album?QStringList{"avatar","img1v1Url","picUrl","cover"}:QStringList{"avatarUrl"})if(!person[name].toString().isEmpty()){url=person[name].toString();break;}
        if(!r.ok()||url.isEmpty()){if(album&&!fallback)self->loadIdentity(true);return;}
        QUrl address(url);if(address.scheme()=="http")address.setScheme("https");
        self->displayIdentity(address.toString(),cacheKey,album&&!fallback);
    },[self,token,account,request,cacheKey]{return self&&self->m_token==token&&self->m_identityRequest==request&&self->m_identityKey==cacheKey&&self->m_music->accountGeneration()==account;});
}

// Share the native image cache/network policy and publish decoded small pixels.
// QML no longer downloads a second, full-size remote image through another manager.
void PlaylistShowcase::displayIdentity(QString url,QString cacheKey,bool canFallback){
    m_identityPending=true;
    const auto token=m_token;const auto account=m_account;const auto request=++m_identityRequest;QPointer<PlaylistShowcase> self(this);
    m_music->host->loadCover(url,[self,token,account,request,cacheKey,canFallback](QString imageKey){
        if(!self||self->m_token!=token||self->m_identityRequest!=request||self->m_identityKey!=cacheKey||self->m_music->accountGeneration()!=account)return;
        self->m_identityPending=false;
        const auto image=self->m_music->host->image(imageKey);
        if(image.isNull()){if(canFallback)self->loadIdentity(true);return;}
        QByteArray bytes;QBuffer buffer(&bytes);buffer.open(QIODevice::WriteOnly);
        if(!image.save(&buffer,"PNG"))return;
        self->m_identityAvatar="data:image/png;base64,"+QString::fromLatin1(bytes.toBase64());
        self->m_avatarCache[cacheKey]=self->m_identityAvatar;emit self->changed();
    },96);
}
