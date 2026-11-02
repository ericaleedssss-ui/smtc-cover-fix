#include "MusicLibrary.h"
#include "MusicData.h"
#include <algorithm>

namespace {
QJsonArray without(const QJsonArray &values, const QString &field, const QJsonValue &key) {
    QJsonArray result;
    for (const auto &value : values) {
        const auto match = field.isEmpty() ? value : value.toObject()[field];
        if (match != key) {
            result.append(value);
        }
    }
    return result;
}
}

bool MusicLibrary::canMutate(const QString &route) const {
    if (provider == "netease") {
        return true;
    }
    if (provider != "qq") {
        return false;
    }
    static const QHash<QString, QStringList> features{
        {"/like", {"mutations", "likeSong"}},
        {"/album/sub", {"mutations", "subscribeAlbum"}},
        {"/playlist/subscribe", {"mutations", "subscribePlaylist"}},
        {"/playlist/tracks", {"mutations", "updatePlaylistTracks"}},
        {"/playlist/create", {"playlistManagement", "createPlaylist"}},
        {"/playlist/name/update", {"playlistManagement", "renamePlaylist"}},
        {"/playlist/delete", {"playlistManagement", "deletePlaylist"}},
    };
    const auto feature = features.value(route);
    if (feature.isEmpty()) {
        return false;
    }
    // 暂时读不到声明时仍沿用精确锁定版本的契约；明确关闭的能力禁止写入。
    return capabilities.isEmpty() || capabilities[feature[0]].toObject()[feature[1]].toBool();
}

bool MusicLibrary::canEditPlaylist(const QJsonObject &value) const {
    if (!editable() || uid.isEmpty() || value["kind"] != "playlist" || value["creatorID"] != uid) {
        return false;
    }
    if (provider != "qq") {
        return true;
    }
    bool parsed = false;
    const auto directoryId = value["dirId"].toString().toInt(&parsed);
    return value["owned"].toBool() && parsed && directoryId >= 1 && directoryId <= 199;
}

std::shared_ptr<MusicDirectory> MusicLibrary::editablePlaylistContext() const {
    for (auto folder = directory; folder; folder = folder->parent) {
        if (canEditPlaylist(folder->item)) { return folder; }
    }
    return {};
}

bool MusicLibrary::playlistContains(const MusicDirectory &playlist, const QJsonObject &song) const {
    return MusicData::indexOf(playlist.ids, song["id"]) >= 0 ||
           MusicData::indexOfId(playlist.songs, song["id"].toString()) >= 0;
}

/** 按当前账号与选中条目读取三态收藏信息。 */
void MusicLibrary::loadSubscriptionStatus(const QJsonObject &value) {
    const auto kind = value["kind"].toString();
    if (provider != "qq" || uid.isEmpty() || value["virtual"].toBool() ||
        !QStringList{"song", "album", "playlist"}.contains(kind)) {
        return;
    }
    const auto key = value["key"].toString();
    const auto token = ++m_subscriptionGeneration;
    const auto accountAlive = valid(m_accountGeneration, &m_accountGeneration);
    const auto selectionAlive = valid(token, &m_subscriptionGeneration);
    api.call(
        "subscriptionStatus", {kind, value["id"]},
        [this, key](MusicReply result) {
            if (current["key"] != key) {
                return;
            }
            subscriptionStates[key] = result.ok() ? result.value.toString("unknown") : "unknown";
            changed();
        },
        [accountAlive, selectionAlive] { return accountAlive() && selectionAlive(); });
}

