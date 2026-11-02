#include "NativeHud.h"
#include "MusicData.h"
#include <QUrl>
#include <QDateTime>
#include <algorithm>
#include <cmath>

QString NativeHud::body() const {
    const auto item = m_music->current;
    if (m_music->isLocal()) {
        return item["path"].toString() + "\n" + item["format"].toString() + " / " +
               QString::number(item["sampleRate"].toInt()) + " Hz / " +
               QString::number(item["bitrate"].toInt()) + " kbps";
    }
    if (item.isEmpty()) {
        return {};
    }
    if (item["kind"] == "song") {
        if (tab == "overview") {
            const auto wiki = item["wiki"].toString();
            if (!wiki.isEmpty()) {
                return wiki;
            }
            return m_music->detailLoading ? "正在读取歌曲百科…" : "暂无歌曲百科";
        }
        auto date = item["date"].toString();
        auto description = item["description"].toString();
        if (date.isEmpty()) {
            date = "暂无";
        }
        if (description.isEmpty()) {
            description = "暂无专辑介绍";
        }
        return "专辑：" + item["album"].toString() + "\n歌手：" + item["artist"].toString() + "\n发行日期：" +
               date + "\n" + description;
    }
    if (tab == "overview") {
        const auto description = item["description"].toString();
        return description.isEmpty() ? "暂无简介" : description;
    }
    return "编号：" + item["id"].toString() + "\n名称：" + item["title"].toString() + "\n" +
           item["artist"].toString() + "\n已载入 " + QString::number(m_music->tracks.size()) + " 首";
}

