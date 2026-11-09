#include "NowPlaying.h"
#include "PipelineDiagnostics.h"
#include "MusicData.h"
#include <QBuffer>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QFutureWatcher>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <array>

namespace {
// Cloudy artwork.go: sample each cell, then select its dominant vivid hue.
QColor dominantColor(const QImage &image){
    std::array<double,18> weight{};
    std::array<std::array<double,3>,18> sum{};
    std::array<double,3> gray{};
    for(int y=0;y<24;++y)for(int x=0;x<24;++x){
        const int x0=x*image.width()/24,x1=(x+1)*image.width()/24;
        const int y0=y*image.height()/24,y1=(y+1)*image.height()/24;
        int r=0,g=0,b=0,count=0;
        for(int yy=y0;yy<std::max(y1,y0+1);yy+=std::max(1,(y1-y0)/4))
            for(int xx=x0;xx<std::max(x1,x0+1);xx+=std::max(1,(x1-x0)/4)){
                const auto pixel=image.pixelColor(std::min(xx,image.width()-1),std::min(yy,image.height()-1));
                r+=pixel.red();g+=pixel.green();b+=pixel.blue();++count;
            }
        const QColor pixel(r/count,g/count,b/count);
        const double red=pixel.redF(),green=pixel.greenF(),blue=pixel.blueF();
        gray[0]+=red;gray[1]+=green;gray[2]+=blue;
        const double saturation=pixel.hsvSaturationF(),value=pixel.valueF();
        if(saturation<.15||value<.15)continue;
        const int bucket=std::clamp(int(pixel.hsvHueF()*18),0,17);
        const double w=saturation*saturation*value;
        weight[bucket]+=w;sum[bucket][0]+=red*w;sum[bucket][1]+=green*w;sum[bucket][2]+=blue*w;
    }
    const auto best=std::distance(weight.begin(),std::max_element(weight.begin(),weight.end()));
    const auto channel=[](double value){return std::clamp(int(value*255),0,255);};
    if(weight[best]<2)return QColor(channel(gray[0]/576),channel(gray[1]/576),channel(gray[2]/576));
    return QColor(channel(sum[best][0]/weight[best]),channel(sum[best][1]/weight[best]),channel(sum[best][2]/weight[best]));
}
QString identity(QJsonObject song){return song.isEmpty()?QString():MusicPlayer::identity(song);}
QString id(QJsonValue value){return value.isString()?value.toString():QString::number(value.toInteger());}
QString circularPNG(const QImage &source,int side){
    if(source.isNull())return {};
    QImage image(side,side,QImage::Format_ARGB32_Premultiplied);image.fill(Qt::transparent);
    QPainter painter(&image);painter.setRenderHint(QPainter::Antialiasing);painter.setRenderHint(QPainter::SmoothPixmapTransform);
    QPainterPath circle;circle.addEllipse(QRectF(1,1,side-2,side-2));painter.setClipPath(circle);
    const auto scaled=source.scaled(side,side,Qt::KeepAspectRatioByExpanding,Qt::SmoothTransformation);
    painter.drawImage(QPointF((side-scaled.width())/2.,(side-scaled.height())/2.),scaled);painter.end();
    QByteArray bytes;QBuffer buffer(&bytes);buffer.open(QIODevice::WriteOnly);if(!image.save(&buffer,"PNG"))return {};
    return "data:image/png;base64,"+QString::fromLatin1(bytes.toBase64());
}
QJsonArray wikiTags(const QString &wiki){
    QJsonArray tags;
    for(const auto &line:wiki.split('\n',Qt::SkipEmptyParts)){
        auto colon=line.indexOf(QChar(0xff1a));if(colon<0)colon=line.indexOf(':');
        const auto label=line.left(colon).trimmed().toLower();
        if(colon<0||!QStringList{QStringLiteral("曲风"),QStringLiteral("风格"),"genre","genres","style"}.contains(label))continue;
        for(auto value:line.mid(colon+1).split('/',Qt::SkipEmptyParts)){
            value=value.trimmed();if(!value.isEmpty()&&!tags.contains(value))tags.append(value);
        }
    }
    return tags;
}
QJsonArray songGenres(const QJsonObject &body){
    QJsonArray tags;
    for(const auto &block:body["data"].toObject()["blocks"].toArray())
        for(const auto &entry:block.toObject()["creatives"].toArray()){
            const auto creative=entry.toObject();
            if(creative["creativeType"]!="songTag")continue;
            for(const auto &resource:creative["resources"].toArray()){
                const auto value=resource.toObject()["uiElement"].toObject()["mainTitle"].toObject()["title"].toString().trimmed();
                if(!value.isEmpty()&&!tags.contains(value))tags.append(value);
            }
        }
    return tags;
}
}
NowPlaying::NowPlaying(MusicLibrary *music,PlaylistMagazine *magazine,QObject *parent):QObject(parent),m_music(music),m_magazine(magazine){
    connect(&music->player,&MusicPlayer::changed,this,&NowPlaying::sync);
    connect(music,&MusicLibrary::invalidated,this,&NowPlaying::sync);
    connect(&music->player.lyrics,&LyricsController::changed,this,&NowPlaying::syncLyrics);
    connect(&music->player,&MusicPlayer::seekRequested,this,&NowPlaying::followRequested);
    connect(magazine,&PlaylistMagazine::changed,this,&NowPlaying::changed);
    sync();
}
void NowPlaying::loadTags(){
    if(m_track["provider"]!="netease"||m_music->provider!="netease"||m_key.isEmpty()||!m_tags.isEmpty()||m_tagsLoading)return;
    if(m_tagsCache.contains(m_key)){m_tags=m_tagsCache.value(m_key);emit changed();return;}
    m_tagsLoading=true;m_tagsFailed=false;++m_tagsAttempts;emit changed();
    QPointer<NowPlaying> self(this);const auto generation=m_generation;const auto account=m_account;const auto key=m_key;
    m_music->api.request("/song/wiki/summary",{{"id",m_track["id"].toString()}},[self,generation,account,key](MusicReply reply){
        if(!self||self->m_generation!=generation||self->m_music->accountGeneration()!=account||self->m_key!=key)return;
        if(reply.ok()&&!reply.value.toObject()["data"].toObject()["blocks"].isArray())reply.error=QStringLiteral("曲风数据格式无效");
        if(!reply.ok()&&self->m_tagsAttempts<2&&!reply.failure["authExpired"].toBool()&&!QSet<int>{400,401,403,404,405,429,509}.contains(reply.failure["code"].toInt())){
            self->m_music->host->schedule(1500,[self,generation,account,key]{
                if(!self||self->m_generation!=generation||self->m_music->accountGeneration()!=account||self->m_key!=key||!self->m_tagsLoading)return;
                self->m_tagsLoading=false;self->loadTags();
            });
            return;
        }
        self->m_tagsLoading=false;self->m_tagsFailed=!reply.ok();
        if(!reply.ok()){emit self->changed();return;}
        const auto tags=songGenres(reply.value.toObject());
        self->m_tags=tags;if(self->m_tagsCache.size()>=128)self->m_tagsCache.erase(self->m_tagsCache.begin());self->m_tagsCache.insert(key,tags);emit self->changed();
    },[self,generation,account,key]{return self&&self->m_generation==generation&&self->m_music->accountGeneration()==account&&self->m_key==key;});
}
void NowPlaying::sync(){
    if(m_queue!=m_music->player.queue){m_queue=m_music->player.queue;++m_queueRevision;emit queueChanged();}
    const auto song=m_music->player.current;const auto key=identity(song);const auto account=m_music->accountGeneration();
    if(key!=m_key||account!=m_account){
        if(account!=m_account){m_hotComments.clear();m_tagsCache.clear();}
        m_hotComment.clear();m_hotCommentRequested=false;emit hotCommentChanged();
        ++m_generation;m_key=key;m_account=account;m_track=song;m_status.clear();m_album={};m_tags=m_tagsCache.value(key);m_tagsLoading=false;m_tagsFailed=false;m_cover.clear();m_avatar.clear();m_artistID.clear();m_document={};m_imageFlights.clear();m_pixelKeys.clear();
        m_tagsAttempts=0;
        m_coverTint=QColor("#787882");
        if(!m_tagsCache.contains(key)){m_tags=wikiTags(song["wiki"].toString());if(m_tags.isEmpty())m_tags=song["tags"].toArray();}
        if(m_images.size()>16){m_images.clear();m_imageTints.clear();}
        emit changed();emit linesChanged();
        if(!key.isEmpty()){
            pixels(song["cover"].toString(),"cover");
            QPointer<NowPlaying> tagOwner(this);const auto tagGeneration=m_generation;const auto accountGeneration=account;const auto tagKey=key;
            m_music->host->schedule(0,[tagOwner,tagGeneration,accountGeneration,tagKey]{
                if(tagOwner&&tagOwner->m_generation==tagGeneration&&tagOwner->m_music->accountGeneration()==accountGeneration&&tagOwner->m_key==tagKey)tagOwner->loadTags();
            });
            const auto people=song["artists"].toArray();if(!people.isEmpty())m_artistID=id(people.first().toObject()["id"]);
            artist();
            const auto albumID=song["albumID"].toString();const auto albumKey=song["provider"].toString()+":"+albumID;
            if(m_albums.contains(albumKey))m_album=m_albums[albumKey];
            else if(!albumID.isEmpty()&&song["provider"].toString()==m_music->provider){
                QPointer<NowPlaying> self(this);const auto generation=m_generation;
                m_music->api.call("detail",{MusicData::item("album",albumID,song["album"].toString(),{},m_music->provider)},[self,albumKey](MusicReply reply){
                    if(!self||!reply.ok())return;const auto values=reply.value.toArray();if(values.isEmpty())return;
                    self->m_album=values.first().toObject();if(self->m_albums.size()>64)self->m_albums.clear();self->m_albums[albumKey]=self->m_album;emit self->changed();
                },[self,generation,account]{return self&&self->m_generation==generation&&self->m_music->accountGeneration()==account;});
            }
            if(song["provider"].toString()==m_music->provider&&!m_music->likedIDs&&!m_music->uid.isEmpty())m_music->ensureLikedIDs();
        }
    }else if(song!=m_track){
        const auto oldCover=m_track["cover"].toString();m_track=song;
        if(m_tags.isEmpty()&&!m_tagsCache.contains(key)){
            m_tags=wikiTags(song["wiki"].toString());if(m_tags.isEmpty())m_tags=song["tags"].toArray();
            if(!m_tags.isEmpty()){m_tagsLoading=false;m_tagsFailed=false;}
        }
        if(m_cover.isEmpty()||oldCover!=song["cover"].toString())pixels(song["cover"].toString(),"cover");
        if(m_artistID.isEmpty()){const auto people=song["artists"].toArray();if(!people.isEmpty()){m_artistID=id(people.first().toObject()["id"]);artist();}}
        emit changed();
    }else if(m_cover.isEmpty()&&!m_music->player.coverImage.isEmpty()){
        preparePixels(m_music->host->image(m_music->player.coverImage),"cover:"+m_track["cover"].toString(),"cover",m_generation,m_account,512,false);
    }
    bool liked=false;const bool known=bool(m_music->likedIDs)&&song["provider"].toString()==m_music->provider;
    if(known)for(const auto &value:*m_music->likedIDs)if(id(value)==song["id"].toString()){liked=true;break;}
    if(m_known!=known||m_liked!=liked||m_write!=m_music->writeLoading){m_known=known;m_liked=liked;m_write=m_music->writeLoading;emit changed();}
    syncLyrics();
}
void NowPlaying::syncLyrics(){
    const auto &lyrics=m_music->player.lyrics;
    const auto document=lyrics.currentKey==LyricsController::trackKey(m_music->player.current)?lyrics.document():QJsonObject{};
    if(document!=m_document){m_document=document;emit linesChanged();}
    emit playbackChanged();
}
QVariantMap NowPlaying::info()const{
    auto info=m_track.toVariantMap();info["session"]=m_key;info["coverPixels"]=m_cover;info["artistAvatar"]=m_avatar;
    info["date"]=m_album["date"].toString(m_track["date"].toString());
    info["coverTint"]=m_coverTint.name();
    info["tags"]=m_tags.toVariantList();
    info["liked"]=m_liked;info["likeKnown"]=m_known;info["likeBusy"]=m_write;
    info["tagsLoading"]=m_tagsLoading;info["tagsFailed"]=m_tagsFailed;
    info["canLike"]=m_track["provider"].toString()==m_music->provider&&m_music->provider=="netease"&&!m_music->uid.isEmpty();return info;
}
QVariantMap NowPlaying::playback()const{
    const auto &player=m_music->player;const auto &lyrics=player.lyrics;
    return {{"playing",!player.loading&&!player.failed&&player.state["playing"].toBool()},{"visualBass",player.state["visualBass"].toDouble()},{"visualBands",player.state["visualBands"]},{"loading",player.loading},{"seekable",player.state["seekable"].toBool()},
        {"index",m_document.isEmpty()?-1:lyrics.index},{"timed",!m_document.isEmpty()&&m_document["timing"]!="none"},
        {"lyricStatus",lyrics.currentKey==LyricsController::trackKey(player.current)?lyrics.status:QString("loading")},
        {"positionMs",lyrics.positionMs+m_document["offsetMs"].toDouble()+lyrics.offsetMs},{"offsetMs",lyrics.offsetMs}};
}
QVariantList NowPlaying::lines()const{return m_document["lines"].toArray().toVariantList();}
QVariantList NowPlaying::queue()const {
    PipelineDiagnostics::Scope trace("queue.toVariant");
    QVariantList rows;for(int i=0;i<m_queue.size();++i){auto row=m_queue.at(i).toObject().toVariantMap();row["index"]=i;row["key"]=MusicPlayer::identity(m_queue.at(i).toObject());rows.append(row);}return rows;
}
// Cloudy virtual rows ask for metadata only when that row is drawn. Keep the
// complete queue in C++; do not box thousands of unseen rows into QML objects.
QVariantMap NowPlaying::queueRow(int index)const {
    PipelineDiagnostics::Scope trace("queue.visible-row");
    if(index<0||index>=m_queue.size())return {};
    const auto song=m_queue.at(index).toObject();auto row=song.toVariantMap();
    row["index"]=index;row["key"]=MusicPlayer::identity(song);return row;
}
int NowPlaying::queueIndex(QString identity)const {
    for(int i=0;i<m_queue.size();++i)if(MusicPlayer::identity(m_queue.at(i).toObject())==identity)return i;
    return -1;
}
bool NowPlaying::queueHasDeferred()const {
    for(const auto &value:m_queue)if(value.toObject()["deferred"].toBool())return true;
    return false;
}
void NowPlaying::hydrateQueue(QVariantList indices) {
    QList<int> visible;
    for (const auto &value : indices) {
        bool ok = false;
        const auto index = value.toInt(&ok);
        if (ok && visible.size() < 96) visible.append(index);
    }
    m_music->player.hydrateQueue(visible);
}
void NowPlaying::loadHotComment(){
    if(m_hotCommentRequested||m_key.isEmpty()||m_track["provider"]!="netease"||m_music->provider!="netease")return;
    m_hotCommentRequested=true;
    if(m_hotComments.contains(m_key)){m_hotComment=m_hotComments.value(m_key);emit hotCommentChanged();return;}
    QPointer<NowPlaying> self(this);const auto generation=m_generation;const auto account=m_account;const auto key=m_key;
    m_music->api.request("/comment/hot",{{"id",m_track["id"].toString()},{"type",0},{"limit",1},{"offset",0}},
        [self,key](MusicReply reply){
            if(!self||!reply.ok())return;
            const auto rows=reply.value.toObject()["hotComments"].toArray();
            self->m_hotComment=rows.isEmpty()?QString():rows.first().toObject()["content"].toString().simplified().left(1000);
            if(self->m_hotComments.size()>=64)self->m_hotComments.clear();
            self->m_hotComments.insert(key,self->m_hotComment);emit self->hotCommentChanged();
        },[self,generation,account,key]{return self&&self->m_generation==generation&&self->m_music->accountGeneration()==account&&self->m_key==key;});
}
void NowPlaying::seekLine(int index,QString session){
    if(session!=m_key||session!=identity(m_music->player.current)||!playback()["seekable"].toBool()||!playback()["timed"].toBool())return;
    const auto rows=m_document["lines"].toArray();if(index<0||index>=rows.size())return;
    const auto position=rows[index].toObject()["startMs"].toDouble()-m_document["offsetMs"].toDouble()-m_music->player.lyrics.offsetMs;
    emit followRequested();m_music->host->mediaControl("seek",std::max(0.,position));
}
void NowPlaying::openArtist(QString artistID){
    const auto people=m_track["artists"].toArray();for(int i=0;i<people.size();++i)if(id(people[i].toObject()["id"])==artistID){emit navigate("player:song-artist:"+QString::number(i));return;}
}
void NowPlaying::operate(QString operation){
    if(m_key.isEmpty()||m_key!=identity(m_music->player.current))return;
    if(operation=="retry-tags"){if(m_tagsFailed&&!m_tagsLoading){m_tagsAttempts=0;loadTags();}return;}
    if(operation=="browse"){
        m_music->archiveNowPlaying=false;m_music->archivePlayingDirectory.reset();
        const auto origin=m_music->archiveReturnItem;
        if(!m_music->directory&&(origin["kind"]=="playlist"||origin["kind"]=="album")){
            auto item=origin;if(item["key"].toString().isEmpty())item=MusicData::item(origin["kind"].toString(),origin["id"].toString(),origin["title"].toString(),{},origin["provider"].toString());
            if(m_music->current["key"]!=item["key"])m_music->choose(item,false,false);
        }else if(!m_music->directory){m_music->changed();emit navigate("back");return;}
        m_music->changed();return;
    }
    if(operation=="album"){if(!m_track["albumID"].toString().isEmpty()&&m_track["albumID"]!="0")emit navigate("player:song-album");return;}
    if(operation=="details"){emit navigate("player:song-detail");return;}
    if(operation=="retry-lyrics"){emit navigate("player:lyrics-retry");return;}
    if(operation=="comments"){m_music->archiveNowPlaying=true;emit navigate("player:comments");return;}
    if(operation=="like"){if(m_known&&!m_write&&info()["canLike"].toBool())emit navigate("music:like-current");return;}
    if(operation=="share"||operation=="collect"||operation=="official"){
        if(operation=="official"){emit navigate("player:official");return;}
        if(operation=="share"&&m_music->sourceURL(m_track).isEmpty()){m_status="此歌曲暂不支持分享";emit changed();return;}
        m_magazine->showSongMenu("playing",0,m_key,0,0);
        const bool canCollect=m_magazine->songMenu()["canCollect"].toBool();
        m_magazine->songAction(operation);m_status=operation=="collect"&&canCollect?QString():m_magazine->status();emit changed();
    }
}
void NowPlaying::pixels(QString url,QString role,bool fallback){
    if(url.isEmpty())return;const auto cacheKey=role+":"+url;
    m_pixelKeys[role]=cacheKey;
    if(m_images.contains(cacheKey)){if(role=="cover"){m_cover=m_images[cacheKey];m_coverTint=m_imageTints.value(cacheKey,QColor("#787882"));}else m_avatar=m_images[cacheKey];emit changed();return;}
    QPointer<NowPlaying> self(this);const auto generation=m_generation;const auto account=m_account;const int side=role=="cover"?512:96;
    m_music->host->loadCover(url,[self,generation,account,cacheKey,role,fallback,side](QString image){
        if(!self||self->m_generation!=generation||self->m_music->accountGeneration()!=account||self->m_pixelKeys.value(role)!=cacheKey)return;
        self->preparePixels(self->m_music->host->image(image),cacheKey,role,generation,account,side,fallback);
    },side);
}
void NowPlaying::preparePixels(QImage image,QString cacheKey,QString role,quint64 generation,quint64 account,int side,bool fallback){
    if(m_generation!=generation||m_music->accountGeneration()!=account)return;
    if(!m_pixelKeys.contains(role))m_pixelKeys[role]=cacheKey;
    if(m_pixelKeys.value(role)!=cacheKey)return;
    if(role=="cover"&&!image.isNull()){
        m_coverTint=dominantColor(image);
        m_imageTints.insert(cacheKey,m_coverTint);
    }
    if(image.isNull()){if(role=="avatar"&&!fallback)artist(true);return;}
    if(m_imageFlights.contains(cacheKey))return;
    m_imageFlights.insert(cacheKey);
    auto *watcher=new QFutureWatcher<QString>(this);
    connect(watcher,&QFutureWatcher<QString>::finished,this,[this,watcher,cacheKey,role,generation,account,fallback]{
        const auto png=watcher->result();watcher->deleteLater();
        if(m_generation!=generation||m_music->accountGeneration()!=account)return;
        m_imageFlights.remove(cacheKey);
        if(m_pixelKeys.value(role)!=cacheKey)return;
        if(png.isEmpty()){if(role=="avatar"&&!fallback)artist(true);return;}
        m_images[cacheKey]=png;
        if(role=="cover")m_cover=png;
        else {m_avatar=png;if(m_artists.size()>32)m_artists.clear();m_artists[m_music->provider+":"+m_artistID]=png;}
        emit changed();
    });
    watcher->setFuture(QtConcurrent::run([image=std::move(image),side]{return circularPNG(image,side);}));
}
void NowPlaying::artist(bool fallback){
    const auto cacheKey=m_music->provider+":"+m_artistID;
    if(!fallback&&m_artists.contains(cacheKey)){m_avatar=m_artists[cacheKey];emit changed();return;}
    if(m_artistID.isEmpty()||m_artistID=="0"||m_music->provider!="netease"||m_track["provider"].toString()!=m_music->provider)return;
    QPointer<NowPlaying> self(this);const auto generation=m_generation;const auto account=m_account;
    m_music->api.request(fallback?"/artists":"/artist/detail",{{"id",m_artistID}},[self,fallback](MusicReply reply){
        if(!self)return;const auto body=reply.value.toObject();const auto person=fallback?body["artist"].toObject():body["data"].toObject()["artist"].toObject();QString url;
        for(const auto &field:{"avatar","img1v1Url","picUrl","cover"})if(!person[field].toString().isEmpty()){url=person[field].toString();break;}
        if(!reply.ok()||url.isEmpty()){if(!fallback)self->artist(true);return;}self->pixels(url,"avatar",fallback);
    },[self,generation,account]{return self&&self->m_generation==generation&&self->m_music->accountGeneration()==account;});
}
