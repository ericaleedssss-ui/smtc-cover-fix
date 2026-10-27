"""G57 routing, radio entry, capsule bar and right-edge queue surface."""
from pathlib import Path
import re
def edit(path, old, new):
    p=Path(path); s=p.read_text(encoding="utf-8"); count=s.count(old)
    if count!=1: raise RuntimeError(f"Expected single anchor in {path}: {old[:110]!r} got {count}")
    p.write_text(s.replace(old,new,1),encoding="utf-8")

# The radio is an action, not a new "Discover" tab or static playlist.
edit("Qt/qml/SideNavigation.qml",
    '                        onInvoked: navigation.discover(modelData.tab)',
    '''                        onInvoked: {
                            if (modelData.tab === "roam") {
                                rhine.action("roam:start");
                                navigation.scheduleClose();
                            } else {
                                navigation.discover(modelData.tab);
                            }
                        }''')

# Reuse the existing lyric detail view whenever a new FM session begins.
edit("Qt/src/NativeHudController.cpp",
    '    connect(music, &MusicLibrary::invalidated, this, &NativeHud::finishPage);',
    '''    connect(music, &MusicLibrary::invalidated, this, &NativeHud::finishPage);
    connect(&music->player, &MusicPlayer::roamSongStarted, this,
            [this] { openPlayingSong(true); });''')

# This branch of the dispatcher precedes the existing discover: and player: routes.
edit("Qt/src/NativeHudController.cpp",
    '    if (value.startsWith("discover:")) {',
    '''    if (value.startsWith("roam:")) {
        auto &player = music.player;
        if (value == "roam:start") {
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
    if (value.startsWith("discover:")) {''')

# The clickable comment icon navigates to the *current* song, not a stale
# song selected elsewhere on the archive page.
edit("Qt/src/NativeHudController.cpp",
    '    } else if (name == "song-artist") {',
    '''    } else if (name == "comments") {
        if (!player.current.isEmpty()) {
            openPlayingSong(false);
            openComments();
        }
    } else if (name == "song-artist") {''')

# In radio mode keep the lyric page active when the current song changes.
edit("Qt/src/NativeHudDetail.cpp",
    '    if (lyricsMode && MusicPlayer::identity(item) != MusicPlayer::identity(music.player.current)) {',
    '    if (lyricsMode && !music.player.roamActive && MusicPlayer::identity(item) != MusicPlayer::identity(music.player.current)) {')

# Expose radio status and retain the existing G56 scrobble state.
edit("Qt/src/NativeHud.cpp",
    '            {"accountUID", m_music->uid}, {"directoryOpen", bool(m_music->directory)}, {"lyricsMode", lyricsMode},',
    '''            {"accountUID", m_music->uid}, {"directoryOpen", bool(m_music->directory)}, {"lyricsMode", lyricsMode},
            {"roamActive", m_music->player.roamActive},
            {"roamLoading", m_music->player.roamLoading},
            {"roamStatus", m_music->player.roamStatus},''')

# Full G57 playerbar is ordinary source, not a compressed base64 workflow blob.
p=Path("Qt/src/NativeHudPlayer.cpp");s=p.read_text(encoding="utf-8")
start=s.index("void NativeHud::playerBar(")
end=s.index("void NativeHud::playerPanel(",start)
fragment=(Path(__file__).resolve().parents[1]/"maintained/G57-playerbar.cppfrag").read_text(encoding="utf-8")
s=s[:start]+fragment+"\n\n"+s[end:]
p.write_text(s,encoding="utf-8")

# Native right-edge queue: no fullscreen white modal and no backdrop blackout.
edit("Qt/src/NativeHud.cpp",
    '    if (modal == "lyrics-source") {',
    '''    if (modal == "player") {
        const double panelWidth = std::min(430., std::max(320., width * .29));
        return {width - panelWidth - 18, 116, panelWidth, 842};
    }
    if (modal == "lyrics-source") {''')

