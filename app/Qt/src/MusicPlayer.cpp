#include "MusicPlayer.h"
#include "MusicData.h"
#include <QPointer>
#include <QFileInfo>
#include <QUrl>
#include <QJsonDocument>
#include <QDateTime>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <algorithm>
#include <cmath>

void MusicPlayer::hydrateQueue(const QList<int> &indices) {
    if (m_api->provider == "local") return;
    if (m_queueHydrationEpoch != m_host->epoch) {
        m_queueHydrationEpoch = m_host->epoch;
        m_queueHydrating.clear();
        m_queueHydrationRetry.clear();
    }
    if (m_queueHydrating.size() >= 96) return;
    QJsonArray ids;
    QSet<QString> keys;
    const auto now = QDateTime::currentMSecsSinceEpoch();
    for (const int at : indices) {
        if (at < 0 || at >= queue.size()) continue;
        const auto row = queue[at].toObject();
        const auto key = identity(row);
        if (!row["deferred"].toBool() || row["provider"].toString() != m_api->provider ||
            keys.contains(key) || m_queueHydrating.contains(key) || m_queueHydrationRetry.value(key) > now) continue;
        keys.insert(key); ids.append(row["id"]);
        if (ids.size() == 48 || m_queueHydrating.size() + keys.size() >= 96) break;
    }
    if (ids.isEmpty()) return;
    m_queueHydrating.unite(keys);
    QPointer<MusicPlayer> self(this);
    const auto epoch = m_host->epoch;
    const auto provider = m_api->provider;
    m_api->call("songs", {QJsonValue(ids)}, [self, keys, epoch, provider](MusicReply reply) {
        if (!self || self->m_host->epoch != epoch || self->m_api->provider != provider) return;
        for (const auto &key : keys) {
            self->m_queueHydrating.remove(key);
            self->m_queueHydrationRetry.insert(key, QDateTime::currentMSecsSinceEpoch() + 15000);
        }
        if (!reply.ok()) return;
        QHash<QString, QJsonObject> loaded;
        for (const auto &value : reply.value.toArray()) {
            const auto row = value.toObject();
            const auto key = identity(row);
            if (keys.contains(key) && !row["deferred"].toBool() && !row["title"].toString().isEmpty()) loaded.insert(key, row);
        }
        bool changed = false;
        for (int i = 0; i < self->queue.size(); ++i) {
            const auto old = self->queue[i].toObject();
            const auto key = identity(old);
            if (!old["deferred"].toBool() || !loaded.contains(key)) continue;
            auto row = loaded[key];
            if (old["queueSource"].isObject()) row["queueSource"] = old["queueSource"];
            self->queue.replace(i, row);
            self->m_queueHydrationRetry.remove(key);
            changed = true;
        }
        if (changed) emit self->changed();
    });
}

double MusicPlayer::chorusStart(const QJsonObject &reply, const QString &id) {
    auto rows = reply.value("chorus").toArray();
    if (rows.isEmpty()) { rows = reply.value("data").toArray(); }
    for (const auto &value : rows) {
        const auto row = value.toObject();
        const auto songId = row["id"].isString() ? row["id"].toString() : QString::number(row["id"].toDouble(), 'f', 0);
        const double start = row.value("startTime").toDouble(-1);
        const double end = row.value("endTime").toDouble(-1);
        if (songId == id && std::isfinite(start) && std::isfinite(end) && start > 0 && end > start && end <= 86400000) {
            return start / 1000.;
        }
    }
    return -1;
}

QString MusicPlayer::identity(const QJsonObject &track) {
    return track["provider"].toString("netease") + ":" + track["id"].toString();
}
bool MusicPlayer::isEpisode(const QJsonObject &track) {
    return track.value("programID").toVariant().toLongLong()>0 || track.value("programId").toVariant().toLongLong()>0 || track.value("queueSource").toObject().value("section")=="programs";
}
void MusicPlayer::setPodcastSpeed(double value) {
    if (!std::isfinite(value) || !QList<double>{.75,1,1.25,1.5,1.75,2}.contains(value)) return;
    podcastSpeed=value;
    m_host->setPreference("podcast-speed",QString::number(value));
    m_host->mediaControl("rate",isEpisode(current)?podcastSpeed:1);
    emit changed();
}

/** 本地音质近似分级 */
QString MusicPlayer::localQuality(const QJsonObject &track) {
    const auto name = QFileInfo(track["path"].toString()).completeBaseName().toLower();
    const auto format = track["format"].toString().toLower();
    const auto bitrateKbps = track["bitrate"].toInt();
    if (name.contains("jymaster") || name.contains("母带") || name.contains("[master]") ||
        name.contains("master quality")) {
        return "jymaster";
    }
    if (name.contains("全景声") || name.contains("沉浸") || name.contains("dolby atmos") ||
        name.contains("[atmos]") || name.contains("[sky]")) {
        return "sky";
    }
    if (name.contains("jyeffect") || name.contains("臻音")) {
        return "jyeffect";
    }
    const bool lossless =
        QStringList{"flac", "ape", "wav", "aif", "aiff", "alac", "wv", "dsf", "dff"}.contains(format) ||
        (format == "m4a" && bitrateKbps >= 700);
    if (lossless) {
        const bool highResolution = name.contains("hi-res") || name.contains("hires") ||
                                    name.contains("高解析") || name.contains("24bit") ||
                                    name.contains("24-bit") || track["sampleRate"].toInt() > 48000 ||
                                    bitrateKbps > 1600;
        return highResolution ? "hires" : "sq";
    }
    return bitrateKbps >= 192 || name.contains("320k") || name.contains("[hq]") ? "hq" : "standard";
}

