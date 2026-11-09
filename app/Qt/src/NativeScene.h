#pragma once
#include <QJsonObject>
#include <QString>
#include <QVector>
#include <array>

// Library navigation state only: no model, renderer, picking, camera or warmup.
class NativeScene {
  public:
    explicit NativeScene(QString root);
    bool ready() const { return failure.isEmpty(); }
    QJsonObject sample(double time, bool advance = true);
    void setMode(QString mode);
    bool setTrackListView(bool enabled);
    void select(int index, QJsonObject navigation = {});
    void navigate(QString axis, int direction);
    int selection() const { return m_selected; }
    void reduced(bool value) { m_reduced = value; m_changed = true; }
    void theme(bool) { m_changed = true; }
    bool review(QString mode) { setMode(mode); return ready(); }
    void resize(double, double) {}
    void trimMemory() {}
    bool changed() const { return m_changed; }
    struct FrameTimings {
        double simulateMs = 0, metadataMs = 0, buffersMs = 0, engineMs = 0;
    } timings;
    void profileFrames(bool enabled) { m_profileFrames = enabled; }
    bool isProfiling() const { return m_profileFrames; }
    QJsonObject frame;
    QString failure;
  private:
    std::array<QVector<int>, 5> m_columns;
    std::array<int, 5> m_memories{};
    int m_count = 0, m_selected = 0;
    QString m_mode = "archive";
    bool m_changed = true, m_reduced = false, m_trackListView = false, m_profileFrames = false;
    double m_trackListBlend = 0, m_lastTime = 0;
};