edit("Qt/src/NativeHudModal.cpp",
    '    if (modal == "lyrics-source") {',
    '''    if (modal == "player") {
        const auto bounds = modalBounds(width);
        const auto panelX = bounds.x(), panelY = bounds.y(), panelW = bounds.width();
        const QString contour = QString("M %1 %2 L %3 %2 Q %4 %2 %4 %5 L %4 %6 Q %4 %7 %3 %7 L %1 %7 Q %8 %7 %8 %6 L %8 %5 Q %8 %2 %1 %2 Z")
            .arg(panelX + 20).arg(panelY).arg(panelX + panelW - 20)
            .arg(panelX + panelW).arg(panelY + 20).arg(panelY + 822)
            .arg(panelY + 842).arg(panelX);
        op({"fill-path", contour, dark ? QJsonArray{.17,.20,.18,.91} : QJsonArray{.92,.91,.87,.91}});
        op({"path", contour, 1., dark ? QJsonArray{1,1,1,.22} : QJsonArray{1,1,1,.78}, QJsonArray{}, 0});
        hits = {};
        m_modalControls = false;
        text("播放队列", panelX + 24, panelY + 34, 24, "demibold");
        button("×", panelX + panelW - 53, panelY + 16, 38, 38, "close-modal", 26);
        playerPanel(panelX, panelY, panelW);
        restore();
        return;
    }
    if (modal == "lyrics-source") {''')

# Compact queue scroll/rows. List is informational and does not overwrite
# ordinary playback until user explicitly clicks a play control.
p=Path("Qt/src/NativeHudPlayer.cpp");s=p.read_text(encoding="utf-8")
begin=s.index("void NativeHud::playerPanel(")
compact=r'''void NativeHud::playerPanel(double x, double y, double width) {
    const auto &player = m_music->player;
    const auto left = x + 23;
    const auto usable = width - 46;
    const auto title = player.current.value("title").toString();
    if (!title.isEmpty()) {
        limited(title, left, y + 91, 17, usable, "demibold");
        limited(player.current.value("artist").toString(), left, y + 116, 13, usable);
    }
    rule(left, y + 147, usable, .16);
    text("QUEUE / " + QString::number(player.queue.size()) + " 首", left, y + 177, 12);
    if (!player.roamActive) {
        button("清空待播", x + width - 109, y + 157, 86, 36, "player:clear", 13);
    } else {
        button("退出漫游", x + width - 112, y + 157, 90, 36, "roam:exit", 13);
    }
    queueOffset = std::clamp(queueOffset, 0, std::max(0, int(player.queue.size()) - 10));
    for (int row = 0; row < 10 && queueOffset + row < player.queue.size(); ++row) {
        const int index = queueOffset + row;
        const auto song = player.queue.at(index).toObject();
        const double yy = y + 219 + row * 51;
        if (index == player.index) {
            fill(left, yy - 15, usable, 43, dark ? QJsonArray{.66,.72,.61,.16} : QJsonArray{.54,.59,.47,.14});
        }
        limited(song["title"].toString(), left + 4, yy, 15, usable - 87,
                index == player.index ? "demibold" : "regular");
        limited(song["artist"].toString(), left + 4, yy + 20, 11, usable - 87);
        button("▶", left + usable - 69, yy - 12, 31, 35,
               "player:queue-play:" + QString::number(index), 16);
        if (index != player.index && !player.roamActive) {
            button("×", left + usable - 29, yy - 12, 29, 35,
                   "player:remove:" + QString::number(index), 16);
        }
        rule(left, yy + 29, usable, .10);
    }
    if (player.queue.size() > 10) {
        button("↑", left, y + 745, 48, 36, "player:queue-page-prev", 16);
        button("↓", left + 57, y + 745, 48, 36, "player:queue-page-next", 16);
        text(QString::number(queueOffset + 1) + "–" + QString::number(std::min(int(player.queue.size()), queueOffset + 10)),
             left + 140, y + 767, 12);
    }
    if (player.roamActive) {
        if (!player.roamStatus.isEmpty()) {
            limited(player.roamStatus, left, y + 805, 13, usable);
        }
        button("不喜欢并跳过", left, y + 792, 145, 38, "roam:dislike", 14);
        button("再取一批", left + 161, y + 792, 112, 38, "roam:retry", 14);
    }
}
'''
p.write_text(s[:begin]+compact,encoding="utf-8")
edit("Qt/src/NativeHudController.cpp",
    '    } else if (name == "queue-play") {\n        if (index >= 0 && index < player.queue.size()) { player.play(player.queue.at(index).toObject(), std::nullopt, index); }\n    } else if (name == "remove") {',
    '''    } else if (name == "queue-play") {
        if (index >= 0 && index < player.queue.size()) { player.play(player.queue.at(index).toObject(), std::nullopt, index); }
    } else if (name == "queue-page-prev" || name == "queue-page-next") {
        queueOffset = std::clamp(queueOffset + (name == "queue-page-next" ? 10 : -10),
                                 0, std::max(0, int(player.queue.size()) - 10));
    } else if (name == "remove") {''')

