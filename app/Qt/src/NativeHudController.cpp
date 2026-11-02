#include "NativeHud.h"
#include "MusicData.h"
#include "MusicDiscover.h"
#include <QJsonDocument>
#include <QPointer>
#include <QSet>
#include <QScopeGuard>
#include <QUrl>
#include <QDateTime>
#include <QRegularExpression>
#include <QColor>
#include <algorithm>
#include <cmath>

namespace {
int wrap(int value, int count) {
    return count > 0 ? (value % count + count) % count : 0;
}

QString cycle(const QStringList &values, const QString &value) {
    return values.at(wrap(values.indexOf(value) + 1, values.size()));
}

QString decode(const QString &value) {
    return QUrl::fromPercentEncoding(value.toUtf8());
}
}

/** 建立原生界面状态与音乐通知；所有延迟动作都绑定控制器生命周期和查询代数。 */
NativeHud::NativeHud(Host *host, Glyphs *glyphs, MusicLibrary *music, HudSceneActions scene, QObject *parent)
    : QObject(parent), m_host(host), m_glyphs(glyphs), m_music(music), m_scene(std::move(scene)) {
    themeMode = host->preference("theme");
    if (themeMode.isEmpty()) {
        themeMode = "light";
    }
    dark = themeMode == "system" ? host->systemDark() : themeMode == "dark";
    reduced = host->preference("motion") == "reduced";
    startupAnimation = host->preference("startup-animation") == "on";
    discRotation = host->preference("disc-rotation") == "on";
    sceneEnhancement = host->preference("scene-enhancement") != "off";
    textFrosted = host->preference("text-frosted") != "off";
    desktopLyricsEnabled = host->preference("desktop-lyrics") == "on";
    desktopLyricsLocked = host->preference("desktop-lyrics-locked") == "on";
    const auto font = host->preference("desktop-lyrics-font");
    if (!font.isEmpty()) { desktopLyricsFont = font; }
    bool sizeValid = false;
    const auto size = host->preference("desktop-lyrics-size").toInt(&sizeValid);
    if (sizeValid) { desktopLyricsSize = std::clamp(size, 18, 48); }
    const auto savedColor = [host](const QString &key, const QString &fallback) {
        const auto color = QColor::fromString(host->preference(key));
        return color.isValid() ? color.name() : fallback;
    };
    desktopLyricsTone = host->preference("desktop-lyrics-tone") == "light" ? "light" : "dark";
    desktopLyricsPrimaryColor = savedColor("desktop-lyrics-primary-color", {});
    desktopLyricsSecondaryColor = savedColor("desktop-lyrics-secondary-color", {});
    desktopLyricsBackgroundColor = savedColor("desktop-lyrics-background-color", "#f5f0e4");
    bool opacityValid = false;
    const auto opacity = host->preference("desktop-lyrics-background-opacity").toInt(&opacityValid);
    if (opacityValid) { desktopLyricsBackgroundOpacity = std::clamp(opacity, 0, 100); }
    connect(&host->updater, &AppUpdater::updateAvailable, this, [this] {
        m_music->status = "发现新版本 " + m_host->updater.latestVersion() + "，可在设置中下载更新";
    });
    connect(music, &MusicLibrary::invalidated, this, &NativeHud::finishPage);
    connect(&music->player, &MusicPlayer::trackSelected, this,
            [this](const QJsonObject &song) { loadSocialCounts(song); });
    connect(&music->player, &MusicPlayer::roamSongStarted, this,
            [this] { openPlayingSong(true); });
}

void NativeHud::loadSocialCounts(QJsonObject song) {
    const quint64 token = ++m_socialGeneration;
    const auto id = song.value("id").toString();
    m_socialSongID = id;
    socialRedCount = -1;
    socialCommentCount = -1;
    socialRedLoading = false;
    socialCommentLoading = false;
    if (song.value("kind") != "song" ||
        song.value("provider").toString("netease") != "netease" ||
        m_music->provider != "netease" || id.isEmpty()) {
        m_host->invalidate();
        return;
    }
    bool numberOK = false;
    id.toULongLong(&numberOK);
    if (!numberOK) {
        m_host->invalidate();
        return;
    }
    const auto account = m_music->accountGeneration();
    const auto hostEpoch = m_host->epoch;
    QPointer<NativeHud> owner(this);
    const auto valid = [owner, token, id, account, hostEpoch] {
        return owner && owner->m_socialGeneration == token &&
            owner->m_socialSongID == id &&
            owner->m_music->accountGeneration() == account &&
            owner->m_music->provider == "netease" &&
            owner->m_music->player.current.value("id").toString() == id &&
            owner->m_host->epoch == hostEpoch;
    };
    socialRedLoading = true;
    socialCommentLoading = true;
    m_host->invalidate();
    m_music->api.request("/song/red/count", {{"id", id}},
        [this](MusicReply reply) {
            socialRedLoading = false;
            if (reply.ok()) {
                const auto body = reply.value.toObject();
                const auto numerical = [](QJsonValue value) -> double {
                    if (value.isDouble()) { return value.toDouble(-1); }
                    if (value.isString()) {
                        bool ok = false;
                        const auto number = value.toString().toDouble(&ok);
                        return ok ? number : -1;
                    }
                    return -1;
                };
                auto total = numerical(body.value("count"));
                if (total < 0) { total = numerical(body.value("redCount")); }
                if (total < 0) { total = numerical(body.value("likeCount")); }
                if (total < 0) { total = numerical(body.value("data")); }
                const auto data = body.value("data").toObject();
                for (const auto &key : {"count", "redCount", "likeCount", "total", "likedCount"}) {
                    if (total >= 0) { break; }
                    total = numerical(data.value(QLatin1String(key)));
                }
                if (total >= 0) { socialRedCount = total; }
            }
            m_host->invalidate();
        }, valid);
    m_music->api.request("/comment/music",
        {{"id", id}, {"limit", 1}, {"offset", 0}},
        [this](MusicReply reply) {
            socialCommentLoading = false;
            if (reply.ok()) {
                const auto total = reply.value.toObject().value("total");
                if (total.isDouble() && total.toDouble() >= 0) {
                    socialCommentCount = total.toDouble();
                }
            }
            m_host->invalidate();
        }, valid);
}

void NativeHud::openModal(QString kind) {
    // Legacy callers may request player, but it never enters the page modal stack.
    if (kind == "player") { queueOpen = true; return; }
    if (kind == "playlist-picker") { queueCollectionTracks = {}; }
    if (commentsOpen && kind != "profile" && kind != "player") {
        closeComments();
    }
    if (m_music->isLocal() &&
        QStringList{"login", "quality", "playlist-picker", "playlist-form"}.contains(kind)) {
        return;
    }
    if (kind == "discover" && m_music->isLocal()) {
        kind = "local";
    }
    if (!modal.isEmpty() && !closing && modal != kind && modal != "profile" &&
        kind != "profile" && kind != "desktop-settings") {
        m_modalBack.append({modal, kind, query, groupBy, activeGroup, listOffset, musicCollection,
                           settingsScroll, m_music->accountGeneration()});
        if (m_modalBack.size() > 16) { m_modalBack.removeFirst(); }
    }
    ++m_searchGeneration;
    if (m_scene.pointer) {
        m_scene.pointer("pointercancel", 0, 0, 0);
        m_scene.pointer("pointerleave", 0, 0, 0);
    }
    modal = kind;
    closing = false;
    motion.set(true, lastTime, reduced);
    query.clear();
    listOffset = 0;
    settingsScroll = 0;
    activeGroup.clear();
    artistTab = "songs";
    categoryPicker = false;
    categoryPage = 0;
    if (kind == "saved") {
        musicCollection = std::max(1, m_music->selectedLane);
        if (m_music->provider == "kugou" && musicCollection == 4) {
            musicCollection = 2;
        }
        if (m_music->lists[musicCollection].isEmpty()) {
            m_music->loadMoreSource(musicCollection);
        }
    }
    if (kind == "search") {
        query = m_music->keyword;
    }
}

