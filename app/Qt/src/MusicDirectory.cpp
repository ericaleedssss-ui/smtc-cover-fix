#include "PipelineDiagnostics.h"
#include "MusicLibrary.h"
#include "MusicData.h"
#include "MusicDiscover.h"
#include <QRegularExpression>
#include <algorithm>
#include <cmath>

/** 先建立可返回的目录状态，再加载内容；目录关闭或被替换后丢弃旧响应。 */
void MusicLibrary::enterDirectory(QJsonObject value, bool recordBrowse) {
    PipelineDiagnostics::Scope trace("directory.enter");
    if (value.isEmpty()) {
        return;
    }
    if (value["kind"] == "song") {
        choose(value);
        return;
    }
    ++m_directoryGeneration;
    // 进入子目录会取消父目录请求；保留已载入内容，但清除父目录未完成的加载标记。
    if (directory) { directory->albumsLoading = false; }
    ++m_selectionGeneration;
    ++m_wikiGeneration;
    const auto physical = selectedPhysical >= 0
                              ? selectedPhysical
                              : frame["selected"].toInt(physicalSlots[selectedLane].value(0, -1));
    auto next = std::make_shared<MusicDirectory>();
    next->parent = directory;
    next->parentInfo = directoryInfo;
    next->parentSongDetails = frame["mode"] == "detail" && current["kind"] == "song";
    next->item = value;
    next->openDetails = true;
    next->albumsMore = value["kind"] == "artist";
    next->parentPhysical = physical;
    next->parentLane = selectedLane;
    next->parentItem = current.isEmpty() ? value : current;
    next->recordBrowse=recordBrowse;
    if(recordBrowse&&directory){
        next->parent=directory->parent;next->parentInfo=directory->parentInfo;next->parentSongDetails=directory->parentSongDetails;
        next->parentPhysical=directory->parentPhysical;next->parentLane=directory->parentLane;next->parentItem=directory->parentItem;next->returnTab=directory->returnTab;
    }
    directory = next;
    directoryInfo = false;
    directoryLoading = true;
    wantsSongDetails = false;
    current = {};
    tracks = {};
    trackIDs = {};
    coverImage.clear();
    coverKey.clear();
    detailLoading = false;
    emit modeRequested("archive");
    emit navigationRequested("lane", 1);
    const auto destination = (selectedLane + 1) % 5;
    next->anchor = destination * 8 + rowMemory[destination];
    selectedPhysical = -1;
    status = QStringLiteral("正在打开：") + value["title"].toString();
    changed();
    if (isLocal()) {
        next->songs = local->tracks(value);
        next->item["trackCount"] = next->songs.size();
        for (const auto &song : next->songs) {
            next->ids.append(song.toObject()["id"]);
        }
        next->cursor = next->ids.size();
        next->albumsMore = false;
        directoryLoading = false;
        showDirectoryInfo();
        changed();
        return;
    }
    next->detailsPending = true;
    showDirectoryInfo();
}

