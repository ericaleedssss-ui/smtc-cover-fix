#include "NativeHud.h"
#include "MusicData.h"
#include <QPointer>
#include <QUrl>
#include <QJsonDocument>
#include <QDateTime>
#include <algorithm>

namespace {
int wrap(int value, int count) {
    return count > 0 ? (value % count + count) % count : 0;
}
QString decode(QString value) {
    return QUrl::fromPercentEncoding(value.toUtf8());
}
}

/** 将音乐界面动作交给原生资料库；写入确认捕获账号代数，避免切换后修改另一个账号。 */
void NativeHud::musicAction(const QStringList &parts, const QString &value) {
    auto &music = *m_music;
    const auto name = parts.value(1);
    const auto last = parts.constLast().toInt();
    if (music.isLocal() &&
        QStringList{"login", "logout", "qr", "login-method", "kugou-edition", "like", "like-current",
                    "subscribe", "create-playlist", "delete-playlist", "rename-playlist", "add-to-playlist",
                    "playlist-pick", "official", "source", "refresh-personal", "activate", "remove-track"}
            .contains(name)) {
        return;
    }
    if (name == "collection-browse") {
        const auto item=QJsonDocument::fromJson(decode(value.mid(QString("music:collection-browse:").size())).toUtf8()).object();
        browseCollection(item);
    } else if (name == "collection-open") {
        const auto item=QJsonDocument::fromJson(QUrl::fromPercentEncoding(value.mid(QString("music:collection-open:").size()).toUtf8()).toUtf8()).object();
        if(item["provider"].toString()!=music.provider || !QStringList{"playlist","album"}.contains(item["kind"].toString()) || item["id"].toString().isEmpty())return;
        closeModal(false);lyricsMode=false;m_lyricsReturn.reset();closeComments();music.enterDirectory(item);tab="overview";trackOffset=0;
    } else if (name == "context-artist") {
        const auto item=QJsonDocument::fromJson(decode(value.mid(QString("music:context-artist:").size())).toUtf8()).object();
        if(item["provider"].toString()!=music.provider||item["kind"]!="artist"||item["id"].toString().isEmpty())return;
        closeModal(false);lyricsMode=false;m_lyricsReturn.reset();closeComments();music.enterDirectory(item);artistTab="songs";trackOffset=0;
    } else if (name == "context-comments") {
        const auto song=QJsonDocument::fromJson(QUrl::fromPercentEncoding(value.mid(QString("music:context-comments:").size()).toUtf8()).toUtf8()).object();
        if(song["kind"]!="song"||song["provider"].toString()!=music.provider)return;
        closeModal(false);queueOpen=false;music.directoryInfo=false;
        music.choose(song,false,true);m_scene.mode("detail");frame["mode"]="detail";music.frame["mode"]="detail";
        tab="comments";openComments();
    } else if (name == "row-like") {
        const auto songs=music.directory?music.directory->songs:music.tracks;
        const int index=parts.value(2).toInt();
        if(index>=0&&index<songs.size()){
            const auto song=songs.at(index).toObject();
            if(song["id"].toString()==decode(parts.value(3)))music.like(song);
        }
    } else if (name == "row-artist" || name == "row-album") {
        const auto index = parts.value(2).toInt();
        const auto songs = music.directory ? music.directory->songs : music.tracks;
        if (index < 0 || index >= songs.size()) { return; }
        const auto song = songs.at(index).toObject();
        QJsonObject destination;
        if (name == "row-artist") {
            const auto artist = song["artists"].toArray().at(parts.value(3).toInt()).toObject();
            if (!artist["id"].toString().isEmpty()) { destination = MusicData::item("artist", artist["id"].toString(), artist["name"].toString(), {}, music.provider); }
        } else if (!song["albumID"].toString().isEmpty()) {
            destination = MusicData::item("album", song["albumID"].toString(), song["album"].toString(), song["artist"].toString(), music.provider);
        }
        if (!destination.isEmpty()) {
            if (music.directory) { music.directory->hudOffset = trackOffset; }
            music.enterDirectory(destination); tab = "overview"; artistTab = "songs"; trackOffset = 0;
        }
    } else if (name == "slot") {
        const auto directory = music.directory;
        if (directory && !directory->songs.isEmpty()) {
            const auto index =
                directory->page + wrap(music.selectedLane * 8 + last - directory->anchor, 40);
            if (index >= directory->songs.size() && directory->cursor < directory->ids.size()) {
                music.loadDirectoryPage(index);
            } else {
                music.selectDirectory(wrap(index, directory->songs.size()));
            }
            return;
        }
        const auto count = music.libraryItems().size();
        if (count > 0) {
            const auto index = wrap(music.offsets[music.selectedLane] + last, count);
            const auto raw = music.groupLane == music.selectedLane ? music.groupIndices.value(index) : index;
            music.selectResult(raw, music.selectedLane, false);
            m_scene.mode("archive");
        }
    } else if (name == "index") {
        // 列表命中使用完整资料库索引，跨列选择仍由既有资料库维护物理唱片位置。
        const auto values = music.libraryItems();
        if (!trackListMode || frame["mode"] != "archive" || last < 0 || last >= values.size() ||
            values.at(last).toObject()["kind"] != "song") {
            return;
        }
        if (music.directory) {
            music.selectDirectory(last);
        } else {
            const auto raw = music.groupLane == music.selectedLane ? music.groupIndices.value(last) : last;
            music.selectResult(raw, music.selectedLane, false);
        }
    } else if (name == "result") {
        const int lane=parts.value(2).toInt(),index=parts.value(3).toInt();
        if(lane>=0&&lane<5&&index>=0&&index<music.lists[lane].size()&&music.lists[lane][index].toObject()["kind"]=="song"){
            music.selectResult(index,lane,false);if(!music.current["unavailable"].toBool())music.play();
        }else music.selectResult(index,lane);
        tab = "overview";
        trackOffset = 0;
        bodyOffset = 0;
        closeModal(false);
    } else if (name == "play-row") {
        if(music.directory&&last>=0&&last<music.directory->songs.size()){
            const auto song=MusicData::withQueueSource(music.directory->songs[last].toObject(),music.directory->item);
            if(!song["unavailable"].toBool()){music.archiveNowPlaying=true;music.archivePlayingDirectory=music.directory;music.archiveReturnItem=music.directory->item;music.player.play(song,music.directoryQueue());music.changed();}
        }
    } else if (name == "track") {
        if (frame["mode"] == "detail" && music.current["kind"] == "song" && tab == "history" && last >= 0 && last < music.tracks.size()) {
            music.playContext = MusicData::withQueueSource(music.tracks, music.current);
            music.choose(MusicData::withQueueSource(music.tracks.at(last).toObject(), music.current), false, true);
        } else if (music.directory && last >= 0 && last < music.directory->songs.size()) {
            music.directory->hudOffset = trackOffset;
            music.selectDirectory(last, "detail");
        } else if (last >= 0 && last < music.tracks.size()) {
            // 详情页曲目列表就是当前单曲所在的歌曲列表。
            music.playContext = MusicData::withQueueSource(music.tracks, music.current);
            music.choose(MusicData::withQueueSource(music.tracks.at(last).toObject(), music.current), false, true);
        }
        tab = "overview";
        trackOffset = 0;
        bodyOffset = 0;
    } else if (name == "parent") {
        music.leaveDirectory();
    } else if (name == "directory-more") {
        if (music.directory) {
            music.loadDirectoryPage();
        } else {
            music.loadTrackPage(trackOffset);
        }
    } else if (name == "playlist-info") {
        if (music.current.value("kind") != "playlist") { return; }
        music.enterDirectory(music.current);
        if (music.directory) {
            music.directory->openDetails = true;
            music.showDirectoryInfo();
        }
        tab = "overview"; trackOffset = 0; bodyOffset = 0;
    } else if (name == "directory-info") {
        music.showDirectoryInfo();
        trackOffset = 0;
    } else if (name == "directory") {
        if (music.directory) {
            music.returnToDirectory();
        } else if (!music.current.isEmpty()) {
            music.enterDirectory(music.current);
        }
    } else if (name == "first-track") {
        if (trackOffset >= 0 && trackOffset < music.tracks.size()) {
            music.playContext = MusicData::withQueueSource(music.tracks, music.current);
            music.choose(MusicData::withQueueSource(music.tracks.at(trackOffset).toObject(), music.current));
        }
        tab = "overview";
        trackOffset = 0;
        bodyOffset = 0;
    } else if (name == "hint") {
        query = decode(value.mid(11));
        listOffset = 0;
        music.search(query);
    } else if (name == "kind") {
        ++m_searchGeneration;
        listOffset = 0;
        activeGroup.clear();
        const auto kind = QStringList{"song", "album", "playlist", "artist"}.value(last, "song");
        const auto text = query.isEmpty() ? music.keyword : query;
        if (text.isEmpty()) {
            music.searchKind = kind;
        } else {
            music.search(text, kind);
        }
    } else if (name == "group") {
        music.setGroupView({}, {}, modal == "saved" ? musicCollection : 0);
        ++m_searchGeneration;
        groupBy = QStringList{"none", "artist", "album"}.value(last, "none");
        activeGroup.clear();
        listOffset = 0;
    } else if (name == "expand") {
        ++m_searchGeneration;
        const auto lane = modal == "saved" ? musicCollection : 0;
        const auto key = decode(value.mid(13));
        const auto groups = rows(lane);
        const auto group = std::find_if(groups.cbegin(), groups.cend(),
                                        [&key](const Row &row) { return row.value["key"] == key; });
        activeGroup = key;
        listOffset = 0;
        if (group != groups.cend()) {
            music.setGroupView(group->value["title"].toString(), group->indices, lane);
        }
    } else if (name == "group-back") {
        music.setGroupView({}, {}, modal == "saved" ? musicCollection : 0);
        ++m_searchGeneration;
        activeGroup.clear();
        listOffset = 0;
    } else if (name == "recommend-retry") {
        if (tab == "recommendations") { openRecommendations(true); }
    } else if (name == "recommend-song") {
        if (recommendationsOpen && last >= 0 && last < recommendationSongs.size()) {
            m_recommendationBack.append({music.current, music.directory, recommendationSongs.at(last).toObject().value("id").toString()});
            if (music.directory) { music.leaveDirectory(false); }
            music.choose(recommendationSongs.at(last).toObject(), false, true);
            tab = "overview";
        }
    } else if (name == "recommend-playlist") {
        if (recommendationsOpen && last >= 0 && last < recommendationPlaylists.size()) {
            music.enterDirectory(recommendationPlaylists.at(last).toObject());
            if (music.directory) {
                music.directory->returnTab = "recommendations";
                music.directory->openDetails = true;
                music.showDirectoryInfo();
            }
            tab = "overview"; trackOffset = 0;
        }
    } else if (name == "share") {
        const auto song = music.current;
        const auto id = song.value("id").toString();
        if (music.provider == "netease" && song.value("kind") == "song" &&
            !id.isEmpty() && std::all_of(id.cbegin(), id.cend(), [](QChar c) { return c >= '0' && c <= '9'; })) {
            m_host->copy(song.value("title").toString() + " — " + song.value("artist").toString() +
                         "\nhttps://music.163.com/song?id=" + id);
            sharedSong = MusicPlayer::identity(song);
            sharedUntil = QDateTime::currentMSecsSinceEpoch() + 2000;
            const QPointer<NativeHud> owner(this);
            m_host->schedule(2100, [owner] { if (owner) { owner->m_host->invalidate(); } });
        }
    } else if (name == "artist") {
        music.openSongArtist(last);
        artistTab = "songs";
    } else if (name == "artist-tab") {
        artistTab = parts.value(2);
        trackOffset = 0;
        if (artistTab == "albums") {
            music.loadArtistAlbums();
        }
    } else if (name == "song-album") {
        const auto song = music.current;
        if (music.directory && music.directory->item.value("kind") == "album" &&
            music.directory->item.value("id") == song.value("albumID")) {
            music.showDirectoryInfo();
            tab = "overview";
            trackOffset = music.directory->hudOffset;
        } else if (!song.value("albumID").toString().isEmpty()) {
            music.enterDirectory(MusicData::item("album", song["albumID"].toString(),
                song["album"].toString(), song["artist"].toString(), music.provider));
            tab = "overview";
            trackOffset = 0;
        }
    } else if (name == "artist-album") {
        if (music.directory && last >= 0 && last < music.directory->albums.size()) {
            music.directory->hudTab = artistTab;
            music.directory->hudOffset = trackOffset;
            music.enterDirectory(music.directory->albums.at(last).toObject());
        }
        tab = "overview";
        trackOffset = 0;
        artistTab = "songs";
    } else if (name == "artist-more") {
        music.loadArtistAlbums();
    } else if (name == "collection") {
        if (last < 0 || last >= 5) {
            return;
        }
        activeGroup.clear();
        ++m_searchGeneration;
        musicCollection = last;
        listOffset = 0;
        if (music.lists[last].isEmpty()) {
            music.loadMoreSource(last);
        }
    } else if (name == "more") {
        if (last >= 0 && last < 5) {
            music.loadMoreSource(last);
        }
    } else if (name == "page-prev" || name == "page-next") {
        pageResults(name == "page-prev" ? -1 : 1);
    } else if (name == "play") {
        music.play();
    } else if (name == "preview" && music.provider == "qq") {
        music.player.play(music.current, std::nullopt, std::nullopt, true);
    } else if (name == "play-next" || name == "enqueue") {
        music.player.enqueue(music.current, name == "play-next");
    } else if (name == "play-loaded") {
        music.playDirectory();
    } else if (name == "remove-track" || name == "add-current-playlist") {
        if (const auto playlist = music.editablePlaylistContext()) {
            const bool contained = music.playlistContains(*playlist, music.current);
            if (contained == (name == "remove-track")) {
                music.playlistTrack(playlist->item["id"].toString(), music.current, contained);
            }
        }
    } else if (name == "picker-prev" || name == "picker-next") {
        const auto maximum = std::max(0, int(music.lists[2].size()) - 7);
        listOffset = std::clamp(listOffset + (name == "picker-prev" ? -7 : 7), 0, maximum);
    } else if (name == "official") {
        music.playOfficial();
    } else if (name == "copy") {
        if (!music.current.isEmpty()) {
            m_host->copy(music.current.value("id").toString());
            music.status = "已复制" + music.providerName() + " ID";
            music.changed();
        }
    } else if (name == "source") {
        if (!music.current.isEmpty()) {
            m_host->open(music.sourceURL());
        }
    } else if (name.startsWith("project-")) {
        static const QHash<QString, QString> links{
            {"project-home", "https://github.com/MikeQu223/Rhine-Music-Database"},
            {"project-author", "https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced"},
            {"project-player", "https://github.com/yakult-green-tea/qq-music-api"},
            {"project-kugou", "https://github.com/MakcRe/KuGouMusicApi"},
            {"project-rhine", "https://github.com/LBEILC/RhineLabUI"},
            {"project-lyricsx", "https://github.com/MxIris-LyricsX-Project/LyricsX"},
            {"project-lyricskit", "https://github.com/MxIris-LyricsX-Project/LyricsKit"},
            {"project-lyrimuse", "https://github.com/Yudaotor/lyrimuse"}};
        if (links.contains(name)) {
            m_host->open(links[name]);
        }
    } else if (name == "login") {
        openModal("login");
        music.loginMethod = "qr";
        music.startLogin();
    } else if (name == "kugou-edition") {
        const QPointer<NativeHud> owner(this);
        const auto token = m_searchGeneration;
        music.switchProvider("kugou", parts.value(2), [owner, token](bool ok) {
            if (ok && owner && owner->modal == "login" && owner->m_searchGeneration == token) {
                owner->m_music->startLogin();
            }
        });
    } else if (name == "login-method") {
        music.cancelLogin();
        music.loginMethod = parts.value(2);
        music.loginStatus.clear();
        if (QStringList{"qr", "wechat"}.contains(music.loginMethod)) {
            music.startLogin();
        }
    } else if (name == "refresh-personal") {
        music.refreshPersonal(musicCollection);
    } else if (name == "like" || name == "like-current") {
        const auto target = name == "like" ? QJsonObject() : music.player.current;
        music.like(target);
        if (name == "like-current" && target.value("kind") == "song") {
            const auto id = target.value("id").toString();
            const auto account = music.accountGeneration();
            QPointer<NativeHud> owner(this);
            m_host->schedule(1300, [owner, id, account] {
                if (owner && owner->m_music->accountGeneration() == account &&
                    owner->m_music->player.current.value("id").toString() == id) {
                    owner->loadSocialCounts(owner->m_music->player.current);
                }
            });
        }
    } else if (name == "subscribe") {
        music.subscribe();
    } else if (name == "create-playlist") {
        formKind = "create";
        formPID.clear();
        openModal("playlist-form");
    } else if (name == "delete-playlist") {
        if (!music.directory || !music.canEditPlaylist(music.directory->item)) {
            return;
        }
        const auto item = music.directory->item;
        confirmTitle = "删除歌单：" + item["title"].toString();
        const QPointer<MusicLibrary> owner(&music);
        const auto generation = music.accountGeneration();
        m_confirm = [owner, generation, item]() {
            if (!owner || owner->accountGeneration() != generation) {
                return;
            }
            owner->mutate("/playlist/delete", {{"id", item["id"]}}, [owner, item](QJsonObject) {
                if (!owner) {
                    return;
                }
                QJsonArray values;
                for (const auto &entry : owner->lists[2]) {
                    if (entry.toObject()["id"] != item["id"]) {
                        values.append(entry);
                    }
                }
                owner->lists[2] = values;
                owner->totals[2] = values.size();
                owner->leaveDirectory();
            });
        };
        openModal("confirm");
    } else if (name == "rename-playlist") {
        if (music.directory && music.canEditPlaylist(music.directory->item)) {
            formKind = "rename";
            formPID = music.directory->item["id"].toString();
            openModal("playlist-form");
        }
    } else if (name == "add-to-playlist") {
        openModal("playlist-picker");
        if (music.lists[2].isEmpty()) {
            music.loadMoreSource(2);
        }
    } else if (name == "playlist-pick") {
        const QPointer<NativeHud> owner(this);
        const auto token = m_searchGeneration;
        if (queueCollectionOpen) {
            if (music.writeLoading || queueCollectionAccount != music.accountGeneration()) { return; }
            const auto account = queueCollectionAccount;
            music.playlistTracks(parts.value(2), queueCollectionTracks, [owner, account](bool ok) {
                if (ok && owner && owner->queueCollectionOpen &&
                    owner->queueCollectionAccount == account && owner->m_music->accountGeneration() == account) {
                    owner->queueCollectionOpen = false; owner->queueCollectionTracks = {};
                }
            });
            return;
        }
        const auto complete = [owner, token](bool ok) {
            if (ok && owner && owner->m_searchGeneration == token && owner->modal == "playlist-picker") {
                owner->queueCollectionTracks = {};
                owner->closeModal();
            }
        };
        if (!queueCollectionTracks.isEmpty()) {
            if (queueCollectionAccount != music.accountGeneration()) {
                queueCollectionTracks = {}; closeModal(false); return;
            }
            music.playlistTracks(parts.value(2), queueCollectionTracks, complete);
        } else {
            music.playlistTrack(parts.value(2), {}, false, complete);
        }
    } else if (name == "qr") {
        music.startLogin();
    } else if (name == "logout") {
        music.logout();
    } else if (name == "activate") {
        m_host->setActivates(!m_host->activates());
    }
}

void NativeHud::browseCollection(QJsonObject item) {
    auto &music=*m_music;
        if(item["provider"].toString()!=music.provider||!QStringList{"playlist","album"}.contains(item["kind"].toString())||item["id"].toString().isEmpty()||!music.directory)return;
        const auto previous=music.directory;const auto key=previous->item["key"].toString();
        closeModal(false);music.enterDirectory(item,true);
        const auto next=music.directory;
        if(next&&next!=previous){
            if(profileNavigated&&m_profileItem==key)m_profileItem=item["key"].toString();
            if(!m_viewBack.isEmpty()&&m_viewBack.last().target==key&&m_viewBack.last().account==music.accountGeneration())m_viewBack.last().target=item["key"].toString();
        }
        tab="overview";trackOffset=0;music.changed();
}
