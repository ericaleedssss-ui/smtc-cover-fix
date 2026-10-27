"""G63: make 4k-song queue responsive by sending a bounded page and keeping
a stable ListModel; polish spectral contour and reaction/marquee spacing.
Runs strictly after G62 without weakening previous regression checks.
"""
from pathlib import Path

def edit(path, old, new):
    p=Path(path)
    s=p.read_text(encoding="utf-8")
    count=s.count(old)
    if count!=1:
        raise RuntimeError(f"G63 anchor mismatch {path}: {count} of {old[:100]!r}")
    p.write_text(s.replace(old,new,1),encoding="utf-8")

# Root cause of the 4,080-song jank: G62 exposes the *entire* queue in
# NativeHud::state(), a frequently refreshed property, including every
# metadata field. ListView treated each new huge array as a fresh model.
# Send at most 40 lightweight visible rows; QtQuick retains a stable model
# and updates it only when this page's content actually changes.
edit("Qt/src/NativeHud.cpp",
    '''            {"queueRows", modal == "player" ? m_music->player.queue : QJsonArray{}},''',
    '''            {"queueRows", [this] {
                QJsonArray visible;
                if (modal != "player") { return visible; }
                const auto &all = m_music->player.queue;
                const int first = std::clamp(queueOffset, 0, std::max(0, int(all.size()) - 40));
                const int end = std::min(int(all.size()), first + 40);
                for (int i = first; i < end; ++i) {
                    const auto song = all.at(i).toObject();
                    visible.append(QJsonObject{
                        {"index", i}, {"id", song.value("id")},
                        {"title", song.value("title")},
                        {"artist", song.value("artist")}
                    });
                }
                return visible;
            }()},
            {"queueOffset", std::clamp(queueOffset, 0, std::max(0, int(m_music->player.queue.size()) - 40))},
            {"queuePageSize", 40},''')
edit("Qt/src/NativeHudController.cpp",
    '''        queueOffset = std::clamp(queueOffset + (name == "queue-page-next" ? 10 : -10),
                                 0, std::max(0, int(player.queue.size()) - 10));''',
    '''        queueOffset = std::clamp(queueOffset + (name == "queue-page-next" ? 40 : -40),
                                 0, std::max(0, int(player.queue.size()) - 40));''')

# Protect the visibly faded end of long titles from colliding with the heart
# button's 40px hitbox. The social cluster still keeps a fixed relative gap.
edit("Qt/src/NativeHudPlayer.cpp",
    '    const double reactionX = infoX + infoWidth + 8;  // fixed close to album metadata',
    '    const double reactionX = infoX + infoWidth + 24;  // clear the title fade and hover region')

# Keep existing 1.27 second InOutCubic easing. A subtle teal to periwinkle
# to orchid to warm coral ribbon differentiates the transient sweep from
# the permanent green playback rail, without turning the chrome neon.
edit("Qt/qml/Main.qml",
    '''            for (var pass = 0; pass < 2; ++pass) {''',
    '''            var spectrum = [[99, 191, 217], [141, 158, 229],
                            [197, 144, 217], [232, 163, 161]];
            for (var pass = 0; pass < 2; ++pass) {''')
edit("Qt/qml/Main.qml",
    '''                    ctx.strokeStyle = pass === 0
                        ? "rgba(158,198,142," + (fade * .18 * (.38 + .62 * f1)) + ")"
                        : "rgba(101,155,93," + (fade * .94 * (.19 + .81 * f1 * f1)) + ")";''',
    '''                    var step = Math.min(2, Math.floor(f1 * 3));
                    var blend = Math.min(1, f1 * 3 - step);
                    var a = spectrum[step], b = spectrum[step + 1];
                    var red = Math.round(a[0] + (b[0] - a[0]) * blend);
                    var green = Math.round(a[1] + (b[1] - a[1]) * blend);
                    var blue = Math.round(a[2] + (b[2] - a[2]) * blend);
                    var opacity = pass === 0
                        ? fade * .22 * (.38 + .62 * f1)
                        : fade * .94 * (.19 + .81 * f1 * f1);
                    ctx.strokeStyle = "rgba(" + red + "," + green + "," + blue + "," + opacity + ")";''')

# Offline regression: simulate a 4,080-track playlist and ensure the
# exposed model never scales with full library size, including last-page
# navigation. Restore live player/queue state before continuing other tests.
edit("Qt/tests/UiChecks.cpp",
    '    check(hud.modal.isEmpty(), "close modal");',
    '''    check(hud.modal.isEmpty(), "close modal");

    {
        const auto savedQueue = player.queue;
        const auto savedModal = hud.modal;
        const auto savedOffset = hud.queueOffset;
        QJsonArray hugeQueue;
        for (int i = 0; i < 4080; ++i) {
            hugeQueue.append(QJsonObject{
                {"id", QString::number(i + 1)},
                {"title", QStringLiteral("测试队列歌曲")},
                {"artist", QStringLiteral("测试歌手")},
            });
        }
        player.queue = hugeQueue;
        hud.modal = "player";
        hud.queueOffset = 0;
        const auto first = hud.state();
        check(first.value("queueCount").toInt() == 4080 &&
              first.value("queueRows").toArray().size() == 40,
              "4080-song queue exports only 40 lightweight visible rows");
        hud.queueOffset = 4040;
        const auto last = hud.state().value("queueRows").toArray();
        check(last.size() == 40 && last.first().toObject().value("index").toInt() == 4040,
              "large queue end-page indexing remains exact");
        player.queue = savedQueue;
        hud.queueOffset = savedOffset;
        hud.modal = savedModal;
    }''')

# G62 copies this versioned, reviewable QML module before G63 runs.
qml=Path("Qt/qml/PlayerQueueGlass.qml").read_text(encoding="utf-8")
assert "ListModel { id: stableQueueRows }" in qml
assert "model: stableQueueRows" in qml
assert "if (signature === syncedRows) return;" in qml
assert 'onClicked: rhine.action("player:queue-page-next")' in qml
assert 'objectName: "playerQueueEdgeFade"' in qml
cpp=Path("Qt/src/NativeHud.cpp").read_text(encoding="utf-8")
assert 'first + 40' in cpp and 'player.queue : QJsonArray{}' not in cpp
assert 'queueOffset", std::clamp(queueOffset' in cpp
hud=Path("Qt/src/NativeHudPlayer.cpp").read_text(encoding="utf-8")
assert "const double reactionX = infoX + infoWidth + 24;" in hud
main=Path("Qt/qml/Main.qml").read_text(encoding="utf-8")
assert 'duration: 1270' in main and 'Easing.InOutCubic' in main
assert 'var spectrum = [[99, 191, 217]' in main
print("G63: bounded 40-row queue snapshots, stable QML model, page browsing, separated socials, spectral curved trail.")