/** 只识别本次可播放地址及其响应元数据；不读取偏好或歌曲可用音质列表。 */
QString MusicPlayer::sourceQuality(const QString &provider, const QJsonObject &audio, bool trial) {
    if (trial || audio["url"].toString().isEmpty()) {
        return {};
    }
    const auto url = QUrl(audio["url"].toString());
    const auto file = url.fileName().toUpper();
    auto format = audio["type"].toString().toLower();
    if (format.isEmpty()) {
        format = audio["extName"].toString().toLower();
    }
    if (format.isEmpty()) {
        format = QFileInfo(url.path()).suffix().toLower();
    }
    if (provider == "qq") {
        // 登录接口可能没有 quality；前缀是实际获准播放的媒体文件类型。
        if (file.startsWith("F000") || file.startsWith("A000")) {
            return "sq";
        }
        if (file.startsWith("M800")) {
            return "hq";
        }
        if (file.startsWith("M500") || file.startsWith("C400")) {
            return "standard";
        }
        return {};
    }
    const auto bitrate = audio["br"].toDouble();
    const bool lossy = format == "mp3" || format == "m4a" || format == "aac";
    if (lossy && bitrate > 0) {
        // 替代音源可能保留原等级；已返回的有损格式与码率优先于等级标签。
        return bitrate >= 192000 ? "hq" : "standard";
    }
    if (provider == "netease") {
        const auto level = audio["level"].toString();
        const QHash<QString, QString> levels{
            {"standard", "standard"}, {"higher", "hq"},         {"exhigh", "hq"}, {"lossless", "sq"},
            {"hires", "hires"},       {"jyeffect", "jyeffect"}, {"sky", "sky"},   {"jymaster", "jymaster"}};
        if (levels.contains(level)) {
            const auto resolved = levels.value(level);
            if (!lossy || resolved == "standard" || resolved == "hq") {
                return resolved;
            }
        }
    }
    const bool lossless = format == "flac" || format == "ape" || format == "alac";
    if (lossless) {
        // 无损码率高不能证明 Hi-Res；必须同时取得采样率与位深。
        if (audio["sampleRate"].toDouble() > 48000 && audio["bitDepth"].toInt() > 16) {
            return "hires";
        }
        return "sq";
    }
    return {};
}

QVector<QPair<QString, QString>> MusicPlayer::qualityOptions(const QString &provider) {
    if (provider == "qq") {
        return {{"best", "自动最高可用"},
                {"standard", "标准"},
                {"exhigh", "HQ 高品质"},
                {"lossless", "SQ 无损 / FLAC"},
                {"ape", "SQ 无损 / APE"}};
    }
    if (provider == "kugou") {
        return {{"standard", "标准"},
                {"exhigh", "HQ 高品音质"},
                {"lossless", "SQ 无损音质"},
                {"hires", "Hi-Res 高解析音质"}};
    }
    return {
        {"standard", "标准"},           {"higher", "较高"},      {"exhigh", "极高"}, {"lossless", "SQ 无损"},
        {"hires", "Hi-Res 高解析音质"}, {"jymaster", "超清母带"}};
}

/** 共享音质偏好；换源保留队列、歌词、播放位置和暂停意图，迟到响应由播放代数隔离。 */
void MusicPlayer::setQuality(const QString &value) {
    const auto options = qualityOptions(m_api->provider);
    const auto found = std::find_if(options.begin(), options.end(),
                                    [&value](const auto &option) { return option.first == value; });
    if (found == options.end() || quality == value) {
        return;
    }
    quality = value;
    m_recoveryAttempts = 0;
    m_host->setPreference("quality", value);
    if (current.isEmpty() || (loading && !m_resumePosition)) {
        emit changed();
        return;
    }
    if (!m_resumePosition) {
        m_resumePosition = state["position"].toDouble();
        m_resumePaused = !state["playing"].toBool();
    }
    const auto generation = ++m_generation;
    m_host->mediaControl("stop");
    actualQuality.clear();
    failed = false;
    trial = false;
    loading = true;
    status = QStringLiteral("正在切换音质…");
    emit changed();
    prepare(current, generation, true);
}

MusicPlayer::MusicPlayer(Host *host, MusicApi *api, QObject *parent)
    : QObject(parent), lyrics(host), m_host(host), m_api(api) {
    state = {{"playing", false}, {"position", 0}, {"duration", 0}, {"volume", 0.7}, {"seekable", false}};
    const auto speed=host->preference("podcast-speed").toDouble();
    if(QList<double>{.75,1,1.25,1.5,1.75,2}.contains(speed))podcastSpeed=speed;
    quality = host->preference("quality");
    if (!QStringList{"standard", "higher", "exhigh", "lossless", "hires", "jymaster", "best", "ape"}.contains(
            quality)) {
        quality = "exhigh";
    }
    localCovers = QJsonDocument::fromJson(host->preference("local-cover-cache").toUtf8()).object();
    alternative = host->preference("alternate-source") == "on";
    const auto saved = QJsonDocument::fromJson(host->preference("play-history").toUtf8()).array();
    const QRegularExpression identifier(QStringLiteral("^[a-zA-Z0-9_-]{1,80}$"));
    for (const auto &value : saved) {
        const auto track = value.toObject();
        if (track["kind"] == "song" && identifier.match(track["id"].toString()).hasMatch()) {
            history.append(track);
            if (history.size() == 200) {
                break;
            }
        }
    }
    connect(&lyrics, &LyricsController::changed, this, &MusicPlayer::changed);
    connect(&lyrics, &LyricsController::coverMatched, this, [this](QString key, QString url) {
        if (current["provider"] != "local" || LyricsController::trackKey(current) != key ||
            !current["cover"].toString().isEmpty()) {
            return;
        }
        const auto alive = valid(m_generation);
        m_host->loadCover(url, [this, alive, url](QString image) {
            if (alive() && !image.isEmpty()) {
                coverImage = image;
                m_host->setMediaArtwork(coverImage);
                current["cover"] = url;
                const auto key = current["id"].toString() + ':' + current["fingerprint"].toString();
                localCovers[key] = url;
                while (localCovers.size() > 200) {
                    localCovers.remove(localCovers.begin().key());
                }
                m_host->setPreference(
                    "local-cover-cache",
                    QString::fromUtf8(QJsonDocument(localCovers).toJson(QJsonDocument::Compact)));
                if (index >= 0 && index < queue.size()) {
                    queue.replace(index, current);
                }
                emit changed();
            }
        });
    });
}