// A cancelled request belongs to its directory generation. Returning through
// real navigation history resumes the same folder, without pushing history again.
void MusicLibrary::loadDirectoryDetails() {
    const auto next = directory;
    if (!next || !next->detailsPending || next->detailsGeneration == m_directoryGeneration) {
        return;
    }
    const auto token = m_directoryGeneration;
    next->detailsGeneration = token;
    directoryLoading = true;
    const auto value = next->item;
    api.call(
        "detail", {value},
        [this, next, value](MusicReply result) {
            next->detailsPending = false;
            if (!result.ok()) {
                directoryLoading = false;
                next->item["loadError"] = result.error;
                status = QStringLiteral("读取失败：") + result.error;
                changed();
                return;
            }
            PipelineDiagnostics::qml("directory.data-arrived");
            const auto values = result.value.toArray();
            next->item = values.at(0).toObject();
            if (value.contains("originType")) { next->item["originType"] = value.value("originType"); }
            if (value["kind"] == "artist" && provider == "netease") {
                api.request("/artist/detail", {{"id", value["id"]}}, [this, next](MusicReply reply) {
                    const auto user = reply.value.toObject()["data"].toObject()["user"].toObject();
                    const auto id = user["userId"];
                    const auto userID = id.isString() ? id.toString() : QString::number(id.toInteger());
                    if (reply.ok() && userID != "0" && !userID.isEmpty()) {
                        next->item["userID"] = userID;
                        if (directory == next && directoryInfo) { current["userID"] = userID; }
                        changed();
                    }
                }, valid(m_directoryGeneration, &m_directoryGeneration));
            }
            next->songs = values.at(1).toArray();
            next->ids = values.at(2).toArray();
            next->cursor = MusicData::cursor(next->songs, next->ids);
            details[next->item["key"].toString()] = next->item;
            directoryLoading = false;
            status = QStringLiteral("已打开：") + next->item["title"].toString();
            if (value["kind"] == "artist" || value["kind"] == "album" || next->openDetails) {
                showDirectoryInfo();
            } else if (!next->songs.isEmpty()) {
                next->index = 0;
                choose(MusicData::withQueueSource(next->songs.first().toObject(), next->item));
            } else {
                changed();
            }
        },
        valid(token, &m_directoryGeneration));
}

/**
 * 在资料库发现页的每日推荐
 */
bool MusicLibrary::openDaily() {
    if (!discover) {
        return false;
    }
    QJsonArray songs;
    for (const auto &value : discover->items) {
        if (value.toObject()["kind"] == "song") {
            songs.append(value);
        }
    }
    if (songs.isEmpty()) {
        status = QStringLiteral("每日推荐暂无可打开的歌曲");
        changed();
        return false;
    }
    ++m_directoryGeneration;
    ++m_selectionGeneration;
    ++m_wikiGeneration;
    const auto physical = selectedPhysical >= 0
                              ? selectedPhysical
                              : frame["selected"].toInt(physicalSlots[selectedLane].value(0, -1));
    auto next = std::make_shared<MusicDirectory>();
    next->parent = directory;
    next->item = QJsonObject{
        {"provider", provider},
        {"kind", "playlist"},
        {"virtual", true},
        {"id", "daily"},
        {"key", provider + ":playlist:daily"},
        {"title", provider == "qq" ? QStringLiteral("每日 30 首") : QStringLiteral("每日推荐")},
        {"artist", providerName()},
        {"cover", songs.first().toObject()["cover"].toString()},
        {"description", QStringLiteral("来自发现音乐的每日推荐，打开后不会同步到账号歌单。")},
        {"trackCount", int(songs.size())},
    };
    next->songs = songs;
    for (const auto &value : songs) {
        next->ids.append(value.toObject()["id"]);
    }
    next->cursor = next->ids.size();
    next->parentPhysical = physical;
    next->parentLane = selectedLane;
    next->parentItem = current;
    directory = next;
    directoryInfo = false;
    directoryLoading = false;
    wantsSongDetails = false;
    current = {};
    tracks = {};
    trackIDs = {};
    coverImage.clear();
    coverKey.clear();
    detailLoading = false;
    emit modeRequested("archive");
    emit navigationRequested("lane", 1);
    const auto destination = (selectedLane + 1) % 5;
    next->anchor = destination * 8 + rowMemory[destination];
    selectedPhysical = -1;
    status = QStringLiteral("已打开：") + next->item["title"].toString();
    next->index = 0; next->openDetails = true;
    showDirectoryInfo();
    return true;
}