/** 写操作串行化并核对账号代数；成功后才更新本地集合和失效元数据缓存。 */
void MusicLibrary::mutate(QString route, QJsonObject values, std::function<void(QJsonObject)> success,
                          Completion done) {
    if (!canMutate(route) || writeLoading || uid.isEmpty()) {
        if (!editable()) {
            status = providerName() + QStringLiteral("当前支持读取与播放");
        } else if (uid.isEmpty()) {
            status = QStringLiteral("请先登录") + providerName();
        } else if (!canMutate(route)) {
            status = QStringLiteral("当前 QQ 服务未开放此编辑功能");
        }
        changed();
        if (done) {
            done(false);
        }
        return;
    }
    writeLoading = true;
    if (provider == "qq") {
        ++m_subscriptionGeneration;
    }
    changed();
    const auto complete = [this, success, done](MusicReply result) {
        if (provider == "qq") {
            // 写入期间启动的状态读取也必须作废，不能在确认结果后回填旧红心。
            ++m_subscriptionGeneration;
        }
        bool ok = result.ok();
        const auto body = result.value.toObject();
        const auto nestedCode = body["body"].toObject()["code"].toInt(200);
        if (ok && nestedCode != 200) {
            ok = false;
            status = providerName() + QStringLiteral("返回 ") + QString::number(nestedCode);
        } else if (ok) {
            host->invalidateMetadata();
            if (success) {
                success(body);
            }
            status = QStringLiteral("已同步至") + providerName();
        } else {
            status = result.error;
            if (provider == "qq") {
                subscriptionStates.clear();
                // 写入可能已经生效；下次刷新必须绕开旧列表缓存，不能自动再写。
                host->invalidateMetadata();
            }
        }
        writeLoading = false;
        changed();
        if (done) {
            done(ok);
        }
    };
    const auto alive = valid(m_accountGeneration, &m_accountGeneration);
    if (provider == "qq") {
        api.call("mutate", {route, values}, complete, alive);
    } else {
        api.request(route, values, complete, alive);
    }
}

void MusicLibrary::ensureLikedIDs(Completion done) {
    if(provider!="netease"||uid.isEmpty()){if(done)done(false);return;}
    if(likedIDs){if(done)done(true);return;}
    if(m_likedIDsAccount!=m_accountGeneration){
        m_likedIDWaiters.clear();m_likedIDsLoading=false;m_likedIDsError.clear();m_likedIDsAccount=m_accountGeneration;
    }
    if(done)m_likedIDWaiters.append(std::move(done));
    if(m_likedIDsLoading)return;
    m_likedIDsLoading=true;m_likedIDsError.clear();
    const auto account=m_accountGeneration;const auto user=uid;
    changed();
    api.call("likedIDs",{user},[this](MusicReply reply){
        const bool ok=reply.ok()&&reply.value.isArray();
        if(ok&&!likedIDs){
            QJsonArray ids;QSet<QString> seen;
            for(const auto &v:reply.value.toArray()){
                const auto id=v.isString()?v.toString():QString::number(v.toInteger());
                if(id.isEmpty()||id=="0"||seen.contains(id))continue;
                seen.insert(id);ids.append(id);
            }
            likedIDs=ids;
        }
        m_likedIDsLoading=false;
        m_likedIDsError=ok?QString():reply.ok()?QString("喜欢状态返回格式无效"):reply.error;
        auto waiters=std::move(m_likedIDWaiters);m_likedIDWaiters.clear();
        changed();
        for(const auto &waiter:waiters)if(waiter)waiter(ok);
    },[this,account,user]{return m_accountGeneration==account&&uid==user&&provider=="netease";});
}

void MusicLibrary::like(QJsonObject value) {
    if (value.isEmpty()) {
        value = current;
    }
    if (value["kind"] != "song") {
        return;
    }
    if (uid.isEmpty()) {
        status = QStringLiteral("请先登录") + providerName();
        changed();
        return;
    }
    const auto update = [this, value](bool enabled) {
        if (provider == "qq") {
            subscriptionStates[value["key"].toString()] = enabled ? "subscribed" : "not-subscribed";
        }
        const bool existed = MusicData::indexOfId(lists[1], value["id"].toString()) >= 0;
        if (!enabled) {
            lists[1] = without(lists[1], "id", value["id"]);
            if (likedIDs) {
                *likedIDs = without(*likedIDs, {}, value["id"]);
            }
        } else {
            lists[1] = MusicData::unique(lists[1], {value});
            if (likedIDs && MusicData::indexOf(*likedIDs, value["id"]) < 0) {
                likedIDs->append(value["id"]);
            }
        }
        if (provider == "qq") {
            int adjustment = -1;
            if (enabled) {
                adjustment = existed ? 0 : 1;
            }
            totals[1] = std::max(int(lists[1].size()), totals[1] + adjustment);
            likedCursor = int(lists[1].size());
        } else {
            totals[1] = int(likedIDs ? likedIDs->size() : lists[1].size());
        }
    };
    if (provider == "qq") {
        mutate("/like", {{"id", value["id"]}},
               [update](QJsonObject body) { update(body["liked"].toBool()); });
        return;
    }
    if (!likedIDs) {
        ensureLikedIDs([this,value](bool ok){if(ok)like(value);else {status=likedIDsError();changed();}});
        return;
    }
    // The complete server ID list is authoritative; a stale shelf item is not.
    const auto liked = MusicData::indexOf(*likedIDs, value["id"]) >= 0;
    mutate("/like", {{"id", value["id"]}, {"like", !liked}},
           [update, liked](QJsonObject) { update(!liked); });
}

