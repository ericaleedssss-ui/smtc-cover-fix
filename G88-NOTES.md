# G88 — immersive artwork and a global now-playing entry

## Scope and behavior

The original archive glass material, dimensions and placement are unchanged. The existing now-playing content now has enlarged, translucent artwork in a fixed tilted plane. Only artwork texture coordinates rotate. A fixed soft sheen overlays it; broad overlapping light bands replace narrow outline rings. The right visual field has a left feather and top/bottom/right edge fades, clipping the atmosphere inside the card and protecting the lyrics. The shadow/contact lip are much lighter. Playback-state animation remains lightweight; it is not actual audio beat analysis.

Comments, the existing supplied like/unlike artwork and share use matching compact translucent capsules. More remains available, including playlist collection and detail actions. Existing lyrics hover/time/seek, local wheel scrolling and both edge fades remain.

A new four-bar sound indicator is an independent button at the far right of the existing footer. Tooltip: 打开正在播放页面. Its animation stops when paused, hidden/minimised, reduced-motion or blocked. The actual volume control and desktop-lyrics drawing/hit regions move left by 40 design units, keeping the rest of the footer layout unchanged. Existing footer cover/title still open full song details.

The new entry opens the current playing song in the same home glass from another folder, album, settings or discovery view. It never calls play, seek or queue replacement. It reads the playing song's real queueSource; Escape continues to use existing source-return behavior. Repeated clicks do not restart playback. The button is disabled while a message/queue drawer owns the outside interaction. Empty-player state is disabled. FM retains its existing lyric presentation and queue behavior.

## Files

- `maintained/Qt/qml/NowPlayingPanel.qml`: enlarged visual field, shared compact action capsules, fixed sheen and existing content/controls.
- `maintained/Qt/shaders/recordAtmosphere.frag`: broad light bands, fixed surface sheen, soft artwork edge and field mask. One bounded offscreen visual field, no animated blur or new dependencies.
- `maintained/Qt/qml/NowPlayingShortcut.qml`: accessible lightweight footer button, real playback indicator, tooltip and blocked/empty/motion states.
- `maintained/G88-open-playing.cppfrag`: native global navigation, clears obstructing views and uses actual playing origin without changing transport.
- `maintained/G88-ui-checks.cppfrag`: actual Windows footer click, current-track/queue retention, separate volume/lyrics/entry hit regions, drawer blocking, immersive field and screenshot.
- `scripts/enable-g88.py`, `scripts/apply-maintained.py`: integrate the new component, native action and narrowly scoped footer geometry changes.
- `scripts/test-g86-qml.py`: actual QML/shader precompile, immersive geometry and global shortcut interaction tests. Explicit offline coloured artwork is QA-only and never shipped.
- `scripts/test-g88-navigation.py`: compile the production native navigation helper with real MusicData provenance normalization and explicit fixtures.
- `scripts/verify-build-source.py`: new component equality check, reviewed footer/controller hashes. Player transport files and original glass/shader hashes stay protected.
- `.github/workflows/build-smtc.yml`: G88 readable labels/artifact; embedded compressed patches are unchanged.

## Validation and limits

Local actual OpenGL rendering and software QML tests passed four viewport sizes. Inspected actual rendered preview for enlarged translucent cover and soft edge composition. QML bytecode and GLSL/HLSL/MSL shader compilation, original glass retention/hidden sampling, stationary platter at four artwork angles, pause/hide, local lyric scroll/follow/seek, all existing song actions plus the new shortcut/blocked/empty states passed.

Compiled production navigation helper passed: empty state, current track from another browsing folder/settings, real origin, unchanged song/queue/position/index/play mode, repeated entry and unchanged FM route. Changed native sources receive local syntax verification; complete Windows compilation and actual integrated footer tests remain CI work at submission. Signed-in provider writes and physical Windows GPU performance are not claimed as locally verified. Software fallback retains translucent artwork and clipping but cannot reproduce the GPU sheen/mask exactly. Reference composition is adapted to the user's unchanged smaller glass component, not a full-page enlargement.