void NativeHud::closeModal(bool returnToParent) {
    if (modal == "desktop-settings") {
        modal = "settings"; settingsScroll = desktopSettingsScroll; closing = false;
        motion.set(true, lastTime, reduced); return;
    }
    if (returnToParent && !m_modalBack.isEmpty()) {
        const auto previous = m_modalBack.last();
        if (previous.target == modal && previous.account == m_music->accountGeneration()) {
            m_modalBack.removeLast();
            if (modal == "login") { m_music->cancelLogin(); }
            modal = previous.name; query = previous.query; groupBy = previous.group;
            activeGroup = previous.active; listOffset = previous.listOffset;
            musicCollection = previous.collection; settingsScroll = previous.scroll;
            closing = false; motion.set(true, lastTime, reduced); ++m_searchGeneration;
            return;
        }
        m_modalBack.clear();
    }
    ++m_searchGeneration;
    if (modal == "login") {
        m_music->cancelLogin();
    }
    closing = true;
    motion.set(false, lastTime, reduced);
}

void NativeHud::setQuery(QString value) {
    query = value;
    listOffset = 0;
    activeGroup.clear();
    const auto token = ++m_searchGeneration;
    if (modal == "search") {
        const QPointer<NativeHud> owner(this);
        m_host->schedule(700, [owner, token, value]() {
            if (!owner || token != owner->m_searchGeneration) {
                return;
            }
            owner->m_music->search(value);
            if (owner->m_music->provider == "netease" && !owner->m_host->fromLink(value).isEmpty()) {
                if (owner->m_profileReturn) {
                    owner->profileSection = "music"; owner->profileFilter = "created";
                    owner->openModal("profile"); owner->loadProfileRows();
                } else { owner->closeModal(); }
            }
        });
    }
}

void NativeHud::form(QJsonObject fields) {
    if (modal == "login" && QStringList{"phone", "email"}.contains(m_music->loginMethod) &&
        fields["account"].isString() && fields["password"].isString() &&
        fields["account"].toString().size() <= 100 && fields["password"].toString().size() <= 256) {
        m_music->passwordLogin(m_music->loginMethod, fields["account"].toString(),
                               fields["password"].toString());
    }
    if (modal == "playlist-form" && fields["name"].isString()) {
        const QPointer<NativeHud> owner(this);
        const auto token = m_searchGeneration;
        m_music->playlistForm(formKind, fields["name"].toString(), formPID, [owner, token](bool ok) {
            if (ok && owner && owner->m_searchGeneration == token && owner->modal == "playlist-form") {
                owner->closeModal();
            }
        });
    }
}

/** 查询分组只缓存当前修订；原始索引保留给资料库选择，合唱曲目可进入多个组。 */
QVector<NativeHud::Row> NativeHud::rows(int lane) {
    if (lane < 0 || lane >= 5) {
        return {};
    }
    const auto filter = modal == "saved" ? query.toLower() : QString();
    const auto key =
        QString::fromUtf8(QJsonDocument(QJsonArray{lane, double(m_music->revision),
                                                   m_music->lists[lane].size(), filter, groupBy, activeGroup})
                              .toJson(QJsonDocument::Compact));
    if (key == m_rowsKey) {
        return m_rows;
    }
    QVector<Row> values;
    for (int index = 0; index < m_music->lists[lane].size(); ++index) {
        const auto value = m_music->lists[lane].at(index).toObject();
        const auto title = value["title"].toString() + value["artist"].toString() + value["id"].toString();
        if (filter.isEmpty() || title.toLower().contains(filter)) {
            values.append({index, value, {}});
        }
    }
    const bool songs = std::any_of(values.cbegin(), values.cend(),
                                   [](const Row &row) { return row.value["kind"] == "song"; });
    if (groupBy != "none" && songs) {
        QVector<Row> groups;
        QVector<QVector<Row>> entries;
        QHash<QString, int> indices;
        for (const auto &row : values) {
            const auto value = row.value;
            if (value["kind"] != "song") {
                continue;
            }
            QVector<QPair<QString, QString>> labels;
            if (groupBy == "artist") {
                for (const auto &entry : value["artists"].toArray()) {
                    const auto artist = entry.toObject();
                    const auto id = artist["id"].toString();
                    const auto name = artist["name"].toString();
                    labels.append({id.isEmpty() ? "name:" + name : "artist:" + id, name});
                }
                if (labels.isEmpty()) {
                    auto name = value["artist"].toString();
                    labels.append({"name:" + name, name.isEmpty() ? "未知歌手" : name});
                }
            } else {
                const auto id = value["albumID"].toString();
                const auto album = value["album"].toString();
                labels.append({id.isEmpty() ? "album-name:" + album : "album:" + id,
                               album.isEmpty() ? "未知专辑" : album});
            }
            QSet<QString> seen;
            for (const auto &[label, title] : labels) {
                if (seen.contains(label)) {
                    continue;
                }
                seen.insert(label);
                if (!indices.contains(label)) {
                    indices.insert(label, groups.size());
                    groups.append(
                        {-1,
                         {{"kind", "group"}, {"key", label}, {"title", title}, {"album", "点击展开分组"}},
                         {}});
                    entries.append(QVector<Row>{});
                }
                const auto index = indices[label];
                entries[index].append(row);
                groups[index].indices.append(row.index);
            }
        }
        for (auto &group : groups) {
            group.value["id"] = QString::number(group.indices.size());
            group.value["artist"] = QString::number(group.indices.size()) + " 首已载入";
        }
        if (activeGroup.isEmpty()) {
            values = groups;
        } else {
            values = entries.value(indices.value(activeGroup, -1));
            if (m_music->groupLane == lane) {
                m_music->groupIndices.clear();
                for (const auto &row : values) {
                    m_music->groupIndices.append(row.index);
                }
            }
        }
    }
    m_rowsKey = key;
    m_rows = values;
    return values;
}

/** 分页等待音乐状态通知；弹窗、来源或查询变化后丢弃原来的翻页目标。 */
void NativeHud::pageResults(int direction) {
    if (closing || !QStringList{"search", "saved"}.contains(modal)) {
        return;
    }
    const auto lane = modal == "saved" ? musicCollection : 0;
    const auto desired = std::max(0, listOffset + direction * 5);
    m_page = Page{modal, lane, m_searchGeneration, desired};
    if (direction > 0 && desired > std::max(0, int(rows(lane).size()) - 5) && m_music->hasMore[lane] &&
        !m_music->sourceLoading()) {
        m_music->loadMoreSource(lane);
    }
    finishPage();
}