MusicApi::Valid MusicPlayer::valid(quint64 generation) {
    return [owner = QPointer(this), generation] { return owner && owner->m_generation == generation; };
}

void MusicPlayer::cancelHeart() {
    ++m_heartGeneration;
    heartPending = false;
}

// Restore queue ownership without restarting the currently audible track.
void MusicPlayer::leaveHeart() {
    cancelHeart();
    if(m_heartHasContext){
        queue=m_heartSavedQueue;
        index=-1;
        // Prefer the exact original occurrence if an entry appears twice.
        if(m_heartSavedIndex>=0&&m_heartSavedIndex<queue.size()&&identity(queue.at(m_heartSavedIndex).toObject())==identity(current))index=m_heartSavedIndex;
        else for(int i=0;i<queue.size();++i)if(identity(queue.at(i).toObject())==identity(current)){index=i;break;}
        // A recommendation can be outside the original playlist. Keep playing
        // it, then resume after the seed without inserting it into the list.
        if(index<0)m_heartResumeIndex=m_heartSavedIndex;else m_heartResumeIndex.reset();
    }
    m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;
    mode="off";
    emit changed();
}

void MusicPlayer::startHeart(const QString &uid, MusicApi::Valid accountValid, bool advance) {
    cancelHeart();
    if (m_api->provider != "netease" || uid.isEmpty() || current.isEmpty() ||
        current.value("provider").toString("netease") != "netease") {
        if (mode == "shuffle") { mode = "off"; }
        status = QStringLiteral("心动模式需要登录网易云并播放一首网易云歌曲");
        emit changed();
        return;
    }
    heartPending = true;
    m_heartUid = uid;
    m_heartAccountValid = accountValid;
    const auto token = m_heartGeneration;
    const auto playback = m_generation;
    const auto seed = current;
    const auto alive = [owner = QPointer(this), token, playback, accountValid] {
        return owner && owner->m_heartGeneration == token && owner->m_generation == playback && accountValid();
    };
    const auto fail = [this, advance] {
        heartPending = false;
        // Failed refill preserves the context for an explicit exit or retry.
        if (!advance && mode == "shuffle") { mode = "off"; }
        status = QStringLiteral("暂时无法获取心动推荐，已保留播放队列");
        emit changed();
    };
    emit changed();
    m_api->request("/user/playlist", {{"uid", uid}, {"limit", 100}},
        [this, seed, alive, fail, advance](MusicReply reply) {
            if (!reply.ok()) { fail(); return; }
            QString playlist;
            for (const auto &value : reply.value.toObject()["playlist"].toArray()) {
                const auto item = value.toObject();
                if (item["specialType"].toInt() == 5) {
                    playlist = item["id"].isString() ? item["id"].toString() : QString::number(item["id"].toDouble(), 'f', 0);
                    break;
                }
            }
            if (playlist.isEmpty()) { fail(); return; }
            m_api->request("/playmode/intelligence/list", {{"id", seed["id"]}, {"sid", seed["id"]}, {"pid", playlist}, {"count", 30}},
                [this, seed, fail, advance](MusicReply result) {
                    if (!result.ok()) { fail(); return; }
                    QJsonArray replacement{seed};
                    QSet<QString> seen{identity(seed)};
                    for (const auto &value : result.value.toObject()["data"].toArray()) {
                        const auto raw = value.toObject()["songInfo"].toObject();
                        auto song = MusicData::parse(raw, "song");
                        if (raw.isEmpty() || song["id"].toString().isEmpty() || seen.contains(identity(song))) { continue; }
                        seen.insert(identity(song)); replacement.append(song);
                    }
                    if (replacement.size() < 2) { fail(); return; }
                    heartPending = false;
                    if(!m_heartHasContext){m_heartSavedQueue=queue;m_heartSavedIndex=m_heartResumeIndex.value_or(index);m_heartHasContext=true;}
                    m_heartResumeIndex.reset();
                    queue = replacement; index = 0; mode = "heart";
                    status = QStringLiteral("心动模式已开启");
                    emit changed();
                    if (advance) { next(); }
                }, alive);
        }, alive);
}

int MusicPlayer::enqueueMany(const QJsonArray &tracks) {
    if (roamActive) return 0;
    QSet<QString> seen;for(const auto &v:queue)seen.insert(identity(v.toObject()));
    int added=0;
    for(const auto &v:tracks){const auto s=v.toObject();const auto id=identity(s);
        if(s["kind"]!="song"||s["unavailable"].toBool()||(m_api->provider=="local")!=(s["provider"]=="local")||seen.contains(id))continue;
        queue.append(s);seen.insert(id);++added;
    }
    if(added)emit changed();return added;
}

