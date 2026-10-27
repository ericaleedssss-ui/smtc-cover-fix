"""G57: bounded private FM session, genuine radio feedback and playback bar.

Runs after G56 scrobble is applied. Anchored edits fail loudly if base drifts.
"""
from pathlib import Path
def edit(path, old, new):
    p=Path(path); s=p.read_text(encoding="utf-8"); n=s.count(old)
    if n != 1: raise RuntimeError(f"{path}: anchor occurs {n} times: {old[:90]!r}")
    p.write_text(s.replace(old,new,1),encoding="utf-8")

edit("Qt/src/MusicPlayer.h", "    void clearUpcoming();\n", """    void clearUpcoming();
    void startRoam(QString uid, MusicApi::Valid accountValid);
    void leaveRoam(bool restorePrevious = true);
    void dislikeRoam();
    void retryRoam();
    bool roamActive = false;
    bool roamLoading = false;
    QString roamStatus;
""")
edit("Qt/src/MusicPlayer.h", "    void trackSelected(QJsonObject track);\n", """    void trackSelected(QJsonObject track);
    void roamSongStarted();
""")
edit("Qt/src/MusicPlayer.h", "    quint64 m_generation = 0;\n", """    quint64 m_generation = 0;
    quint64 m_roamGeneration = 0;
    QString m_roamUid;
    MusicApi::Valid m_roamAccountValid;
    QJsonArray m_roamSavedQueue;
    QJsonObject m_roamSavedCurrent;
    QString m_roamSavedMode;
    int m_roamSavedIndex = -1;
    double m_roamSavedPosition = 0;
    bool m_roamSavedPaused = false;
    bool m_roamInternalPlay = false;
    void fetchRoam();
""")
edit("Qt/src/MusicPlayer.cpp", '#include "MusicData.h"\n', '#include "MusicData.h"\n#include <QPointer>\n')
edit("Qt/src/MusicPlayer.cpp", '    if (source) {\n        QSet<QString> seen;', '''    if (roamActive && !m_roamInternalPlay) {
        // Choosing an unrelated song exits the radio without reinstating the
        // old queue; the newly selected track becomes the user's new context.
        leaveRoam(false);
    }
    if (source) {
        QSet<QString> seen;''')
# Intercept all next/prev/track-end commands, preventing FM from repeating a 2-song list.
edit("Qt/src/MusicPlayer.cpp", """void MusicPlayer::next(int direction, bool ended) {
    if (queue.isEmpty()) {""", """void MusicPlayer::next(int direction, bool ended) {
    if (roamActive) {
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
    if (queue.isEmpty()) {""")
edit("Qt/src/MusicPlayer.cpp", """void MusicPlayer::stop() {
    chorusSeconds = -1;""", """void MusicPlayer::stop() {
    if (roamActive) { leaveRoam(false); }
    chorusSeconds = -1;""")
# Insert methods before a stable function. G53 has these anchors.
p=Path("Qt/src/MusicPlayer.cpp"); s=p.read_text(encoding="utf-8")
anchor="void MusicPlayer::next(int direction, bool ended) {"
if s.count(anchor)!=1: raise RuntimeError("Missing MusicPlayer::next")
methods=r'''// Private FM is a session, never a materialized playlist. Previous listening
// context is saved, and each exhausted batch is refilled from NetEase's radio.
void MusicPlayer::startRoam(QString uid, MusicApi::Valid accountValid) {
    if (roamActive || uid.isEmpty() || m_api->provider != "netease" ||
        !accountValid || !accountValid()) {
        status = QStringLiteral("私人漫游需要登录网易云音乐");
        emit changed();
        return;
    }
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
                queue.append(track);
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
            } else {
                roamStatus.clear();
            }
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
    if (restorePrevious) {
        if (!previousSong.isEmpty() && m_api->provider == previousSong["provider"]) {
            m_roamInternalPlay = true;
            play(previousSong, previousQueue, previousIndex >= 0
                 ? std::optional<int>(previousIndex) : std::nullopt);
            m_roamInternalPlay = false;
            if (previousPosition > 0) {
                m_resumePosition = previousPosition;
                m_resumePaused = previousPaused;
            } else if (previousPaused) {
                setPaused(true);
            }
        } else {
            queue = previousQueue;
            current = previousSong;
            index = previousIndex;
        }
    }
    emit changed();
}

'''
s=s.replace(anchor,methods+anchor,1);p.write_text(s,encoding="utf-8")
# The bridge's explicit endpoint whitelist must include the negative-feedback route.
edit("MusicBridge/worker.cjs", "const routes = Object.freeze({",
     "const routes = Object.freeze({\n    '/fm_trash': 'fm_trash',")
print("G57 private FM session: independent queue, on-demand recommendations, distinct dislike feedback and return.")
