"""G61: fixed title/social geometry, quiet seek handle, true outline transition.

Runs after G60; all changes are anchored and tested. Playback seeking is
always mapped strictly to the straight top tangent of the stadium.
"""
from pathlib import Path

def edit(path, old, new):
    p=Path(path)
    source=p.read_text(encoding="utf-8")
    found=source.count(old)
    if found != 1:
        raise RuntimeError(f"G61: expected 1 anchor in {path}, got {found}: {old[:94]!r}")
    p.write_text(source.replace(old,new,1),encoding="utf-8")

# Previous per-track dynamic width moved both red-heart and comment buttons.
# The 204px viewport is the SAME for short and long names; long names move
# inside the viewport, and all hit regions remain anchored to the same x.
edit("Qt/src/NativeHud.cpp",
    '            {"playerTitleBounds", rect(QRectF(109, 1003, std::clamp(m_glyphs->width(m_music->player.current.value("title").toString(), 19, "demibold") + 14., 116., 252.), 29))},',
    '            {"playerTitleBounds", rect(QRectF(109, 1003, 204., 29))},')

# Track identity is separate from position/duration. Hovering or dragging a
# seek control must not trigger a transition; only track replacement does.
edit("Qt/src/NativeHud.cpp",
    '            {"playerTitle", m_music->player.current.value("title").toString()},',
    '''            {"playerTitle", m_music->player.current.value("title").toString()},
            {"playerTrackKey", m_music->player.current.isEmpty() ? QString() :
                (m_music->player.current.value("provider").toString("netease") + ":" +
                 m_music->player.current.value("id").toString())},''')

# Revert G59's always-visible fake glass ball. It was distracting when idle.
# The original tactile 15px thumb is hover/drag-only, with time tooltip.
edit("Qt/qml/Main.qml",
    '''                visible: adjustment.isSeek && adjustment.duration > 0
                width: (adjustment.pressed ? 20 : adjustment.interacting ? 16 : 11) * root.stageScale
                height: width
                radius: width / 2
                x: Math.max(0, Math.min(parent.width - width, parent.width * adjustment.shownFraction - width / 2))
                y: 10 * root.stageScale - height / 2
                color: rhine.state.dark ? "#bed0c5" : "#e0e9e0"
                opacity: .95
                border.width: 1.15 * root.stageScale
                border.color: "#fafffa"
                Behavior on width { NumberAnimation { duration: rhine.state.reduced ? 0 : 140; easing.type: Easing.OutCubic } }
                Rectangle {
                    x: 2.5 * root.stageScale; y: 2.1 * root.stageScale
                    width: parent.width * .32; height: parent.height * .25
                    radius: height / 2
                    color: "#ffffff"
                    opacity: .90
                    rotation: -25
                }''',
    '''                visible: adjustment.interacting && adjustment.duration > 0
                width: 15 * root.stageScale; height: width; radius: width / 2
                x: Math.max(0, Math.min(parent.width - width, parent.width * adjustment.shownFraction - width / 2))
                y: 10 * root.stageScale - height / 2
                color: "#faf8ef"
                border.width: Math.max(.6, root.stageScale)
                border.color: "#b5b6a6"''')

# The top edge is now an obvious rail rather than a near-invisible line
# drawn under the glass rim; the hitbox still reaches +/-10 px.
edit("Qt/qml/Main.qml",
    '''                height: (adjustment.interacting ? 6 : 3) * root.stageScale
                y: 10 * root.stageScale - height / 2
                color: rhine.state.dark ? "#45483f" : "#d3d3c8"''',
    '''                height: (adjustment.interacting ? 5 : 3.5) * root.stageScale
                y: 10 * root.stageScale - height / 2
                color: rhine.state.dark ? "#525d51" : "#b4bcae"''')
edit("Qt/qml/Main.qml",
    '''                    color: rhine.state.dark ? "#b7bea1" : "#777b60"
                }
            }
            Item {
                id: chorusMarker''',
    '''                    color: rhine.state.dark ? "#bbd7a9" : "#68865d"
                }
            }
            Item {
                id: chorusMarker''')