void NativeHud::detail(double width, double opacity) {
    auto &music = *m_music;
    const auto item = music.current;
    if (item.isEmpty()) {
        archive(width);
        return;
    }
    if (item["kind"] != "song") {
        container(width, opacity);
        return;
    }
    const auto x = width * 0.56;
    if (lyricsMode && !music.player.roamActive && MusicPlayer::identity(item) != MusicPlayer::identity(music.player.current)) {
        lyricsMode = false;
    }
    const auto usable = width - x - 59;
    constexpr double gap = 12;
    const auto buttonWidth = (usable - gap * 2) / 3;
    save();
    alpha(opacity);
    if (!lyricsMode) {
        const auto bounds = detailBounds(width);
        fill(bounds.x(), bounds.y(), bounds.width(), bounds.height(),
             dark ? QJsonArray{0.08, 0.095, 0.09, 0.96} : QJsonArray{0.929, 0.922, 0.894, 0.96});
    }

    text("MUSIC DATABASE", 64, 819, 9, "demibold", 1.4);
    limited(item["id"].toString(), 64, 838, 32, 322);
    text("DRAG TO INSPECT", 64, 883, 9, "regular", .6);
    button("查看封面 ↗", 64, 913, 260, 26, "viewer", 15);
    if (lyricsMode) {
        lyricsPanel(x, usable);
        restore();
        return;
    }
    text("SONG ID / " + item["id"].toString(), x, 278, 14);
    const auto &player = music.player;
    const bool isCurrent = MusicPlayer::identity(item) == MusicPlayer::identity(player.current) &&
                           !player.loading && !player.failed;
    auto quality = isCurrent ? player.actualQuality : QString();
    if (music.isLocal()) {
        quality = MusicPlayer::localQuality(item);
    }
    const auto badgeProvider = music.isLocal() ? QStringLiteral("netease") : music.provider;
    const auto badgeKey = "quality:" + badgeProvider + "-" + quality;
    const auto badge = quality.isEmpty() ? QImage() : m_host->image(badgeKey);
    double badgeWidth = 0;
    if (!quality.isEmpty()) {
        if (!music.isLocal()) {
            hit(width * 0.927 - 55, 300, 110, 48, "quality:open", "音质说明与切换");
        }
        if (!badge.isNull()) {
            constexpr double badgeHeight = 25;
            badgeWidth = badgeHeight * badge.width() / badge.height();
            const auto badgeX = width * 0.927 - badgeWidth / 2;
            if (music.provider == "kugou") {
                fill(badgeX - 8, 307, badgeWidth + 16, badgeHeight + 10, {0.30, 0.33, 0.26, 1});
            }
            image(badgeKey, badgeX, 312, badgeWidth, badgeHeight);
        } else {
            // 平台没有独立图标的普通档位用文字说明，不伪造官方徽标。
            const auto label = quality == "standard" ? QStringLiteral("标准") : QStringLiteral("高品质");
            badgeWidth = 56;
            text(label, width * 0.927 - badgeWidth / 2, 312, 14, "demibold");
        }
    }
    const auto titleWidth = badgeWidth > 0 ? width * 0.927 - badgeWidth / 2 - x - 24 : usable;
    const auto titleLines = m_glyphs->wrap(item["title"].toString(), titleWidth, 32);
    for (int index = 0; index < std::min(2, int(titleLines.size())); ++index) {
        auto line = titleLines.at(index);
        if (index == 1 && titleLines.size() > 2) {
            line += "…";
        }
        limited(line, x, 305 + index * 40, 32, titleWidth, "bold");
    }
    const bool inlineComments = music.provider == "netease";
    const double artistY = inlineComments && titleLines.size() <= 1 ? 362 : 394;
    const double actionY = inlineComments ? artistY + 42 : 436;
    const double playY = inlineComments ? actionY + 56 : 498;
    const double infoY = inlineComments ? playY + 66 : 565;
    const double tabY = inlineComments ? infoY + 60 : 720;
    const double bodyY = tabY + 70;
    const auto artists = item["artists"].toArray();
    if (artists.isEmpty()) {
        limited(item["artist"].toString(), x, artistY, 19, usable, "demibold");
    } else {
        double artistX = x;
        for (int index = 0; index < artists.size() && artistX < x + usable - 20; ++index) {
            if (index > 0) {
                if (x + usable - artistX < m_glyphs->width(" / ", 19, "demibold") + 20) { break; }
                text(" / ", artistX, artistY, 19, "demibold");
                artistX += m_glyphs->width(" / ", 19, "demibold");
            }
            const auto available = x + usable - artistX;
            const auto name = artists.at(index).toObject().value("name").toString();
            if (available < 20 || name.isEmpty()) { break; }
            link(name, artistX, artistY, 19, available, "music:artist:" + QString::number(index), "demibold");
            artistX += std::min(available, m_glyphs->width(name, 19, "demibold"));
        }
    }
    if (music.canMutate("/like")) {
        bool liked = (music.likedIDs && MusicData::indexOf(*music.likedIDs, item["id"]) >= 0) ||
                     MusicData::indexOfId(music.lists[1], item["id"].toString()) >= 0;
        QString label = liked ? "♥ 已喜欢" : "♡ 喜欢";
        if (music.provider == "qq") {
            const auto state = music.subscriptionStates.value(item["key"].toString(), "unknown");
            liked = state == "subscribed";
            label = liked ? "♥ 已喜欢" : "♡ 喜欢";
            if (state == "unknown") {
                label = "红心 / 核实后切换";
            }
        }
        actionButton(label, x, actionY, buttonWidth, "music:like");
        actionButton("加入歌单", x + buttonWidth + gap, actionY, buttonWidth, "music:add-to-playlist");
    }
    if (music.provider == "netease") {
        actionButton(sharedSong == MusicPlayer::identity(item) && QDateTime::currentMSecsSinceEpoch() < sharedUntil ? "已复制 ✓" : "分享",
                     x + (buttonWidth + gap) * 2, actionY, buttonWidth, "music:share");
    }
    actionButton("▶ 面板内播放", x, playY, buttonWidth, "music:play", true);
    actionButton("加入队列", x + buttonWidth + gap, playY, buttonWidth, "music:play-next");
    if (const auto playlist = music.editablePlaylistContext()) {
        const bool contained = music.playlistContains(*playlist, item);
        actionButton(music.writeLoading ? "正在同步…" : contained ? "从歌单移除" : "加入此歌单",
                     x + (buttonWidth + gap) * 2, playY, buttonWidth,
                     contained ? "music:remove-track" : "music:add-current-playlist");
    } else if (music.canMutate("/playlist/tracks")) {
        actionButton("加入歌单", x + (buttonWidth + gap) * 2, playY, buttonWidth, "music:add-to-playlist");
    }
    rule(x, infoY, usable, 0.4);
    if (inlineComments) {
        if (!item.value("albumID").toString().isEmpty()) {
            link("专辑：" + item["album"].toString(), x, infoY + 20, 15, usable - 170, "music:song-album");
        } else {
            limited("专辑：" + item["album"].toString(), x, infoY + 20, 15, usable - 170);
        }
        text("时长：" + MusicData::time(item), x + usable - 150, infoY + 20, 15);
    } else {
    const auto column = (usable - gap) / 2;
    const QVector<QPair<QString, QString>> meta{
        {"ARTIST / 歌手", item["artist"].toString()},
        {"ALBUM / 专辑", item["album"].toString()},
        {"DURATION / 时长", MusicData::time(item)},
        {"PLAYBACK / 播放方式", music.isLocal() ? "本地文件 / 面板内播放" : "面板内播放 / 官方入口"}};
    for (int index = 0; index < meta.size(); ++index) {
        const auto xx = x + (index % 2) * (column + gap);
        const auto yy = 584 + (index / 2) * 64;
        text(meta.at(index).first, xx, yy, 11);
        const auto value = meta.at(index).second;
        limited(value.isEmpty() ? "暂无" : value, xx, yy + 23, 16, column - 12);
    }
    }
    QStringList keys{"overview", "notes", "history"};
    QStringList labels{music.isLocal() ? "文件信息" : "歌曲百科", "专辑信息", "同专辑"};
    if (inlineComments) {
        keys = {"overview", "history", "comments", "recommendations"};
        labels = {"歌曲百科", "同专辑", "评论", "相似推荐"};
    }
    for (int index = 0; index < keys.size(); ++index) {
        const auto xx = x + index * usable / keys.size();
        button(labels.at(index), xx, tabY, usable / keys.size() - 12, 38, "tab:" + keys.at(index), 15);
        if (tab == keys.at(index)) {
            rule(xx, tabY + 40, usable / keys.size() - 24, 1);
        }
    }
    rule(x, tabY + 42, usable, 0.2);
    if (inlineComments && tab == "comments") {
        commentsBounds = QRectF(x, bodyY, usable, std::max(1.0, 895 - bodyY));
    } else if (inlineComments && tab == "recommendations") {
        recommendationsBounds = QRectF(x, bodyY, usable, std::max(1.0, 880 - bodyY));
    } else if (tab == "history") {
        detailRows = std::max(1, int((880 - bodyY) / 48));
        detailRowsBounds = QRectF(x, bodyY - 4, usable, detailRows * 48);
        trackOffset = std::clamp(trackOffset, 0, std::max(0, int(music.tracks.size()) - detailRows));
        const auto songs = MusicData::slice(music.tracks, trackOffset, detailRows);
        for (int index = 0; index < songs.size(); ++index) {
            const auto song = songs.at(index).toObject();
            const auto yy = bodyY + index * 48;
            text(MusicData::pad(trackOffset + index + 1), x, yy, 11);
            limited(song["title"].toString() + " / " + song["artist"].toString(), x + 35, yy, 16,
                    usable - 115);
            text(MusicData::time(song), x + usable - 65, yy, 14);
            rule(x, yy + 36, usable, dark ? 0.10 : 0.075);
            hit(x, yy - 4, usable, 42, "music:track:" + QString::number(trackOffset + index),
                song["title"].toString());
        }
        if (music.tracks.isEmpty()) {
            text(music.detailLoading ? "正在载入曲目…" : "暂无曲目信息", x, bodyY, 17);
        }
    } else {
        readerBounds = QRectF(x, bodyY, usable, std::max(1.0, 880 - bodyY));
        readerText = body();
        readerSession = item.value("key").toString() + ":" + item.value("id").toString() + ":" + tab;
        readerFont = 16;
        readerLeading = 31;
    }
    if (music.provider == "qq") {
        actionButton("试听片段", x + buttonWidth + gap, 910, buttonWidth, "music:preview");
    }
    restore();
}

