#include "PlaylistMagazine.h"
#include "MusicData.h"
#include "MusicDiscover.h"
#include <QDateTime>
#include <QDir>
#include <QJsonDocument>
#include <QFileInfo>
#include <QUrlQuery>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <algorithm>
#include <cmath>

namespace {
QString key(const QJsonObject &s) { return MusicPlayer::identity(s); }
QString encoded(const QJsonObject &s) { return QString::fromUtf8(QUrl::toPercentEncoding(QString::fromUtf8(QJsonDocument(s).toJson(QJsonDocument::Compact)))); }
QString textID(const QJsonValue &v) { return v.isString()?v.toString():QString::number(v.toInteger()); }
QJsonArray eligible(const QJsonArray &songs,bool playable=true) {
    QJsonArray result; QSet<QString> seen;
    for (const auto &v:songs) { const auto s=v.toObject(); const auto id=key(s);
        if (s["kind"]=="song" && !s["id"].toString().isEmpty() && (!playable || !s["unavailable"].toBool()) && !seen.contains(id)) { result.append(s);seen.insert(id); }
    } return result;
}
}
PlaylistMagazine::PlaylistMagazine(MusicLibrary *music, NativeHud *hud, QObject *parent)
    : QAbstractListModel(parent),m_music(music),m_hud(hud),m_account(music->accountGeneration()) {
    connect(music,&MusicLibrary::invalidated,this,&PlaylistMagazine::sync);
    connect(&music->player,&MusicPlayer::changed,this,[this]{
        // Playback position changes frequently. Do not invalidate every visible
        // playlist row just because the player's clock advanced.
        if(!m_menuSong.isEmpty()&&m_menuScope=="queue")emit menuChanged();
    });
    sync();
}
PlaylistMagazine::~PlaylistMagazine(){
    ++m_socialToken;++m_menuToken;++m_downloadSerial;
    for(auto *reply:m_network.findChildren<QNetworkReply*>()){QObject::disconnect(reply,nullptr,this,nullptr);reply->abort();}
    if(m_file)m_file->cancelWriting();
}
int PlaylistMagazine::rowCount(const QModelIndex &p) const { return p.isValid()?0:m_rows.size(); }
QHash<int,QByteArray> PlaylistMagazine::roleNames() const { return {{Track,"track"},{SourceIndex,"sourceIndex"},{Chosen,"chosen"},{Heart,"heart"},{HeartKnown,"heartKnown"}}; }
QVariant PlaylistMagazine::data(const QModelIndex &i,int role) const {
    if(!i.isValid()||i.row()<0||i.row()>=m_rows.size()) return {};
    const int n=m_rows[i.row()];const auto song=m_songs.at(n).toObject();
    if(role==Track) { auto value=song; value["durationLabel"]=MusicData::time(song);value["identity"]=key(song);return value.toVariantMap(); }
    if(role==SourceIndex)return n;
    if(role==Chosen)return m_selected.contains(key(song));
    const bool known=m_likesKnown||m_likedKeys.contains(textID(song["id"]));
    if(role==HeartKnown)return known;
    if(role==Heart)return known?QVariant(m_likedKeys.contains(textID(song["id"]))):QVariant();
    return {};
}
bool PlaylistMagazine::active() const {
    const auto folder=m_music->directory;
    if(!folder||m_hud->lyricsMode)return false;
    const auto kind=folder->item["kind"].toString();
    // Ordinary album details retain the native introduction/comment reader.
    // Only albums reached through the record stack share its persistent page.
    const bool magazine=kind=="playlist"||(kind=="album"&&folder->recordBrowse);
    return magazine&&(m_music->directoryInfo||(m_music->directoryLoading&&m_music->current.isEmpty()));
}
QString PlaylistMagazine::session() const { return m_folder?m_folder->item["key"].toString():QString(); }
QString PlaylistMagazine::query() const { return m_folder?m_folder->magazineQuery:QString(); }
QString PlaylistMagazine::filter() const { return m_folder?m_folder->magazineFilter:QString("all"); }
QString PlaylistMagazine::tab() const { return m_folder?m_folder->magazineTab:QString("songs"); }
double PlaylistMagazine::scrollPosition() const { return m_folder?m_folder->magazineScroll:0.; }
QVariantMap PlaylistMagazine::info() const {
    if(!m_folder)return {};
    auto i=m_folder->item.toVariantMap();i.remove("collectorCount");
    i["loaded"]=m_songs.size();i["total"]=std::max({int(m_folder->ids.size()),m_folder->item["trackCount"].toInt(),int(m_songs.size())});
    i["loading"]=m_music->directoryLoading;i["more"]=m_folder->cursor<m_folder->ids.size();
    i["editable"]=m_music->canEditPlaylist(m_folder->item);i["canCollect"]=m_music->provider=="netease"&&!m_music->uid.isEmpty();
    bool subscribed=m_folder->item["subscribed"].toBool()||m_music->subscriptions.contains(session());
    const auto lane=m_folder->item["kind"]=="album"?4:3;
    for(const auto &entry:m_music->lists[lane])subscribed|=entry.toObject()["key"].toString()==session();
    i["subscribed"]=subscribed;
    i["canSubscribe"]=m_music->provider=="netease"&&!m_music->uid.isEmpty()&&!m_folder->item["virtual"].toBool()&&!m_music->canEditPlaylist(m_folder->item);
    i["canDownload"]=m_music->provider=="netease"&&!m_music->uid.isEmpty();
    i["recordsLoading"]=m_music->personalLoading;i["recordsMore"]=!m_recordsComplete;i["recordPosition"]=m_recordIndex+1;i["recordCount"]=m_recordSequence.size();
    i["likesLoading"]=m_music->likedIDsLoading();i["likesError"]=m_music->likedIDsError();
    if(m_collectorCount>=0)i["collectorCount"]=m_collectorCount;
    i["collectorError"]=m_collectorError;
    i["likeBusy"]=m_music->writeLoading;i["searchComplete"]=m_folder->cursor>=m_folder->ids.size()&&!m_music->directoryLoading;
    i["socialLoading"]=m_socialLoading;i["socialMore"]=m_socialOffset<m_socialTotal;
    i["visibleCount"]=rowCount();return i;
}
void PlaylistMagazine::retryLikes(){m_likesAttempted=false;sync();}
void PlaylistMagazine::loadCollectorCount(){
    if(!m_folder||m_folder->item["kind"]!="playlist"||m_folder->item["virtual"].toBool()||m_music->provider!="netease")return;
    const auto folder=m_folder;const auto account=m_account;const auto token=m_collectorToken;
    QPointer<PlaylistMagazine> self(this);
    m_music->api.request("/playlist/subscribers",{{"id",folder->item["id"]},{"limit",1},{"offset",0}},[self](MusicReply r){
        if(!self)return;
        const auto total=r.value.toObject()["total"];
        if(r.ok()&&total.isDouble()&&total.toDouble()>=0){self->m_collectorCount=total.toInteger();self->m_collectorError.clear();}
        else self->m_collectorError=r.ok()?QString("接口未提供收藏者总数"):QString("暂无法读取收藏者总数");
        emit self->changed();
    },[self,folder,account,token]{return self&&self->m_folder==folder&&self->m_music->accountGeneration()==account&&self->m_collectorToken==token;});
}
void PlaylistMagazine::report(QString s){m_status=s;emit changed();m_music->host->invalidate();}
void PlaylistMagazine::sync() {
    if(m_syncing)return;m_syncing=true;
    const bool account=m_account!=m_music->accountGeneration();
    if(account){m_likesAttempted=false;m_recordAnchor={};m_recordSequence={};m_recordInputs={};m_recordKey.clear();m_mutating=false;m_unavailableCovers.clear();m_account=m_music->accountGeneration();m_menuSong={};++m_menuToken;m_downloads={};++m_downloadSerial;if(m_reply)m_reply->abort();m_reply=nullptr;m_file.reset();m_downloading=false;m_pending.clear();m_remove={};m_removeFolder.reset();emit menuChanged();}
    const auto folder=(m_music->directory && QStringList{"playlist","album"}.contains(m_music->directory->item["kind"].toString()))?m_music->directory:nullptr;
    const bool reset=folder!=m_folder||account;
    if(reset){m_likesAttempted=false;m_collectorsRequested=false;m_collectorCount=-1;m_collectorError.clear();++m_collectorToken;if(folder&&!folder->recordBrowse)m_recordAnchor=folder->item;m_recordKey.clear();m_searchRequested=false;m_status.clear();m_folder=folder;m_selected.clear();m_pending.clear();m_waitCursor=-1;m_social={};m_socialOffset=0;m_socialTotal=0;++m_socialToken;m_socialLoading=false;}
    if(m_folder&&!m_music->directoryLoading){if(!m_folder->item["loadError"].toString().isEmpty())m_unavailableCovers.insert(session());else m_unavailableCovers.remove(session());}
    rebuild(reset);refreshCovers();m_syncing=false;emit changed();
    if(m_folder&&m_music->provider=="netease"&&!m_music->uid.isEmpty()&&!m_music->likedIDs&&!m_likesAttempted){
        m_likesAttempted=true;const auto account=m_account;QTimer::singleShot(0,this,[this,account]{if(m_folder&&account==m_music->accountGeneration())m_music->ensureLikedIDs();else if(account==m_account)m_likesAttempted=false;});
    }
    if(m_folder&&!m_collectorsRequested&&!m_music->directoryLoading){m_collectorsRequested=true;loadCollectorCount();}
    if(!m_pending.isEmpty())QTimer::singleShot(0,this,&PlaylistMagazine::finishAll);
    if(reset && m_folder && tab()!="songs")loadSocial(true);
    if(m_folder&&!query().isEmpty()&&!m_searchRequested&&m_pending.isEmpty()&&!m_music->directoryLoading&&m_folder->cursor<m_folder->ids.size())beginAll("search-all");
}
void PlaylistMagazine::rebuild(bool reset) {
    const auto songs=m_folder?m_folder->songs:QJsonArray();
    QJsonArray liked=m_music->likedIDs.value_or(QJsonArray());
    if(!m_music->likedIDs)for(const auto &v:m_music->lists[1])liked.append(v.toObject()["id"]);
    const bool known=m_music->provider!="netease"||m_music->uid.isEmpty()||m_music->likedIDs.has_value();
    const bool knownChanged=known!=m_likesKnown;m_likesKnown=known;
    if(!reset && !knownChanged && songs==m_songs && m_modelQuery==query() && m_modelFilter==filter() && liked==m_likedSnapshot)return;
    const bool heartsChanged=liked!=m_likedSnapshot;m_likedSnapshot=liked;m_likedKeys.clear();for(const auto &v:liked)m_likedKeys.insert(textID(v));m_modelQuery=query();m_modelFilter=filter();
    QVector<int> rows;
    const auto q=query().trimmed();
    for(int i=0;i<songs.size();++i){const auto s=songs.at(i).toObject();
        if(!q.isEmpty() && !(s["title"].toString()+" "+s["artist"].toString()+" "+s["album"].toString()).contains(q,Qt::CaseInsensitive))continue;
        if(filter()=="liked"&&!m_likedKeys.contains(textID(s["id"])))continue;
        if(filter()=="available"&&s["unavailable"].toBool())continue;
        rows.append(i);
    }
    if(!reset && rows==m_rows){if(songs!=m_songs){m_songs=songs;if(rowCount())emit dataChanged(index(0),index(rowCount()-1));}else if((heartsChanged||knownChanged)&&rowCount())emit dataChanged(index(0),index(rowCount()-1),{Heart,HeartKnown});return;}
    if(!reset && rows.size()>m_rows.size() && std::equal(m_rows.begin(),m_rows.end(),rows.begin())) {
        beginInsertRows({},m_rows.size(),rows.size()-1);m_rows=rows;m_songs=songs;endInsertRows();return;
    }
    beginResetModel();m_rows=rows;m_songs=songs;endResetModel();
}
void PlaylistMagazine::refreshCovers(){
    if(!m_folder){m_covers={};return;}
    const std::array<QJsonArray,3> inputs{m_music->lists[2],m_music->lists[3],m_music->lists[4]};
    const bool complete=m_music->uid.isEmpty()||(!m_music->hasMore[2]&&!m_music->hasMore[3]&&!m_music->hasMore[4]);
    if(inputs==m_recordInputs && m_recordKey==session() && complete==m_recordsComplete)return;
    m_recordInputs=inputs;m_recordKey=session();m_recordsComplete=complete;
    QJsonArray sequence;QSet<QString> seen;
    const auto append=[&](QJsonObject i){
        const auto id=i["key"].toString();
        if(id.isEmpty()||seen.contains(id)||i["cover"].toString().isEmpty()||m_unavailableCovers.contains(id)||i["deleted"].toBool()||i["unavailable"].toBool())return;
        if(i["provider"].toString()!=m_music->provider||!QStringList{"playlist","album"}.contains(i["kind"].toString()))return;
        sequence.append(i);seen.insert(id);
    };
    for(const auto &source:inputs)for(const auto &v:source)append(v.toObject());
    if(!m_recordAnchor.isEmpty()&&!seen.contains(m_recordAnchor["key"].toString())){
        const auto anchor=m_recordAnchor;append(anchor);
        if(!sequence.isEmpty()&&sequence.last().toObject()["key"]==anchor["key"]){sequence.removeAt(sequence.size()-1);sequence.prepend(anchor);}
    }
    if(!seen.contains(session())){sequence.prepend(m_folder->item);seen.insert(session());}
    m_recordSequence=sequence;m_recordIndex=MusicData::indexOfId(sequence,m_folder->item["id"].toString());
    // IDs are provider/kind scoped. Locate the exact key, not an album with the same ID.
    for(int i=0;i<sequence.size();++i)if(sequence.at(i).toObject()["key"]==m_folder->item["key"]){m_recordIndex=i;break;}
    QVariantList visible;
    const int n=sequence.size();
    for(int side:{-1,1}){
        int index=m_recordIndex+side;
        if(index<0||index>=n){if(!complete)continue;index=(index+n)%std::max(1,n);}
        if(index<0||index>=n||index==m_recordIndex)continue;
        auto item=sequence.at(index).toObject();bool duplicate=false;
        for(const auto &v:visible)if(v.toMap()["key"].toString()==item["key"].toString())duplicate=true;
        if(duplicate)continue;
        item["side"]=side;visible.append(item.toVariantMap());
    }
    m_covers=visible;
}
QVariantMap PlaylistMagazine::recordNeighbour(int offset) const {
    const int n=m_recordSequence.size();
    if(!n||m_recordIndex<0)return {};
    int index=m_recordIndex+offset;
    if(index<0||index>=n){if(!m_recordsComplete)return {};index=(index%n+n)%n;}
    if(index==m_recordIndex)return {};
    auto item=m_recordSequence.at(index).toObject();item["side"]=offset<0?-1:1;
    return item.toVariantMap();
}
void PlaylistMagazine::prepareRecords(){
    if(!m_folder||m_music->uid.isEmpty()||m_music->personalLoading)return;
    if(m_recordSequence.size()>2&&m_recordIndex+2<m_recordSequence.size())return;
    if(m_music->hasMore[2])m_music->loadMoreSource(2);
    else if(m_music->hasMore[3])m_music->loadMoreSource(3);
    else if(m_music->hasMore[4])m_music->loadMoreSource(4);
}