void MusicLibrary::subscribe(QJsonObject value) {
    if (value.isEmpty()) {
        value = current;
    }
    const auto kind = value["kind"].toString();
    if (!QStringList{"album", "playlist", "artist"}.contains(kind)) {
        return;
    }
    if (provider == "qq" && kind == "artist") {
        status = QStringLiteral("QQ 上游尚未提供收藏歌手写入");
        changed();
        return;
    }
    const auto lane = kind == "album" ? 4 : 3;
    const auto key = value["key"].toString();
    bool subscribed = subscriptions.contains(key);
    for (const auto &entry : lists[lane]) {
        subscribed |= entry.toObject()["key"] == key;
    }
    mutate(kind == "playlist" ? "/playlist/subscribe" : "/" + kind + "/sub",
           {{"id", value["id"]}, {"t", subscribed ? 2 : 1}},
           [this, value, kind, lane, key, subscribed](QJsonObject body) {
               const auto enabled = provider == "qq" ? body["subscribed"].toBool() : !subscribed;
               if (provider == "qq") {
                   subscriptionStates[key] = enabled ? "subscribed" : "not-subscribed";
               }
               if (!enabled) {
                   subscriptions.remove(key);
                   if (kind != "artist") {
                       lists[lane] = without(lists[lane], "key", key);
                   }
               } else {
                   subscriptions.insert(key);
                   if (kind != "artist") {
                       lists[lane] = MusicData::unique(lists[lane], {value});
                   }
               }
               if (kind != "artist") {
                   totals[lane] = int(lists[lane].size());
               }
           });
}

void MusicLibrary::playlistForm(QString kind, QString name, QString id, Completion done) {
    name = name.trimmed();
    const auto maximum = provider == "qq" ? 20 : 100;
    if (name.isEmpty() || name.toUcs4().size() > maximum) {
        status = QStringLiteral("请输入 1–") + QString::number(maximum) + QStringLiteral(" 字歌单名称");
        changed();
        if (done) {
            done(false);
        }
        return;
    }
    if (kind == "rename" && MusicData::indexOfId(lists[2], id) < 0 &&
        !(directory && directory->item["id"] == id && directory->item["creatorID"] == uid)) {
        status = QStringLiteral("只能编辑自己创建的歌单");
        changed();
        if (done) {
            done(false);
        }
        return;
    }
    mutate(
        kind == "create" ? "/playlist/create" : "/playlist/name/update",
        kind == "create" ? QJsonObject{{"name", name}} : QJsonObject{{"id", id}, {"name", name}},
        [this, kind, name, id](QJsonObject body) {
            if (kind == "create" && body["playlist"].isObject()) {
                auto value = provider == "qq" ? body["playlist"].toObject()
                                              : MusicData::parse(body["playlist"].toObject(), "playlist");
                if (!value.isEmpty()) {
                    value["creatorID"] = uid;
                    lists[2] = MusicData::unique(lists[2], {value});
                }
            }
            if (kind == "rename") {
                const auto verifiedName = body["name"].toString(name);
                for (qsizetype i = 0; i < lists[2].size(); ++i) {
                    auto value = lists[2].at(i).toObject();
                    if (value["id"] == id) {
                        value["title"] = verifiedName;
                        lists[2].replace(i, value);
                    }
                }
                if (directory && directory->item["id"] == id) {
                    directory->item["title"] = verifiedName;
                }
            }
            totals[2] = int(lists[2].size());
        },
        done);
}

