#include "MessageCenter.h"
#include <QJsonDocument>
#include <QDateTime>
#include <QPointer>
#include <QRegularExpression>
#include <QUrl>
#include <algorithm>

namespace {
QString id(QJsonValue v){return v.isString()?v.toString():v.isDouble()?QString::number(v.toInteger()):QString();}
QJsonObject object(QJsonValue v){return v.isObject()?v.toObject():QJsonDocument::fromJson(v.toString().toUtf8()).object();}
QString https(QString u){return u.startsWith("http://")?"https://"+u.mid(7):u;}
QString encoded(QJsonObject o){return QString::fromUtf8(QUrl::toPercentEncoding(QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact))));}
void merge(QVariantList &rows,const QVariantList &incoming){
    for(const auto &v:incoming){const auto key=v.toMap().value("key").toString();auto i=std::find_if(rows.begin(),rows.end(),[&](const auto &a){return a.toMap().value("key")==key;});if(i==rows.end())rows.append(v);else *i=v;}
}
}
MessageCenter::MessageCenter(MusicLibrary *music,QObject *parent):QAbstractListModel(parent),m_music(music){
    connect(music,&MusicLibrary::invalidated,this,&MessageCenter::syncAccount);
    m_poll.setInterval(45000);connect(&m_poll,&QTimer::timeout,this,[this]{if(m_open&&supported()){counts();if(m_peer.isEmpty())load(m_tab,true);else loadHistory(true);}});
    syncAccount();
}
bool MessageCenter::supported()const{return m_music->provider=="netease"&&!m_music->uid.isEmpty();}
void MessageCenter::syncAccount(){
    if(m_account==m_music->accountGeneration()&&m_uid==m_music->uid)return;
    beginResetModel();m_account=m_music->accountGeneration();m_uid=m_music->uid;m_peer.clear();m_peerName.clear();m_feedback.clear();m_counts={};m_countBusy=false;
    for(auto &p:m_pages)p=Page{};
    // No response or draft crosses an account boundary.
    m_chats.clear();endResetModel();emit changed();emit historyChanged();emit draftChanged();
    if(m_open&&supported()){counts();load(m_tab,true);}
}
int MessageCenter::rowCount(const QModelIndex &p)const{return p.isValid()?0:m_pages[m_tab].rows.size();}
QVariant MessageCenter::data(const QModelIndex &i,int role)const{return role==Row&&i.isValid()&&i.row()>=0&&i.row()<rowCount()?m_pages[m_tab].rows[i.row()]:QVariant();}
QVariantMap MessageCenter::state()const{
    const auto &p=m_pages[m_tab];const auto c=m_chats.value(chatKey());
    return {{"open",m_open},{"supported",supported()},{"tab",m_tab},{"counts",m_counts},{"loading",m_peer.isEmpty()?p.busy:c.busy},{"more",m_peer.isEmpty()?p.more:c.more},{"error",m_peer.isEmpty()?p.error:c.error},{"feedback",m_feedback},{"peer",m_peer},{"peerName",m_peerName},{"sending",c.sending},{"allReadSupported",false},{"permission",m_music->uid.isEmpty()?QString("请先登录网易云音乐"):QString("当前平台暂不提供站内消息接口")}};
}
QString MessageCenter::chatKey()const{return m_peer;}
QVariantList MessageCenter::history()const{return m_chats.value(chatKey()).rows;}
QString MessageCenter::draft()const{return m_chats.value(chatKey()).draft;}
void MessageCenter::setDraft(QString s){if(m_peer.isEmpty()||s==draft())return;m_chats[chatKey()].draft=s;emit draftChanged();}
void MessageCenter::request(QString route,QJsonObject params,std::function<void(MusicReply)> callback){
    if(!supported())return;const auto account=m_account;const auto uid=m_uid;QPointer<MessageCenter> self(this);
    params["timestamp"]=QDateTime::currentMSecsSinceEpoch();
    m_music->api.request(route,params,[self,callback](MusicReply r){if(!self)return;
        // Never echo transport/server error text: it may contain request credentials.
        if(!r.ok())r.error=QString("请求失败，请检查网络或重新登录后重试");callback(r);
    },[self,account,uid]{return self&&self->m_music->accountGeneration()==account&&self->m_music->uid==uid&&self->supported();});
}
void MessageCenter::setOpen(bool on){m_open=on;if(on){syncAccount();if(supported()){counts();if(!m_pages[m_tab].loaded)load(m_tab,true);else if(m_peer.isEmpty())load(m_tab,true);else loadHistory(true);}m_poll.start();}else m_poll.stop();emit changed();}
void MessageCenter::selectTab(int t){if(t<0||t>3)return;beginResetModel();m_tab=t;m_peer.clear();m_peerName.clear();m_feedback.clear();endResetModel();emit changed();emit historyChanged();emit draftChanged();if(!m_pages[t].loaded)load(t,true);counts();}
void MessageCenter::refresh(){if(!supported())return;counts();m_feedback.clear();if(m_peer.isEmpty())load(m_tab,true);else loadHistory(true);}
void MessageCenter::more(){load(m_tab,false);}
void MessageCenter::counts(){
    if(m_countBusy||!supported())return;m_countBusy=true;
    request("/pl/count",{},[this](MusicReply r){m_countBusy=false;if(r.ok()){
        const auto b=r.value.toObject();const auto nested=b["count"].toObject();QVariantList result;
        const QStringList names{"msg","comment","forward","notice"};
        for(const auto &n:names){auto v=b[n];if(v.isUndefined())v=nested[n];result.append(v.isDouble()&&v.toDouble()>=0?QVariant(v.toInteger()):QVariant());}m_counts=result;
    }else m_feedback="未读数量暂时无法更新，请刷新重试";emit changed();});
}
QVariantMap MessageCenter::normalize(const QJsonObject raw,int tab,bool chat,QString own){
    const auto payload=object(raw[chat?"msg":tab==0?"lastMsg":tab==3?"notice":"json"]);
    auto user=raw[tab==0||chat?"fromUser":"user"].toObject();
    if(user.isEmpty())user=payload.value("user").toObject();if(user.isEmpty())user=raw["fromUser"].toObject();
    auto time=raw[chat?"time":tab==0?"lastMsgTime":"time"].toInteger();if(!time)time=raw["updateTime"].toInteger();
    QString text=payload.value("msg").toString(payload.value("content").toString(raw["content"].toString(raw["comment"].toObject()["content"].toString())));
    QString kind,cover,target;QJsonObject resource;
    for(const auto &k:{"song","album","playlist"})if(payload[k].isObject()){kind=k;resource=payload[k].toObject();break;}
    if(!resource.isEmpty()){
        const auto rid=id(resource.value("id"));if(!rid.isEmpty())target=encoded({{"id",rid},{"provider","netease"},{"kind",kind},{"key","netease:"+kind+":"+rid},{"title",resource.value("name")}});
        text+=(text.isEmpty()?"":"\n")+QString("[%1] %2").arg(kind=="song"?"歌曲":kind=="album"?"专辑":"歌单",resource.value("name").toString());
        cover=https(resource.value("picUrl").toString(resource.value("coverImgUrl").toString(resource.value("album").toObject()["picUrl"].toString())));
    }
    auto pic=payload.value("picInfo").toObject();QString image=https(pic.value("picUrl").toString(payload.value("picUrl").toString()));
    if(!image.isEmpty())text+=(text.isEmpty()?"":"\n")+QString("[图片]");
    if(text.isEmpty())text=QString("[暂不支持的消息类型]");
    QString uid=id(user.value("userId"));if(tab==0&&!chat&&uid==own){user=raw["toUser"].toObject();uid=id(user.value("userId"));}
    const auto identity=user.value("avatarDetail").toObject();
    QString badge;if(user.value("userType").toInt()>0||user.value("authStatus").toInt()>0||!identity.isEmpty())badge="认证";else if(user.value("vipType").toInt()>0)badge="VIP";
    QString key=tab==0&&!chat?uid:id(raw["id"]);if(key.isEmpty())key=uid+":"+QString::number(time)+":"+text;
    auto resourceJson=object(raw["resourceJson"]);if(resourceJson.isEmpty())resourceJson=object(raw["resource"]);
    if(target.isEmpty()&&resourceJson.value("song").isObject())resourceJson=resourceJson.value("song").toObject();
    if(target.isEmpty()&&resourceJson.contains("id")&&resourceJson.contains("artists")){const auto rid=id(resourceJson.value("id"));target=encoded({{"id",rid},{"kind","song"},{"provider","netease"},{"key","netease:song:"+rid},{"title",resourceJson.value("name")}});kind="song";}
    return {{"key",key},{"uid",uid},{"name",user.value("nickname").toString("平台通知")},{"avatar",https(user.value("avatarUrl").toString())},{"badge",badge},{"text",text},{"time",time},{"unread",raw["newMsgCount"].isDouble()?QVariant(raw["newMsgCount"].toInteger()):QVariant()},{"mine",chat&&uid==own},{"image",image},{"cover",cover},{"resourceTitle",resource.value("name").toString()},{"target",target},{"kind",kind}};
}
void MessageCenter::load(int t,bool reset){
    if(!supported()||t<0||t>3)return;auto &p=m_pages[t];if(p.busy||(!reset&&(!p.loaded||!p.more)))return;
    p.busy=true;p.error.clear();const auto serial=++p.serial;emit changed();
    const QStringList routes{"/msg/private","/msg/comments","/msg/forwards","/msg/notices"};
    QJsonObject params{{"limit",30},{"offset",reset?0:p.offset},{"uid",m_uid},{"before",reset?-1:p.before},{"lasttime",reset?-1:p.before}};
    request(routes[t],params,[this,t,reset,serial](MusicReply r){auto &p=m_pages[t];if(p.serial!=serial)return;p.busy=false;
        if(!r.ok()){p.error=r.error;emit changed();return;}
        const auto b=r.value.toObject();const QStringList names{"msgs","comments","forwards","notices"};
        if(!b[names[t]].isArray()){p.error="消息接口返回格式不受支持，请稍后重试";emit changed();return;}
        const auto a=b[names[t]].toArray();QVariantList incoming;for(const auto &v:a)incoming.append(normalize(v.toObject(),t,false,m_uid));
        auto next=reset?incoming:p.rows;if(!reset)merge(next,incoming);
        bool sameKeys=next.size()==p.rows.size();if(sameKeys)for(int i=0;i<next.size();++i)if(next[i].toMap()["key"]!=p.rows[i].toMap()["key"]){sameKeys=false;break;}
        if(t==m_tab&&!sameKeys)beginResetModel();
        const auto previous=p.rows;p.rows=next;
        if(t==m_tab){if(!sameKeys)endResetModel();else for(int i=0;i<next.size();++i)if(previous[i]!=next[i])emit dataChanged(index(i),index(i),{Row});}
        p.offset=(reset?0:p.offset)+a.size();p.loaded=true;
        p.more=b["more"].toBool(b["hasMore"].toBool(false))&&!a.isEmpty();
        if(!a.isEmpty()){auto last=a.last().toObject();p.before=last[t==1?"updateTime":"time"].toInteger();}
        emit changed();counts();
    });
}
void MessageCenter::activate(int row){if(row<0||row>=rowCount())return;const auto r=m_pages[m_tab].rows[row].toMap();
    if(m_tab==0){startConversation(r["uid"].toString(),r["name"].toString());return;}
    const auto target=r["target"].toString();if(!target.isEmpty()){
        emit navigate((r["kind"]=="song"?"music:context-comments:":"music:collection-open:")+target);setOpen(false);
    }else {m_feedback="此消息未提供可在客户端打开的原始内容，内容可能已失效";emit changed();}
}
void MessageCenter::startConversation(QString uid,QString name){
    if(!supported()||!QRegularExpression("^[1-9][0-9]{0,19}$").match(uid).hasMatch()||uid==m_uid){m_feedback="请输入有效的对方用户 ID，不能给自己发送私信";emit changed();return;}
    m_peer=uid;m_peerName=name.isEmpty()?"用户 "+uid:name;m_feedback.clear();emit changed();emit historyChanged();emit draftChanged();loadHistory(true);
}
void MessageCenter::leaveConversation(){m_peer.clear();m_peerName.clear();emit changed();emit historyChanged();emit draftChanged();counts();}
void MessageCenter::older(){loadHistory(false);}
void MessageCenter::loadHistory(bool reset){
    if(m_peer.isEmpty()||!supported())return;const auto peer=m_peer;auto &c=m_chats[peer];if(c.busy||(!reset&&!c.more))return;c.busy=true;c.error.clear();const auto serial=++c.serial;emit changed();
    request("/msg/private/history",{{"uid",peer},{"limit",30},{"before",reset?0:c.before}},[this,peer,serial,reset](MusicReply r){auto &c=m_chats[peer];if(c.serial!=serial)return;c.busy=false;
        if(!r.ok())c.error=r.error;else{const auto b=r.value.toObject();if(!b["msgs"].isArray())c.error="会话接口返回格式不受支持";else{
            const auto a=b["msgs"].toArray();QVariantList incoming;for(const auto &v:a)incoming.append(normalize(v.toObject(),0,true,m_uid));
            // Refresh merges newest messages; previously paged history remains available.
            merge(c.rows,incoming);std::stable_sort(c.rows.begin(),c.rows.end(),[](const auto &a,const auto &b){return a.toMap()["time"].toLongLong()<b.toMap()["time"].toLongLong();});
            // A refresh starts a new pagination window. Always replace the
            // cursor with the oldest message in the returned newest page.
            c.more=b["more"].toBool(b["hasMore"].toBool(false))&&!a.isEmpty();
            if(!a.isEmpty())c.before=a.last().toObject()["time"].toInteger();
        }}if(m_peer==peer){emit historyChanged();emit changed();}counts();
    });
}
void MessageCenter::send(){
    if(m_peer.isEmpty()||!supported())return;const auto peer=m_peer;auto &c=m_chats[peer];const auto text=c.draft.trimmed();if(c.sending||text.isEmpty())return;
    if(text.size()>1000){c.error="文字消息最多 1000 字";emit changed();return;}c.sending=true;c.error.clear();emit changed();
    const auto original=c.draft;
    request("/send/text",{{"user_ids",peer},{"msg",text}},[this,peer,original](MusicReply r){auto &c=m_chats[peer];c.sending=false;
        if(!r.ok()){c.error="发送未确认。草稿已保留，请先刷新会话确认，再决定是否重试";}
        else{const auto b=r.value.toObject();if(b["code"].toInt()!=200){c.error="服务端未确认发送，草稿已保留";}
        else{if(c.draft==original)c.draft.clear();if(m_peer==peer){m_feedback="已发送";loadHistory(true);}load(0,true);}}
        if(m_peer==peer){emit draftChanged();emit changed();}
    });
}
void MessageCenter::allRead(){m_feedback="当前消息 API 未提供批量已读接口，未更改服务端或本地未读状态";emit changed();}

void MessageCenter::openResource(int n){
    const auto rows=history();if(n<0||n>=rows.size())return;const auto row=rows[n].toMap();const auto target=row["target"].toString();if(target.isEmpty())return;
    emit navigate((row["kind"]=="song"?"music:context-comments:":"music:collection-open:")+target);setOpen(false);
}