void NativeHud::finishPage() {
    if (!m_page) {
        return;
    }
    const auto page = *m_page;
    if (modal != page.modal || closing || m_searchGeneration != page.generation ||
        (modal == "saved" && page.lane != musicCollection)) {
        m_page.reset();
        return;
    }
    if (m_music->sourceLoading()) {
        return;
    }
    m_page.reset();
    listOffset = std::min(page.desired, std::max(0, int(rows(page.lane).size()) - 5));
}

void NativeHud::openPlayingSong(bool lyrics) {
    auto &music = *m_music;
    if (music.player.current.isEmpty()) { return; }
    if (lyrics && !lyricsMode) {
        m_lyricsReturn = LyricsReturn{music.current, music.directory, frame["mode"].toString(), modal,
                                     tab, artistTab, trackOffset, music.selectedPhysical,
                                     music.selectedLane, music.directoryInfo, music.accountGeneration()};
    } else if (!lyrics) {
        m_lyricsReturn.reset();
    }
    modal.clear(); closing = false;
    lyricsMode = lyrics;
    m_lyricsBrowse.reset();
    // Explicit player/roam navigation must bypass passive playlist retention.
    music.directoryInfo = false;
    music.frame["mode"]="detail";
    music.followPlayback(music.player.current);
    tab = "overview";
    m_scene.mode("detail"); frame["mode"] = "detail";
    if (!lyrics) { music.loadSongWiki(); }
}

bool NativeHud::returnFromLyrics() {
    if (!lyricsMode) { return false; }
    lyricsMode = false;
    if (!m_lyricsReturn) { return true; }
    const auto previous = *m_lyricsReturn;
    m_lyricsReturn.reset();
    auto &music = *m_music;
    if (music.accountGeneration() != previous.account) { return true; }
    music.directory = previous.directory;
    music.selectedLane = previous.lane;
    music.selectedPhysical = previous.physical;
    music.choose(previous.item, previous.directoryInfo, previous.mode == "detail");
    music.directoryInfo = previous.directoryInfo;
    tab = previous.tab; artistTab = previous.artistTab; trackOffset = previous.offset;
    m_scene.mode(previous.mode); frame["mode"] = previous.mode;
    if (previous.physical >= 0) { emit music.selectionRequested(previous.physical, {}); }
    if (!previous.modal.isEmpty()) { openModal(previous.modal); }
    return true;
}

void NativeHud::openNowPlaying() {
    auto &music=*m_music;
    if(music.player.current.isEmpty())return;
    // Keep the established FM presentation and transport untouched.
    if(music.player.roamActive){openPlayingSong(true);return;}
    const auto origin=MusicData::queueSource(music.player.current["queueSource"].toObject());
    if(music.directory)music.leaveDirectory(false);
    if(frame["viewer"].toBool())m_scene.viewerKey("Escape");
    if(!modal.isEmpty())closeModal(false);
    modal.clear();closing=false;m_modalBack.clear();
    closeComments();lyricsMode=false;queueOpen=false;
    focusAction.clear();hoveredLink.clear();
    music.archiveReturnItem=origin;music.archivePlayingDirectory.reset();
    music.archiveNowPlaying=true;
    m_scene.mode("archive");frame["mode"]="archive";music.frame["mode"]="archive";
    music.changed();m_host->invalidate();
}

