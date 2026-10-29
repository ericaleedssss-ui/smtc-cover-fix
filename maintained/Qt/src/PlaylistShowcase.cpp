#include "PlaylistShowcase.h"
#include "MusicData.h"
#include <QJsonDocument>
#include <QPointer>
#include <QRandomGenerator>
#include <QUrl>
#include <QTimer>
#include <algorithm>

namespace {QString key(QJsonObject o){return o["key"].toString();} QString textID(QJsonValue v){return v.isString()?v.toString():QString::number(v.toInteger());}}
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
    const auto account=m_music->accountGeneration();const auto current=m_music->current;
    if(m_account!=account||m_key!=key(current)||m_directory!=bool(m_music->directory)){
        m_directory=bool(m_music->directory);
        ++m_token;m_account=account;m_key=key(current);m_item=current;m_songs={};m_ids={};m_loading=false;m_previewLoading=false;m_durationFailed=false;m_loaded=false;m_pending.clear();m_unsubscribe.clear();m_status.clear();
        if(current["kind"]=="playlist"&&!m_music->directory)load();
        emit changed();return;
    }
    if(m_revision!=m_music->revision){m_revision=m_music->revision;if(m_item["kind"]=="playlist")emit changed();}
}
void PlaylistShowcase::refresh(){if(!m_loading){++m_token;m_loaded=false;m_previewLoading=false;m_durationFailed=false;m_pending.clear();m_music->host->invalidateMetadata();load();}}
void PlaylistShowcase::load(){
    if(m_loading||m_item["kind"]!="playlist"||m_music->directory)return;
    m_loading=true;m_status.clear();emit changed();const auto token=m_token;const auto account=m_account;const auto k=m_key;QPointer<PlaylistShowcase> self(this);
    m_music->api.call("detail",{m_item},[self](MusicReply r){
        if(!self)return;self->m_loading=false;
        const auto a=r.value.toArray();
        if(!r.ok()||a.size()<3||!a[1].isArray()||!a[2].isArray()||key(a[0].toObject())!=self->m_key){self->m_status="歌单读取失败，请重试";self->m_pending.clear();emit self->changed();return;}
        auto updated=a[0].toObject();if(updated["cover"].toString().isEmpty())updated["cover"]=self->m_item["cover"];self->m_item=updated;self->m_songs=a[1].toArray();self->m_ids=a[2].toArray();self->m_loaded=true;
        self->m_music->details[self->m_key]=self->m_item;
        const auto pending=self->m_pending;self->m_pending.clear();emit self->changed();if(!pending.isEmpty())self->execute(pending);self->completeDuration();
    },[self,token,account,k]{return self&&self->m_token==token&&self->m_music->accountGeneration()==account&&key(self->m_music->current)==k&&!self->m_music->directory;});
}
bool PlaylistShowcase::subscribed()const{
    if(m_music->subscriptions.contains(m_key))return true;
    for(const auto &v:m_music->lists[3])if(key(v.toObject())==m_key)return true;
    return m_item["subscribed"].toBool();
}
QVariantMap PlaylistShowcase::info()const{
    auto i=m_item.toVariantMap();i["sourceLabel"]=m_music->libraryName();i["loading"]=m_loading;i["subscribed"]=subscribed();i["editable"]=m_music->canEditPlaylist(m_item);
    i["canSubscribe"]=m_music->provider=="netease"&&!m_music->uid.isEmpty()&&!m_item["virtual"].toBool()&&!m_music->canEditPlaylist(m_item);
    i["total"]=std::max(m_item["trackCount"].toInt(),int(m_ids.size()));
    qint64 ms=0;bool complete=m_loaded&&!m_songs.isEmpty()&&m_songs.size()==m_ids.size();
    for(const auto &v:m_songs){const auto duration=v.toObject()["duration"].toInteger();ms+=duration;complete&=duration>0;}
    i["durationLabel"]=complete?QString("%1 小时 %2 分钟").arg(ms/3600000).arg(ms/60000%60):((m_durationFailed||(m_loaded&&m_songs.size()>=m_ids.size()))?QString("总时长暂不可用"):QString("正在计算总时长…"));
    i["recordsLoading"]=m_music->personalLoading;i["recordsMore"]=m_music->hasMore[m_music->selectedLane];i["recordPosition"]=m_music->libraryIndex()+1;i["recordCount"]=m_music->libraryItems().size();
    i["session"]=m_key;return i;
}
QVariantMap PlaylistShowcase::recordNeighbour(int step)const{
    const auto a=m_music->libraryItems();int pos=-1;for(int n=0;n<a.size();++n)if(key(a[n].toObject())==m_key){pos=n;break;}
    if(pos<0||a.size()<2)return{};int at=pos+step;
    if(at<0||at>=a.size()){if(m_music->hasMore[m_music->selectedLane])return{};at=(at%a.size()+a.size())%a.size();}
    auto o=a[at].toObject();if(o["kind"]!="playlist"||key(o)==m_key)return{};o["side"]=step<0?-1:1;return o.toVariantMap();
}
QVariantList PlaylistShowcase::covers()const{QVariantList out;for(int d:{-1,1}){auto o=recordNeighbour(d);if(!o.isEmpty())out.append(o);}return out;}
void PlaylistShowcase::prepareRecords(){if(m_music->hasMore[m_music->selectedLane]&&!m_music->personalLoading)m_music->loadMoreSource(m_music->selectedLane);}
void PlaylistShowcase::openCover(QString k){
    if(k==m_key)return;for(const auto &v:m_music->libraryItems())if(key(v.toObject())==k&&v.toObject()["kind"]=="playlist"){
        const auto lane=m_music->selectedLane;for(int n=0;n<m_music->lists[lane].size();++n)if(key(m_music->lists[lane][n].toObject())==k){m_music->selectResult(n,lane,false);return;}return;
    }
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
    if(m_item["kind"]!="playlist"||m_music->directory)return;
    if(op=="details"){emit navigate("music:playlist-info");return;}
    if(op=="creator"){const auto uid=m_item["creatorID"].toString();if(!uid.isEmpty())emit navigate("profile:open:"+uid);return;}
    if(op=="copy"){const auto url=m_music->sourceURL(m_item);if(url.isEmpty())m_status="当前歌单没有可分享的链接";else{m_music->host->copy(m_item["title"].toString()+"\n"+url);m_status="已复制歌单链接";}emit changed();return;}
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
    const auto tracks=queue();if(tracks.isEmpty()){m_status="这张歌单没有可播放的歌曲";emit changed();return;}
    if(op=="append"){const auto n=m_music->player.enqueueMany(tracks);m_status=QString("已添加 %1 首歌曲").arg(n);}
    else{const int at=op=="shuffle"?QRandomGenerator::global()->bounded(int(tracks.size())):0;m_music->player.mode=op=="shuffle"?"shuffle":"all";m_music->player.play(tracks[at].toObject(),tracks,at);if(m_music->player.mode!=(op=="shuffle"?"shuffle":"all")){m_music->player.mode=op=="shuffle"?"shuffle":"all";m_music->player.changed();}m_status=op=="shuffle"?"已开始随机播放":"已开始播放歌单";}
    emit changed();
}