void MusicPlayer::enqueue(const QJsonObject &track, bool next) {
    if (track["kind"] != "song" || (m_api->provider == "local") != (track["provider"] == "local")) {
        return;
    }
    for (qsizetype i = 0; i < queue.size(); ++i) {
        if (i != index && identity(queue.at(i).toObject()) == identity(track)) {
            if(m_heartResumeIndex&&i<=*m_heartResumeIndex)--*m_heartResumeIndex;
            queue.removeAt(i);
            if (i < index) {
                --index;
            }
            break;
        }
    }
    const int insertion=next?std::max(0,m_heartResumeIndex.value_or(index)+1):int(queue.size());
    queue.insert(insertion,track);
    emit changed();
}

/** 停止旧音源并推进代数，先完成元数据再交付播放；迟到的地址不能恢复旧曲目。 */
void MusicPlayer::play(QJsonObject track, std::optional<QJsonArray> source, std::optional<int> queueIndex,
                       bool preview) {
    if (track["kind"] != "song" || (m_api->provider == "local" && track["provider"] != "local") ||
        (m_api->provider != "local" && track["provider"] == "local")) {
        return;
    }
    if (roamActive && !m_roamInternalPlay) {
        // Choosing an unrelated song exits the radio without reinstating the
        // old queue; the newly selected track becomes the user's new context.
        leaveRoam(false);
    }
    if (heartPending) { cancelHeart(); }
    // Restoring a suspended radio context is not a new playlist selection.
    // Preserve duplicates, exact index, mode and the current song's own source.
    if (!m_restoringRoamContext) {
        if (source) {
            m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;m_heartResumeIndex.reset();
            cancelHeart();
            if (mode == "heart") { mode = "all"; }
            QSet<QString> seen;
            queue = {};
            for (const auto &value : *source) {
                const auto song = value.toObject();
                const auto key = identity(song);
                if (song["kind"] == "song" && !seen.contains(key)) {
                    seen.insert(key);
                    queue.append(song);
                }
            }
        }
        int selected = -1;
        for (qsizetype i = 0; i < queue.size(); ++i) {
            if (identity(queue.at(i).toObject()) == identity(track)) {
                selected = int(i);
                break;
            }
        }
        if (selected < 0) {
            selected = int(queue.size());
            queue.append(track);
        }
        if (!queueIndex && selected >= 0) { queue.replace(selected, track); }
        if (queueIndex && *queueIndex >= 0 && *queueIndex < queue.size()) {
            track.remove("queueSource");
            track = MusicData::withQueueSource(track, queue.at(*queueIndex).toObject().value("queueSource").toObject());
        }
        index = queueIndex.value_or(selected);
    }
    if(!m_restoringRoamContext)m_heartResumeIndex.reset();
    const auto generation = ++m_generation;
    // A manual replay or a new song starts a new, independent listening session.
    // Resuming after a temporary media failure does not reset this counter.
    m_scrobbleClock.invalidate();
    m_scrobbleSeconds = 0;
    m_scrobbleAccount.clear();
    m_scrobbleAttempted = false;
    scrobbleStatus = "idle";
    m_resumePosition.reset();
    m_recoveryAttempts = 0;
    previewRequested = preview && m_api->provider == "qq";
    m_host->mediaControl("stop");
    current = track;
    chorusSeconds = -1;
    if (m_api->provider == "netease" && track.value("provider").toString("netease") == "netease") {
        const auto id = track.value("id").toString();
        m_api->request("/song/chorus", {{"id", id}}, [this, id](MusicReply reply) {
            if (!reply.ok()) { return; }
            chorusSeconds = chorusStart(reply.value.toObject(), id);
            emit changed();
        }, valid(generation));
    }
    actualQuality.clear();
    lyrics.clear();
    coverImage.clear();
    m_host->setMediaArtwork({});
    loading = true;
    failed = false;
    trial = false;
    status = QStringLiteral("正在准备：") + track["title"].toString();
    emit changed();
    if (!track["deferred"].toBool()) {
        prepare(track, generation);
        return;
    }
    m_api->call(
        "songs", {QJsonValue(QJsonArray{track["id"]})},
        [this, generation](MusicReply result) {
            const auto songs = result.value.toArray();
            if (!result.ok() || songs.isEmpty()) {
                fail(result.ok() ? QStringLiteral("此曲目暂不可读取") : result.error);
                return;
            }
            const auto origin = current.value("queueSource");
            current = songs.first().toObject();
            if (origin.isObject()) { current["queueSource"] = origin; }
            if (index >= 0 && index < queue.size()) {
                queue.replace(index, current);
            }
            emit changed();
            prepare(current, generation);
        },
        valid(generation));
}