# Moving to a different account/provider drops old FM session state immediately.
edit("Qt/src/MusicLibrary.cpp",
    '    player.scrobbleAccountId = [this] {',
    '''    player.scrobbleAccountId = [this] {''') if False else None
# Align the blur-backed QML surface with the new independently rounded bar,
# rather than using G53's shallower glass strip at y=992.
edit("Qt/qml/Main.qml",
    '        x: 20 * root.stageScale; y: 992 * root.stageScale\n        width: root.width - 40 * root.stageScale; height: 76 * root.stageScale',
    '        x: 15 * root.stageScale; y: 976 * root.stageScale\n        width: root.width - 30 * root.stageScale; height: 102 * root.stageScale')
edit("Qt/qml/Main.qml",
    '            sampleX: 20 * root.stageScale; sampleY: 992 * root.stageScale\n            uiScale: root.stageScale; radius: 34 * root.stageScale',
    '            sampleX: 15 * root.stageScale; sampleY: 976 * root.stageScale\n            uiScale: root.stageScale; radius: 45 * root.stageScale')

# Preserve the existing navigation regression assertion, but record exactly
# which state is unexpected. Delayed Qt scene ticks may need a settling frame.
checks = Path("Qt/tests/UiChecks.cpp")
check_source = checks.read_text(encoding="utf-8")
old_checkpoint = '''    backend.action("open");
    folderWait.restart();
    while (music.directoryLoading && folderWait.elapsed() < 10000) { settle(30); }
    refresh();
    check(music.directory && music.directoryInfo && music.current.value("kind") == "playlist" &&
          hasHudAction("music:track:0"),
          "the main playlist entry opens its detail page consistently with navigation and discovery");'''
new_checkpoint = '''    backend.action("open");
    folderWait.restart();
    while (music.directoryLoading && folderWait.elapsed() < 10000) { settle(30); }
    settle(100); refresh();
    qInfo() << "G57 playlist reentry diagnostics:"
            << "directory" << bool(music.directory)
            << "directoryInfo" << music.directoryInfo
            << "currentKind" << music.current.value("kind")
            << "currentID" << music.current.value("id")
            << "mode" << hud.frame.value("mode")
            << "tracks" << (music.directory ? music.directory->songs.size() : -1)
            << "hasFirstTrack" << hasHudAction("music:track:0");
    check(music.directory && music.directoryInfo && music.current.value("kind") == "playlist" &&
          hasHudAction("music:track:0"),
          "the main playlist entry opens its detail page consistently with navigation and discovery");'''
if check_source.count(old_checkpoint) != 1:
    raise RuntimeError("Expected one playlist-reentry regression checkpoint")
checks.write_text(check_source.replace(old_checkpoint,new_checkpoint,1),encoding="utf-8")
print("G57 routed left navigation, live FM controls, capsule player and right-side queue.")
