"""Add accurate, once-per-playback NetEase listening reports to the G53 source tree.

This deliberately does not turn local Rhine play-history into remote scrobbles.
A song is submitted only after a genuine duration of active playback, and an
attempt cannot be repeated automatically when the network response is unclear.
"""
from pathlib import Path

def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    content = file.read_text(encoding="utf-8")
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one anchor; found {count}: {old[:110]!r}")
    file.write_text(content.replace(old, new, 1), encoding="utf-8")

replace_once(
    "Qt/src/MusicPlayer.h",
    '#include "LyricsController.h"\n',
    '#include "LyricsController.h"\n#include <QElapsedTimer>\n',
)
replace_once(
    "Qt/src/MusicPlayer.h",
    '    std::function<void()> onEnd;\n',
    '''    std::function<void()> onEnd;
    // Supplied by the owning music library, so anonymous/other-provider plays
    // are never reported and account changes are detected per song.
    std::function<QString()> scrobbleAccountId;
    QString scrobbleStatus = "idle";
''',
)
replace_once(
    "Qt/src/MusicPlayer.h",
    '    int m_recoveryAttempts = 0;\n',
    '''    int m_recoveryAttempts = 0;
    QElapsedTimer m_scrobbleClock;
    double m_scrobbleSeconds = 0;
    QString m_scrobbleAccount;
    bool m_scrobbleAttempted = false;
    void updateScrobble(const QJsonObject &previousState);
''',
)
replace_once(
    "Qt/src/MusicLibrary.cpp",
    '    connect(&player, &MusicPlayer::trackSelected, this, &MusicLibrary::followPlayback);\n',
    '''    connect(&player, &MusicPlayer::trackSelected, this, &MusicLibrary::followPlayback);
    player.scrobbleAccountId = [this] {
        return provider == "netease" && api.provider == "netease" ? uid : QString();
    };
''',
)
replace_once(
    "Qt/src/MusicPlayer.cpp",
    '    const auto generation = ++m_generation;\n    m_resumePosition.reset();\n',
    '''    const auto generation = ++m_generation;
    // A manual replay or a new song starts a new, independent listening session.
    // Resuming after a temporary media failure does not reset this counter.
    m_scrobbleClock.invalidate();
    m_scrobbleSeconds = 0;
    m_scrobbleAccount.clear();
    m_scrobbleAttempted = false;
    scrobbleStatus = "idle";
    m_resumePosition.reset();
''',
)
replace_once(
    "Qt/src/MusicPlayer.cpp",
    '    lyrics.sync(state["position"].toDouble());\n',
    '''    updateScrobble(previous);
    lyrics.sync(state["position"].toDouble());
''',
)
replace_once(
    "Qt/src/MusicPlayer.cpp",
    '    m_host->mediaControl("stop");\n    m_host->mediaMetadata({}, {}, {});\n',
    '''    m_host->mediaControl("stop");
    m_scrobbleClock.invalidate();
    m_scrobbleSeconds = 0;
    m_scrobbleAccount.clear();
    m_scrobbleAttempted = false;
    scrobbleStatus = "idle";
    m_host->mediaMetadata({}, {}, {});
''',
)
# No direct cookie access here: all requests go through the existing private
# music bridge, which already scopes credentials and validates API responses.
cpp=Path("Qt/src/MusicPlayer.cpp")
text=cpp.read_text(encoding="utf-8")
before="void MusicPlayer::toggle() {"
if text.count(before)!=1:
    raise RuntimeError("MusicPlayer::toggle anchor changed")
method=r'''// Count *real elapsed playback*, never the seekable progress bar's position.
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
        current["provider"].toString("netease") != "netease" || current["kind"] != "song" ||
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

'''
text=text.replace(before,method+before,1)
cpp.write_text(text,encoding="utf-8")

worker="MusicBridge/worker.cjs"
replace_once(
    worker,
    "const routes = Object.freeze({",
    "const routes = Object.freeze({\n    '/scrobble': 'scrobble',",
)
print("Enabled session-scoped NetEase scrobble: monotonic playback, account binding, single attempt.")