void MusicLibrary::playlistTrack(QString id, QJsonObject value, bool remove, Completion done) {
    if (value.isEmpty()) {
        value = current;
    }
    if (value["kind"] != "song") {
        if (done) {
            done(false);
        }
        return;
    }
    auto target = directory;
    while (target && (target->item["kind"] != "playlist" || target->item["id"] != id)) { target = target->parent; }
    if (MusicData::indexOfId(lists[2], id) < 0 && !(target && canEditPlaylist(target->item))) {
        status = QStringLiteral("请选择自己创建的歌单");
        changed();
        if (done) {
            done(false);
        }
        return;
    }
    if (target && !canEditPlaylist(target->item)) { if (done) { done(false); } return; }
    const auto existed = target && playlistContains(*target, value);
    mutate(
        "/playlist/tracks", {{"pid", id}, {"tracks", value["id"]}, {"op", remove ? "del" : "add"}},
        [this, target, value, remove, existed](QJsonObject) {
            if (!target) {
                return;
            }
            target->songs = remove ? without(target->songs, "id", value["id"])
                                   : MusicData::unique(target->songs, {value});
            if (remove) {
                const auto old = MusicData::indexOf(target->ids, value["id"]);
                if (old >= 0 && old < target->cursor) {
                    target->cursor = std::max(0, target->cursor - 1);
                }
                target->ids = without(target->ids, {}, value["id"]);
                if (existed) { target->item["trackCount"] = std::max(0, target->item["trackCount"].toInt() - 1); }
                target->index = std::min(target->index, std::max(0, int(target->songs.size()) - 1));
            } else if (!existed) {
                target->ids.append(value["id"]);
                target->item["trackCount"] = target->item["trackCount"].toInt() + 1;
            }
        },
        done);
}

// Batch queue collection uses the existing account-aware mutation path and
// one NetEase write, rather than thousands of concurrent per-track mutations.
void MusicLibrary::playlistTracks(QString id, QJsonArray tracks, Completion done) {
    if (tracks.size()>100) { playlistTracksPage(id, tracks, 0, accountGeneration(), std::move(done)); return; }
    if (tracks.size() == 1) { playlistTrack(id, tracks.first().toObject(), false, done); return; }
    if (provider != "netease" || tracks.isEmpty() || MusicData::indexOfId(lists[2], id) < 0) {
        if (done) { done(false); } return;
    }
    QStringList ids;
    QSet<QString> seen;
    QJsonArray songs;
    for (const auto &value : tracks) {
        const auto song = value.toObject();
        const auto songId = song.value("id").toString();
        if (song.value("kind") == "song" && song.value("provider").toString("netease") == "netease" &&
            !songId.isEmpty() && !seen.contains(songId)) { ids.append(songId); seen.insert(songId); songs.append(song); }
    }
    if (ids.isEmpty()) { if (done) { done(false); } return; }
    auto target = directory;
    while (target && (target->item["kind"] != "playlist" || target->item["id"] != id)) { target = target->parent; }
    if (target && !canEditPlaylist(target->item)) { if (done) { done(false); } return; }
    mutate("/playlist/tracks", {{"pid", id}, {"tracks", ids.join(',')}, {"op", "add"}},
        [target, songs](QJsonObject) {
            // mutate() invalidates platform metadata on successful writes.
            // Preserve cached counts until the server refreshes them: some
            // submitted songs may already belong to the destination playlist.
            if (target) {
                target->songs = MusicData::unique(target->songs, songs);
                for (const auto &value : songs) {
                    const auto key = value.toObject().value("id");
                    if (MusicData::indexOf(target->ids, key) < 0) { target->ids.append(key); }
                }
            }
        }, done);
}

void MusicLibrary::playlistTracksPage(QString id,QJsonArray tracks,int offset,quint64 account,Completion done){
    if(accountGeneration()!=account){if(done)done(false);return;}
    const auto page=MusicData::slice(tracks,offset,100);const QPointer<MusicLibrary> owner(this);
    playlistTracks(id,page,[owner,id,tracks,offset,account,done](bool ok){
        if(!owner)return;if(!ok||owner->accountGeneration()!=account){if(done)done(false);return;}
        if(offset+100<tracks.size())owner->playlistTracksPage(id,tracks,offset+100,account,done);
        else if(done)done(true);
    });
}