void NativeHud::playerAction(const QStringList &parts) {
    auto &music = *m_music;
    auto &player = music.player;
    const auto name = parts.value(1);
    if(name=="now-playing"){openNowPlaying();return;}
    const auto value = parts.value(2).toDouble();
    const auto index = int(value);
    // QML sends the identity it rendered as well as the absolute queue index.
    // A removal or account/queue replacement cannot redirect a stale click.
    if (QStringList{"queue-play", "remove", "queue-collect", "queue-source"}.contains(name)) {
        if (index < 0 || index >= player.queue.size()) { return; }
        if (parts.size() > 3 && QUrl::fromPercentEncoding(parts.value(3).toUtf8()) !=
            MusicPlayer::identity(player.queue.at(index).toObject())) { return; }
    }
    if (name == "queue-collect" || name == "queue-collect-all") {
        if (music.provider != "netease" || music.writeLoading) { return; }
        if (music.uid.isEmpty()) { queueOpen = false; openModal("login"); return; }
        const QJsonArray selected = name == "queue-collect-all" ? player.queue : QJsonArray{player.queue.at(index)};
        QJsonArray eligible;
        QSet<QString> seen;
        for (const auto &value : selected) {
            const auto song = value.toObject();
            const auto key = MusicPlayer::identity(song);
            if (song.value("kind") == "song" && song.value("provider").toString("netease") == "netease" &&
                !seen.contains(key)) { eligible.append(song); seen.insert(key); }
        }
        if (eligible.isEmpty()) { return; }
        queueCollectionOpen = true;
        queueCollectionTracks = eligible; // immutable selection, not music.current
        queueCollectionAccount = music.accountGeneration();
        if (music.lists[2].isEmpty()) { music.loadMoreSource(2); }
        return;
    }
    if (name == "queue-source") {
        const auto source = MusicData::queueSource(player.queue.at(index).toObject().value("queueSource").toObject());
        if (source.isEmpty() || source.value("provider").toString() != music.provider) { return; }
        const auto route = source.value("route").toString();
        if (route == "likes" && source.value("id").toString() != music.uid) { return; }
        queueOpen = false; queueCollectionOpen = false; queueCollectionTracks = {};
        if (route == "directory") {
            auto destination = MusicData::item(source.value("kind").toString(), source.value("id").toString(),
                source.value("title").toString(), {}, music.provider);
            destination["originType"] = source.value("type");
            closeModal(false); music.enterDirectory(destination); tab = "overview"; trackOffset = 0;
        } else if (route == "discover") {
            closeModal(false); openModal("discover");
            music.discover->category = source.value("category").toString("全部");
            music.discover->newSongArea = source.value("area").toString("5");
            music.discover->load(source.value("tab").toString());
        } else if (route == "search") {
            closeModal(false); openModal("search");
            query = source.value("query").toString();
            music.search(query, source.value("searchKind").toString("song"));
        } else if (route == "likes" && source.value("id").toString() == music.uid) {
            action("navigation:likes");
        } else if (route == "profile") {
            closeModal(false); action("profile:open:" + source.value("id").toString());
            profileSection = source.value("section").toString("music");
            profileFilter = source.value("filter").toString("created"); loadProfileRows();
        }
        return;
    }
    if (name == "lyrics") {
        if (!returnFromLyrics()) { openPlayingSong(true); }
    } else if (name == "song-lyrics") {
        openPlayingSong(true);
    } else if (name == "song-detail") {
        openPlayingSong(false);
    } else if (name == "comments") {
        if (!player.current.isEmpty()) {
            openPlayingSong(false);
            openComments();
        }
    } else if (name == "song-album") {
        const auto song=player.current;const auto albumID=song["albumID"].toString();
        if(!albumID.isEmpty()&&albumID!="0"){
            music.enterDirectory(MusicData::item("album",albumID,song["album"].toString(),song["artist"].toString(),song["provider"].toString(music.provider)));
            tab="overview";trackOffset=0;
        }
    } else if (name == "song-artist") {
        openPlayingSong(false);
        music.openSongArtist(index);
        artistTab = "songs";
    } else if (name == "lyrics-close") {
        returnFromLyrics();
    } else if (name == "lyrics-follow") {
        m_lyricsBrowse.reset();
    } else if (name == "lyrics-earlier" || name == "lyrics-later") {
        player.lyrics.adjustOffset(name == "lyrics-earlier" ? 200 : -200);
    } else if (name == "lyrics-sources" && music.isLocal() && player.current.value("provider") == "local") {
        if (modal == "lyrics-source" && !closing) {
            closeModal();
        } else {
            openModal("lyrics-source");
        }
    } else if (name == "lyrics-source" && music.isLocal()) {
        player.lyrics.selectLocalSource(player.current, parts.value(2));
        m_lyricsBrowse.reset();
        closeModal();
    } else if (name == "lyrics-retry") {
        if (!player.current.isEmpty()) {
            player.lyrics.load(player.current, true);
        }
    } else if (name == "lyric-line") {
        const auto document = player.lyrics.document();
        const auto lines = document["lines"].toArray();
        if (index >= 0 && index < lines.size() && player.state["seekable"].toBool()) {
            const auto position = lines.at(index).toObject()["startMs"].toDouble() -
                                  document["offsetMs"].toDouble() - player.lyrics.offsetMs;
            m_host->mediaControl("seek", std::clamp(position, 0.0, player.state["duration"].toDouble()));
            m_lyricsBrowse.reset();
        }
    } else if (name == "open") {
        queueOpen = !queueOpen;
        if (!queueOpen) { queueCollectionOpen = false; queueCollectionTracks = {}; }
    } else if (name == "toggle") {
        player.toggle();
    } else if (name == "prev" || name == "next") {
        player.next(name == "prev" ? -1 : 1);
    } else if (name == "seek" || name == "seek-fraction") {
        player.seek(name == "seek" ? value / 20 : value);
    } else if (name == "volume" || name == "volume-fraction") {
        player.volume(name == "volume" ? value / 10 : value);
    } else if (name == "mute") {
        const auto volume = player.state["volume"].toDouble();
        if (volume > 0) { audibleVolume = volume; player.volume(0); }
        else { player.volume(audibleVolume); }
    } else if (name == "mode") {
        if (player.heartPending) {
            player.leaveHeart();
        } else if (player.mode == "heart") {
            player.leaveHeart();
        } else if (player.mode == "shuffle" && music.provider == "netease") {
            const auto generation = music.accountGeneration();
            QPointer<MusicLibrary> owner(&music);
            player.startHeart(music.uid, [owner, generation] { return owner && owner->accountGeneration() == generation; });
        } else {
            player.cancelHeart();
            player.mode = cycle({"off", "all", "one", "shuffle", "heart"}, player.mode);
            if (music.provider != "netease" && player.mode == "heart") { player.mode = "off"; }
        }
    } else if (name == "queue") {
        if (index >= 0 && index < player.queue.size()) {
            music.playContext = player.queue;
            music.choose(player.queue.at(index).toObject(), false, true);
            m_scene.mode("detail"); frame["mode"] = "detail";
            closeModal(false);
        }
    } else if (name == "queue-play") {
        if (index >= 0 && index < player.queue.size()) { player.play(player.queue.at(index).toObject(), std::nullopt, index); }
    } else if (name == "queue-page-prev" || name == "queue-page-next") {
        queueOffset = std::clamp(queueOffset + (name == "queue-page-next" ? 40 : -40),
                                 0, std::max(0, int(player.queue.size()) - 40));
    } else if (name == "remove") {
        if (!player.roamActive) { player.remove(index); }
        queueOffset = std::clamp(queueOffset, 0, std::max(0, int(player.queue.size()) - 40));
    } else if (name == "clear") {
        if (!player.roamActive) { player.clearUpcoming(); }
        queueOffset = 0;
    } else if (name == "official") {
        music.playOfficial(player.current);
    }
}

void NativeHud::openRecommendations(bool retry) {
    const auto song = m_music->current;
    const auto id = song.value("id").toString();
    if (m_music->provider != "netease" || song.value("kind") != "song" ||
        !QRegularExpression("^[0-9]+$").match(id).hasMatch()) { return; }
    const auto key = id + ":" + QString::number(m_host->epoch);
    recommendationsOpen = true;
    if (!retry && m_recommendationKey == key &&
        (recommendationsLoaded || recommendationsPending > 0)) { return; }
    if (m_recommendationEpoch != m_host->epoch) { m_recommendationBack.clear(); }
    m_recommendationKey = key;
    m_recommendationSong = id;
    m_recommendationEpoch = m_host->epoch;
    const auto generation = ++m_recommendationGeneration;
    recommendationSongs = {}; recommendationPlaylists = {};
    recommendationsError.clear(); recommendationsPending = 2; recommendationsLoaded = false;
    QPointer<NativeHud> owner(this);
    const auto valid = [owner, generation, id] {
        return owner && owner->recommendationsOpen && owner->m_recommendationGeneration == generation &&
            owner->m_music->provider == "netease" && owner->m_host->epoch == owner->m_recommendationEpoch &&
            owner->m_music->current.value("id") == id;
    };
    for (const bool playlists : {true, false}) {
        m_music->api.request(playlists ? "/simi/playlist" : "/simi/song", {{"id", id}},
            [this, playlists](MusicReply reply) {
                --recommendationsPending;
                recommendationsLoaded = recommendationsPending == 0;
                const auto body = reply.value.toObject();
                const auto field = playlists ? "playlists" : "songs";
                if (!reply.ok() || !body.value(field).isArray()) {
                    recommendationsError = QStringLiteral("部分推荐暂时未能读取，可以重试");
                } else {
                    QJsonArray rows;
                    QSet<QString> seen;
                    for (const auto &entry : body.value(field).toArray()) {
                        auto item = MusicData::parse(entry.toObject(), playlists ? "playlist" : "song");
                        const auto id = item.value("id").toString();
                        if (id.isEmpty() || seen.contains(id) || (!playlists && id == m_recommendationSong)) { continue; }
                        seen.insert(id);
                        auto cover = item.value("cover").toString();
                        if (cover.startsWith("http://")) { cover.replace(0, 7, "https://"); }
                        item["cover"] = cover.startsWith("https://") ? cover : QString();
                        item["timeLabel"] = MusicData::time(item);
                        rows.append(item);
                        if (rows.size() == (playlists ? 3 : 10)) { break; }
                    }
                    if (playlists) { recommendationPlaylists = rows; }
                    else { recommendationSongs = rows; }
                }
                m_host->invalidate();
            }, valid);
    }
}

void NativeHud::closeComments() {
    commentsOpen = false;
    commentsLoading = false;
    ++m_commentsGeneration;
}

void NativeHud::openComments() {
    const auto song = m_music->current;
    if (m_music->provider != "netease" || (song.value("kind") != "song" && song.value("kind") != "album") ||
        !QRegularExpression("^[0-9]+$").match(song.value("id").toString()).hasMatch()) {
        return;
    }
    commentsSong = {{"id", song.value("id")}, {"kind", song.value("kind")}, {"title", song.value("title")},
                    {"artist", song.value("artist")}};
    const auto key = song.value("kind").toString() + ":" + song.value("id").toString() + ":" + commentsSort + ":" + QString::number(m_host->epoch);
    commentsOpen = true;
    m_commentsEpoch = m_host->epoch;
    if (m_commentsKey != key || commentsRows.isEmpty() || QDateTime::currentMSecsSinceEpoch() - m_commentsLoadedAt > 60000) {
        loadComments(true);
    }
}

