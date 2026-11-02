#include "NativeHud.h"
#include "MusicDiscover.h"
#include <algorithm>
#include <cmath>
#include <QUrl>

void NativeHud::hoverItem(QString value, double x, double y) {
    const QPointF point(x, y);
    const bool moved = std::hypot(x - navigationPointer.x(), y - navigationPointer.y()) > 2;
    if (moved) { navigationPointer = point; }
    if (keyboardNavigation && !moved) { return; }
    const bool changed = keyboardNavigation || focusAction != value;
    keyboardNavigation = false; focusAction = value;
    if (changed) { m_host->invalidate(); }
}

bool NativeHud::navigatePage(QString key) {
    if (queueOpen) { return key.startsWith("Arrow") || key == "Enter"; }
    const bool arrow = key.startsWith("Arrow");
    if (!arrow && key != "Enter") { return false; }
    if (modal.isEmpty() && frame["mode"] == "archive" && !lyricsMode) { return false; }
    keyboardNavigation = true;
    if (modal == "profile") { return true; } // QML owns the responsive card grid.
    const int direction = key == "ArrowDown" ? 1 : key == "ArrowUp" ? -1 : 0;
    if (modal.isEmpty() && lyricsMode) {
        if (direction) {
            const auto maximum = m_lyricsLayout.isEmpty() ? 0. : m_lyricsLayout.constLast().top;
            m_lyricsBrowse = std::clamp(m_lyricsBrowse.value_or(m_lyricsScroll) + direction * 65., 0., maximum);
            m_lyricsPlainOffset = std::max(0, m_lyricsPlainOffset + direction);
        }
        return true;
    }
    if (modal.isEmpty() && frame["mode"] == "detail" &&
        (key == "ArrowLeft" || key == "ArrowRight")) {
        const int step = key == "ArrowRight" ? 1 : -1;
        if (m_music->current["kind"] == "song") {
            const QStringList tabs = m_music->provider == "netease" ?
                QStringList{"overview", "history", "comments", "recommendations"} : QStringList{"overview", "notes", "history"};
            const auto index = std::clamp(int(tabs.indexOf(tab)) + step, 0, int(tabs.size()) - 1);
            action("tab:" + tabs.at(index));
        } else if (m_music->current["kind"] == "artist") {
            action("music:artist-tab:" + QString(step > 0 ? "albums" : "songs"));
        } else if (m_music->current["kind"] == "album" && m_music->provider == "netease") {
            action(step > 0 ? "tab:comments" : "tab:overview");
        }
        return true;
    }
    if (modal.isEmpty() && ((commentsBounds && tab == "comments") ||
        (readerBounds && m_music->current["kind"] == "song") || recommendationsBounds)) {
        return true; // Reading areas receive the same key through Engine::pageNavigation.
    }
    QString prefix;
    int count = 0, visible = 0;
    int *offset = nullptr;
    if (modal.isEmpty() && frame["mode"] == "detail") {
        const bool albums = m_music->directory && m_music->current["kind"] == "artist" && artistTab == "albums";
        prefix = albums ? "music:artist-album:" : "music:track:";
        count = m_music->current["kind"] == "song" ? m_music->tracks.size() :
            m_music->directory ? (albums ? m_music->directory->albums.size() : m_music->directory->songs.size()) : m_music->tracks.size();
        visible = m_music->current["kind"] == "song" ? detailRows : containerLayout(width).rowCount;
        offset = &trackOffset;
    } else if (modal == "discover" && !categoryPicker) {
        prefix = "discover:item:"; count = m_music->discover->items.size(); visible = 6; offset = &listOffset;
    } else if (modal == "player") {
        prefix = "player:queue:"; count = m_music->player.queue.size(); visible = 7; offset = &queueOffset;
    }
    if (offset && count > 0) {
        int current = focusAction.startsWith(prefix) ? focusAction.mid(prefix.size()).toInt() :
            (prefix == "music:track:" && m_music->directory ? m_music->directory->index : *offset);
        current = std::clamp(current, 0, count - 1);
        if (direction) { current = std::clamp(current + direction, 0, count - 1); }
        focusAction = prefix + QString::number(current);
        if (current < *offset) { *offset = current; }
        if (current >= *offset + visible) { *offset = current - visible + 1; }
        if (direction > 0 && current == count - 1) {
            if (prefix == "music:artist-album:") { m_music->loadArtistAlbums(); }
            else if (prefix == "music:track:" && m_music->directory) { m_music->loadDirectoryPage(); }
            else if (prefix == "music:track:") { m_music->loadTrackPage(current); }
        }
        if (key == "Enter") { action(focusAction); }
        return true;
    }
    if (modal == "search" || modal == "saved") {
        const auto lane = modal == "saved" ? musicCollection : 0;
        const auto entries = rows(lane);
        QStringList actions;
        for (const auto &entry : entries) {
            actions.append(entry.value["kind"] == "group" ? "music:expand:" + QString::fromUtf8(QUrl::toPercentEncoding(entry.value["key"].toString())) :
                "music:result:" + QString::number(lane) + ":" + QString::number(entry.index));
        }
        if (!actions.isEmpty()) {
            int index = actions.indexOf(focusAction);
            index = index < 0 ? listOffset : std::clamp(index + direction, 0, int(actions.size()) - 1);
            focusAction = actions.at(index);
            if (index < listOffset) { listOffset = index; }
            if (index >= listOffset + 5) { listOffset = index - 4; }
            if (direction > 0 && index == actions.size() - 1 && !m_music->sourceLoading() && m_music->hasMore[lane]) { m_music->loadMoreSource(lane); }
            if (key == "Enter") { action(focusAction); }
        }
        return true;
    }
    // Remaining small pickers retain their existing row actions.
    QVector<QString> candidates;
    for (const auto &value : hits) {
        const auto hit = value.toObject();
        if (hit["navigation"].toBool() && !candidates.contains(hit["action"].toString())) {
            candidates.append(hit["action"].toString());
        }
    }
    if (!candidates.isEmpty()) {
        int current = candidates.indexOf(focusAction);
        if (current < 0) { current = direction > 0 ? -1 : 0; }
        const int next = current + direction;
        if (direction && (next < 0 || next >= candidates.size()) &&
            QStringList{"search", "saved", "playlist-picker"}.contains(modal)) {
            const int maximum = modal == "playlist-picker" ? std::max(0, int(m_music->lists[2].size()) - 7) :
                std::max(0, int(rows(modal == "saved" ? musicCollection : 0).size()) - 5);
            listOffset = std::clamp(listOffset + direction, 0, maximum);
        }
        focusAction = candidates.at(std::clamp(next, 0, int(candidates.size()) - 1));
        if (key == "Enter") { action(focusAction); }
    }
    // Every non-shelf page consumes unused arrows instead of leaking to the shelf.
    return true;
}

