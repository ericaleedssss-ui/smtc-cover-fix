#include "NativeHud.h"
#include "MusicData.h"
#include <algorithm>

void NativeHud::playerBar(double, double y, double width) {
    const auto &player = m_music->player;
    const auto first = hits.size();
    const double center = width / 2;
    const double cy = y + 45;
    const QJsonArray accent = dark ? QJsonArray{.72,.78,.65,1} : QJsonArray{.45,.50,.39,1};
    const QJsonArray light{.98,.97,.94,1};
    auto textInk = ink();
    auto subtle = ink(); subtle[3] = .36;
    // G59: LiquidGlass QML is the ONLY physical panel. Previous versions
    // painted a second native capsule on top, producing doubled corners and
    // a visible rectangular/dark lower layer. Transport icons stay native.
    // The glass material and edge highlight are owned by glassPlayerBar.

    const double duration = player.state["duration"].toDouble();
    const double position = duration > 0 ? std::clamp(player.state["position"].toDouble() / duration, 0., 1.) : 0;
    // A single inset track, rendered by the QML seek control. No duplicate
    // native line and no accidental clipping at the top of the capsule.
    // The top straight edge of the 78px glass stadium spans x=71..width-71.
    // Slider is centered on y=990, exactly where the glass boundary sits.
    playerSeekRect = QRectF(71, y - 4, width - 142, 20);

    const double coverX = 45, coverY = cy - 29;
    // The actual artwork is QML-masked as a circular album disc. Rendering
    // a native square underneath would leave its four corners uncovered.

    // Fixed-width title viewport: short and long tracks use IDENTICAL
    // layout coordinates; overflow is handled by PlayerTitleMarquee only.
    auto title = player.failed ? player.status : player.current.value("title").toString();
    if (title.isEmpty() && !player.failed) { title = QStringLiteral("尚未播放"); }
    const double infoX = 119.;
    const double infoWidth = 167.;  // fixed marquee viewport for EVERY song
    // The QML ping-pong marquee owns title pixels; native click hits remain.
    auto artist = player.current.value("artist").toString();
    if (artist.isEmpty()) { artist = "RHINE LAB / MUSIC DATABASE"; }
    centeredText(fit(artist, 14, infoWidth), infoX, cy + 14, 14);
    if (!player.current.isEmpty()) {
        hit(coverX, coverY, 60, 60, "player:song-lyrics", "歌曲歌词");
        hit(infoX, cy - 26, infoWidth, 26, "player:song-detail", "歌曲详情");
        // Restore each actual artist's own clickable destination. A generic
        // lyric hit over the artist line would silently break G53 navigation.
        const auto artists = player.current.value("artists").toArray();
        double ax = infoX;
        for (int i = 0; i < artists.size() && ax < infoX + infoWidth; ++i) {
            const auto name = artists.at(i).toObject().value("name").toString();
            if (name.isEmpty()) { continue; }
            const double remaining = infoX + infoWidth - ax;
            const double artistWidth = std::min(m_glyphs->width(name, 14), remaining);
            hit(ax, cy + 1, artistWidth, 25, "player:song-artist:" + QString::number(i), name);
            ax += artistWidth + m_glyphs->width(" / ", 14);
        }
        if (artists.isEmpty()) {
            hit(infoX, cy + 1, infoWidth, 25, "player:song-lyrics", "查看歌词");
        }
    }

    const auto icon = [this, cy](double x, const QString &shape, QJsonArray color = {}) {
        save(); translate(x - 12, cy - 12);
        op({"path", shape, 1.85, color.isEmpty() ? ink() : color, QJsonArray{}, 0});
        restore();
    };
    const auto control = [this, cy](double x, const QString &action, const QString &tooltip) {
        hit(x - 20, cy - 22, 40, 44, action, tooltip);
    };

    // An always-available per-song social cluster. Count is global red hearts,
    // distinct from whether the signed-in listener liked the current song.
    const double reactionX = infoX + infoWidth + 24;  // clear the title fade and hover region
    const bool neteaseSong = player.current.value("kind") == "song" &&
        player.current.value("provider").toString("netease") == "netease";
    const bool showSocial = neteaseSong && reactionX + 142 < center - 172;
    const auto countText = [](double number, bool pending) {
        if (number < 0) { return pending ? QStringLiteral("···") : QStringLiteral("—"); }
        if (number >= 100000) { return QString::number(int(number / 10000)) + QStringLiteral("w+"); }
        if (number >= 10000) { return QString::number(number / 10000., 'f', 1) + QStringLiteral("w"); }
        return QString::number(qint64(number));
    };
    if (showSocial) {
        const bool liked = m_music->likedIDs &&
            MusicData::indexOf(*m_music->likedIDs, player.current["id"]) >= 0;
        if (!m_music->writeLoading && m_music->canMutate("/like")) {
            control(reactionX, "music:like-current", "喜欢 / 取消喜欢");
        }
        if(m_music->likedIDs||liked){
            const auto asset=m_host->resourceImage(liked?":/icons/song-like-on.png":":/icons/song-like-off.png");
            const auto size=QSizeF(m_host->image(asset).size()).scaled(QSizeF(24,24),Qt::KeepAspectRatio);
            image(asset,reactionX-size.width()/2,cy-size.height()/2,size.width(),size.height());
        }else centeredText("…",reactionX,cy,15);
        const auto redLabel = countText(socialRedCount, socialRedLoading);
        centeredText(redLabel, reactionX + 29, cy + 1, 10, "demibold");
        control(reactionX + 81, "player:comments", "打开当前歌曲评论");
        icon(reactionX + 81, "M 3 4 L 21 4 L 21 17 L 13 17 L 8 22 L 8 17 L 3 17 Z M 7 9 L 17 9 M 7 13 L 14 13");
        const auto commentLabel = countText(socialCommentCount, socialCommentLoading);
        centeredText(commentLabel, reactionX + 110, cy + 1, 10, "demibold");
    }

    const bool roaming = player.roamActive;
    if (roaming) {
        control(center - 144, "roam:exit", "退出漫游并恢复普通队列");
        icon(center - 144, "M 6 16 C 2 16 2 8 6 8 C 9 8 10 11 12 12 C 14 13 15 16 18 16 C 22 16 22 8 18 8 C 15 8 14 11 12 12 C 10 13 9 16 6 16 Z", accent);
    } else {
        static const QHash<QString, QString> modes{{"off","顺序"},{"all","循环"},{"one","单曲"},{"shuffle","随机"},{"heart","心动"}};
        control(center - 144, "player:mode", modes.value(player.mode, "播放模式"));
        if (player.mode == "heart") {
            icon(center - 144, "M 12 21 C 9 18 2 13 2 7 C 2 1 9 0 12 6 C 15 0 22 1 22 7 C 22 13 15 18 12 21 Z", accent);
        } else if(player.mode!="shuffle") {
            icon(center - 144, "M 4 8 C 4 5 6 4 9 4 L 21 4 M 17 0 L 21 4 L 17 8 M 20 16 C 20 19 18 20 15 20 L 3 20 M 7 16 L 3 20 L 7 24",
                 player.mode == "off" ? textInk : accent);
            if (player.mode == "one") { centeredText("1", center - 144, cy, 10, "demibold", true); }
        }
    }
    control(center - 72, "player:prev", "上一首");
    icon(center - 72, "M 5 3 L 5 21 M 19 3 L 8 12 L 19 21 Z");
    control(center + 72, "player:next", "下一首");
    icon(center + 72, "M 19 3 L 19 21 M 5 3 L 16 12 L 5 21 Z");
    save();alpha(detailFlightBarOpacity);
    op({"ellipse", QJsonArray{.45,.49,.38,1}, center - 29, cy - 29, 58, 58});
    hit(center - 30, cy - 30, 60, 60, "player:toggle", player.state["playing"].toBool() ? "暂停" : "播放");
    if (player.loading || (roaming && player.roamLoading)) {
        for (int i = -1; i <= 1; ++i) { op({"ellipse", light, center + i*9 - 2, cy - 2, 4, 4}); }
    } else if (player.state["playing"].toBool()) {
        fill(center - 8, cy - 10, 5, 20, light);
        fill(center + 3, cy - 10, 5, 20, light);
    } else {
        save(); translate(center, cy);
        op({"fill-path", "M -6 -11 L 13 0 L -6 11 Z", light}); restore();
    }
    restore();
    // Queue stays next to the main transport buttons, not at the far right.
    control(center + 144, "player:open", "右侧播放队列");
    icon(center + 144, "M 3 5 L 21 5 M 3 11 L 21 11 M 3 17 L 12 17 M 17 15 L 22 19 L 17 23 Z");
    if (roaming) {
        control(center + 208, "roam:dislike", "不喜欢：告诉网易云并跳到下一首");
        const auto asset=m_host->resourceImage(":/icons/song-like-off.png");
        const auto size=QSizeF(m_host->image(asset).size()).scaled(QSizeF(24,24),Qt::KeepAspectRatio);
        image(asset,center+208-size.width()/2,cy-size.height()/2,size.width(),size.height());
        save();translate(center+208-12,cy-12);op({"path","M 3 3 L 21 21",1.6,QJsonArray{.70,.42,.42,1},QJsonArray{},0});restore();
    }

    // No persistent timestamp under transport buttons. The hover seek
    // tooltip already supplies exact position and duration when needed.
    const double vx = width - 278;
    control(vx - 32, "player:mute", "静音 / 恢复");
    icon(vx - 32, "M 2 9 L 6 9 L 12 4 L 12 20 L 6 15 L 2 15 Z M 16 8 C 19 10 19 14 16 16 M 19 4 C 25 9 25 15 19 20");
    playerVolumeRect = QRectF(vx, cy - 22, 82, 44);
    fill(vx, cy - 1, 82, 2, subtle);
    const double volume = std::clamp(player.state["volume"].toDouble(), 0., 1.);
    fill(vx, cy - 1, 82 * volume, 2, accent);
    op({"ellipse", accent, vx + 82*volume - 4, cy - 4, 8, 8});
    control(width - 132, "desktop:toggle", "桌面歌词开关");
    icon(width - 132, "M 2 3 L 22 3 L 22 17 L 2 17 Z M 8 22 L 16 22 M 12 17 L 12 22 M 6 8 L 18 8 M 6 12 L 14 12",
         desktopLyricsEnabled ? accent : textInk);
    for (auto i = first; i < hits.size(); ++i) {
        auto value = hits.at(i).toObject(); value["fixed"] = true; hits[i] = value;
    }
}

void NativeHud::playerPanel(double x, double y, double width) {
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