/** 歌词换文档或宽度时排版；进度更新只采样原生曲线并绘制可见行。 */
void NativeHud::lyricsPanel(double x, double width) {
    lyricRows = {}; lyricBounds.reset();
    auto &player = m_music->player;
    auto &lyrics = player.lyrics;
    auto muted = ink();
    muted[3] = 0.45;
    limited(player.current.value("title").toString(), x, 278, 20, width - 85, "demibold");
    limited(player.current.value("artist").toString(), x, 310, 15, width - 85);
    button("关闭", x + width - 60, 278, 60, 40, "player:lyrics-close", 14);
    if (m_music->isLocal() && player.current.value("provider") == "local") {
        button("歌词来源 ⌃", x + width - 267, 914, 130, 32, "player:lyrics-sources", 15);
    }
    constexpr double top = 360;
    constexpr double bottom = 889;
    const auto document = lyrics.document();
    const auto lines = document["lines"].toArray();
    if (lines.isEmpty()) {
        save();
        clip(x, top, width, bottom - top);
        const auto plain = document["plainText"].toString();
        auto message = plain.isEmpty() ? lyrics.message : plain;
        if (message.isEmpty()) {
            message = "播放歌曲后显示歌词";
        }
        const auto size = plain.isEmpty() ? 24 : 27;
        const auto rows = m_glyphs->wrap(message, width - 24, size);
        m_lyricsPlainOffset = std::min(m_lyricsPlainOffset, std::max(0, int(rows.size()) - 9));
        for (int index = 0; index < std::min(9, int(rows.size()) - m_lyricsPlainOffset); ++index) {
            text(rows.at(m_lyricsPlainOffset + index), x, top + 55 + index * 48, size, "bold", 0, muted);
        }
        restore();
        if (lyrics.status == "error" || lyrics.status == "empty") {
            button("重新查找歌词 ↗", x, 909, 170, 36, "player:lyrics-retry", 14);
        }
        return;
    }
    constexpr double size = 34;
    if (m_lyricsDocument != document || m_lyricsWidth != width) {
        m_lyricsDocument = document;
        m_lyricsWidth = width;
        m_lyricsLayout.clear();
        double height = 0;
        for (const auto &value : lines) {
            const auto line = value.toObject();
            auto original = line["text"].toString();
            if (original.isEmpty()) {
                original = "•••";
            }
            const auto wrapped = m_glyphs->wrap(original, width - 145, size, "bold");
            const auto translation = line["translation"].toString();
            QStringList translated;
            if (!translation.isEmpty()) {
                translated = m_glyphs->wrap(translation, width - 145, 17);
            }
            m_lyricsLayout.append({height, wrapped, translated});
            height += std::max(1, int(wrapped.size())) * 47 + translated.size() * 26 + 32;
        }
        m_lyricsBrowse.reset();
        m_lyricsPlainOffset = 0;
        m_lyricsTarget.reset();
        m_lyricsCurve.reset();
        m_lyricsScroll = m_lyricsLayout.at(std::clamp(lyrics.index, 0, int(m_lyricsLayout.size()) - 1)).top;
    }
    const auto active = std::clamp(lyrics.index, 0, int(m_lyricsLayout.size()) - 1);
    const auto target = m_lyricsBrowse.value_or(m_lyricsLayout.at(active).top);
    const auto sample =
        m_lyricsCurve ? m_lyricsCurve->sample(lastTime) : std::array<double, 2>{m_lyricsScroll, 0};
    m_lyricsScroll = sample[0];
    if (!m_lyricsTarget || target != *m_lyricsTarget) {
        m_lyricsTarget = target;
        if (reduced) {
            m_lyricsScroll = target;
            m_lyricsCurve.reset();
        } else {
            m_lyricsCurve.emplace(sample[0], target, sample[1], lastTime, m_lyricsBrowse ? 0.18 : 0.42);
        }
    }
    constexpr double focusY = top + 155;
    const auto activeTime = lyrics.index >= 0 ? lines.at(active).toObject()["startMs"] : QJsonValue();
    lyricBounds = QRectF(x - 4, top, width + 8, bottom - top);
    int browsing = active;
    if (m_lyricsBrowse) {
        for (int i = 0; i < m_lyricsLayout.size(); ++i) {
            if (std::abs(m_lyricsLayout.at(i).top - *m_lyricsBrowse) < std::abs(m_lyricsLayout.at(browsing).top - *m_lyricsBrowse)) { browsing = i; }
        }
    }
    save();
    clip(x - 4, top, width + 8, bottom - top);
    for (int index = 0; index < lines.size(); ++index) {
        const auto line = lines.at(index).toObject();
        const auto &row = m_lyricsLayout.at(index);
        const auto y = focusY + row.top - m_lyricsScroll;
        const double height = row.text.size() * 47 + row.translation.size() * 26;
        if (y + height < top || y > bottom) {
            continue;
        }
        const bool isActive = lyrics.index >= 0 && line["startMs"] == activeTime;
        const bool focused = m_lyricsBrowse ? index == browsing : isActive;
        QStringList rendered = row.text;
        QStringList translated = row.translation;
        lyricRows.append(QJsonObject{{"index", index}, {"y", y - top}, {"original", rendered.join('\n')},
            {"translation", translated.join('\n')}, {"translationY", row.text.size() * 47}, {"focused", focused}});
        if (player.state["seekable"].toBool()) {
            if (m_lyricsBrowse && index == browsing) {
                const auto seconds = std::max(0, int((line["startMs"].toDouble() - document["offsetMs"].toDouble() - lyrics.offsetMs) / 1000));
                const auto label = QString("▶ %1:%2").arg(seconds / 60, 2, 10, QChar('0')).arg(seconds % 60, 2, 10, QChar('0'));
                button(label, x + width - 111, std::clamp(y + 10, top + 5, bottom - 35), 105, 30,
                       "player:lyric-line:" + QString::number(index), 15);
            }
            const auto hitY = std::max(top, y);
            const auto label = line["text"].toString();
            hit(x, hitY, width, std::max(0.0, std::min(bottom, y + height + 20) - hitY),
                "player:lyric-line:" + QString::number(index), label.isEmpty() ? "间奏" : label);
        }
    }
    restore();
    button("歌词提前 0.2s", x, 914, 132, 32, "player:lyrics-earlier", 15);
    button("歌词延后 0.2s", x + 142, 914, 132, 32, "player:lyrics-later", 15);
    QString offsetLabel = "未校准";
    if (lyrics.offsetMs != 0) {
        const auto direction = lyrics.offsetMs > 0 ? "已提前 " : "已延后 ";
        offsetLabel = QString(direction) + QString::number(std::abs(lyrics.offsetMs) / 1000, 'f', 1) + "s";
    }
    if (m_music->isLocal()) {
        const auto offsetWidth = std::max(0.0, width - 563);
        if (offsetWidth > 24) {
            text(fit(offsetLabel, 14, offsetWidth), x + 284, 922, 14, "regular", 0, muted);
        }
    } else {
        text(offsetLabel, x + 284, 922, 14, "regular", 0, muted);
    }
    button("回到当前句", x + width - 125, 914, 125, 32, "player:lyrics-follow", 15);
}