void MusicPlayer::prepare(QJsonObject track, quint64 generation, bool reload) {
    if (track["provider"] == "local") {
        const QUrl source(track["url"].toString());
        if (m_api->provider != "local" || !source.isLocalFile() ||
            !QFileInfo(source.toLocalFile()).isReadable()) {
            fail(QStringLiteral("本地文件无法访问，请检查文件位置或重新扫描"));
            return;
        }
    }
    if (track["provider"] == "local" && track["cover"].toString().isEmpty()) {
        const auto key = track["id"].toString() + ':' + track["fingerprint"].toString();
        if (localCovers.contains(key)) {
            track["cover"] = localCovers[key];
            current = track;
        }
    }
    if (!reload) {
        if (!track["cover"].toString().isEmpty()) {
            m_host->loadCover(track["cover"].toString(), [this, alive = valid(generation)](QString key) {
                if (!alive()) {
                    return;
                }
                coverImage = key;
                m_host->setMediaArtwork(coverImage);
                if (key.isEmpty() && current["provider"] == "local") {
                    current["cover"] = "";
                    const auto cacheKey = current["id"].toString() + ':' + current["fingerprint"].toString();
                    localCovers.remove(cacheKey);
                    m_host->setPreference(
                        "local-cover-cache",
                        QString::fromUtf8(QJsonDocument(localCovers).toJson(QJsonDocument::Compact)));
                    // 下一轮再补图，确保同步失败回调不会早于本次歌词初始化。
                    m_host->schedule(0, [this, alive] {
                        if (alive()) {
                            lyrics.matchCover(current);
                        }
                    });
                }
                emit changed();
            });
        }
        emit trackSelected(current);
        lyrics.load(current);
    }
    if (track["provider"] == "local") {
        const auto url = QUrl(track["url"].toString());
        if (m_api->provider != "local" || !url.isLocalFile() || !QFileInfo(url.toLocalFile()).isReadable()) {
            fail(QStringLiteral("本地文件无法访问，请检查文件位置或重新扫描"));
            return;
        }
        m_host->mediaMetadata(track["title"].toString(), track["artist"].toString(),
                              track["album"].toString());
        if (!m_host->mediaLoad(url.toString())) {
            fail(QStringLiteral("本地音频无法加载"));
            return;
        }
        m_host->mediaControl("rate",isEpisode(track)?podcastSpeed:1);
        m_endSerial = m_host->mediaState().value("ended").toLongLong();
        actualQuality = localQuality(track);
        status = QStringLiteral("正在播放本地文件：") + track["format"].toString();
        loading = false;
        emit changed();
        return;
    }
    // QQ 专有音质在其他平台转换为通用无损
    const auto qqQuality = quality == "best" || quality == "ape";
    auto effectiveQuality = qqQuality && m_api->provider != "qq" ? "lossless" : quality;

    // 网易云专有音质在其他平台转换为对应档位
    if (m_api->provider != "netease") {
        if (quality == "jymaster" || quality == "jyeffect" || quality == "sky") {
            effectiveQuality = "lossless";
        } else if (quality == "higher") {
            effectiveQuality = "standard";
        }
    }

    // 酷狗不支持 ape，转换为通用无损
    if (m_api->provider == "kugou" && quality == "ape") {
        effectiveQuality = "lossless";
    }

    m_api->call(
        previewRequested ? "preview" : "playback", {track, effectiveQuality, alternative},
        [this, track](MusicReply result) {
            if (!result.ok()) {
                fail(result.error);
                return;
            }
            const auto audio = result.value.toObject();
            const auto url = audio["url"].toString();
            if (url.isEmpty()) {
                fail(QStringLiteral("此歌曲暂无可用音源，请检查登录和歌曲权限"));
                return;
            }
            m_host->mediaMetadata(track["title"].toString(), track["artist"].toString(),
                                  track["album"].toString());
            if (!m_host->mediaLoad(url, m_api->provider == "netease" && alternative)) {
                fail(QStringLiteral("音频地址不可用"));
                return;
            }
            m_host->mediaControl("rate",isEpisode(track)?podcastSpeed:1);
            if (m_resumePosition && m_resumePaused) {
                m_host->mediaControl("pause");
            }
            m_endSerial = m_host->mediaState().value("ended").toLongLong();
            auto entry = track;
            entry["wiki"] = "";
            entry["description"] = "";
            QJsonArray recent{entry};
            for (const auto &value : history) {
                if (identity(value.toObject()) != identity(track) && recent.size() < 200) {
                    recent.append(value);
                }
            }
            history = recent;
            m_host->setPreference("play-history",
                                  QString::fromUtf8(QJsonDocument(history).toJson(QJsonDocument::Compact)));
            const auto preview = audio["freeTrialInfo"];
            trial = audio["preview"].toBool() || preview.isObject() || preview.isArray() ||
                    (preview.isString() && !preview.toString().isEmpty() && preview.toString() != "null") ||
                    (preview.isBool() && preview.toBool()) || (preview.isDouble() && preview.toDouble() != 0);
            actualQuality = sourceQuality(m_api->provider, audio, trial);
            status = trial ? QStringLiteral("当前音源为试听片段")
                           : QStringLiteral("正在播放：") + track["title"].toString();
            const QHash<QString, QString> qualities{{"128", "标准"}, {"320", "高品质"}, {"flac", "无损"}};
            if (!trial && qualities.contains(audio["quality"].toString())) {
                status += QStringLiteral("（") + qualities.value(audio["quality"].toString()) +
                          QStringLiteral("）");
            }
            if (!audio["qualityFallback"].toString().isEmpty()) {
                status += QStringLiteral("（已切换为") + audio["qualityFallback"].toString() +
                          QStringLiteral("音质）");
            }
            loading = false;
            emit changed();
        },
        valid(generation));
}

void MusicPlayer::fail(QString error) {
    m_resumePosition.reset();
    failed = true;
    actualQuality.clear();
    status = error;
    loading = false;
    emit changed();
}

/** 重新获取当前歌曲的地址并恢复位置 */
void MusicPlayer::recoverPlayback() {
    ++m_recoveryAttempts;
    const auto generation = ++m_generation;
    m_resumePosition = state["position"].toDouble();
    m_resumePaused = !state["requested"].toBool();
    loading = true;
    failed = false;
    actualQuality.clear();
    status = QStringLiteral("正在恢复播放（%1/2）…").arg(m_recoveryAttempts);
    m_host->mediaControl("stop");
    emit changed();
    prepare(current, generation, true);
}

