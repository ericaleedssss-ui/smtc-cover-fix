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

## G87 failed-run correction

Run 40883105833 passed the actual Windows build/deploy but failed real UI QA: the material Loader unloaded across directory navigation, and the broad pending-now-playing flag intercepted discovery return. Distribution correctly stopped before offline tests/ZIP.

The correction keeps the original glass material object alive, hides it and detaches its background source while unused; only content changes. Playback origin is now scoped to the exact directory instance through a weak reference, so an unrelated or reopened folder retains its real navigation history. Escape from recommendations with no playlist/album source delegates to existing saved-page return, preserving the discovery tab and list position. The Windows fixture now actually starts playback inside the folder before asserting its playback return. No assertions removed. Animation pause/resume is applied only after an animation starts, eliminating the stopped-animation pause warnings.

Added `scripts/test-g87-return.py`: compiled production `restorePage` passes unplayed discovery return with preserved position, exact played-directory home return and same-ID/new-session isolation. Local software and real OpenGL QML checks now also hide/show the reading surface while asserting the identical material object; explicit frosting-off still releases the effect and detaches background sampling, preserving the existing settings contract; pause warnings are treated as failures. Production model regressions, nine native C++ syntax checks, integrated Main QML release precompile and source verification passed locally. Final corrected Windows UI run remains pending at submission.

### Follow-up: dormant-surface QA contract

Run 40886442749 again passed Windows compilation/deployment. All previous G81 material identity, G87 playback-directory return and discovery Escape checks now passed. Its only two failed assertions still assumed that settings/detail isolation requires deleting the retained material Loader. The corrected checks assert the real isolation boundary instead: Loader invisible and retained material background source null in both settings and detail. Frosting-off still separately requires an inactive Loader and null effect item. No failed check removed or ignored. Local QML additionally verifies that hiding the reading surface retains its exact material identity, hides its externally parented Loader and disconnects the background source; showing it reconnects that source. No runtime code or visuals changed in this follow-up.
