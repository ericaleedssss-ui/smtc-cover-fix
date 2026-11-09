#include "NativeScene.h"
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <algorithm>
#include <cmath>
namespace {
int wrap(int value, int count) { return count ? (value % count + count) % count : 0; }
}
NativeScene::NativeScene(QString root) {
    QFile file(root + "/slots.json");
    if (!file.open(QIODevice::ReadOnly)) { failure = "Missing library navigation data"; return; }
    const auto content = QJsonDocument::fromJson(file.readAll()).object();
    const auto columns = content["columns"].toArray(), records = content["records"].toArray();
    m_count = records.size();
    for (int lane = 0; lane < std::min(5, int(columns.size())); ++lane) {
        for (int i = 0; i < records.size(); ++i)
            if (records[i].toObject()["category"] == columns[lane]) m_columns[lane].append(i);
        if (!m_columns[lane].isEmpty()) m_memories[lane] = m_columns[lane].first();
    }
    if (!m_count) failure = "Empty library navigation data";
}
void NativeScene::setMode(QString mode) {
    // Saved preferences cannot reactivate the retired 3D boot or viewer.
    const auto next = mode == "detail" ? QString("detail") : QString("archive");
    if (m_mode != next) { m_mode = next; m_changed = true; }
}
void NativeScene::select(int index, QJsonObject) {
    if (index < 0 || index >= m_count || index == m_selected) return;
    m_selected = index;
    for (int lane = 0; lane < 5; ++lane)
        if (m_columns[lane].contains(index)) m_memories[lane] = index;
    m_changed = true;
}
void NativeScene::navigate(QString axis, int direction) {
    for (int lane = 0; lane < 5; ++lane) {
        const auto &files = m_columns[lane];
        const auto row = files.indexOf(m_selected);
        if (row < 0) continue;
        if (axis == "lane") select(m_memories[wrap(lane + direction, 5)]);
        else select(files[wrap(row + direction, files.size())]);
        return;
    }
}
bool NativeScene::setTrackListView(bool enabled) {
    if (enabled == m_trackListView) return false;
    m_trackListView = enabled; m_changed = true; return true;
}
QJsonObject NativeScene::sample(double time, bool advance) {
    const double target = m_trackListView ? 1 : 0;
    if (advance) {
        const double dt = std::clamp(time - m_lastTime, 0., .05);
        m_trackListBlend = m_reduced ? target :
            m_trackListBlend + (target - m_trackListBlend) * (1 - std::exp(-14 * dt));
        if (std::abs(target - m_trackListBlend) < .0001) m_trackListBlend = target;
        m_lastTime = time;
    }
    frame = {{"mode", m_mode}, {"selected", m_selected}, {"detail", m_mode == "detail" ? 1 : 0},
             {"viewer", false}, {"pointerCursor", "default"}, {"trackListBlend", m_trackListBlend},
             {"pendingAnimations", m_trackListBlend != target}};
    m_changed = false;
    return frame;
}
