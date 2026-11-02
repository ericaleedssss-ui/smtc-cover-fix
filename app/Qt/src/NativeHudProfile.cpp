#include "NativeHud.h"
#include "MusicData.h"
#include <QJsonDocument>
#include <QPointer>
#include <QRegularExpression>
#include <QUrl>
#include <QDateTime>
#include <algorithm>

namespace {
QString numberID(QJsonValue value) {
    return value.isString() ? value.toString() : value.isDouble() ? QString::number(value.toInteger()) : QString();
}
bool validID(const QString &id) { return QRegularExpression("^[0-9]{1,20}$").match(id).hasMatch(); }
QJsonObject musicItem(const QJsonObject &raw, const QString &kind) {
    auto item = MusicData::parse(raw, kind);
    item["timeLabel"] = MusicData::time(item);
    return item;
}
}

void NativeHud::requestListCover(QString url) {
    if (listCoverEpoch != m_host->epoch) {
        listCoverEpoch = m_host->epoch;
        listCovers.clear(); listCoverPending.clear(); listCoverRetry.clear(); listCoverFailures.clear();
    }
    if (url.isEmpty() || listCoverPending.contains(url)) { return; }
    if (m_host->hasImage(listCovers.value(url))) { return; }
    listCovers.remove(url);
    if (listCoverRetry.value(url) > QDateTime::currentMSecsSinceEpoch()) { return; }
    if (listCovers.size() > 512) { listCovers.erase(listCovers.begin()); }
    listCoverPending.insert(url);
    const auto epoch = listCoverEpoch;
    QPointer<NativeHud> owner(this);
    m_host->loadCover(url, [owner, url, epoch](QString key) {
        if (!owner || owner->m_host->epoch != epoch || owner->listCoverEpoch != epoch) { return; }
        owner->listCoverPending.remove(url);
        if (key.isEmpty()) {
            const int failures = std::min(5, owner->listCoverFailures.value(url) + 1);
            owner->listCoverFailures[url] = failures;
            const int delay = std::min(60000, 1000 * (1 << failures));
            owner->listCoverRetry[url] = QDateTime::currentMSecsSinceEpoch() + delay;
            owner->m_host->schedule(delay + 20, [owner, epoch] {
                if (owner && owner->m_host->epoch == epoch) { owner->m_host->invalidate(); }
            });
        } else {
            owner->listCovers[url] = key;
            owner->listCoverRetry.remove(url); owner->listCoverFailures.remove(url);
        }
        owner->m_host->invalidate();
    }, 160);
}

void NativeHud::openProfile(QString id) {
    if (m_music->provider != "netease" || !validID(id)) { return; }
    if (!m_profileReturn) {
        m_profileLyrics = lyricsMode;
        m_profileComments = commentsOpen ? QJsonObject{{"rows",commentsRows},{"featured",commentsFeatured},
            {"song",commentsSong},{"key",m_commentsKey},{"offset",m_commentsOffset},{"sort",commentsSort},
            {"total",commentsTotal},{"more",commentsMore},{"epoch",m_commentsEpoch}} : QJsonObject();
        m_profileReturn = LyricsReturn{m_music->current, m_music->directory, frame["mode"].toString(), modal,
            tab, artistTab, trackOffset, m_music->selectedPhysical, m_music->selectedLane,
            m_music->directoryInfo, m_music->accountGeneration()};
    }
    profileID = id; profile = {}; profileRows = {}; profileError.clear();
    profileSection = "music"; profileFilter = id == m_music->uid ? "recent" : "created";
    profileRecentKind = "playlist"; profileRankPeriod = "all";
    m_profileItem.clear();
    openModal("profile");
    ++profileGeneration;
    const auto account = m_music->accountGeneration();
    QPointer<NativeHud> owner(this);
    m_music->api.request("/user/detail", {{"uid", id}}, [this](MusicReply reply) {
        if (reply.ok()) {
            const auto body = reply.value.toObject();
            profile = body["profile"].toObject();
            profile["level"] = body["level"];
            profile["listenSongs"] = body["listenSongs"];
        } else { profileError = reply.error; }
        m_host->invalidate();
    }, [owner, id, account] { return owner && owner->profileID == id && owner->m_profileReturn &&
        owner->m_music->accountGeneration() == account; });
    loadProfileRows();
}