void PlaylistMagazine::search(QString q){
    if(!m_folder)return;
    if(q!=query()){
        m_folder->magazineQuery=q;m_folder->magazineScroll=0;m_searchRequested=false;
        if(m_pending=="search-all"){m_pending.clear();m_waitCursor=-1;}
        m_status.clear();rebuild(true);emit changed();
    }
    // Filtering is synchronous against the latest text. Async work only fills
    // this folder's metadata, so an older keyword can never replace new results.
    if(!q.isEmpty()&&m_folder->cursor<m_folder->ids.size()&&m_pending.isEmpty())beginAll("search-all");
}

void PlaylistMagazine::setFilter(QString f){if(!m_folder||!QStringList{"all","liked","available"}.contains(f)||f==filter())return;m_folder->magazineFilter=f;m_folder->magazineScroll=0;rebuild(true);emit changed();}
void PlaylistMagazine::savePosition(QString s,double y){if(m_folder&&s==session()&&std::isfinite(y))m_folder->magazineScroll=std::max(0.,y);}
void PlaylistMagazine::setTab(QString t){if(!m_folder||!QStringList{"songs","comments","collectors"}.contains(t)||t==tab()||(t=="collectors"&&m_folder->item["kind"]=="album"))return;m_folder->magazineTab=t;m_folder->magazineScroll=0;++m_socialToken;m_socialLoading=false;m_social={};emit changed();if(t!="songs")loadSocial(true);}
void PlaylistMagazine::more(){if(tab()=="songs")m_music->loadDirectoryPage();else loadSocial(false);}
void PlaylistMagazine::loadSocial(bool reset){
    if(!m_folder||m_socialLoading||m_music->provider!="netease"||m_folder->item["virtual"].toBool())return;
    if(reset){m_socialOffset=0;m_social={};}else if(m_socialOffset>=m_socialTotal)return;
    const auto token=++m_socialToken;const auto account=m_account;const auto folder=m_folder;const auto section=tab();const bool comments=section=="comments";
    m_socialLoading=true;emit changed();QPointer<PlaylistMagazine> self(this);
    m_music->api.request(comments?(m_folder->item["kind"]=="album"?"/comment/album":"/comment/playlist"):"/playlist/subscribers",{{"id",folder->item["id"]},{"limit",20},{"offset",m_socialOffset}},[self,comments](MusicReply r){
        if(!self)return;self->m_socialLoading=false;
        if(!r.ok()){self->report(r.error);return;}
        const auto body=r.value.toObject();
        if(!comments&&body["total"].isDouble()&&body["total"].toDouble()>=0){self->m_collectorCount=body["total"].toInteger();self->m_collectorError.clear();}
        const auto raw=body[comments?"comments":"subscribers"].toArray();
        for(const auto &v:raw){const auto i=v.toObject();const auto user=comments?i["user"].toObject():i;
            self->m_social.append(QVariantMap{{"id",textID(user["userId"])},{"name",user["nickname"].toString()},{"avatar",user["avatarUrl"].toString()},
                {"content",i["content"].toString()},{"time",i["timeStr"].toString()},{"likes",i["likedCount"].toInt()}});}
        self->m_socialOffset+=raw.size();self->m_socialTotal=body["total"].toInt(self->m_socialOffset);
        if(raw.isEmpty())self->m_socialTotal=self->m_socialOffset;emit self->changed();
    },[self,token,account,folder,section]{return self&&self->m_socialToken==token&&self->m_music->accountGeneration()==account&&self->m_folder==folder&&self->tab()==section;});
}
void PlaylistMagazine::openCover(QString k){
    for(const auto &v:m_covers){const auto i=QJsonObject::fromVariantMap(v.toMap());if(i["key"]==k){emit navigate("music:collection-browse:"+encoded(i));return;}}
}
QJsonObject PlaylistMagazine::findSong(QString k,int *source)const{if(!m_folder)return{};for(int i=0;i<m_folder->songs.size();++i){const auto s=m_folder->songs.at(i).toObject();if(key(s)==k){if(source)*source=i;return s;}}return{};}
void PlaylistMagazine::rowAction(QString op,QString k){
    int i=-1;auto song=findSong(k,&i);if(song.isEmpty())return;
    if(op=="select"){if(m_selected.contains(k))m_selected.remove(k);else m_selected.insert(k);if(rowCount())emit dataChanged(index(0),index(rowCount()-1),{Chosen});emit changed();return;}
    if(op=="detail"){emit navigate("music:track:"+QString::number(i));return;}
    if(op=="artist"||op.startsWith("artist:")||op=="album"){
        const bool artist=op.startsWith("artist");const int person=op=="artist"?0:op.section(':',1,1).toInt();
        emit navigate("music:row-"+QString(artist?"artist":"album")+":"+QString::number(i)+(artist?":"+QString::number(person):QString()));return;
    }
    if(op=="like"){m_music->like(song);return;}
    if(op=="play"){if(song["unavailable"].toBool()){report("这首歌曲当前不可播放");return;}m_music->archiveNowPlaying=true;m_music->archiveReturnItem=m_folder->item;m_music->player.play(MusicData::withQueueSource(song,m_folder->item),m_music->directoryQueue());m_music->changed();return;}
}
void PlaylistMagazine::selectAll(bool on){m_selected.clear();if(on)for(int n:m_rows)m_selected.insert(key(m_songs.at(n).toObject()));if(rowCount())emit dataChanged(index(0),index(rowCount()-1),{Chosen});emit changed();}
QJsonArray PlaylistMagazine::selectedSongs()const{QJsonArray out;if(m_folder)for(const auto &v:m_folder->songs){auto s=v.toObject();if(m_selected.contains(key(s)))out.append(MusicData::withQueueSource(s,m_folder->item));}return out;}
void PlaylistMagazine::bulk(QString op){if(op=="play-all"){m_music->playDirectory();return;}if(op=="append-all"||op=="download-all"){beginAll(op);return;}m_menuFolder.reset();const auto s=selectedSongs();if(s.isEmpty()){report("先选择要操作的歌曲");return;}apply(op,s);}
void PlaylistMagazine::beginAll(QString op){if(!m_folder||busy())return;m_pending=op;if(op=="search-all")m_searchRequested=true;m_waitCursor=-1;finishAll();}
void PlaylistMagazine::finishAll(){
    if(m_pending.isEmpty()||!m_folder)return;if(m_music->directoryLoading)return;
    if(m_waitCursor>=0 && m_folder->cursor==m_waitCursor){m_pending.clear();report(query().isEmpty()?"曲目加载失败，可重试":"部分曲目读取失败，当前结果尚不完整；可重试");return;}
    if(m_folder->cursor<m_folder->ids.size()){m_waitCursor=m_folder->cursor;m_music->loadDirectoryPage();return;}
    const auto op=m_pending;m_pending.clear();m_waitCursor=-1;
    if(op=="search-all"){rebuild(true);emit changed();return;}
    apply(op=="append-all"?"append":"download",MusicData::withQueueSource(m_folder->songs,m_folder->item));
}
void PlaylistMagazine::apply(QString op,QJsonArray songs){
    if(op=="append"){const auto valid=eligible(songs);const int added=m_music->player.enqueueMany(valid);report(QString("已追加 %1 首；跳过 %2 首不可用或重复条目").arg(added).arg(songs.size()-added));}
    else if(op=="download")download(eligible(songs));
    else if(op=="collect"){
        if(m_music->provider!="netease"||m_music->uid.isEmpty()){report("请先登录网易云音乐后收藏");return;}
        m_hud->queueCollectionTracks=eligible(songs,false);if(m_hud->queueCollectionTracks.isEmpty())return;
        m_hud->queueCollectionAccount=m_account;m_hud->queueCollectionOpen=true;
        if(m_music->lists[2].isEmpty())m_music->loadMoreSource(2);m_music->host->invalidate();
    } else if(op=="remove"){
        const auto folder=m_menuFolder?m_menuFolder:m_folder;
        if(!folder||!m_music->canEditPlaylist(folder->item)){report("只能移除自己歌单中的歌曲");return;}
        m_remove= songs;m_removeFolder=folder;emit changed();
    }
}
void PlaylistMagazine::removeConfirmed(){if(m_remove.isEmpty()||m_mutating||!m_removeFolder||!m_music->canEditPlaylist(m_removeFolder->item))return;const auto songs=m_remove;m_remove={};m_mutating=true;emit changed();mutateChunks(m_removeFolder->item["id"].toString(),songs,true);}
void PlaylistMagazine::cancelRemoval(){m_remove={};m_removeFolder.reset();emit changed();}
void PlaylistMagazine::mutateChunks(QString pid,QJsonArray songs,bool remove,int offset){
    if(m_music->accountGeneration()!=m_account){m_mutating=false;report("账号已切换，操作取消");return;}
    QStringList ids;QJsonArray chunk;for(int i=offset;i<std::min(offset+100,int(songs.size()));++i){ids.append(songs.at(i).toObject()["id"].toString());chunk.append(songs.at(i));}
    const auto account=m_account;const auto folder=m_removeFolder;QPointer<PlaylistMagazine> self(this);
    m_music->mutate("/playlist/tracks",{{"pid",pid},{"tracks",ids.join(',')},{"op",remove?"del":"add"}},[folder,chunk,remove](QJsonObject){
        if(!folder||!remove)return;QSet<QString> ids;for(const auto &v:chunk)ids.insert(v.toObject()["id"].toString());
        QJsonArray keptSongs,keptIDs;int before=0;for(int i=0;i<folder->ids.size();++i){const auto id=folder->ids.at(i);if(!ids.contains(id.toString()))keptIDs.append(id);else if(i<folder->cursor)++before;}
        for(const auto &v:folder->songs)if(!ids.contains(v.toObject()["id"].toString()))keptSongs.append(v);
        folder->item["trackCount"]=std::max(0,folder->item["trackCount"].toInt()-int(folder->ids.size()-keptIDs.size()));
        folder->ids=keptIDs;folder->songs=keptSongs;folder->cursor=std::max(0,folder->cursor-before);
    },[self,pid,songs,remove,offset,account](bool ok){if(!self)return;if(account!=self->m_music->accountGeneration()){self->m_mutating=false;return;}
        if(!ok){self->m_mutating=false;self->report(QString("批量操作未完成：已处理 %1 首。%2").arg(offset).arg(self->m_music->status));return;}
        if(offset+100<songs.size()){QTimer::singleShot(100,self,[self,pid,songs,remove,offset]{if(self)self->mutateChunks(pid,songs,remove,offset+100);});return;}
        self->m_mutating=false;self->m_selected.clear();self->m_removeFolder.reset();self->sync();self->report("已完成批量操作");});
}
void PlaylistMagazine::setSubscribed(QString sessionKey,bool enabled){
    if(!m_folder||session()!=sessionKey||m_music->writeLoading)return;
    if(!info().value("canSubscribe").toBool()){report("请登录后收藏其他用户的歌单或专辑");return;}
    if(info().value("subscribed").toBool()==enabled)return;
    const auto folder=m_folder;const auto item=folder->item;
    const auto lane=item["kind"]=="album"?4:3;
    QPointer<PlaylistMagazine> self(this);
    m_music->mutate(item["kind"]=="album"?"/album/sub":"/playlist/subscribe",
        {{"id",item["id"]},{"t",enabled?1:2}},
        [self,folder,item,lane,sessionKey,enabled](QJsonObject){
            if(!self)return;
            folder->item["subscribed"]=enabled;
            if(enabled){
                self->m_music->subscriptions.insert(sessionKey);
                self->m_music->lists[lane]=MusicData::unique(self->m_music->lists[lane],{folder->item});
            }else{
                self->m_music->subscriptions.remove(sessionKey);
                QJsonArray kept;for(const auto &v:self->m_music->lists[lane])if(v.toObject()["key"].toString()!=sessionKey)kept.append(v);
                self->m_music->lists[lane]=kept;
            }
            self->m_music->totals[lane]=self->m_music->lists[lane].size();
        },[self,enabled](bool ok){if(self)self->report(ok?(enabled?"已收藏":"已取消收藏"):"收藏操作失败，请重试");});
}
void PlaylistMagazine::share(){if(!m_folder)return;if(m_folder->item["virtual"].toBool()){report("这个临时列表没有公开歌单链接");return;}const auto url=m_music->sourceURL(m_folder->item);if(url.isEmpty()){report("此歌单暂不支持分享");return;}m_music->host->copy(m_folder->item["title"].toString()+"\n"+url);report("已复制歌单分享链接");}
void PlaylistMagazine::showSongMenu(QString scope,int i,QString identity,double x,double y){
    QJsonArray songs;std::shared_ptr<MusicDirectory> folder;
    if(scope=="playing")songs=QJsonArray{m_music->player.current};
    else if(scope=="queue")songs=m_music->player.queue;
    else if(scope=="discover")songs=m_music->discover->items;
    else if(scope=="profile")songs=m_hud->profileRows;
    else if(scope=="recommendations")songs=m_hud->recommendationSongs;
    else if(scope=="library"){songs=m_music->libraryItems();folder=m_music->directory;}
    else if(scope.startsWith("lane")){const int lane=scope.mid(4).toInt();if(lane>=0&&lane<5)songs=m_music->lists[lane];}
    else {folder=m_music->directory;songs=folder?folder->songs:m_music->tracks;}
    if(i<0||i>=songs.size()){closeMenu();return;}auto song=songs.at(i).toObject();
    if(song["kind"]!="song"||(!identity.isEmpty()&&key(song)!=identity)){closeMenu();return;}
    if(folder)song=MusicData::withQueueSource(song,folder->item);
    else if(scope.startsWith("lane")||scope=="library")song=MusicData::withQueueSource(song,m_music->sourceOrigin(scope=="library"?m_music->selectedLane:scope.mid(4).toInt()));
    m_menuSong=song;m_menuIndex=i;m_menuFolder=folder;m_menuScope=scope;m_menuX=x;m_menuY=y;m_menuComments=-1;const auto token=++m_menuToken;const auto account=m_account;emit menuChanged();
    if(scope=="playing"||m_music->provider!="netease")return;QPointer<PlaylistMagazine> self(this);
    m_music->api.request("/comment/music",{{"id",song["id"]},{"limit",1}},[self](MusicReply r){if(self&&r.ok()){self->m_menuComments=r.value.toObject()["total"].toInt(-1);emit self->menuChanged();}},[self,token,account]{return self&&self->m_menuToken==token&&self->m_music->accountGeneration()==account;});
}
void PlaylistMagazine::showHitMenu(QString hit,double x,double y){
    const auto p=hit.split(':');const auto name=p.value(1);int i=p.value(2).toInt();
    if(name=="index")showSongMenu("library",i,{},x,y);
    else if(name=="queue")showSongMenu("queue",i,{},x,y);
    else if(name=="slot"){
        const auto values=m_music->libraryItems();if(values.isEmpty())return;
        if(m_music->directory){const auto f=m_music->directory;i=f->page+((m_music->selectedLane*8+i-f->anchor)%40+40)%40;}
        else i=(m_music->offsets[m_music->selectedLane]+i)%values.size();
        showSongMenu("library",i,{},x,y);
    }
    else if(name=="track"||name=="row-artist"||name=="row-album")showSongMenu("directory",i,{},x,y);
    else if(name=="result")showSongMenu("lane"+p.value(2),p.value(3).toInt(),{},x,y);
}
QVariantMap PlaylistMagazine::songMenu()const{return {{"visible",!m_menuSong.isEmpty()},{"x",m_menuX},{"y",m_menuY},{"title",m_menuSong["title"].toString()},
    {"isQueue",m_menuScope=="queue"},{"canRemove",m_menuScope=="queue"?(!m_music->player.roamActive&&m_menuIndex!=m_music->player.index):bool(m_menuFolder)&&m_music->canEditPlaylist(m_menuFolder->item)},{"canCollect",m_music->provider=="netease"&&!m_music->uid.isEmpty()},
    {"canDownload",m_music->provider=="netease"&&!m_music->uid.isEmpty()},{"playable",!m_menuSong["unavailable"].toBool()},{"canComments",m_music->provider=="netease"},{"comments",m_menuComments}};}