namespace {
QJsonObject commentRow(const QJsonObject &row) {
    const auto id = row.value("commentId");
    const auto key = id.isString() ? id.toString() : QString::number(qint64(id.toDouble()));
    if (key.isEmpty() || key == "0" || !row.value("content").isString()) { return {}; }
    QJsonObject quote;
    const auto replies = row.value("beReplied").toArray();
    if (!replies.isEmpty()) {
        const auto reply = replies.first().toObject();
        if (!reply.value("content").toString().isEmpty()) {
            quote = {{"author", reply.value("user").toObject().value("nickname").toString()},
                     {"avatar", reply["user"].toObject()["avatarUrl"].toString()},
                     {"userID", reply["user"].toObject()["userId"].isString() ? reply["user"].toObject()["userId"].toString() : QString::number(reply["user"].toObject()["userId"].toInteger())},
                     {"content", reply.value("content").toString().left(16000)}};
        }
    }
    return {{"id", key}, {"author", row.value("user").toObject().value("nickname").toString("匿名用户")},
            {"avatar", row["user"].toObject()["avatarUrl"].toString()},
            {"userID", row["user"].toObject()["userId"].isString() ? row["user"].toObject()["userId"].toString() : QString::number(row["user"].toObject()["userId"].toInteger())},
            {"content", row.value("content").toString().left(16000)}, {"quote", quote},
            {"date", QDateTime::fromMSecsSinceEpoch(qint64(row.value("time").toDouble())).toLocalTime().toString("yyyy.MM.dd")},
            {"likes", std::max(0.0, row.value("likedCount").toDouble())}};
}
}

void NativeHud::loadComments(bool reset) {
    if (!commentsOpen || m_music->provider != "netease" ||
        (!reset && (commentsLoading || !commentsMore))) { return; }
    if (reset) {
        ++m_commentsGeneration;
        commentsRows = {};
        commentsFeatured = {};
        commentsTotal = 0;
        commentsMore = false;
        m_commentsOffset = 0;
        m_commentsCursor = 0;
    }
    const auto generation = m_commentsGeneration;
    const auto id = commentsSong.value("id").toString();
    const bool album = commentsSong.value("kind") == "album";
    m_commentsKey = commentsSong.value("kind").toString() + ":" + id + ":" + commentsSort + ":" + QString::number(m_host->epoch);
    commentsLoading = true;
    commentsError.clear();
    QPointer<NativeHud> owner(this);
    const auto valid = [owner, generation] {
        return owner && owner->commentsOpen && owner->m_commentsGeneration == generation &&
               owner->m_music->provider == "netease" && owner->m_host->epoch == owner->m_commentsEpoch;
    };
    if (reset) {
        m_music->api.request("/comment/hot", {{"id", id}, {"type", album ? 1 : 0}, {"limit", 5}, {"offset", 0}},
            [this](MusicReply reply) {
                const auto rows = reply.value.toObject().value("hotComments").toArray();
                if (reply.ok()) {
                    commentsFeatured = {};
                    for (const auto &value : rows) {
                        const auto row = commentRow(value.toObject());
                        if (!row.isEmpty()) { commentsFeatured.append(row); }
                        if (commentsFeatured.size() == 5) { break; }
                    }
                }
                m_host->invalidate();
            }, valid);
    }
    // 每次追加四条；超过接口的 offset 范围后用末条时间继续分页。
    QJsonObject parameters{{"id", id}, {"limit", 4}, {"offset", m_commentsOffset}};
    if (m_commentsOffset >= 5000) {
        parameters["offset"] = 0;
        parameters["before"] = m_commentsCursor;
    }
    m_music->api.request(album ? "/comment/album" : "/comment/music", parameters, [this](MusicReply reply) {
        commentsLoading = false;
        if (!reply.ok()) {
            commentsError = reply.error;
            m_host->invalidate();
            return;
        }
        const auto body = reply.value.toObject();
        if (!body.value("comments").isArray()) {
            commentsError = QStringLiteral("评论数据格式无效，请重试");
            m_host->invalidate();
            return;
        }
        const auto batch = body.value("comments").toArray();
        QSet<QString> seen;
        for (const auto &row : commentsRows) { seen.insert(row.toObject().value("id").toString()); }
        int appended = 0;
        for (const auto &value : batch) {
            const auto row = commentRow(value.toObject());
            const auto key = row.value("id").toString();
            if (!key.isEmpty() && !seen.contains(key)) {
                commentsRows.append(row);
                seen.insert(key);
                ++appended;
            }
        }
        m_commentsOffset += batch.size();
        if (!batch.isEmpty()) { m_commentsCursor = batch.last().toObject().value("time").toDouble(); }
        commentsTotal = body.value("total").toDouble(commentsTotal);
        commentsMore = appended > 0 && body.value("more").toBool(batch.size() == 4);
        commentsError.clear();
        m_commentsLoadedAt = QDateTime::currentMSecsSinceEpoch();
        m_host->invalidate();
    }, valid);
}

void NativeHud::rememberPage() {
    ViewReturn page;
    page.item = m_music->current; page.directory = m_music->directory;
    page.mode = frame["mode"].toString("archive"); page.modal = closing ? QString() : modal;
    page.tab = tab; page.artistTab = artistTab; page.query = query;
    page.groupBy = groupBy; page.activeGroup = activeGroup;
    page.trackOffset = trackOffset; page.bodyOffset = bodyOffset; page.listOffset = listOffset;
    page.collection = musicCollection; page.lane = m_music->selectedLane;
    page.physical = m_music->selectedPhysical; page.directoryInfo = m_music->directoryInfo;
    page.lyrics = lyricsMode; page.account = m_music->accountGeneration();
    page.context = m_music->playContext; page.focus = focusAction;
    m_viewBack.append(page);
    if (m_viewBack.size() > 64) { m_viewBack.removeFirst(); }
}