void NativeHud::loadProfileRows(bool more) {
    if (!validID(profileID) || m_music->provider != "netease" || (more && (profileLoading || !profileMore))) { return; }
    const auto token = ++profileGeneration;
    // Metadata and tab contents have separate validity checks.
    const auto account = m_music->accountGeneration();
    if (!more) { profileRows = {}; profileOffset = 0; profileLastTime = -1; focusAction.clear(); }
    profileLoading = true; profileError.clear(); profileMore = false;
    m_host->invalidate();
    QString route = "/user/playlist";
    QJsonObject parameters{{"uid", profileID}, {"limit", 30}, {"offset", profileOffset}};
    const auto section = profileSection; const auto filter = profileFilter; const auto recentKind = profileRecentKind;
    if (section == "notes") {
        route = "/user/event"; parameters = {{"uid", profileID}, {"limit", 20}, {"lasttime", double(profileLastTime)}};
    } else if (section == "programs") {
        route = "/dj/program"; parameters = {{"rid", profileRadioID}, {"limit",30}, {"offset",profileOffset}};
    } else if (section == "podcasts") {
        route = "/user/audio";
    } else if (filter == "recent") {
        if (profileID != m_music->uid) {
            profileLoading = false; profileError = "近期记录仅在自己的主页展示"; m_host->invalidate(); return;
        }
        if (recentKind == "ranking") {
            route = "/user/record"; parameters = {{"uid", profileID}, {"type", profileRankPeriod == "week" ? 1 : 0}};
        } else {
            route = "/record/recent/" + recentKind; parameters = {{"limit", 100}};
            if (recentKind == "playlist") {
                profileRows.append(QJsonObject{{"kind", "ranking"}, {"key", "profile:ranking"}, {"title", "我的听歌排行"}});
            }
        }
    } else if (filter == "albums") {
        if (profileID != m_music->uid) { profileLoading = false; m_host->invalidate(); return; }
        route = "/album/sublist";
    }
    QPointer<NativeHud> owner(this);
    const auto id = profileID;
    const auto rankPeriod = profileRankPeriod;
    m_music->api.request(route, parameters, [this, section, filter, id, recentKind, rankPeriod](MusicReply reply) {
        profileLoading = false;
        if (!reply.ok()) { profileError = reply.error; m_host->invalidate(); return; }
        const auto body = reply.value.toObject();
        QJsonArray raw;
        if (section == "notes") { raw = body["events"].toArray(); profileLastTime = body["lasttime"].toInteger(-1); }
        else if (section == "podcasts") { raw = body["djRadios"].toArray(); }
        else if (section == "programs") { raw = body["programs"].toArray(); }
        else if (filter == "recent") { raw = recentKind == "ranking" ? body[rankPeriod == "week" ? "weekData" : "allData"].toArray() : body["data"].toObject()["list"].toArray(); }
        else if (filter == "albums") { raw = body["data"].toArray(); }
        else { raw = body["playlist"].toArray(); }
        QSet<QString> seen;
        for (const auto &entry : profileRows) { seen.insert(entry.toObject()["key"].toString()); }
        for (const auto &entry : raw) {
            auto value = entry.toObject(); QJsonObject item;
            if (section == "notes") {
                auto payload = QJsonDocument::fromJson(value["json"].toString().toUtf8()).object();
                const auto noteID = numberID(value["id"]);
                item = {{"kind", "note"}, {"id", noteID}, {"key", "note:" + noteID},
                    {"title", payload["msg"].toString()},
                    {"date", QDateTime::fromMSecsSinceEpoch(value["eventTime"].toInteger()).toLocalTime().toString("yyyy.MM.dd")}};
                const auto pictures = value["pics"].toArray();
                if (!pictures.isEmpty()) { item["cover"] = pictures.first().toObject()["originUrl"]; }
                if (payload["song"].isObject()) { item["resource"] = musicItem(payload["song"].toObject(), "song"); }
                else if (payload["album"].isObject()) { item["resource"] = musicItem(payload["album"].toObject(), "album"); }
                if (item["title"].toString().isEmpty()) { item["title"] = "分享了一条动态"; }
            } else if (section == "programs") {
                item = musicItem(value["mainSong"].toObject(), "song");
                item["title"] = value["name"]; item["cover"] = value["coverUrl"];
            } else if (section == "podcasts") {
                const auto radioID = numberID(value["id"]);
                item = {{"kind", "radio"}, {"id", radioID}, {"key", "radio:" + radioID},
                    {"title", value["name"]}, {"cover", value["picUrl"]},
                    {"artist", value["desc"]}, {"trackCount", value["programCount"]}};
            } else if (filter == "recent") {
                if (recentKind == "ranking") {
                    item = musicItem(value["song"].toObject(), "song");
                    item["rank"] = profileRows.size() + 1;
                    if (value["playCount"].isDouble()) { item["listeningCount"] = value["playCount"]; }
                } else {
                    item = musicItem(value["data"].toObject(), recentKind);
                    // A release date is not a listening timestamp.
                    item["date"] = value["playTime"].toDouble() > 0 ?
                        QDateTime::fromMSecsSinceEpoch(value["playTime"].toInteger()).toLocalTime().toString("MM.dd HH:mm") : QString();
                }
            } else if (filter == "albums") { item = musicItem(value, "album"); }
            else {
                const bool created = numberID(value["creator"].toObject()["userId"]) == id;
                if ((filter == "created") != created) { continue; }
                item = musicItem(value, "playlist");
            }
            const auto key = item["key"].toString();
            if (!key.isEmpty() && !seen.contains(key)) { profileRows.append(item); seen.insert(key); }
        }
        profileOffset += raw.size();
        profileMore = body["more"].toBool(body["hasMore"].toBool());
        if (section == "notes") { profileMore &= profileLastTime > 0; }
        if ((section == "music" && filter == "recent") || section == "podcasts") { profileMore = false; }
        if (raw.isEmpty()) { profileMore = false; }
        m_host->invalidate();
    }, [owner, token, account] { return owner && owner->profileGeneration == token &&
        owner->m_music->accountGeneration() == account; });
}