void PlaylistMagazine::closeMenu(){m_menuSong={};++m_menuToken;emit menuChanged();}
void PlaylistMagazine::songAction(QString op){
    const auto song=m_menuSong;if(song.isEmpty())return;
    if(op=="play"){if(song["unavailable"].toBool())report("这首歌曲当前不可播放");else if(m_menuScope=="queue") {const int i=m_menuIndex;if(i>=0&&i<m_music->player.queue.size()&&key(m_music->player.queue.at(i).toObject())==key(song))m_music->player.play(song,std::nullopt,i);else report("队列已变化，请重新打开菜单");} else m_music->player.play(song);}
    else if(op=="next")m_music->player.enqueue(song,true);
    else if(op=="comments"){emit navigate("music:context-comments:"+encoded(song));}
    else if(op=="remove"&&m_menuScope=="queue"){const int i=m_menuIndex;if(i>=0&&i<m_music->player.queue.size()&&key(m_music->player.queue.at(i).toObject())==key(song))m_music->player.remove(i);}
    else if(op=="collect"||op=="download"||op=="remove")apply(op,QJsonArray{song});
    else if(op=="share"||op=="copy"){const auto url=m_music->sourceURL(song);if(!url.isEmpty()){m_music->host->copy((op=="share"?song["title"].toString()+" — "+song["artist"].toString()+"\n":QString())+url);report("已复制歌曲链接");}}
    closeMenu();
}
void PlaylistMagazine::download(QJsonArray songs){
    if(m_music->provider!="netease"||m_music->uid.isEmpty()){report("请登录后下载，实际可下载范围由歌曲权限决定");return;}
    if(m_downloading){report("已有下载任务，请等待完成");return;}
    ++m_downloadSerial;m_downloading=true;m_downloads=songs;m_downloadAccount=m_account;m_saved=m_failed=m_existing=0;nextDownload();
}
void PlaylistMagazine::nextDownload(){
    if(m_music->accountGeneration()!=m_downloadAccount){m_downloading=false;m_downloads={};report("账号已切换，下载已取消");return;}
    if(m_downloads.isEmpty()){m_downloading=false;report(QString("下载完成：%1 首，已存在 %2 首，未下载 %3 首。下载目录 / RhineMusic").arg(m_saved).arg(m_existing).arg(m_failed));return;}
    const auto song=m_downloads.first().toObject();m_downloads.removeFirst();QPointer<PlaylistMagazine> self(this);const auto account=m_downloadAccount;const auto serial=m_downloadSerial;
    report(QString("正在下载：%1 · 剩余 %2 首").arg(song["title"].toString()).arg(m_downloads.size()));
    m_music->api.request("/song/download/url/v1",{{"id",song["id"]},{"level","standard"}},[self,song,account,serial](MusicReply r){
        if(!self||self->m_downloadSerial!=serial)return;const auto data=r.value.toObject()["data"].toObject();const QUrl url(data["url"].toString());
        if(!r.ok()||!QStringList{"http","https"}.contains(url.scheme())||url.host().isEmpty()||data["freeTrialInfo"].isObject()){
            ++self->m_failed;self->scheduleDownload();return;}
        QString name=song["title"].toString().left(70);name.replace(QRegularExpression("[<>:\"/\\\\|?*\\x00-\\x1f]"),"_");
        QString ext=data["type"].toString("mp3").toLower();if(!QStringList{"mp3","flac","m4a","wav"}.contains(ext))ext="mp3";
        const auto dir=QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)+"/RhineMusic";
        if(!QDir().mkpath(dir)){++self->m_failed;self->scheduleDownload();return;}
        const auto filename=dir+"/"+name+"-"+song["id"].toString()+"."+ext;
        if(QFileInfo::exists(filename)){++self->m_existing;self->scheduleDownload();return;}
        self->m_file=std::make_unique<QSaveFile>(filename);
        if(!self->m_file->open(QIODevice::WriteOnly)){++self->m_failed;self->scheduleDownload();return;}
        QNetworkRequest request(url);request.setTransferTimeout(60000);request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,QNetworkRequest::NoLessSafeRedirectPolicy);
        auto *reply=self->m_network.get(request);reply->setReadBufferSize(256*1024);self->m_reply=reply;
        connect(reply,&QNetworkReply::readyRead,self,[self,reply,serial]{if(!self||serial!=self->m_downloadSerial||self->m_reply!=reply||!self->m_file)return;const auto bytes=reply->readAll();if(self->m_file->write(bytes)!=bytes.size()||self->m_file->size()>512ll*1024*1024)reply->abort();});
        connect(reply,&QNetworkReply::finished,self,[self,reply,account,serial]{
            if(!self)return;if(self->m_downloadSerial!=serial){reply->deleteLater();return;}const auto type=reply->header(QNetworkRequest::ContentTypeHeader).toString().toLower();
            bool ok=reply->error()==QNetworkReply::NoError&&account==self->m_music->accountGeneration()&&self->m_file &&
                !type.startsWith("text/")&&!type.contains("json")&&reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()==200;
            if(ok){const auto bytes=reply->readAll();ok=self->m_file->write(bytes)==bytes.size()&&self->m_file->size()>0&&self->m_file->commit();}
            if(ok)++self->m_saved;else {++self->m_failed;if(self->m_file)self->m_file->cancelWriting();}
            self->m_file.reset();self->m_reply=nullptr;reply->deleteLater();self->scheduleDownload();
        });
    },[self,account,serial]{return self&&self->m_downloadSerial==serial&&self->m_music->accountGeneration()==account;});
}

void PlaylistMagazine::scheduleDownload(){const auto serial=m_downloadSerial;QTimer::singleShot(80,this,[this,serial]{if(serial==m_downloadSerial)nextDownload();});}

void PlaylistMagazine::cancelDownload(){++m_downloadSerial;m_downloads={};if(m_reply)m_reply->abort();m_reply=nullptr;if(m_file)m_file->cancelWriting();m_file.reset();m_downloading=false;report("已取消下载，未完成文件已清理");}