bool NativeHud::restorePage() {
    if (m_viewBack.isEmpty()) { return false; }
    const auto currentKey = m_music->directoryInfo && m_music->directory ? m_music->directory->item["key"].toString() : m_music->current["key"].toString();
    if (m_viewBack.last().target != currentKey) { m_viewBack.clear(); return false; }
    const auto previous = m_viewBack.takeLast();
    if (previous.account != m_music->accountGeneration()) { m_viewBack.clear(); return false; }
    auto &music = *m_music;
    if(music.archiveNowPlaying&&!music.player.roamActive&&!music.player.current.isEmpty()&&music.directory&&music.archivePlayingDirectory.lock()==music.directory&&music.directory!=previous.directory&&!previous.directory){
        music.archivePlayingDirectory.reset();
        music.leaveDirectory(false);
        music.choose(music.archiveReturnItem.isEmpty()?previous.item:music.archiveReturnItem,false,false);
        m_scene.mode("archive");frame["mode"]="archive";music.frame["mode"]="archive";
        modal.clear();closing=false;lyricsMode=false;music.changed();m_host->invalidate();return true;
    }
    if (music.directory && music.directory != previous.directory) { music.leaveDirectory(false); }
    music.directory = previous.directory; music.selectedLane = previous.lane;
    music.selectedPhysical = previous.physical;
    if (previous.physical >= 0) { emit music.selectionRequested(previous.physical, {}); }
    if (music.directory && previous.directoryInfo) { music.showDirectoryInfo(); }
    else { music.choose(previous.item, false, previous.mode == "detail"); }
    music.directoryInfo = previous.directoryInfo; music.playContext = previous.context;
    m_scene.mode(previous.mode); frame["mode"] = previous.mode; music.frame["mode"] = previous.mode;
    modal.clear(); closing = false;
    if (!previous.modal.isEmpty()) { openModal(previous.modal); }
    else { modal.clear(); closing = false; }
    tab = previous.tab; artistTab = previous.artistTab; query = previous.query;
    groupBy = previous.groupBy; activeGroup = previous.activeGroup;
    trackOffset = previous.trackOffset; bodyOffset = previous.bodyOffset;
    listOffset = previous.listOffset; musicCollection = previous.collection;
    lyricsMode = previous.lyrics; focusAction = previous.focus;
    m_host->invalidate();
    return true;
}