bool NativeHud::profileAction(const QString &value) {
    if (value == "saved" && m_music->provider == "netease" && !m_music->uid.isEmpty()) {
        openProfile(m_music->uid); return true;
    }
    if (value.startsWith("profile:open:")) { openProfile(value.mid(13)); return true; }
    if ((value == "back" || value == "close-modal") && modal == "profile") {
        return profileAction("profile:close");
    }
    if ((value == "back" || value == "close-modal") && modal == "playlist-form" && m_profileReturn) {
        openModal("profile"); return true;
    }
    if ((value == "back" || value == "music:directory") && !m_profileItem.isEmpty() && (m_music->current["key"] == m_profileItem ||
        (m_music->directory && (m_music->directoryInfo || m_music->current.isEmpty()) && m_music->directory->item["key"] == m_profileItem))) {
        m_profileItem.clear(); openModal("profile"); return true;
    }
    if (!value.startsWith("profile:")) { return false; }
    const auto parts = value.split(':'); const auto name = parts.value(1);
    if (name == "close") {
        ++profileGeneration; profileLoading = false;
        modal.clear(); closing = false;
        if (m_profileReturn) {
            const auto previous = *m_profileReturn; m_profileReturn.reset();
            if (previous.account == m_music->accountGeneration() && profileNavigated) {
                m_music->directory = previous.directory;
                m_music->selectedLane = previous.lane; m_music->selectedPhysical = previous.physical;
                m_music->choose(previous.item, previous.directoryInfo, previous.mode == "detail");
                m_music->directoryInfo = previous.directoryInfo;
                m_scene.mode(previous.mode); frame["mode"] = previous.mode;
            }
            tab = previous.tab; artistTab = previous.artistTab; trackOffset = previous.offset;
            lyricsMode = m_profileLyrics;
            if (!m_profileComments.isEmpty() && previous.account == m_music->accountGeneration() &&
                m_profileComments["epoch"].toInt() == m_host->epoch) {
                ++m_commentsGeneration; commentsOpen = true; commentsLoading = false;
                commentsRows = m_profileComments["rows"].toArray(); commentsFeatured = m_profileComments["featured"].toArray();
                commentsSong = m_profileComments["song"].toObject(); m_commentsKey = m_profileComments["key"].toString();
                m_commentsOffset = m_profileComments["offset"].toInt(); commentsSort = m_profileComments["sort"].toString();
                commentsTotal = m_profileComments["total"].toDouble(); commentsMore = m_profileComments["more"].toBool();
                m_commentsEpoch = m_host->epoch;
            }
            m_profileComments = {};
            if (!previous.modal.isEmpty()) { openModal(previous.modal); }
        }
        m_profileItem.clear(); profileNavigated = false;
    } else if (name == "section") {
        if (QStringList{"music", "notes", "podcasts"}.contains(parts.value(2))) {
            profileSection = parts[2]; loadProfileRows();
        }
    } else if (name == "focus") {
        const int index = parts.value(2).toInt();
        if (index >= 0 && index < profileRows.size()) { focusAction = "profile:item:" + QString::number(index); }
    } else if (name == "blur") {
        if (!keyboardNavigation) { focusAction.clear(); }
    } else if (name == "recent-kind") {
        if (QStringList{"song", "album", "playlist", "ranking"}.contains(parts.value(2))) { profileRecentKind = parts[2]; loadProfileRows(); }
    } else if (name == "rank-period") {
        if (QStringList{"week", "all"}.contains(parts.value(2))) { profileRankPeriod = parts[2]; loadProfileRows(); }
    } else if (name == "filter") {
        if (QStringList{"recent", "created", "collected", "albums"}.contains(parts.value(2))) {
            profileFilter = parts[2]; loadProfileRows();
        }
    } else if (name == "more") { loadProfileRows(true); }
    else if (name == "retry") { if (profile.isEmpty()) { openProfile(profileID); } else { loadProfileRows(); } }
    else if (name == "create" && profileID == m_music->uid) {
        formKind = "create"; formPID.clear(); openModal("playlist-form");
    } else if (name == "artist") {
        const auto artistID = numberID(profile["artistId"]);
        if (validID(artistID)) {
            auto artist = MusicData::item("artist", artistID, profile["nickname"].toString());
            modal.clear(); profileNavigated = true; m_music->enterDirectory(artist); m_profileItem = artist["key"].toString();
        }
    } else if (name == "play") {
        const auto index = parts.value(2).toInt();
        if (index < 0 || index >= profileRows.size()) { return true; }
        const auto item = profileRows.at(index).toObject();
        if (!QStringList{"song", "album", "playlist"}.contains(item["kind"].toString())) { return true; }
        const auto token = ++profilePlayGeneration;
        if (item["kind"] == "song") {
            profilePlayKey.clear();
            QJsonArray songs;
            for (const auto &row : profileRows) { if (row.toObject()["kind"] == "song") { songs.append(row); } }
            const QJsonObject origin{{"route", "profile"}, {"type", "profile"}, {"id", profileID},
                {"title", QStringLiteral("用户主页")}, {"provider", m_music->provider},
                {"section", profileSection}, {"filter", profileFilter}};
            m_music->player.play(MusicData::withQueueSource(item, origin), MusicData::withQueueSource(songs, origin));
        } else {
            const auto account = m_music->accountGeneration();
            profilePlayKey = item["key"].toString(); profileError.clear();
            QPointer<NativeHud> owner(this);
            m_music->api.call("detail", QJsonArray{item}, [this, item](MusicReply reply) {
                profilePlayKey.clear();
                const auto data = reply.value.toArray();
                const auto songs = data.size() > 1 ? data.at(1).toArray() : QJsonArray();
                if (!reply.ok() || songs.isEmpty()) {
                    profileError = reply.error.isEmpty() ? "暂时无法读取可播放曲目" : reply.error;
                } else {
                    auto queue = songs;
                    const auto ids = data.size() > 2 ? data.at(2).toArray() : QJsonArray();
                    if (ids.size() > songs.size()) {
                        QHash<QString, QJsonObject> loaded;
                        for (const auto &song : songs) { loaded[song.toObject()["id"].toString()] = song.toObject(); }
                        queue = {};
                        for (const auto &id : ids) {
                            auto track = loaded.value(numberID(id));
                            if (track.isEmpty()) { track = MusicData::item("song", numberID(id), "待读取曲目", {}, m_music->provider); track["deferred"] = true; }
                            queue.append(track);
                        }
                    }
                    m_music->player.play(MusicData::withQueueSource(songs.first().toObject(), item), MusicData::withQueueSource(queue, item));
                }
                m_host->invalidate();
            }, [owner, token, account] { return owner && owner->profilePlayGeneration == token && owner->m_music->accountGeneration() == account; });
        }
    } else if (name == "item") {
        const auto index = parts.value(2).toInt();
        if (index < 0 || index >= profileRows.size()) { return true; }
        auto item = profileRows.at(index).toObject();
        if (item["kind"] == "ranking") { profileRecentKind = "ranking"; loadProfileRows(); return true; }
        if (item["kind"] == "note") { item = item["resource"].toObject(); }
        if (item.isEmpty()) { return true; }
        if (item["kind"] == "radio") {
            profileRadioID = item["id"].toString(); profileSection = "programs";
            loadProfileRows();
            return true;
        }
        modal.clear(); closing = false; lyricsMode = false; profileNavigated = true; tab = "overview"; trackOffset = 0;
        m_profileItem = item["key"].toString();
        if (item["kind"] == "song") {
            QJsonArray context;
            for (const auto &row : profileRows) { if (row.toObject()["kind"] == "song") { context.append(row); } }
            const QJsonObject origin{{"route", "profile"}, {"type", "profile"}, {"id", profileID},
                {"title", QStringLiteral("用户主页")}, {"provider", m_music->provider},
                {"section", profileSection}, {"filter", profileFilter}};
            m_music->playContext = MusicData::withQueueSource(context, origin);
            if(!item["unavailable"].toBool()){
                if(m_music->directory)m_music->leaveDirectory(false);
                m_music->frame["mode"]="archive";m_scene.mode("archive");frame["mode"]="archive";
                m_music->archiveNowPlaying=true;m_music->archivePlayingDirectory=m_music->directory;m_music->archiveReturnItem=origin;
                m_music->player.play(MusicData::withQueueSource(item,origin),m_music->playContext);m_music->changed();
            }

        } else {
            m_music->enterDirectory(item);
            if (item["kind"] == "playlist" && m_music->directory) {
                m_music->directory->openDetails = true; m_music->showDirectoryInfo();
            }
        }
    }
    m_host->invalidate(); return true;
}
