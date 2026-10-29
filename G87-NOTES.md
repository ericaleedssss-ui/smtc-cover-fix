# G87 — fixed record plane, atmosphere and playback navigation

## Changes

- `maintained/Qt/qml/NowPlayingPanel.qml`: fixed platter, rim and perspective (32° inclination instead of 48°, fixed 18° azimuth); cover texture alone rotates in the stationary circular surface. Removed the detached opaque oval shadow and centre pin. Thin ivory contact edge. Song title opens existing full details.
- `maintained/Qt/shaders/recordAtmosphere.frag`: bounded GPU artwork-coordinate rotation, feathered cover-coloured contact shadow and warm diffuse light with staggered fine rings. No new effects dependency, audio analyser or timer. Motion remains playback-state driven, not beat-synchronised. Software fallback rotates circular artwork only.
- `maintained/Qt/src/PlaylistShowcase.cpp`, `PlaylistMagazine.cpp`, `scripts/enable-g86.py`: only explicit song selections / Play All enter now-playing; transport changes never change archive browsing selection. Directory double-click playback stays in the directory with now-playing pending behind it. Exiting returns to home now-playing rather than the legacy text-only song page. Both directory exit and saved navigation-return paths covered. Roaming excluded.
- `maintained/Qt/src/NowPlaying.cpp`: return to recorded source playlist/album in the same glass; no invented source when one is unavailable. Escape is routed after existing overlays; song title and existing low-key detail link share the original full-detail action.
- `maintained/G79-ui-checks.cppfrag`: actual Windows UI checks for passive transport retention, explicit playback entry and directory return.
- `scripts/test-g86-qml.py`: shader packaging/precompile, four fixed-plane angle snapshots, rotation/pause/hidden checks and clickable title. `scripts/test-g86-model.py` and `scripts/fixtures/g71/MusicLibrary.h`: source return and domain fixture support.
- `scripts/verify-build-source.py`: include new shader in maintained/generated equality and update reviewed navigation-controller hash. `.github/workflows/build-smtc.yml`: G87 labels/artifact only; embedded patches unchanged.

## Validation

Local OpenGL RHI QML test passed: four viewport sizes, original glass object retained, 0/90/180/270-degree artwork rotation with stationary plane corners, pause/hide, lyrics scrolling/seeking, title/details and shared actions. Inspected actual 0° and 90° rendering: cover pattern turns inside the identical stationary rim. Software QML also checked. QML release bytecode compiler and GLSL/HLSL/MSL shader compilation are part of that test.

Production NowPlaying, PlaylistShowcase and PlaylistMagazine C++ fixture regressions passed. Changed native production files passed syntax checks against real project headers with only the unavailable local multimedia backend header made opaque; this is not a full Windows build. Original glass and protected playback source verification and embedded patch checks are required before submission.

Windows end-to-end navigation checks are added to CI, not reported as locally passed. Final Windows packaging, signed-in real-provider metadata/writes, physical GPU performance and reference-image visual acceptance remain for the build and user acceptance. The reference atmosphere is approximated procedurally; no claim of pixel-identical matching.