void MusicLibrary::loadArtistAlbums() {
    const auto folder = directory;
    if (isLocal() || !folder || folder->item["kind"] != "artist" || folder->albumsLoading ||
        !folder->albumsMore) {
        return;
    }
    folder->albumsLoading = true;
    changed();
    api.call(
        "artistAlbums", {folder->item["id"], folder->albumCursor},
        [this, folder](MusicReply result) {
            if (result.ok()) {
                const auto page = result.value.toObject();
                folder->albums = MusicData::unique(folder->albums, page["items"].toArray());
                folder->albumCursor += page["rawCount"].toInt();
                folder->albumsMore = page["more"].toBool();
            } else {
                status = QStringLiteral("专辑读取失败：") + result.error;
            }
            folder->albumsLoading = false;
            changed();
        },
        valid(m_directoryGeneration, &m_directoryGeneration));
}

void MusicLibrary::openSongArtist(int index) {
    if (isLocal()) {
        const auto artist = current.value("artists").toArray().at(index).toObject();
        enterDirectory({{"provider", "local"},
                        {"kind", "artist"},
                        {"id", artist["id"]},
                        {"key", "local:artist:" + artist["id"].toString()},
                        {"title", artist["name"]}});
        return;
    }
    const auto artists = current.value("artists").toArray();
    const auto artist = artists.at(index).toObject();
    static const QRegularExpression identifier(QStringLiteral("^[a-zA-Z0-9_-]{1,80}$"));
    if (!artist.isEmpty() && identifier.match(artist["id"].toString()).hasMatch()) {
        enterDirectory(
            MusicData::item("artist", artist["id"].toString(), artist["name"].toString(), {}, provider));
    }
}

void MusicLibrary::observeDirectory(int physical) {
    const auto folder = directory;
    if (!folder || directoryInfo || selectedPhysical == physical) {
        return;
    }
    int lane = -1;
    for (int i = 0; i < 5; ++i) {
        if (physicalSlots[i].contains(physical)) {
            lane = i;
            break;
        }
    }
    if (lane < 0) {
        return;
    }
    const auto row = int(physicalSlots[lane].indexOf(physical));
    if (folder->songs.isEmpty()) {
        selectedPhysical = physical;
        selectedLane = lane;
        folder->anchor = lane * 8 + row;
        return;
    }
    // 拖动跨越槽位边界时继续逻辑索引，并复用分页入口。
    const auto previousCell = (folder->index + folder->anchor) % 40;
    const auto movement = lane == previousCell / 8
                              ? (row - previousCell % 8 + 12) % 8 - 4
                              : (lane * 8 + row - previousCell + 60) % 40 - 20;
    if (movement != 0) {
        const auto target = folder->index + movement;
        const auto count = int(folder->songs.size());
        const auto index = target >= count && folder->cursor < folder->ids.size()
                               ? target
                               : (target % count + count) % count;
        // 行拖动重新对齐锚点
        folder->anchor = (lane * 8 + row - index % 40 + 40) % 40;
        selectedPhysical = physical;
        selectedLane = lane;
        if (target >= count && folder->cursor < folder->ids.size()) {
            loadDirectoryPage(target);
        } else {
            // 选中槽位后不再通知
            folder->index = index;
            folder->page = index / 40 * 40;
            choose(MusicData::withQueueSource(folder->songs.at(index).toObject(), folder->item));
        }
    }
}

void MusicLibrary::selectDirectory(int index, QString mode, QString axis, int direction) {
    if (!directory || index < 0 || index >= directory->songs.size()) {
        return;
    }
    directoryInfo = false;
    directory->index = index;
    directory->page = index / 40 * 40;
    const auto cell = (index + directory->anchor) % 40;
    selectedLane = cell / 8;
    const auto physical = physicalSlots[selectedLane].value(cell % 8, -1);
    const auto navigation =
        axis.isEmpty() ? QJsonObject{} : QJsonObject{{"axis", axis}, {"direction", direction}};
    emit selectionRequested(physical, navigation);
    selectedPhysical = physical;
    choose(MusicData::withQueueSource(directory->songs.at(index).toObject(), directory->item), false, mode == "detail");
    emit modeRequested(mode);
    changed();
}