void MusicPlayer::tick(double time, bool force) {
    if (!force && time - m_lastPoll < 0.1) {
        return;
    }
    m_lastPoll = time;
    const auto previous = state;
    const auto update = QJsonObject::fromVariantMap(m_host->mediaState());
    for (auto it = update.begin(); it != update.end(); ++it) {
        state[it.key()] = it.value();
    }
    if (m_resumePosition && !loading && state["seekable"].toBool()) {
        const auto position = std::clamp(*m_resumePosition, 0., state["duration"].toDouble());
        m_resumePosition.reset();
        m_host->mediaControl("seek", position);
        if (m_resumePaused) {
            m_host->mediaControl("pause");
        }
    }
    updateScrobble(previous);
    lyrics.sync(state["position"].toDouble());
    // 播放结束或错误状态只在播放中或加载完成后触发
    if (!current.isEmpty() && !loading && state.contains("ended") &&
        state["ended"].toInteger() != m_endSerial) {
        m_endSerial = state["ended"].toInteger();
        if (onEnd) {
            onEnd();
        } else {
            next(1, true);
        }
        return;
    }
    const auto playbackError = state["error"].toString();
    if (!loading && !current.isEmpty() && !playbackError.isEmpty() &&
        (!failed || !actualQuality.isEmpty() || status != playbackError)) {
        constexpr int maxRecoveryAttempts = 2;
        if (!failed && state["recoverable"].toBool() && m_recoveryAttempts < maxRecoveryAttempts &&
            current["provider"] != "local") {
            recoverPlayback();
            return;
        }
        fail(playbackError);
    } else if (state != previous) {
        emit changed();
    }
}

// Count *real elapsed playback*, never the seekable progress bar's position.
// Polling is monotonic. Pauses, buffering, failed streams, seek jumps and long
// system-sleep gaps do not silently manufacture playback seconds.
void MusicPlayer::updateScrobble(const QJsonObject &previousState) {
    if (!m_scrobbleClock.isValid()) {
        m_scrobbleClock.start();
        return;
    }
    const qint64 elapsedMs = m_scrobbleClock.restart();
    const QString uid = scrobbleAccountId ? scrobbleAccountId() : QString();
    if (uid != m_scrobbleAccount) {
        m_scrobbleAccount = uid;
        m_scrobbleSeconds = 0;
        m_scrobbleAttempted = false;
        scrobbleStatus = "idle";
        return;
    }
    if (m_scrobbleAttempted || uid.isEmpty() || m_api->provider != "netease" ||
        current.value("provider").toString("netease") != "netease" || current.value("kind") != "song" ||
        loading || failed || trial || !state["playing"].toBool() ||
        !previousState["playing"].toBool() || state["buffering"].toBool() ||
        !state["error"].toString().isEmpty() || elapsedMs < 1 || elapsedMs > 1500) {
        return;
    }

    // Seeking forward/backward does not grant extra listening time.
    const double positionChange = state["position"].toDouble() - previousState["position"].toDouble();
    if (positionChange < -300. || positionChange > std::max(2500., double(elapsedMs) * 3.)) {
        return;
    }
    const QString id = current["id"].toString();
    static const QRegularExpression numericId(QStringLiteral("^[0-9]{1,20}$"));
    if (!numericId.match(id).hasMatch()) {
        return;
    }

    m_scrobbleSeconds += double(elapsedMs) / 1000.;
    const double durationSecs = state["duration"].toDouble() / 1000.;
    const double threshold = durationSecs > 0
                                 ? std::min(30., std::max(10., durationSecs * .5))
                                 : 30.;
    if (m_scrobbleSeconds < threshold) {
        return;
    }
    m_scrobbleAttempted = true;
    scrobbleStatus = "sending";
    const auto generation = m_generation;
    const auto account = uid;
    const int seconds = int(std::floor(m_scrobbleSeconds));
    QPointer<MusicPlayer> owner(this);
    const auto liveAccount = [owner, generation, account] {
        return owner && owner->m_generation == generation &&
               owner->m_api->provider == "netease" &&
               owner->scrobbleAccountId && owner->scrobbleAccountId() == account;
    };
    m_api->request(
        "/scrobble", {{"id", id}, {"sourceid", id}, {"time", seconds}},
        [this](MusicReply reply) {
            // The classic module wraps both upstream responses with code=200.
            // Verify the *inner* startplay and play results as well.
            if (!reply.ok()) {
                scrobbleStatus = "failed";
            } else {
                const auto details = reply.value.toObject()["details"].toObject();
                const auto start = details["startplay"].toObject();
                const auto played = details["play"].toObject();
                scrobbleStatus = (start["code"].toInt(-1) == 200 &&
                                  played["code"].toInt(-1) == 200)
                                     ? "accepted-by-api" : "unconfirmed";
            }
            // Network failures are not retried blindly: scrobbles are
            // non-idempotent and an ambiguous timeout may mean success.
            emit changed();
        },
        liveAccount);
}

void MusicPlayer::toggle() {
    if (m_resumePosition) {
        setPaused(!m_resumePaused);
        return;
    }
    if (failed && !current.isEmpty()) {
        play(current, std::nullopt, index, previewRequested);
        return;
    }
    if (!loading && !current.isEmpty()) {
        setPaused(state["playing"].toBool());
    }
}