/** 滚轮优先交给当前面板；歌词使用连续距离，资料库保留合并后的整数步数。 */
void NativeHud::wheel(double x, double y, double delta, std::optional<int> steps,
                      std::optional<double> distance) {
    if (frame.isEmpty() || !std::isfinite(delta)) {
        return;
    }
    const auto step = steps.value_or(delta < 0 ? 1 : -1);
    // 鼠标滚轮按帧平滑时角度增量只在首帧出现，后续只补送连续距离。
    if (delta == 0 && step == 0 && distance.value_or(0.) == 0) {
        return;
    }
    auto &music = *m_music;
    if (modal == "settings") {
        const auto bounds = modalBounds(width);
        const auto localY = y - motion.offset;
        if (!closing && x >= bounds.left() && x <= bounds.right() &&
            localY >= bounds.top() + SettingsViewportTop && localY <= bounds.top() + SettingsViewportBottom) {
            settingsScroll =
                std::clamp(settingsScroll + distance.value_or(step * 50.), 0., settingsScrollMaximum());
        }
        return;
    }
    if (frame["viewer"].toBool()) {
        if (delta != 0) {
            m_scene.pointer("wheel", x, y, -delta * 8);
        }
        return;
    }
    if (!modal.isEmpty()) {
        if (modal == "playlist-picker") {
            listOffset = std::clamp(listOffset + step, 0, std::max(0, int(music.lists[2].size()) - 7));
            return;
        }
        if (modal == "discover") {
            listOffset = std::clamp(listOffset + step, 0, std::max(0, int(music.discover->items.size()) - 6));
            return;
        }
        if (modal == "player") {
            queueOffset = std::clamp(queueOffset + step, 0, std::max(0, int(music.player.queue.size()) - 7));
            return;
        }
        if (closing || !QStringList{"search", "saved"}.contains(modal)) {
            return;
        }
        const auto bounds = modalBounds(width);
        y -= motion.offset;
        if (x < bounds.x() + 53 || x > bounds.right() - 53 || y < 475 || y > 867) {
            return;
        }
        const auto lane = modal == "saved" ? musicCollection : 0;
        const auto values = rows(lane);
        listOffset = std::clamp(listOffset + step, 0, std::max(0, int(values.size()) - 5));
        if (step > 0 && listOffset + 5 >= values.size() && !music.sourceLoading() && music.hasMore[lane]) {
            music.loadMoreSource(lane);
        }
        return;
    }
    if (lyricsMode && music.current.value("kind") == "song" && x >= width * 0.56 && y >= 360 && y < 889) {
        const auto lastTop = m_lyricsLayout.isEmpty() ? 0 : m_lyricsLayout.constLast().top;
        const auto movement = distance.value_or((-delta / 120) * 65);
        m_lyricsBrowse = std::clamp(m_lyricsBrowse.value_or(m_lyricsScroll) + movement, 0.0, lastTop);
        m_lyricsPlainOffset = std::max(0, m_lyricsPlainOffset + step);
        return;
    }
    if (frame["mode"] == "detail" && music.current.value("kind") != "song") {
        // 平滑帧只补送距离，不改曲目行偏移，也不重复触发分页加载。
        if (step == 0) {
            return;
        }
        const auto layout = containerLayout(width);
        if (x < layout.x || x > layout.x + layout.width || y < layout.rowsY ||
            y > layout.rowsY + layout.rowCount * layout.rowHeight) {
            return;
        }
        const bool albums =
            music.directory && music.directory->item["kind"] == "artist" && artistTab == "albums";
        int count = music.tracks.size();
        if (music.directory) {
            count = albums ? music.directory->albums.size() : music.directory->songs.size();
        }
        trackOffset = std::clamp(trackOffset + step, 0, std::max(0, count - layout.rowCount));
        if (trackOffset + layout.rowCount >= count) {
            if (albums) {
                music.loadArtistAlbums();
            } else if (music.directory) {
                music.loadDirectoryPage();
            } else {
                music.loadTrackPage(trackOffset);
            }
        }
        return;
    }
    if (frame["mode"] == "detail") {
        // 文本阅读区由 QML 接收滚轮，同专辑列表沿用原生行分页。
        if (tab != "history" || !detailRowsBounds || !detailRowsBounds->contains(QPointF(x, y))) { return; }
        // 详情正文与历史列表只按行进，平滑帧不重复请求曲目页。
        if (step == 0) {
            return;
        }
        if (tab == "history") {
            trackOffset = std::clamp(trackOffset + step, 0, std::max(0, int(music.tracks.size()) - detailRows));
            music.loadTrackPage(trackOffset);
        } else {
            const auto count = m_glyphs->wrap(body(), width * 0.44 - 59, 16).size();
            bodyOffset = std::clamp(bodyOffset + step, 0, std::max(0, int(count) - 3));
        }
        return;
    }
    if (frame["mode"] == "archive") {
        if (step != 0) {
            music.next(step);
        }
    } else if (delta != 0) {
        m_scene.pointer("wheel", x, y, -delta * 8);
    }
}
