"""G60: fetch per-song red-heart and comment counts immediately on track selection.
Also correct the LiquidGlass stadium SDF clamp and keep the FM controls readable.
Runs only after the confirmed G59 patch chain.
"""
from pathlib import Path
def edit(path, before, after):
    p=Path(path); text=p.read_text(encoding="utf-8")
    n=text.count(before)
    if n!=1: raise RuntimeError(f"G60 anchor {path}: {n} matches: {before[:95]!r}")
    p.write_text(text.replace(before, after, 1), encoding="utf-8")

# Root cause of the repeated stadium->rounded-rectangle regression:
# the shader *itself* clamped the corner radius to 25% of panel height,
# regardless of the 50% radius requested by the playback glass.
edit("Qt/shaders/liquidGlass.frag",
     "float radius=min(cornerRadius,min(panelSize.x,panelSize.y)*.25);",
     "float radius=min(cornerRadius,min(panelSize.x,panelSize.y)*.5);")

# The authorized bridge's red-heart endpoint differs from /like:
# /like is a personal user action; /song/red/count gives public aggregate
# likes, and the endpoint is independently fetched for every played song.
edit("MusicBridge/worker.cjs",
     "    '/fm_trash': 'fm_trash',",
     "    '/fm_trash': 'fm_trash',\n    '/song/red/count': 'song_red_count',")
edit("MusicBridge/worker.cjs",
     "    if (message.route === '/song/chorus') {",
     '''    if (message.route === '/song/red/count') {
        const id = String(message.params?.id || '');
        if (!/^[0-9]{1,20}$/.test(id)) {
            return { body: { code: 400, message: '歌曲编号无效' }, cookies: [] };
        }
        const cookie = Object.entries(message.cookies || {})
            .filter(([key, value]) => /^[A-Za-z0-9_]+$/.test(key) &&
                !key.startsWith('__') && key !== 'qqmusic_session' && typeof value === 'string')
            .map(([key, value]) => `${key}=${encodeURIComponent(value)}`).join('; ');
        const response = await axios.get('https://music.163.com/api/song/red/count', {
            params: { songId: id },
            timeout: 15000,
            headers: {
                Referer: 'https://music.163.com/',
                'User-Agent': 'Mozilla/5.0',
                ...(cookie ? { Cookie: cookie } : {}),
            },
        });
        return { body: response.data, cookies: [] };
    }
    if (message.route === '/song/chorus') {''')

# Independent of whether the full comment panel has ever been opened.
edit("Qt/src/NativeHud.h",
     '    double commentsTotal = 0;',
     '''    double commentsTotal = 0;
    double socialRedCount = -1;
    double socialCommentCount = -1;
    bool socialRedLoading = false;
    bool socialCommentLoading = false;
    QString m_socialSongID;
    quint64 m_socialGeneration = 0;
    void loadSocialCounts(QJsonObject song);''')

# A player trackSelected signal fires during prepare() for *every* playback,
# including radio and playlist tracks, not just when opening song details.
edit("Qt/src/NativeHudController.cpp",
     '    connect(music, &MusicLibrary::invalidated, this, &NativeHud::finishPage);',
     '''    connect(music, &MusicLibrary::invalidated, this, &NativeHud::finishPage);
    connect(&music->player, &MusicPlayer::trackSelected, this,
            [this](const QJsonObject &song) { loadSocialCounts(song); });''')

# Preserve the full comment-page pagination and featured-comment requests.
# The count lookup is a separate light read (limit: 1), so changing songs
# doesn't prefetch dozens of comments.
p=Path("Qt/src/NativeHudController.cpp")
text=p.read_text(encoding="utf-8")
marker="void NativeHud::openModal(QString kind) {"
assert text.count(marker)==1
methods=r'''void NativeHud::loadSocialCounts(QJsonObject song) {
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

'''
p.write_text(text.replace(marker,methods+marker,1),encoding="utf-8")

# A personal like/unlike request can change the aggregate count. Refresh that
# same song after the backend has had time to accept the mutation. Changing
# accounts/songs before the timer completes cancels the refresh safely.
edit("Qt/src/NativeHudMusic.cpp",
     '        music.like(name == "like" ? QJsonObject() : music.player.current);',
     '''        const auto target = name == "like" ? QJsonObject() : music.player.current;
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
        }''')

# HUD always carries the two totals for validation; -1 means not known, not
# "zero likes". The bottom player owns its own always-present placeholders.
edit("Qt/src/NativeHud.cpp",
     '            {"commentsTotal", commentsTotal},',
     '''            {"commentsTotal", commentsTotal},
            {"socialRedCount", socialRedCount}, {"socialCommentCount", socialCommentCount},
            {"socialRedLoading", socialRedLoading}, {"socialCommentLoading", socialCommentLoading},
            {"socialSongID", m_socialSongID},''')

# Assertions require both endpoints and the track-change callback; a merely
# static count displayed after opening comments will fail these checks.
source=Path("Qt/src/NativeHudController.cpp").read_text(encoding="utf-8")
assert 'MusicPlayer::trackSelected' in source
assert 'm_music->api.request("/song/red/count"' in source
assert 'm_music->api.request("/comment/music"' in source
assert 'm_socialGeneration == token' in source
shader=Path("Qt/shaders/liquidGlass.frag").read_text(encoding="utf-8")
assert 'min(panelSize.x,panelSize.y)*.5' in shader
player=Path("Qt/src/NativeHudPlayer.cpp").read_text(encoding="utf-8")
assert 'socialRedCount' in player and 'socialCommentCount' in player
print("G60: fetch aggregate hearts/comments at song start with stale-response guards; true 50% shader stadium.")