/** 动作字符串保持原有输入协议，控制器直接更新原生音乐状态和场景。 */
void NativeHud::action(QString value) {
    if (value == "queue-collection-close") {
        if (!m_music->writeLoading) { queueCollectionOpen = false; queueCollectionTracks = {}; }
        return;
    }
    if ((value == "back" || value == "close-modal") && queueCollectionOpen) { action("queue-collection-close"); return; }
    if (value == "queue-close" || ((value == "back" || value == "close-modal") && queueOpen)) {
        if (queueCollectionOpen) { action("queue-collection-close"); return; }
        queueOpen = false; return;
    }
    if (value == "back" && frame["viewer"].toBool()) { m_scene.viewerKey("Escape"); return; }
    if (value == "back" && !modal.isEmpty() && !closing) {
        if (profileAction(value)) { return; }
        closeModal(); return;
    }
    if (value == "back" && returnFromLyrics()) { return; }
    if (profileAction(value)) { return; }
    if (value == "back" && restorePage()) { return; }
    const bool destination = value == "player:song-album" || value == "player:now-playing" || value == "open" || value == "navigation:likes" ||
        value.startsWith("navigation:playlist:") || value.startsWith("discover:item:") || value == "discover:open" ||
        value.startsWith("music:collection-open:") || value.startsWith("music:context-comments:") ||
        value.startsWith("music:result:") || value.startsWith("music:track:") ||
        value.startsWith("music:artist:") || value.startsWith("music:artist-album:") ||
        value.startsWith("music:row-artist:") || value.startsWith("music:row-album:") ||
        value == "music:song-album" || value == "music:playlist-info" || value.startsWith("music:recommend-song:") ||
        value.startsWith("music:recommend-playlist:") || value == "player:song-detail" || value.startsWith("player:song-artist:") || value.startsWith("player:queue:");
    if (destination) { rememberPage(); }
    const int historyIndex = destination ? m_viewBack.size() - 1 : -1;
    const auto recordTarget = qScopeGuard([this, historyIndex] {
        if (historyIndex >= 0 && historyIndex < m_viewBack.size()) {
            auto &page = m_viewBack[historyIndex];
            page.target = m_music->directoryInfo && m_music->directory ? m_music->directory->item["key"].toString() : m_music->current["key"].toString();
            if (page.target == page.item["key"].toString() && page.directory == m_music->directory &&
                page.mode == frame["mode"].toString() && page.modal == (closing ? QString() : modal)) {
                m_viewBack.removeAt(historyIndex);
            }
        }
    });
    hoveredLink.clear();
    if (value == "desktop:settings") {
        desktopSettingsScroll = modal == "settings" ? settingsScroll : 0;
        openModal("desktop-settings"); return;
    }
    if (value == "desktop:back") { closeModal(); return; }
    if (value.startsWith("desktop:")) {
        const auto operation = value.mid(8);
        if (operation == "toggle" || operation == "close") {
            desktopLyricsEnabled = operation == "toggle" && !desktopLyricsEnabled;
            m_host->setPreference("desktop-lyrics", desktopLyricsEnabled ? "on" : "off");
        } else if (operation == "lock") {
            desktopLyricsLocked = !desktopLyricsLocked;
            m_host->setPreference("desktop-lyrics-locked", desktopLyricsLocked ? "on" : "off");
        } else if (operation == "smaller" || operation == "larger") {
            desktopLyricsSize = std::clamp(desktopLyricsSize + (operation == "larger" ? 2 : -2), 18, 48);
            m_host->setPreference("desktop-lyrics-size", QString::number(desktopLyricsSize));
        } else if (operation == "more-transparent" || operation == "less-transparent") {
            desktopLyricsBackgroundOpacity = std::clamp(desktopLyricsBackgroundOpacity +
                (operation == "more-transparent" ? -5 : 5), 0, 100);
            m_host->setPreference("desktop-lyrics-background-opacity", QString::number(desktopLyricsBackgroundOpacity));
        } else if (operation == "reset") {
            desktopLyricsSize = 26;
            desktopLyricsFont = "MiSans";
            desktopLyricsLocked = false;
            desktopLyricsTone = "dark";
            m_host->setPreference("desktop-lyrics-tone", "dark");
            desktopLyricsPrimaryColor.clear();
            desktopLyricsSecondaryColor.clear();
            desktopLyricsBackgroundColor = "#f5f0e4";
            desktopLyricsBackgroundOpacity = 65;
            m_host->setPreference("desktop-lyrics-primary-color", "");
            m_host->setPreference("desktop-lyrics-secondary-color", "");
            m_host->setPreference("desktop-lyrics-background-color", "#f5f0e4");
            m_host->setPreference("desktop-lyrics-background-opacity", "65");
            m_host->setPreference("desktop-lyrics-size", "26");
            m_host->setPreference("desktop-lyrics-font", "MiSans");
            m_host->setPreference("desktop-lyrics-locked", "off");
            m_host->setPreference("desktop-lyrics-position", "");
        }
        return;
    }
    if (value.startsWith("comments:")) {
        const auto operation = value.mid(9);
        if (operation == "open") {
            openComments();
        } else if (operation == "close") {
            closeComments();
        } else if (commentsOpen && operation == "more") {
            loadComments(false);
        } else if (commentsOpen && operation == "retry") {
            loadComments(commentsRows.isEmpty());
        }
        return;
    }
    if (modal == "settings" && !closing &&
        (value == "settings:scroll-up" || value == "settings:scroll-down")) {
        const auto movement = value == "settings:scroll-down" ? 120. : -120.;
        settingsScroll = std::clamp(settingsScroll + movement, 0., settingsScrollMaximum());
        return;
    }

    if (value.startsWith("update:")) {
        auto &updater = m_host->updater;
        if (value == "update:check") {
            updater.check();
        } else if (value == "update:download") {
            updater.download();
        } else if (value == "update:cancel") {
            updater.cancel();
        } else if (value == "update:open") {
            updater.openDownload();
        } else if (value == "update:release") {
            updater.openRelease();
        } else if (value == "update:auto") {
            const bool enabled = m_host->preference("auto-update") != "off";
            m_host->setPreference("auto-update", enabled ? "off" : "on");
        }
        return;
    }
    auto &music = *m_music;
    const auto parts = value.split(':');
    if (value == "archive:tab-mode") {
        if (modal.isEmpty() && supportsTrackList()) {
            trackListMode = !trackListMode;
        }
        return;
    }
    if (value.startsWith("tab:")) {
        trackOffset = 0;
        bodyOffset = 0;
        tab = value.mid(4);
        if (tab != "comments" && commentsOpen) { closeComments(); }
        if (music.current.value("kind") == "song" && (tab == "history" || tab == "notes")) {
            music.sameAlbum();
        }
        return;
    }
    if (value == "provider") {
        openModal("provider");
        return;
    }
    if (value.startsWith("provider:")) {
        const auto provider = value.mid(9);
        if (music.provider != provider) {
            m_recommendationBack.clear();
            ++m_searchGeneration;
            activeGroup.clear();
            query.clear();
            listOffset = 0;
            trackOffset = 0;
            if (tab == "comments" || tab == "recommendations") { tab = "overview"; closeComments(); }
            music.switchProvider(provider);
        }
        return;
    }
    if (value == "confirm:yes") {
        const auto run = std::exchange(m_confirm, {});
        closeModal();
        if (run) {
            run();
        }
        return;
    }
    if (value.startsWith("local:") && music.isLocal()) {
        const auto name = parts.value(1);
        const auto roots = music.local->roots();
        if ((name == "folder" || name == "files") && !music.local->busy) {
            emit localImportRequested(name == "folder");
        } else if (name == "rescan") {
            music.local->rescan();
        } else if (name == "cancel") {
            music.local->cancel();
        } else if (name == "remove") {
            const auto index = parts.value(2).toInt();
            if (index >= 0 && index < roots.size()) {
                confirmTitle = "移除索引：" + roots.at(index).toObject()["name"].toString();
                const QPointer<MusicLibrary> owner(&music);
                // 回调跨越确认面板的生命周期，必须复制字符串，不能捕获临时 JSON 字段引用。
                const auto path = roots.at(index).toObject()["path"].toString();
                m_confirm = [owner, path] {
                    if (!owner || !owner->isLocal()) {
                        return;
                    }
                    const auto current = owner->local->roots();
                    for (int index = 0; index < current.size(); ++index) {
                        if (current.at(index).toObject()["path"] == path) {
                            owner->local->removeRoot(index);
                            break;
                        }
                    }
                };
                openModal("confirm");
            }
        } else if (name == "browse") {
            music.showSource(1);
            closeModal();
        } else if (name == "prev" || name == "next") {
            listOffset =
                std::clamp(listOffset + (name == "prev" ? -4 : 4), 0, std::max(0, int(roots.size()) - 4));
        }
        return;
    }
    if (music.isLocal() &&
        (value.startsWith("discover:") || value.startsWith("quality") || value == "alternative")) {
        return;
    }
    if (value.startsWith("roam:")) {
        auto &player = music.player;
        if (value == "roam:start") {
            if(player.roamActive){openPlayingSong(true);return;}
            const auto generation = music.accountGeneration();
            QPointer<MusicLibrary> owner(&music);
            player.startRoam(music.uid, [owner, generation] {
                return owner && owner->accountGeneration() == generation;
            });
        } else if (value == "roam:exit") {
            player.leaveRoam(true);
            returnFromLyrics();
        } else if (value == "roam:dislike") {
            player.dislikeRoam();
        } else if (value == "roam:retry") {
            player.retryRoam();
        }
        return;
    }
    if (value.startsWith("discover:")) {
        auto &discover = *music.discover;
        const auto name = parts.value(1);
        if (name == "tab") {
            if(parts.value(2)=="roam"){action("roam:start");return;}
            listOffset = 0;
            categoryPicker = false;
            categoryPage = 0;
            discover.load(parts.value(2));
            if (parts.value(2) == "categories" && discover.categories.isEmpty()) {
                discover.loadCategories();
            }
        } else if (name == "item") {
            const auto index = parts.value(2).toInt();
            // Discover's followed-user cards navigate to the real user profile,
            // rather than attempting to open a user as a music directory.
            if (index >= 0 && index < discover.items.size() &&
                discover.items.at(index).toObject()["kind"].toString() == "user") {
                const auto uid = discover.items.at(index).toObject()["id"].toString();
                closeModal(false);
                if (!uid.isEmpty()) { action("profile:open:" + uid); }
            } else {
                discover.open(index);
                closeModal(false);
            }
        } else if (name == "open") {
            if (music.openDaily()) {
                closeModal(false);
            }
        } else if (name == "area" && music.provider == "qq") {
            listOffset = 0;
            discover.newSongArea = parts.value(2);
            discover.load("new-songs");
        } else if (name == "categories") {
            categoryPicker = !categoryPicker;
            categoryPage = 0;
            if (categoryPicker && discover.categories.size() <= 1) {
                discover.loadCategories();
            }
        } else if (name == "category-page") {
            const auto pages =
                std::max(1, (int(discover.categories.size()) + CategoryPageSize - 1) / CategoryPageSize);
            const auto step = parts.value(2) == "prev" ? -1 : 1;
            categoryPage = std::clamp(categoryPage + step, 0, pages - 1);
        } else if (name == "category") {
            listOffset = 0;
            categoryPicker = false;
            discover.category = decode(parts.value(2));
            discover.load("categories");
        } else if (name == "more") {
            discover.load(discover.tab, true);
        } else if (name == "prev" || name == "next") {
            const auto maximum = std::max(0, int(discover.items.size()) - 6);
            listOffset = std::clamp(listOffset + (name == "prev" ? -6 : 6), 0, maximum);
        }
        return;
    }
    if (value.startsWith("player:")) {
        playerAction(parts);
        return;
    }
    if (value == "open") {
        if (music.current.isEmpty() && !music.directory && music.selectedLane == 0) {
            openModal("search");
        } else if (!music.current.isEmpty()) {
            if (music.current.value("kind") != "song") {
                music.enterDirectory(music.current);
            } else if(frame["mode"]=="archive"){
                if(!music.current["unavailable"].toBool())music.play();
            } else {
                m_scene.mode("detail");music.loadSongWiki();
            }
        }
        return;
    }
    if (value == "back") {
        if (returnFromLyrics()) { return; }
        lyricsMode = false;
        if (frame["mode"] == "detail" && music.current.value("kind") == "song" && m_music->provider == "netease" &&
            m_recommendationEpoch == m_host->epoch && !m_recommendationBack.isEmpty() && m_recommendationBack.last().target == music.current.value("id").toString()) {
            const auto previous = m_recommendationBack.takeLast();
            if (music.directory && music.directory != previous.directory) { music.leaveDirectory(false); }
            music.directory = previous.directory;
            music.directoryInfo = false;
            music.choose(previous.song, false, true);
            tab = "recommendations";
            return;
        }
        if (music.directory) {
            const auto returnTab = music.directory->returnTab;
            if (frame["mode"] == "detail" && music.directoryInfo &&
                (music.current.value("kind") == "album" || music.directory->openDetails)) {
                music.leaveDirectory();
                artistTab = music.directory ? music.directory->hudTab : "songs";
                trackOffset = music.directory ? music.directory->hudOffset : 0;
                tab = music.current.value("kind") == "song" ? returnTab : "overview";
            } else if (frame["mode"] == "detail") {
                music.returnToDirectory();
                tab = "overview";
                trackOffset = music.directory ? music.directory->hudOffset : 0;
            } else {
                music.leaveDirectory();
                if (music.current.value("kind") == "song") { tab = returnTab; }
            }
            return;
        }
    }
    if ((value == "column-prev" || value == "column-next") && music.directory) {
        music.navigateDirectory(value == "column-next" ? 8 : -8);
        return;
    }
    if (value == "prev" || value == "next") {
        music.next(value == "next" ? 1 : -1);
        return;
    }
    if (value == "column-prev" || value == "column-next") {
        const auto sources = music.sourceOrder();
        const auto index = sources.indexOf(music.selectedLane);
        music.showSource(sources.at(wrap(index + (value == "column-next" ? 1 : -1), sources.size())));
        return;
    }
    if (value.startsWith("music:")) {
        musicAction(parts, value);
        return;
    }
    if (value.startsWith("viewer:")) {
        m_scene.viewer(value.mid(7));
        return;
    }
    if (value == "navigation:likes") {
        if (!modal.isEmpty()) { closeModal(); }
        music.showSource(1);
        openModal("saved"); musicCollection = 1;
    } else if (value == "navigation:load-playlists") {
        if (!music.uid.isEmpty() && !music.isLocal() && music.lists[2].isEmpty() && music.lists[3].isEmpty()) {
            music.loadMoreSource(2);
        }
    } else if (value.startsWith("navigation:playlist:")) {
        const int lane = parts.value(2).toInt();
        const int index = parts.value(3).toInt();
        if ((lane == 2 || lane == 3) && index >= 0 && index < music.lists[lane].size()) {
            music.enterDirectory(music.lists[lane].at(index).toObject());
            tab = "overview"; trackOffset = 0; bodyOffset = 0;
            if (!modal.isEmpty()) { closeModal(false); }
        }
    } else if (value == "discover") {
        openModal("discover");
        if (!music.isLocal()) {
            music.discover->load();
        }
    } else if (value == "skip" || value == "back") {
        m_scene.mode("archive");
    } else if (QStringList{"search", "saved", "settings"}.contains(value)) {
        openModal(value);
    } else if (value == "close-modal") {
        closeModal();
    } else if (value == "viewer") {
        m_scene.openViewer();
    } else if (value == "replay") {
        if (!modal.isEmpty()) {
            closeModal();
        }
        m_scene.mode("boot");
    } else if (value == "alternative") {
        music.player.alternative = !music.player.alternative;
        m_host->setPreference("alternate-source", music.player.alternative ? "on" : "off");
    } else if (value == "quality") {
        QStringList qualities;
        for (const auto &option : MusicPlayer::qualityOptions(music.provider)) {
            qualities.append(option.first);
        }
        music.player.setQuality(cycle(qualities, music.player.quality));
    } else if (value == "quality:open") {
        openModal("quality");
    } else if (value.startsWith("quality:set:")) {
        music.player.setQuality(value.mid(12));
    } else if (value == "disc-rotation") {
        if (discRotation) {
            discRotation = false;
            m_host->setPreference("disc-rotation", "off");
        } else {
            openModal("disc-rotation-warning");
        }
    } else if (value == "disc-rotation:enable") {
        discRotation = true;
        m_host->setPreference("disc-rotation", "on");
        openModal("settings");
    } else if (value == "disc-rotation:cancel") {
        openModal("settings");
    } else if (value == "theme") {
        themeMode = cycle({"light", "dark", "system"}, themeMode);
        dark = themeMode == "system" ? m_host->systemDark() : themeMode == "dark";
        m_scene.theme(dark);
        m_host->setPreference("theme", themeMode);
    } else if (value == "scene-enhancement") {
        sceneEnhancement = !sceneEnhancement;
        m_host->setPreference("scene-enhancement", sceneEnhancement ? "on" : "off");
    } else if (value == "text-frosted") {
        textFrosted = !textFrosted;
        m_host->setPreference("text-frosted", textFrosted ? "on" : "off");
    } else if (value == "detail-autoplay") {
        const bool enabled = m_host->preference("detail-autoplay") == "on";
        m_host->setPreference("detail-autoplay", enabled ? "off" : "on");
    } else if (value == "single-play-mode") {
        const bool append = m_host->preference("single-play-mode") == "append";
        m_host->setPreference("single-play-mode", append ? "replace" : "append");
    } else if (value == "startup-animation") {
        startupAnimation = !startupAnimation;
        m_host->setPreference("startup-animation", startupAnimation ? "on" : "off");
    } else if (value == "motion") {
        reduced = !reduced;
        m_scene.reduced(reduced);
        m_host->setPreference("motion", reduced ? "reduced" : "full");
    }
}

