#include "NowPlaying.h"
#include "MusicData.h"
#include <QBuffer>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <algorithm>

namespace {
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
}
NowPlaying::NowPlaying(MusicLibrary *music,PlaylistMagazine *magazine,QObject *parent):QObject(parent),m_music(music),m_magazine(magazine){
    connect(&music->player,&MusicPlayer::changed,this,&NowPlaying::sync);
    connect(music,&MusicLibrary::invalidated,this,&NowPlaying::sync);
    connect(&music->player.lyrics,&LyricsController::changed,this,&NowPlaying::syncLyrics);
    connect(magazine,&PlaylistMagazine::changed,this,&NowPlaying::changed);
    sync();
}
void NowPlaying::sync(){
    const auto song=m_music->player.current;const auto key=identity(song);const auto account=m_music->accountGeneration();
    if(key!=m_key||account!=m_account){
        ++m_generation;m_key=key;m_account=account;m_track=song;m_status.clear();m_album={};m_cover.clear();m_avatar.clear();m_artistID.clear();m_document={};
        if(m_images.size()>16)m_images.clear();
        emit changed();emit linesChanged();
        if(!key.isEmpty()){
            pixels(song["cover"].toString(),"cover");
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
        if(m_cover.isEmpty()||oldCover!=song["cover"].toString())pixels(song["cover"].toString(),"cover");
        if(m_artistID.isEmpty()){const auto people=song["artists"].toArray();if(!people.isEmpty()){m_artistID=id(people.first().toObject()["id"]);artist();}}
        emit changed();
    }else if(m_cover.isEmpty()&&!m_music->player.coverImage.isEmpty()){
        const auto png=circularPNG(m_music->host->image(m_music->player.coverImage),512);if(!png.isEmpty()){m_cover=png;emit changed();}
    }
    bool liked=false;const bool known=bool(m_music->likedIDs)&&song["provider"].toString()==m_music->provider;
    if(known)for(const auto &value:*m_music->likedIDs)if(id(value)==song["id"].toString()){liked=true;break;}
    if(m_known!=known||m_liked!=liked||m_write!=m_music->writeLoading){m_known=known;m_liked=liked;m_write=m_music->writeLoading;emit changed();}
    syncLyrics();emit playbackChanged();
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
    auto tags=m_track["tags"].toArray();if(tags.isEmpty())tags=m_album["tags"].toArray();info["tags"]=tags.toVariantList();
    info["liked"]=m_liked;info["likeKnown"]=m_known;info["likeBusy"]=m_write;
    info["canLike"]=m_track["provider"].toString()==m_music->provider&&m_music->provider=="netease"&&!m_music->uid.isEmpty();return info;
}
QVariantMap NowPlaying::playback()const{
    const auto &player=m_music->player;const auto &lyrics=player.lyrics;
    return {{"playing",!player.loading&&!player.failed&&player.state["playing"].toBool()},{"seekable",player.state["seekable"].toBool()},
        {"index",m_document.isEmpty()?-1:lyrics.index},{"timed",!m_document.isEmpty()&&m_document["timing"]!="none"},
        {"lyricStatus",lyrics.currentKey==LyricsController::trackKey(player.current)?lyrics.status:QString("loading")}};
}
QVariantList NowPlaying::lines()const{return m_document["lines"].toArray().toVariantList();}
void NowPlaying::seekLine(int index,QString session){
    if(session!=m_key||session!=identity(m_music->player.current)||!playback()["seekable"].toBool()||!playback()["timed"].toBool())return;
    const auto rows=m_document["lines"].toArray();if(index<0||index>=rows.size())return;
    const auto position=rows[index].toObject()["startMs"].toDouble()-m_document["offsetMs"].toDouble()-m_music->player.lyrics.offsetMs;
    m_music->host->mediaControl("seek",std::max(0.,position));
}
void NowPlaying::openArtist(QString artistID){
    const auto people=m_track["artists"].toArray();for(int i=0;i<people.size();++i)if(id(people[i].toObject()["id"])==artistID){emit navigate("player:song-artist:"+QString::number(i));return;}
}
void NowPlaying::operate(QString operation){
    if(m_key.isEmpty()||m_key!=identity(m_music->player.current))return;
    if(operation=="browse"){
        m_music->archiveNowPlaying=false;
        const auto origin=m_music->archiveReturnItem;
        if(!m_music->directory&&(origin["kind"]=="playlist"||origin["kind"]=="album")){
            auto item=origin;if(item["key"].toString().isEmpty())item=MusicData::item(origin["kind"].toString(),origin["id"].toString(),origin["title"].toString(),{},origin["provider"].toString());
            if(m_music->current["key"]!=item["key"])m_music->choose(item,false,false);
        }
        m_music->changed();return;
    }
    if(operation=="details"){emit navigate("player:song-detail");return;}
    if(operation=="retry-lyrics"){emit navigate("player:lyrics-retry");return;}
    if(operation=="comments"){emit navigate("player:comments");return;}
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
    if(m_images.contains(cacheKey)){if(role=="cover")m_cover=m_images[cacheKey];else m_avatar=m_images[cacheKey];emit changed();return;}
    QPointer<NowPlaying> self(this);const auto generation=m_generation;const auto account=m_account;const int side=role=="cover"?512:96;
    m_music->host->loadCover(url,[self,generation,account,cacheKey,role,fallback,side](QString image){
        if(!self||self->m_generation!=generation||self->m_music->accountGeneration()!=account)return;
        const auto png=circularPNG(self->m_music->host->image(image),side);
        if(png.isEmpty()){if(role=="avatar"&&!fallback)self->artist(true);return;}
        self->m_images[cacheKey]=png;if(role=="cover")self->m_cover=png;else {self->m_avatar=png;if(self->m_artists.size()>32)self->m_artists.clear();self->m_artists[self->m_music->provider+":"+self->m_artistID]=png;}emit self->changed();
    },side);
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