void MusicLibrary::navigateDirectory(int step, QString axis) {
    const auto folder = directory;
    if (!folder || folder->songs.isEmpty()) {
        return;
    }
    const auto target = folder->index + step;
    if (target >= folder->songs.size() && folder->cursor < folder->ids.size()) {
        loadDirectoryPage(target);
        return;
    }
    int direction = step > 0 ? 1 : -1;
    if (axis == "row") {
        direction = step;
    }
    if (axis.isEmpty()) {
        axis = std::abs(step) > 1 ? "lane" : "row";
    }
    const auto count = int(folder->songs.size());
    selectDirectory(((target % count) + count) % count, "archive", axis, direction);
}

/** 按完整 ID 分页补齐曲目，游标按已消费 ID 数推进，无法播放的条目不会重复请求。 */
void MusicLibrary::loadDirectoryPage(std::optional<int> selectAfter) {
    const auto folder = directory;
    if (!folder || directoryLoading || folder->cursor >= folder->ids.size()) {
        return;
    }
    directoryLoading = true;
    const auto ids = MusicData::slice(folder->ids, folder->cursor, 100);
    changed();
    api.call(
        "songs", {QJsonValue(ids)},
        [this, folder, ids, selectAfter](MusicReply result) {
            directoryLoading = false;
            if (!result.ok()) {
                status = result.error;
                changed();
                return;
            }
            folder->songs = MusicData::unique(folder->songs, MusicData::ordered(ids, result.value.toArray()));
            folder->cursor += ids.size();
            if (selectAfter && *selectAfter >= 0 && *selectAfter < folder->songs.size()) {
                selectDirectory(*selectAfter);
            } else if (selectAfter && *selectAfter >= folder->songs.size() &&
                       folder->cursor < folder->ids.size()) {
                // 大步滚动可能跨过多页，不能只补一页就丢弃待选目标。
                loadDirectoryPage(selectAfter);
            } else if (selectAfter && *selectAfter >= 0 && !folder->songs.isEmpty()) {
                selectDirectory(*selectAfter % folder->songs.size());
            } else {
                changed();
            }
        },
        valid(m_directoryGeneration, &m_directoryGeneration));
}

void MusicLibrary::showDirectoryInfo() {
    PipelineDiagnostics::Scope trace("directory.show");
    if (!directory) {
        return;
    }
    ++m_selectionGeneration;
    directoryInfo = true;
    current = directory->item;
    if (!isLocal()) {
        loadSubscriptionStatus(current);
    }
    detailLoading = false;
    tracks = directory->songs;
    trackIDs = directory->ids;
    coverImage.clear();
    coverKey.clear();
    emit musicIdentityRequested(directory->item["key"].toString());
    loadCover(directory->item);
    emit modeRequested("detail");
    loadDirectoryDetails();
    changed();
}

/** 歌曲详情归位保留当前身份和物理槽位，只有目录资料页需要恢复歌曲选择。 */
void MusicLibrary::returnToDirectory() {
    if (directory) {
        if (directory->songs.isEmpty()) {
            leaveDirectory();
            return;
        }
        if ((directory->item["kind"] == "album" || directory->openDetails) && !directoryInfo) {
            showDirectoryInfo();
        } else if (directoryInfo) {
            selectDirectory(directory->index);
        } else {
            wantsSongDetails = false;
            emit modeRequested("archive");
        }
    }
    changed();
}

