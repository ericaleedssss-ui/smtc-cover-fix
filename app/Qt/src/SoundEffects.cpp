// SPDX-License-Identifier: AGPL-3.0-only
#include "SoundEffects.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QPointer>
namespace {
struct Preset {const char *id,*label,*desc,*color,*icon;std::array<double,10> bands;double bass,width,vocal,loud;};
const std::array<Preset,9> styles{{
    {"flat","原声","不做处理，保留录音原貌","#7b8494","cloudyWave",{},0,0,0,0},
    {"pop","流行","人声靠前，节奏明快","#f472b6","cloudyParty",{-1,0,1.5,3,3.5,2.5,1,0,1,1.5},.15,.1,.2,0},
    {"rock","摇滚","鼓点有力，吉他明亮","#ef4444","cloudyGuitar",{4,3,2,0,-1.5,-1,1,2.5,3.5,4},.2,.15,0,0},
    {"jazz","爵士","温暖松弛，像在小酒馆","#6366f1","cloudyWine",{3,2,1,2,-1,-1,0,1,2,3},0,.2,0,0},
    {"classical","古典","层次开阔，弦乐通透","#d4a373","cloudyPiano",{4,3,2,1,-1,-1,0,2,3,4},0,.3,0,0},
    {"electronic","电子","低频饱满，高频闪亮","#22d3ee","cloudyZap",{4,3.5,1,0,-2,1.5,1,1,3,4},.35,.25,0,0},
    {"vocal","人声","突出歌声，听清每个字","#fb7185","cloudyMicVocal",{-2,-2,-1,1,3,4,3.5,1.5,0,-1},0,0,.6,0},
    {"bass","重低音","低频下潜，鼓点更震撼","#f59e0b","cloudyDisc",{6,5,4,2,0,0,0,0,0,0},.5,0,0,0},
    {"night","夜间","高音柔和，音量平稳不吵人","#3b82f6","cloudyMoonStar",{0,0,0,0,0,0,-1,-2,-3.5,-5},0,0,0,.6}
}};
CloudyEffects::Settings preset(QString id){for(auto p:styles)if(id==p.id){CloudyEffects::Settings s;s.on=true;s.bands=p.bands;s.bass=p.bass;s.width=p.width;s.vocal=p.vocal;s.loudness=p.loud;return s;}return {};}
struct Mood {QString label;QStringList tags,words;CloudyEffects::Settings fx;};
const std::array<Mood,5> &moods(){static const auto result=[] {
    std::array<Mood,5> m{{
        {"伤感",{"伤感","思念","孤独","怀旧","失恋","遗憾","寂寞","忧郁"},{"泪","孤单","离开","再见","回忆","遗憾","想你","心碎","分手"},{}},
        {"热血",{"励志","热血","燃","兴奋","运动","战斗"},{"梦想","燃烧","冲","战","飞翔","无畏","勇敢"},{}},
        {"治愈",{"治愈","放松","安静","助眠","清新","舒缓","温暖"},{"晚安","温柔","微风","安静","星空","梦"},{}},
        {"浪漫",{"浪漫","甜蜜","爱情","心动","告白"},{"爱你","喜欢你","心动","拥抱","永远"},{}},
        {"欢快",{"快乐","欢快","派对","KTV","开心","夏日"},{"快乐","开心","阳光","笑","跳舞","派对"},{}}
    }};
    m[0].fx.bands={1,1.5,2,1.5,.5,0,.5,0,-1.5,-2.5};m[0].fx.vocal=.35;m[0].fx.width=.2;m[0].fx.room="room";m[0].fx.treble=-.15;
    m[1].fx.bands={4,3,1,0,-1,0,1.5,2.5,3,3};m[1].fx.bass=.35;m[1].fx.treble=.25;m[1].fx.width=.3;m[1].fx.loudness=.3;
    m[2].fx.bands={1,1,.5,0,0,0,-.5,-1.5,-2.5,-3};m[2].fx.treble=-.2;m[2].fx.width=.15;m[2].fx.loudness=.4;m[2].fx.room="room";
    m[3].fx.bands={0,.5,1,1.5,2,2.5,2,1,.5,0};m[3].fx.vocal=.45;m[3].fx.width=.2;m[3].fx.room="room";
    m[4].fx.bands={2,1.5,1,1,0,1,2,2.5,2.5,2};m[4].fx.bass=.2;m[4].fx.treble=.2;m[4].fx.width=.25;return m;
}();return result;}
}
SoundEffects::SoundEffects(MusicLibrary *music,QObject *parent):QObject(parent),m_music(music){
    const auto saved=QJsonDocument::fromJson(music->host->preference("sound-effects").toUtf8()).object();
    m_settings=CloudyEffects::Settings::fromMap(saved.toVariantMap());m_preset=saved["preset"].toString("flat");
    QStringList ids{"smart","mood","custom"};for(auto p:styles)ids.append(p.id);if(!ids.contains(m_preset))m_preset="flat";
    if(m_settings.spatial!="8d"&&m_settings.spatial!="360")m_settings.spatial.clear();
    bool validRoom=false;for(auto r:CloudyEffects::rooms)if(m_settings.room==r.id)validRoom=true;if(!validRoom)m_settings.room.clear();
    m_save.setSingleShot(true);m_save.setInterval(220);connect(&m_save,&QTimer::timeout,this,&SoundEffects::save);
    m_listen.setInterval(250);connect(&m_listen,&QTimer::timeout,this,&SoundEffects::listen);
    connect(music,&MusicLibrary::playbackInvalidated,this,&SoundEffects::follow);
    connect(&music->player.lyrics,&LyricsController::changed,this,[this]{if(automatic()&&m_preset=="mood")choose(m_tagCache.value(m_song));});
    apply();follow();
}
QVariantMap SoundEffects::info()const{auto m=m_settings.map();QString label="原声";for(auto p:styles)if(m_preset==p.id)label=p.label;if(m_preset=="custom")label="自定义";else if(m_preset=="smart")label="智能音效";else if(m_preset=="mood")label="情绪调音";m["preset"]=m_preset;m["label"]=label;m["note"]=m_note;m["menuNote"]=m_settings.on?label:QString("关闭");return m;}
QVariantList SoundEffects::presets()const{QVariantList r;for(auto p:styles)r.append(QVariantMap{{"id",p.id},{"label",p.label},{"desc",p.desc},{"color",p.color},{"icon",p.icon}});return r;}
QVariantList SoundEffects::rooms()const{QVariantList r;for(auto p:CloudyEffects::rooms)r.append(QVariantMap{{"id",p.id},{"label",p.label}});return r;}
void SoundEffects::save(){m_save.stop();auto m=m_settings.map();m["preset"]=m_preset;m_music->host->setPreference("sound-effects",QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact)));}
void SoundEffects::apply(bool glide){auto s=automatic()&&m_autoReady?m_auto:m_settings;s.on=m_settings.on;s.spatial=m_settings.spatial;s.orbit=m_settings.orbit;m_music->host->setSoundEffects(s.map(),glide);m_save.start();emit changed();}
void SoundEffects::setValue(QString key,QVariant value){
    if(key=="on"){m_settings.on=value.toBool();apply();follow();return;}
    if(key=="room"){bool valid=false;for(auto r:CloudyEffects::rooms)if(value.toString()==r.id)valid=true;if(!valid)return;}
    else if(!QStringList{"bass","treble","width","depth","vocal","loudness","orbit"}.contains(key))return;
    if(key!="room"&&!std::isfinite(value.toDouble()))return;
    auto m=m_settings.map();m[key]=value;m_settings=CloudyEffects::Settings::fromMap(m);m_settings.on=true;m_preset="custom";m_listen.stop();apply();
}
void SoundEffects::setBand(int i,double v){if(i<0||i>=10||!std::isfinite(v))return;m_settings.bands[i]=std::clamp(std::round(v*2)/2,-12.,12.);m_settings.on=true;m_preset="custom";m_listen.stop();apply();}
void SoundEffects::usePreset(QString id){
    if(id=="smart"||id=="mood"){m_preset=id;m_settings.on=true;m_song.clear();m_autoReady=false;m_note.clear();follow();apply();return;}
    for(auto p:styles)if(id==p.id){auto s=preset(id);m_settings.on=true;m_settings.bands=s.bands;m_settings.bass=s.bass;m_settings.width=s.width;m_settings.vocal=s.vocal;m_settings.loudness=s.loudness;m_preset=id;m_listen.stop();apply();return;}
}
void SoundEffects::toggleSpatial(QString id){if(id!="8d"&&id!="360")return;if(m_settings.spatial==id)m_settings.spatial.clear();else{m_settings.spatial=id;m_settings.on=true;}apply();follow();}
void SoundEffects::resetEnhance(){m_settings.bass=m_settings.treble=m_settings.depth=m_settings.width=0;m_settings.on=true;m_preset="custom";apply();}
void SoundEffects::autoApply(CloudyEffects::Settings s,QString note){s.on=true;m_auto=s;m_autoReady=true;m_note=note;m_listen.stop();apply(true);}
void SoundEffects::follow(){
    if(!automatic()){m_listen.stop();return;}
    const auto song=m_music->player.current;const auto identity=MusicPlayer::identity(song);if(identity==m_song)return;
    m_song=identity;m_heard={};m_autoReady=false;m_listen.stop();
    if(song.isEmpty())return;
    choose(m_tagCache.value(identity));
    if(song["provider"].toString(m_music->provider)!="netease"||song["id"].toString().isEmpty()||m_tagCache.contains(identity))return;
    QPointer<SoundEffects> self(this);const auto account=m_music->accountGeneration();
    m_music->api.request("/song/wiki/summary",{{"id",song["id"]}},[self,identity](MusicReply r){if(!self||!r.ok())return;self->m_tagCache[identity]=r.value.toObject();if(self->automatic()&&self->m_song==identity)self->choose(r.value.toObject());},[self,identity,account]{return self&&self->m_song==identity&&self->m_music->accountGeneration()==account;});
}
void SoundEffects::choose(QJsonObject tags){
    if(!automatic())return;
    QStringList genres,feelings;
    for(auto b:tags["data"].toObject()["blocks"].toArray()){auto block=b.toObject();if(block["code"]!="SONG_PLAY_ABOUT_SONG_BASIC")continue;for(auto c:block["creatives"].toArray()){auto creative=c.toObject();for(auto r:creative["resources"].toArray()){auto t=r.toObject()["uiElement"].toObject()["mainTitle"].toObject()["title"].toString();if(creative["creativeType"]=="songTag")genres.append(t);else if(creative["creativeType"]=="songBizTag")feelings.append(t);}}}
    if(m_preset=="smart"){
        const QList<QPair<QStringList,QString>> matches{{{"摇滚","金属","朋克","Rock","Metal"},"rock"},{{"电子","舞曲","EDM","House","Techno","Trance"},"electronic"},{{"说唱","嘻哈","Rap","Hip","Trap"},"bass"},{{"爵士","蓝调","Jazz","Blues","灵魂","Soul"},"jazz"},{{"古典","交响","器乐","歌剧","Classical"},"classical"},{{"民谣","乡村","Folk","Country","独立"},"vocal"},{{"轻音乐","New Age","新世纪","氛围"},"night"},{{"R&B","流行","Pop","ACG","国风","影视"},"pop"}};
        for(auto g:genres)for(auto p:matches)for(auto w:p.first)if(g.contains(w,Qt::CaseInsensitive)){autoApply(preset(p.second),"已识别曲风："+g);return;}
    }else{
        for(auto t:feelings)for(auto m:moods())for(auto w:m.tags)if(t.contains(w)){autoApply(m.fx,"当前情绪："+m.label);return;}
        QString text;for(auto l:m_music->player.lyrics.document()["lines"].toArray()){text+=l.toObject()["text"].toString();text+=l.toObject()["translation"].toString();}
        int best=-1,most=0;for(int i=0;i<5;++i){int n=0;for(auto w:moods()[i].words)n+=text.count(w);if(n>most){most=n;best=i;}}if(most>=2){autoApply(moods()[best].fx,"当前情绪："+moods()[best].label+"（按歌词）");return;}
    }
    if(!m_listen.isActive()){m_note=m_preset=="smart"?"正在聆听这首歌的特点…":"正在感受这首歌的情绪…";m_heard={};m_hearing.restart();m_listen.start();emit changed();}
}
void SoundEffects::listen(){
    if(!automatic()){m_listen.stop();return;}
    const auto levels=m_music->host->soundEffectLevels();if(!m_music->host->mediaState()["playing"].toBool()){m_hearing.restart();return;}
    for(int i=0;i<std::min(24,int(levels.size()));++i)m_heard[i]+=levels[i].toDouble();
    if(m_hearing.elapsed()<6000)return;double low=0,mid=0,high=0;for(int i=0;i<24;++i){if(i<6)low+=m_heard[i];else if(i<17)mid+=m_heard[i];else high+=m_heard[i];}double sum=low+mid+high;if(sum<=0)return;low/=sum;mid/=sum;high/=sum;
    if(m_preset=="smart"){QString id=low>.42?"bass":mid>.42?"vocal":high>.3?"classical":"pop",label=low>.42?"低频饱满":mid>.42?"人声突出":high>.3?"高频明亮":"均衡";autoApply(preset(id),"按声音特点："+label);}
    else{auto m=moods()[low>.4?1:high>.3?4:2];autoApply(m.fx,"当前情绪："+m.label+"（按声音特点）");}
}