# Canvas follows the entire *remaining* contour: top-right -> right
# semicircle -> bottom backwards -> left semicircle -> top-left. Normal
# music progress remains only along the top straight edge. Deliberate
# seek/pause doesn't set a new key, and rapid skips don't start duplicate
# effects. The music playback itself is never blocked by the animation.
edit("Qt/qml/Main.qml",
    '''    // Lyrics/detail hit areas still come from the native HUD. Only the
    // text pixels move, so a long title never blocks the click handlers.''',
    '''    // Playback edge-trail is decorative and never captures mouse input.
    // Actual seek is the straight upper stadium tangent, independently owned
    // by playbackSeekArea and unaffected by this short transition.
    Canvas {
        id: capsuleEdgeTrail
        objectName: "capsuleEdgeTrail"
        x: 32 * root.stageScale
        y: 990 * root.stageScale
        width: root.width - 64 * root.stageScale
        height: 78 * root.stageScale
        z: 15
        visible: edgeMotion.running && !rhine.state.reduced
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        property real travel: 1
        property string trackKey: String(rhine.state.playerTrackKey || "")
        property string priorTrack: ""
        onTrackKeyChanged: {
            var next = trackKey;
            if (priorTrack.length && next.length && priorTrack !== next &&
                !edgeMotion.running && !rhine.state.reduced) {
                edgeMotion.restart();
            }
            priorTrack = next;
        }
        onTravelChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        NumberAnimation {
            id: edgeMotion
            target: capsuleEdgeTrail
            property: "travel"
            from: 0
            to: 1
            duration: 730
            easing.type: Easing.InOutCubic
        }
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!edgeMotion.running || width < height + 1) return;
            var r = height / 2;
            var straight = width - 2 * r;
            var halfCircle = Math.PI * r;
            var distance = 2 * halfCircle + straight;
            function pointAt(d) {
                d = Math.max(0, Math.min(distance, d));
                var theta;
                if (d <= halfCircle) {
                    theta = -Math.PI / 2 + d / r;
                    return [width - r + r * Math.cos(theta), r + r * Math.sin(theta)];
                }
                d -= halfCircle;
                if (d <= straight) return [width - r - d, height];
                d -= straight;
                theta = Math.PI / 2 + d / r;
                return [r + r * Math.cos(theta), r + r * Math.sin(theta)];
            }
            var head = travel * distance;
            var length = Math.min(distance * .17, 118 * root.stageScale);
            var start = Math.max(0, head - length);
            var fade = Math.min(1, (1 - travel) * 9);
            for (var pass = 0; pass < 2; ++pass) {
                for (var i = 0; i < 22; ++i) {
                    var f0 = i / 22, f1 = (i + 1) / 22;
                    var from = pointAt(start + (head - start) * f0);
                    var to = pointAt(start + (head - start) * f1);
                    ctx.beginPath();
                    ctx.moveTo(from[0], from[1]);
                    ctx.lineTo(to[0], to[1]);
                    ctx.lineWidth = (pass === 0 ? 7 : 2.7) * root.stageScale;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = pass === 0
                        ? "rgba(158,198,142," + (fade * .10 * (f1 + .10)) + ")"
                        : "rgba(101,155,93," + (fade * .82 * (f1 * f1)) + ")";
                    ctx.stroke();
                }
            }
        }
    }
    // Lyrics/detail hit areas still come from the native HUD. Only the
    // text pixels move, so a long title never blocks the click handlers.''')

# Update the regression expectations with the restored hover-only thumb.
p=Path("Qt/tests/UiChecks.cpp")
checks=p.read_text(encoding="utf-8")
for old,new in (
    ('check(thumb && thumb->isVisible() && time && !time->isVisible(), "normal progress shows a small glass bead but hides the time pill");',
     'check(thumb && !thumb->isVisible() && time && !time->isVisible(), "normal progress line hides the thumb and time pill");'),
    ('check(thumb && thumb->isVisible() && time && !time->isVisible(), "leaving restores the small glass bead and hides the hover time pill");',
     'check(thumb && !thumb->isVisible() && time && !time->isVisible(), "leaving restores the unobtrusive progress line");')
):
    if checks.count(old)!=1: raise RuntimeError("G61 old thumb check mismatch")
    checks=checks.replace(old,new,1)
p.write_text(checks,encoding="utf-8")

# Inherited G59 checks mention moving reactions; replace only those now stale.
p=Path("Qt/src/NativeHudPlayer.cpp")
native=p.read_text(encoding="utf-8")
assert "const double infoWidth = 204.;" in native
assert "const double reactionX = 109 + infoWidth + 18;" in native
assert "playerSeekRect = QRectF(71, y - 4, width - 142, 20);" in native
assert "centeredText(redLabel, reactionX + 29" in native
assert "centeredText(commentLabel, reactionX + 110" in native
qml=Path("Qt/qml/Main.qml").read_text(encoding="utf-8")
assert 'objectName: "capsuleEdgeTrail"' in qml
assert "edgeMotion.restart();" in qml
assert "visible: adjustment.interacting && adjustment.duration > 0" in qml
assert 'height: (adjustment.interacting ? 5 : 3.5)' in qml
print("G61: fixed title and reactions, readable edge seeker, restored hover thumb, independent contour sweep.")