void NativeHud::container(double width, double opacity) {
    auto &music = *m_music;
    const auto item = music.current;
    if (music.directoryInfo && music.directory && (item["kind"] == "playlist" || item["kind"] == "album")) return;
    const auto layout = containerLayout(width);
    const auto left = layout.left;
    const auto sidebar = layout.sidebar;
    const auto x = layout.x;
    const auto usable = layout.width;
    const auto rowsY = layout.rowsY;
    const auto rowHeight = layout.rowHeight;
    const auto rowCount = layout.rowCount;
    const bool albums = item["kind"] == "artist" && artistTab == "albums";
    QJsonArray songs = music.tracks;
    if (albums) {
        songs = music.directory ? music.directory->albums : QJsonArray();
    } else if (music.directory) {
        songs = music.directory->songs;
    }
    const auto sx = left + 19;
    const auto sideWidth = sidebar - 38;
    const auto coverSize = std::min(220.0, sideWidth);
    trackOffset = std::min(trackOffset, std::max(0, int(songs.size()) - rowCount));
    save();
    alpha(opacity);
    const auto bounds = detailBounds(width);
    fill(bounds.x(), bounds.y(), bounds.width(), bounds.height(),
         dark ? QJsonArray{0.08, 0.095, 0.09, 1} : QJsonArray{0.929, 0.922, 0.894, 1});
    rule(x - 18, 278, 1, 0.12);
    const bool albumPage = item["kind"] == "album";

    QString collection = "PLAYLIST / 歌单";
    if (item["kind"] == "album") {
        collection = "ALBUM / 专辑";
    } else if (item["kind"] == "artist") {
        collection = "ARTIST / 歌手";
    }
    text(collection, sx, 325, 11);
    image(music.coverImage, sx, 355, coverSize, coverSize);
    limited(item["title"].toString(), sx, coverSize + 374, 20, sideWidth, "bold");
    limited(item["artist"].toString(), sx, coverSize + 410, 14, sideWidth);
    const QHash<QString, QString> prefixes{
        {"qq", "QQ MID / "}, {"kugou", "KUGOU ID / "}, {"netease", "NETEASE ID / "}};
    if (item["kind"] == "artist" && !item["userID"].toString().isEmpty()) {
        link("个人主页 ↗", sx, coverSize + 449, 15, sideWidth, "profile:open:" + item["userID"].toString());
    } else if (item["virtual"].toBool()) {
        text(music.providerName() + " / " + item["title"].toString(), sx, coverSize + 449, 11);
    } else {
        text(prefixes.value(music.provider) + item["id"].toString(), sx, coverSize + 449, 11);
    }
    const auto ids = music.directory ? music.directory->ids.size() : 0;
    text(QString::number(std::max({item["trackCount"].toInt(), int(ids), int(songs.size())})) +
             " TRACKS / 曲目",
         sx, coverSize + 479, 14);
    const auto date = item["date"].toString();
    limited(date.isEmpty() ? "" : "发行日期：" + date, sx, coverSize + 510, 14, sideWidth);
    const auto description = item["description"].toString();
    const double descriptionY = coverSize + 550;
    const double descriptionBottom = music.canEditPlaylist(item) ? 844 : 880;
    readerBounds = QRectF(sx, descriptionY, sideWidth, std::max(1.0, descriptionBottom - descriptionY));
    readerText = description.isEmpty() ? "暂无简介" : description;
    readerSession = item.value("key").toString() + ":" + item.value("id").toString() + ":intro";
    readerFont = 14;
    readerLeading = 25;
    if (music.canEditPlaylist(item)) {
        button("修改名称", sx, 866, sideWidth / 2, 30, "music:rename-playlist", 14);
        button("删除歌单", sx + sideWidth / 2, 866, sideWidth / 2, 30, "music:delete-playlist", 14);
    }
    const auto subscribeRoute =
        item["kind"] == "playlist" ? "/playlist/subscribe" : "/" + item["kind"].toString() + "/sub";
    if (!item["virtual"].toBool() && music.canMutate(subscribeRoute)) {
        QString label = "收藏 / 取消";
        if (music.provider == "qq") {
            const auto state = music.subscriptionStates.value(item["key"].toString(), "unknown");
            label = "收藏 / 核实";
            if (state == "subscribed") {
                label = "已收藏 / 取消";
            } else if (state == "not-subscribed") {
                label = "收藏";
            }
        }
        button(label, sx, 913, sideWidth / 2, 32, "music:subscribe", 14);
    }
    if (!music.isLocal() && !item["virtual"].toBool()) {
        button(music.providerName() + " ↗", sx + sideWidth / 2, 913, sideWidth / 2, 32, "music:source", 14);
    }
    limited(item["title"].toString(), x, 279, 30, usable - 155, "bold");
    const auto total = music.directory ? music.directory->ids.size() : music.trackIDs.size();
    const auto countLabel = albums ? QString::number(songs.size()) + " 张专辑" :
        QString::number(songs.size()) + " / " + QString::number(std::max({item["trackCount"].toInt(), int(total), int(songs.size())})) + " 首";
    text(countLabel, x + usable - 130, 289, 14);
    if (!albums) {
        fill(x, 339, 180, 44, {119.0 / 255, 123.0 / 255, 96.0 / 255, 1});
        hit(x, 339, 180, 44, "music:play-loaded", "播放全部");
        text("▶  播放全部", x + 22, 351, 16, "demibold", 0, {0.96, 0.95, 0.91, 1});
    }
    if (item["kind"] == "artist") {
        button("热门歌曲", x + 210, 345, 110, 32, "music:artist-tab:songs", 15);
        button("发行专辑", x + 335, 345, 110, 32, "music:artist-tab:albums", 15);
    }
    if (albumPage && music.provider == "netease") {
        button("曲目", x + 210, 345, 100, 32, "tab:overview", 15);
        button("评论", x + 325, 345, 100, 32, "tab:comments", 15);
        rule(x + (tab == "comments" ? 325 : 210), 382, 78, 0.7);
    }
    rule(x, 399, usable, 0.4);
    if (albumPage && music.provider == "netease" && tab == "comments") {
        commentsBounds = QRectF(x, 422, usable, 470);
        restore();
        return;
    }
    const auto titleX = x + 100;
    const auto artistX = x + usable * (albumPage ? 0.66 : 0.52);
    const auto albumX = x + usable * 0.75;
    const auto timeX = x + usable - (albums ? 130 : 65);
    QVector<QPair<QString, double>> columns{{"#", x},
        {albums ? "ALBUM / 专辑名称" : "TITLE / 歌曲", titleX}};
    if (!albums) { columns.append({"ARTIST / 歌手", artistX}); }
    if (!albums && !albumPage) { columns.append({"ALBUM / 专辑", albumX}); }
    if(!albums)columns.append({"喜欢",timeX-46});
    columns.append({albums ? "RELEASED / 发行日期" : "TIME / 时长", timeX});
    for (const auto &[label, position] : columns) {
        text(label, position, 412, 11);
    }
    for (int row = 0; row < rowCount && trackOffset + row < songs.size(); ++row) {
        const auto index = trackOffset + row;
        const auto song = songs.at(index).toObject();
        const auto yy = rowsY + row * rowHeight;
        if (focusAction.isEmpty() && music.directory && music.directory->index == index) {
            auto color = ink();
            color[3] = 0.055;
            fill(x - 8, yy, usable + 16, rowHeight - 2, color);
        }
        text(MusicData::pad(index + 1), x, yy + 16, 14);
        const auto cover = song["cover"].toString();
        requestListCover(cover);
        auto placeholder = ink(); placeholder[3] = 0.05;
        fill(x + 42, yy + 5, 40, 40, placeholder);
        image(listCovers.value(cover), x + 42, yy + 5, 40, 40);
        limited(song["title"].toString(), titleX, yy + 12, 18,
                (albums ? timeX : artistX) - titleX - 28, "demibold");
        auto stamp = MusicData::time(song);
        if (albums) {
            stamp = song["date"].toString();
            if (stamp.isEmpty()) {
                stamp = "专辑";
            }
        }
        limited(stamp, timeX, yy + 16, 14, albums ? 130 : 65);
        rule(x, yy + rowHeight - 1, usable, 0.15);
        hit(x - 8, yy, usable + 16, rowHeight - 2,
            (albums ? "music:artist-album:" : "music:track:") + QString::number(index),
            song["title"].toString());
        if (!albums) {
            const auto available = (albumPage ? timeX-48 : albumX) - artistX - 20;
            const auto artists = song["artists"].toArray();
            if (artists.isEmpty()) { limited(song["artist"].toString(), artistX, yy + 16, 14, available); }
            double xx = artistX;
            for (int a = 0; a < artists.size() && xx < artistX + available - 12; ++a) {
                if (a) { text(" / ", xx, yy + 16, 14); xx += m_glyphs->width(" / ", 14); }
                const auto name = artists.at(a).toObject()["name"].toString();
                link(name, xx, yy + 16, 14, artistX + available - xx,
                     "music:row-artist:" + QString::number(index) + ":" + QString::number(a));
                xx += m_glyphs->width(name, 14);
            }
            if (!albumPage) {
                if (!song["albumID"].toString().isEmpty()) {
                    link(song["album"].toString(), albumX, yy + 16, 14, timeX - albumX - 64,
                         "music:row-album:" + QString::number(index));
                } else { limited(song["album"].toString(), albumX, yy + 16, 14, timeX - albumX - 64); }
            }
        }
        if(!albums)songHeart(song,timeX-43,yy+14,"music:row-like:"+QString::number(index)+":"+QString::fromUtf8(QUrl::toPercentEncoding(song["id"].toString())));
    }
    if (songs.isEmpty()) {
        limited(music.directoryLoading || music.detailLoading ? "正在载入曲目…" : "暂无可读取曲目", titleX,
                490, 22, usable - 100);
    }
    text(albums ? "滚轮浏览专辑 · 点击查看专辑" : "滚轮浏览曲目 · 点击查看歌曲", x, 934, 11);
    if (albums && music.directory && music.directory->albumsMore) {
        button(music.directory->albumsLoading ? "载入中…" : "更多专辑 ↓", x + usable - 150, 922, 150, 32,
               "music:artist-more", 14);
    }
    if (!albums && songs.size() < total) {
        button(music.directoryLoading ? "载入中…" : "加载更多 ↓", x + usable - 150, 922, 150, 32,
               "music:directory-more", 14);
    }
    restore();
}

void NativeHud::viewer(double width) {
    const auto item = m_music->current;
    if (item.isEmpty()) {
        return;
    }
    button("← 返回音乐   ESC", 59, 69, 300, 54, "viewer:close", 20, "demibold");
    text("RHINE LAB / MUSIC DATABASE / COVER", width / 2 - 145, 70, 11, "regular", 1.5);
    limited(item["title"].toString() + " / 封面", width / 2 - 145, 95, 28, width / 2 - 250, "demibold");
    text(item["id"].toString(), width / 2 - 145, 139, 14);
    text("360°", width - 185, 72, 55, "light");
    button("清晰", width - 247, 189, 84, 38, "viewer:clear", 14);
    button("磨砂", width - 147, 189, 84, 38, "viewer:frosted", 14);
    text("拖动旋转     ↑ ↓ ← → 平移     滚轮缩放", 59, 965, 15);
    button("原始视角", width / 2 - 165, 914, 154, 46, "viewer:reset", 15);
    button("封面正面", width / 2 + 18, 914, 154, 46, "music:cover-front", 15);
    button("复位视角 ↗", width - 194, 914, 135, 46, "viewer:reset", 14);
}