QVariantList PlaylistShowcase::songs()const{return queue().toVariantList();}
void PlaylistShowcase::preview(int at){
    if(!m_loaded||m_previewLoading||at<0||at>=m_ids.size())return;
    const auto id=textID(m_ids[at]);for(const auto &v:m_songs)if(v.toObject()["id"]==id)return;
    m_previewLoading=true;const auto token=m_token;const auto account=m_account;QPointer<PlaylistShowcase> self(this);
    const auto ids=MusicData::slice(m_ids,at/100*100,100);
    m_music->api.call("songs",{ids},[self,ids,token](MusicReply r){
        if(!self)return;self->m_previewLoading=false;
        if(r.ok()){
            self->m_songs=MusicData::unique(self->m_songs,r.value.toArray());
            for(const auto &id:ids)if(MusicData::indexOfId(self->m_songs,textID(id))<0)self->m_durationFailed=true;
        }else{self->m_durationFailed=true;self->m_status="部分曲目信息读取失败，可重新读取资料";}
        emit self->changed();
        if(!self->m_durationFailed)QTimer::singleShot(600,self,[self,token]{if(self&&self->m_token==token)self->completeDuration();});
    },[self,token,account]{return self&&self->m_token==token&&self->m_music->accountGeneration()==account;});
}
void PlaylistShowcase::playSong(int at){const auto tracks=queue();if(at>=0&&at<tracks.size())m_music->player.play(tracks[at].toObject(),tracks,at);}
void PlaylistShowcase::subscribe(bool enabled){
    if(!info()["canSubscribe"].toBool()||m_music->writeLoading)return;
    const auto item=m_item;const auto k=m_key;QPointer<PlaylistShowcase> self(this);
    m_music->mutate("/playlist/subscribe",{{"id",item["id"]},{"t",enabled?1:2}},[self,item,k,enabled](QJsonObject){
        if(!self)return;auto updated=item;updated["subscribed"]=enabled;self->m_music->details[k]=updated;
        if(self->m_key==k)self->m_item=updated;
        if(key(self->m_music->current)==k)self->m_music->current["subscribed"]=enabled;
        if(enabled){self->m_music->subscriptions.insert(k);self->m_music->lists[3]=MusicData::unique(self->m_music->lists[3],{updated});}
        else{self->m_music->subscriptions.remove(k);QJsonArray kept;for(const auto &v:self->m_music->lists[3])if(key(v.toObject())!=k)kept.append(v);self->m_music->lists[3]=kept;}
        self->m_music->totals[3]=self->m_music->lists[3].size();
    },[self,k,enabled](bool ok){if(self&&self->m_key==k){self->m_status=ok?(enabled?"已收藏":"已取消收藏"):"收藏失败，请重试";emit self->changed();}});
}

void PlaylistShowcase::completeDuration(){
    if(!m_loaded||m_previewLoading||m_durationFailed||m_music->directory)return;
    for(int n=0;n<m_ids.size();++n)if(MusicData::indexOfId(m_songs,textID(m_ids[n]))<0){preview(n);return;}
}