void NativeHud::key(QString value, bool command) {
    if (frame.isEmpty()) {
        return;
    }
    if (modal == "settings" && !closing && (value == "ArrowDown" || value == "ArrowUp")) {
        const auto movement = value == "ArrowDown" ? 50. : -50.;
        settingsScroll = std::clamp(settingsScroll + movement, 0., settingsScrollMaximum());
        return;
    }
    if (value == "Enter" && command) {
        m_music->play();
        return;
    }
    if (frame["viewer"].toBool()) {
        m_scene.viewerKey(value);
        return;
    }
    if (value == "Escape") {
        action(modal.isEmpty() ? "back" : "close-modal");
        return;
    }
    if (navigatePage(value)) { return; }
    if (!modal.isEmpty()) {
        return;
    }
    if (value == "Tab" && !command) {
        action("archive:tab-mode");
        return;
    }
    if (value == " ") {
        m_music->player.toggle();
        return;
    }
    static const QHash<QString, QString> actions{{"ArrowLeft", "column-prev"},
                                                 {"ArrowRight", "column-next"},
                                                 {"ArrowUp", "prev"},
                                                 {"ArrowDown", "next"},
                                                 {"Enter", "open"},
                                                 {"/", "search"}};
    if (actions.contains(value)) {
        action(actions[value]);
    }
}

bool NativeHud::supportsTrackList() const {
    return modal.isEmpty() && frame["mode"] == "archive" && !frame["viewer"].toBool() && !lyricsMode &&
           m_music->current.value("kind") == "song";
}

bool NativeHud::animating(double time) const {
    if (reduced) {
        return !motion.finished() || closing;
    }
    const bool lyrics = lyricsMode && modal.isEmpty() && m_lyricsCurve &&
                        time - m_lyricsCurve->start < m_lyricsCurve->duration;
    const bool trackList = trackListMode && frame["mode"] == "archive" && modal.isEmpty() &&
                           m_trackListCurve && time - m_trackListCurve->start < m_trackListCurve->duration;
    if (!motion.finished() || lyrics || trackList || closing || time - m_resultStart < 0.5) {
        return true;
    }
    return std::any_of(m_rolling.cbegin(), m_rolling.cend(),
                       [time](const auto &entry) { return entry.second.active(time); });
}
