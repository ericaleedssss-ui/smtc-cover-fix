#include "PipelineDiagnostics.h"
#include "NativeApplication.h"
#include <cmath>

HudSceneActions NativeApplication::sceneActions(NativeScene *scene) {
    return {[scene](QString mode) { scene->setMode(mode); },
            [scene](bool dark) { scene->theme(dark); },
            [scene](bool reduced) { scene->reduced(reduced); }};
}

/** 建立原生音乐、HUD、场景的值接口；所有异步失效统一唤醒 Qt 帧调度。 */
NativeApplication::NativeApplication(Host *host, Glyphs *glyphs, NativeScene *scene, QJsonObject content,
                                     QObject *parent)
    : QObject(parent), music(host, content), hud(host, glyphs, &music, sceneActions(scene)), m_host(host),
      m_scene(scene) {
    connect(&music, &MusicLibrary::invalidated, host, &Host::invalidate);
    connect(&music, &MusicLibrary::selectionRequested, this,
            [scene](int index, QJsonObject navigation) { scene->select(index, navigation); });
    connect(&music, &MusicLibrary::modeRequested, this, [scene](QString mode) { scene->setMode(mode); });
    connect(&music, &MusicLibrary::navigationRequested, this,
            [scene](QString axis, int direction) { scene->navigate(axis, direction); });

}
void NativeApplication::initialize() {
    m_scene->theme(hud.dark);
    m_scene->reduced(hud.reduced);
    m_scene->setMode("archive");
    const auto saved = m_host->preference("volume");
    bool valid = false;
    const auto volume = saved.toDouble(&valid);
    music.player.volume(valid && std::isfinite(volume) ? volume : 0.7);
    music.restoreAccount();
    music.restoreIdentityName();
}
QJsonObject NativeApplication::step(double time, double width, bool reuseScene) {
    PipelineDiagnostics::Scope trace("native.step");
    const auto viewChanged =
        m_scene->setTrackListView(hud.trackListMode && music.current.value("kind") == "song");
    const auto frame = reuseScene && !viewChanged ? music.frame : m_scene->sample(time);
    if (frame.isEmpty()) {
        return {};
    }
    music.frame = frame;
    music.observe(frame["selected"].toInt());
    if ((hud.tab == "history" || hud.tab == "notes") && music.wantsSongDetails && frame["mode"] == "detail") {
        music.sameAlbum();
    }
    hud.draw(frame, width, time);
    return {{"commands", hud.commands},
            {"hits", hud.hits},
            {"state", hud.state()},
            {"current", music.current},
            {"cover", music.coverImage}};
}
void NativeApplication::poll(double time, bool force) {
    music.player.tick(time, force);
}
void NativeApplication::mediaAction(QString action) {
    if (action == "resume" || action == "pause") {
        music.player.setPaused(action == "pause");
    } else {
        hud.action("player:" + action);
    }
}

void NativeApplication::pointer(QString type, double x, double y) {
    if (!hud.modal.isEmpty()) {
        // 弹窗外只接受完整点击，拖动、取消和面板内部留白都不触发返回。
        if (type == "pointerdown") {
            m_dragging = true;
            m_down = {x, y};
            m_moved = false;
        } else if (type == "pointermove" && m_dragging && std::hypot(x - m_down.x(), y - m_down.y()) > 6) {
            m_moved = true;
        } else if (type == "pointerup") {
            const auto bounds = hud.modalBounds(hud.width).translated(0, hud.motion.offset);
            const bool isClick = !m_moved && std::hypot(x - m_down.x(), y - m_down.y()) <= 6;
            if (m_dragging && isClick && !bounds.contains(m_down) && !bounds.contains(x, y) && !hud.closing) {
                hud.closeModal();
            }
            m_dragging = false;
        } else if (type == "pointercancel" || type == "pointerleave") {
            m_dragging = false;
        }
        return;
    }

}