void MusicLibrary::leaveDirectory(bool restore) {
    PipelineDiagnostics::Scope trace("directory.leave");
    const auto folder = directory;
    if (!folder) {
        return;
    }
    ++m_directoryGeneration;
    directory = restore ? folder->parent : nullptr;
    directoryLoading = false;
    directoryInfo = false;
    ++m_selectionGeneration;
    ++m_wikiGeneration;
    tracks = {};
    trackIDs = {};
    coverImage.clear();
    coverKey.clear();
    detailLoading = false;
    if(restore&&!directory&&archiveNowPlaying&&archivePlayingDirectory.lock()==folder&&!player.current.isEmpty()&&!player.roamActive){
        archivePlayingDirectory.reset();
        selectedLane=folder->parentLane;selectedPhysical=folder->parentPhysical;
        const auto origin=archiveReturnItem.isEmpty()?folder->item:archiveReturnItem;
        choose(origin,false,false);frame["mode"]="archive";
        emit selectionRequested(folder->parentPhysical,{{"axis","lane"},{"direction",-1}});
        emit modeRequested("archive");changed();return;
    }
    if (restore) {
        selectedLane = folder->parentLane;
        selectedPhysical = folder->parentPhysical;
        current = folder->item["kind"] == "album" ? folder->parentItem :
            details.value(folder->item["key"].toString(), folder->parentItem);
        emit selectionRequested(folder->parentPhysical, {{"axis", "lane"}, {"direction", -1}});
        emit modeRequested("archive");
        if (folder->parentSongDetails) {
            choose(folder->parentItem, false, true);
            emit modeRequested("detail");
            changed();
            return;
        }
        if (directory) {
            if (folder->parentInfo) { showDirectoryInfo(); }
            else { selectDirectory(directory->index); }
            status = QStringLiteral("已返回：") + directory->item["title"].toString();
            changed();
            return;
        }
        if (!current.isEmpty()) {
            emit musicIdentityRequested(current.value("key").toString());
            loadCover(current);
        }
    }
    status = QStringLiteral("已返回：") + columns.value(selectedLane);
    changed();
}

/** 切歌沿用原物理选中与取出顺序，队列外曲目建立可返回的播放队列目录。 */
void MusicLibrary::followPlayback(QJsonObject value) {
    // Transport controls never replace the archive browsing selection or glass.
    if(!player.roamActive&&(frame["mode"]=="archive"||(directory&&directoryInfo)))return;
    // Playback controls do not take the user out of a browsed playlist.
    // Opening song detail/lyrics remains an explicit navigation action.
    if (directory && directoryInfo && directory->item["kind"] == "playlist") { return; }
    if (current.value("key") == value["key"] && current.value("id") == value["id"]) {
        return;
    }
    const auto previous = current;
    const auto physical = selectedPhysical >= 0
                              ? selectedPhysical
                              : frame["selected"].toInt(physicalSlots[selectedLane].value(0, -1));
    auto folder = directory;
    auto index = folder ? MusicData::indexOfId(folder->songs, value["id"].toString()) : -1;
    if (index < 0) {
        ++m_directoryGeneration;
        directoryLoading = false;
        folder = std::make_shared<MusicDirectory>();
        folder->parent = directory;
        folder->item = {{"kind", "playlist"},
                        {"key", "playback:queue"},
                        {"id", ""},
                        {"title", "播放队列"},
                        {"trackCount", player.queue.size()}};
        folder->songs = player.queue;
        for (const auto &song : player.queue) {
            folder->ids.append(song.toObject()["id"]);
        }
        folder->cursor = int(player.queue.size());
        index = MusicData::indexOfId(player.queue, value["id"].toString());
        folder->index = index;
        const auto row = std::max(0, int(physicalSlots[selectedLane].indexOf(physical)));
        folder->anchor = selectedLane * 8 + row;
        folder->parentPhysical = physical;
        folder->parentLane = selectedLane;
        folder->parentItem = previous;
        directory = folder;
    }
    if (index < 0 || index >= folder->songs.size()) {
        return;
    }
    folder->songs.replace(index, value);
    const auto cell = (index + folder->anchor) % 40;
    const auto target = physicalSlots[cell / 8].value(cell % 8, -1);
    selectDirectory(index, "detail", target == physical ? "row" : "", target == physical ? 8 : 1);
    if (!frame.isEmpty()) {
        frame["mode"] = "detail";
    }
}