void MusicPlayer::setPaused(bool paused) {
    if (m_resumePosition) {
        m_resumePaused = paused;
    }
    m_host->mediaControl(paused ? "pause" : "resume");
}

void MusicPlayer::seek(double fraction) {
    if (m_resumePosition) {
        m_resumePosition = std::clamp(fraction, 0., 1.) * state["duration"].toDouble();
        emit seekRequested();
        return;
    }
    if (state["seekable"].toBool()) {
        emit seekRequested();
        m_host->mediaControl("seek", std::clamp(fraction, 0., 1.) * state["duration"].toDouble());
    }
}

void MusicPlayer::volume(double value) {
    const auto volume = std::clamp(value, 0., 1.);
    m_host->mediaControl("volume", volume);
    m_host->setPreference("volume", QString::number(volume));
}

// Private FM is a session, never a materialized playlist. Previous listening
// context is saved, and each exhausted batch is refilled from NetEase's radio.
void MusicPlayer::startRoam(QString uid, MusicApi::Valid accountValid) {
    if (roamActive || uid.isEmpty() || m_api->provider != "netease" ||
        !accountValid || !accountValid()) {
        status = QStringLiteral("私人漫游需要登录网易云音乐");
        emit changed();
        return;
    }
    cancelHeart();
    m_roamSavedHeartResumeIndex=m_heartResumeIndex;
    m_heartResumeIndex.reset();
    m_roamSavedQueue = queue;
    m_roamSavedCurrent = current;
    m_roamSavedIndex = index;
    m_roamSavedMode = mode;
    m_roamSavedPosition = state["position"].toDouble();
    m_roamSavedPaused = !state["playing"].toBool();
    m_roamUid = uid;
    m_roamAccountValid = accountValid;
    ++m_roamGeneration;
    roamActive = true;
    roamLoading = false;
    roamStatus = QStringLiteral("正在获取私人漫游推荐…");
    queue = {};
    index = -1;
    mode = "off";
    emit changed();
    fetchRoam();
}

void MusicPlayer::fetchRoam() {
    if (!roamActive || roamLoading) { return; }
    if (m_api->provider != "netease" || !m_roamAccountValid ||
        !m_roamAccountValid()) {
        leaveRoam(false);
        return;
    }
    roamLoading = true;
    roamStatus = QStringLiteral("正在获取下一批推荐…");
    emit changed();
    const auto token = m_roamGeneration;
    QPointer<MusicPlayer> owner(this);
    const auto alive = [owner, token] {
        return owner && owner->roamActive && owner->m_roamGeneration == token &&
               owner->m_api->provider == "netease" &&
               owner->m_roamAccountValid && owner->m_roamAccountValid();
    };
    m_api->request("/personal/fm/mode", {{"mode", "DEFAULT"}, {"limit", 3}},
        [this](MusicReply reply) {
            roamLoading = false;
            if (!reply.ok()) {
                roamStatus = reply.error;
                emit changed();
                return;
            }
            const auto payload = reply.value.toObject();
            const auto rows = payload["data"].toArray();
            const auto originalCount = queue.size();
            for (const auto &value : rows) {
                const auto track = MusicData::parse(value.toObject(), "song");
                if (track.value("kind") != "song" || track.value("id").toString().isEmpty()) {
                    continue;
                }
                if (MusicData::indexOfId(queue, track["id"].toString()) >= 0) {
                    continue;
                }
                // Only admit one new station pick per feedback cycle. A larger
                // response is a server candidate batch, NOT an immutable playlist.
                queue.append(track);
                break;
            }
            if (queue.size() == originalCount) {
                roamStatus = QStringLiteral("暂无新推荐，可以点击下一首重试");
                emit changed();
                return;
            }
            roamStatus.clear();
            const auto nextIndex = index + 1;
            if (nextIndex >= 0 && nextIndex < queue.size()) {
                m_roamInternalPlay = true;
                play(queue.at(nextIndex).toObject(), std::nullopt, nextIndex);
                m_roamInternalPlay = false;
                emit roamSongStarted();
            }
        }, alive);
}

void MusicPlayer::retryRoam() {
    if (roamActive && !roamLoading) { fetchRoam(); }
}

void MusicPlayer::dislikeRoam() {
    if (!roamActive || roamLoading || current["kind"] != "song" ||
        current["provider"].toString("netease") != "netease") { return; }
    const QString id = current["id"].toString();
    const quint64 token = m_roamGeneration;
    const quint64 playback = m_generation;
    QPointer<MusicPlayer> owner(this);
    const auto alive = [owner, token, playback] {
        return owner && owner->roamActive && owner->m_roamGeneration == token &&
               owner->m_generation == playback && owner->m_roamAccountValid &&
               owner->m_roamAccountValid();
    };
    roamLoading = true;  // prevent duplicate dislikes while request is in flight
    roamStatus = QStringLiteral("正在提交不喜欢反馈…");
    emit changed();
    m_api->request("/fm_trash", {{"id", id}, {"time", 25}},
        [this](MusicReply response) {
            roamLoading = false;
            if (!response.ok()) {
                roamStatus = QStringLiteral("不喜欢反馈未确认：") + response.error;
                emit changed();
                return;
            } else {
                roamStatus.clear();
            }
            // After a dislike, throw away prefetched successors. Let the
            // service's new feedback inform the next request.
            while (queue.size() > index + 1) { queue.removeLast(); }
            // An ordinary skip NEVER calls /fm_trash.
            next(1);
        }, alive);
}

void MusicPlayer::leaveRoam(bool restorePrevious) {
    if (!roamActive) { return; }
    ++m_roamGeneration;
    roamActive = false;
    roamLoading = false;
    roamStatus.clear();
    const auto previousHeartResumeIndex=m_roamSavedHeartResumeIndex;
    m_roamSavedHeartResumeIndex.reset();
    const auto previousQueue = m_roamSavedQueue;
    const auto previousSong = m_roamSavedCurrent;
    const auto previousMode = m_roamSavedMode;
    const auto previousIndex = m_roamSavedIndex;
    const auto previousPosition = m_roamSavedPosition;
    const auto previousPaused = m_roamSavedPaused;
    m_roamSavedQueue = {};
    m_roamSavedCurrent = {};
    m_roamUid.clear();
    m_roamAccountValid = {};
    mode = previousMode.isEmpty() ? "all" : previousMode;
    if(!restorePrevious){
        m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;m_heartResumeIndex.reset();
        if(mode=="heart")mode="off";
    }
    if (restorePrevious) {
        queue = previousQueue;
        current = previousSong;
        index = previousIndex;
        if (!previousSong.isEmpty() && m_api->provider == previousSong["provider"].toString()) {
            m_roamInternalPlay = true;
            m_restoringRoamContext = true;
            play(previousSong);
            m_restoringRoamContext = false;
            m_roamInternalPlay = false;
            m_heartResumeIndex=previousHeartResumeIndex;
            if (previousPosition > 0) {
                m_resumePosition = previousPosition;
                m_resumePaused = previousPaused;
            } else if (previousPaused) {
                setPaused(true);
            }
        } else {
            // Returning to an empty/incompatible ordinary session must also
            // stop the FM audio and invalidate its pending media preparation.
            stop();
            queue = previousQueue;
            current = previousSong;
            index = previousIndex;
            mode = previousMode.isEmpty() ? "all" : previousMode;
        }
    }
    emit changed();
}

void MusicPlayer::next(int direction, bool ended) {
    if (roamActive) {
        // Do not invalidate an in-flight feedback callback and strand loading.
        if (roamLoading) { return; }
        if (direction < 0) {
            if (index > 0) {
                m_roamInternalPlay = true;
                play(queue.at(index - 1).toObject(), std::nullopt, index - 1);
                m_roamInternalPlay = false;
            }
            return;
        }
        if (index + 1 < queue.size()) {
            m_roamInternalPlay = true;
            play(queue.at(index + 1).toObject(), std::nullopt, index + 1);
            m_roamInternalPlay = false;
        } else {
            fetchRoam();
        }
        return;
    }
    if (queue.isEmpty()) {
        return;
    }
    if(m_heartResumeIndex){
        if(ended&&mode=="one"){m_host->mediaControl("seek",0);m_host->mediaControl("resume");return;}
        int target=*m_heartResumeIndex+direction;
        if(shuffled())target=QRandomGenerator::global()->bounded(int(queue.size()));
        if(target>=queue.size()&&mode=="off"){
            status=QStringLiteral("队列已播放完");emit changed();return;
        }
        target=((target%queue.size())+queue.size())%queue.size();
        m_heartResumeIndex.reset();
        play(queue.at(target).toObject(),std::nullopt,target);return;
    }
    if (direction > 0 && mode == "heart" && index + 1 >= queue.size()) {
        if (!heartPending) { startHeart(m_heartUid, m_heartAccountValid, true); }
        return;
    }
    if (ended && mode == "one") {
        play(current, std::nullopt, index);
        return;
    }
    auto selected = index + direction;
    if (shuffled() && queue.size() > 1) {
        selected = (index + 1 + QRandomGenerator::global()->bounded(int(queue.size() - 1))) % queue.size();
    }
    if (selected >= queue.size() && mode == "off") {
        status = QStringLiteral("队列已播放完");
        emit changed();
        return;
    }
    selected = ((selected % queue.size()) + queue.size()) % queue.size();
    play(queue.at(selected).toObject(), std::nullopt, selected);
}

void MusicPlayer::remove(int selected) {
    if (selected < 0 || selected >= queue.size() || selected == index) {
        return;
    }
    if(m_heartResumeIndex&&selected<=*m_heartResumeIndex)--*m_heartResumeIndex;
    queue.removeAt(selected);
    if (selected < index) {
        --index;
    }
    emit changed();
}

void MusicPlayer::clearUpcoming() {
    m_heartResumeIndex.reset();
    queue = current.isEmpty() ? QJsonArray{} : QJsonArray{current};
    index = current.isEmpty() ? -1 : 0;
    emit changed();
}

/** 停止播放并作废音源与歌词请求；保留音量和历史等可恢复偏好。 */
void MusicPlayer::stop() {
    m_heartSavedQueue={};m_heartHasContext=false;m_heartSavedIndex=-1;m_heartResumeIndex.reset();
    if (roamActive) { leaveRoam(false); }
    chorusSeconds = -1;
    cancelHeart();
    if (mode == "heart") { mode = "all"; }
    ++m_generation;
    m_resumePosition.reset();
    m_recoveryAttempts = 0;
    lyrics.clear();
    loading = false;
    failed = false;
    status.clear();
    actualQuality.clear();
    coverImage.clear();
    m_host->setMediaArtwork({});
    current = {};
    queue = {};
    index = -1;
    m_host->mediaControl("stop");
    m_scrobbleClock.invalidate();
    m_scrobbleSeconds = 0;
    m_scrobbleAccount.clear();
    m_scrobbleAttempted = false;
    scrobbleStatus = "idle";
    m_host->mediaMetadata({}, {}, {});
    state["playing"] = false;
    state["position"] = 0;
    state["duration"] = 0;
    emit changed();
}
