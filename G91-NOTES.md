# G91 — neutral light, expanded vinyl and album portrait/alignment

## Scope

- `maintained/Qt/qml/NowPlayingPanel.qml`: retain the existing glass bounds, record centre, cover size and fixed 32°/18° perspective. Expand the stationary platter by 10% of the cover size on each side. The inset compensates exactly, leaving artwork width at the former discSize − 8 units. Only printed artwork texture coordinates rotate. A separate procedural ivory tonearm uses the same plane; playback state moves it between contact and a small −12° resting pose over 280 ms. No new playback control or player body, no audio analysis, no new timer.
- `maintained/Qt/shaders/recordAtmosphere.frag`: broad translucent **neutral white** sheets, source-over composited so overlapping waves become gently brighter. Remove coloured halo tones. Preserve a real centre aperture, restrained sheen and thin contact edge; add fine grooves outside the cover. Gradually soften and fade the left side of the record surface while retaining the artwork's readable centre/right. Text/lyrics are not blurred. Only the record's local composition target is sampled for a small five-tap focal feather; no full-screen blur.
- `maintained/Qt/src/PlaylistMagazine.cpp/.h`: album summaries frequently lack a usable portrait. Fetch the first artist's real `/artist/detail` portrait (`data.artist.avatar`, `img1v1Url`, `picUrl` or `cover`), fall back once to `/artists` when metadata or decoding fails, then reuse Host's decoded image cache with a 96px request. Publish circular PNG pixels for QML rather than making QML fetch the remote full-size image again. Bound portrait cache to 64 artists; clear old displayed pixels immediately on folder/account changes, validate generation/account for both API and image callbacks, and avoid repeat requests on ordinary invalidations. Missing IDs/failed APIs remain unavailable rather than using album artwork as a portrait.
- `maintained/Qt/qml/PlaylistMagazine.qml`: use the resolved portrait. Headers and matching title/artist/secondary/heart/duration cells share horizontal centres in playlist and album modes. The album heat centre sits halfway between the artist and heart column centres, with bounded width so its hover area cannot intercept artist links. Heat still uses only real provider popularity; playlist album names, heart state, title/artists/album click targets and durations remain functional.
- `scripts/enable-g91.py`, `scripts/apply-maintained.py`: add the generation step and an actual native API→Host→QML portrait check using explicit offline test data. Existing album-description, heat and navigation assertions remain. Workflow labels/artifact become G91; compressed base patches are unchanged.
- `scripts/test-g71-model.py`, `scripts/fixtures/g71/checks.cpp`: production-model portrait tests with deterministic API/image fixtures, including failed decode→fallback, bounded round pixels, no repeated requests, switching isolation and distinct artists.
- `scripts/test-g71-qml.py`: focused four-size checks for shared header/cell centres, heat midpoint and non-overlap, portrait binding, plus preserved short/long description and actual wheel/close behavior.
- `scripts/test-g86-qml.py`: retain playing/paused, hidden, fixed platter, lyrics, actions and current-track checks; additionally enforce unchanged print size, expanded rim and tonearm poses.

## Actual validation

- Actual OpenGL RHI QML/shader tests passed original glass identity, four layouts, artwork-only rotation, pause/hidden behavior, tonearm poses, lyric wheel/seek/follow, title/album navigation, shared song actions, More collection and the global now-playing entry. Shader compilation targets GLSL, HLSL and MSL. Inspected playing/paused screenshots; the arm remains inside the card. Explicit offline concentric artwork is test material only.
- With artwork stationary, two light phases produced maximum channel change 31/255 and aggregate sampled change 42225; lyric-region maximum change was 4/255. This demonstrates actual moving light without relying only on shader source inspection. Light follows playback state and a slow phase, not live audio amplitude.
- Production magazine model checks passed, including new portrait decoding/fallback/cache/stale-response tests and existing album subscriptions, likes, collector counts and pagination behavior.
- Four-size actual QML checks passed column centres, heat spacing/non-overlap, avatar source binding, and short/long description wheel isolation at 1400×900, 960×540, 960×720 and 1920×1080.
- Production now-playing adapter regression passed shared song operations, image cache, album/artist metadata, lyric seeking and stale identity isolation.
- Actual generated PlaylistMagazine.cpp syntax with project headers passed (only unavailable local multimedia backend left opaque). Release QML bytecode compilation passed both changed QML files. Full source generation/identity verification, workflow patch CRC/SHA checks and git diff checks passed.

## Pending

Full Windows compile/deploy, native integrated portrait check, packaging and physical-machine visual/performance acceptance remain CI/user work. Live provider portraits and logged-in mutation endpoints were not exercised locally. No full unrelated cover animation suite rerun is claimed. Total-duration calculation remains removed; roaming, cover carousel ordering, footer transport controls, navigation and original LiquidGlass/shader are unchanged.

## Windows source-generation encoding correction

Run 40924004830 stopped before compilation in `enable-g91.py`: implicit Path.read_text used the Windows cp1252 default on UTF-8 C++ containing Chinese text. Both input and output now specify UTF-8 explicitly. No UI/animation/API logic changes. The source-generation step is verified with the G91 script's implicit default deliberately simulated as cp1252; final Windows compilation and rendering remain pending.

## Native portrait fixture envelope correction

Run 40924512917 completed Windows compilation/deployment and the album description/scroll checks. The portrait assertion failed because the new Host-level fixture returned `{code,data}` instead of the real IPC envelope `{body:{code,data}}`. Production MusicApi correctly rejected it as invalid metadata; the lower-level domain fixture had not exercised that wrapper.

The Windows fixture now supplies the real envelope. Added `scripts/test-g91-api-envelope.py`, which compiles the actual generated MusicApi.cpp/h and feeds precisely the portrait response expression generated into UiChecks.cpp, replacing only the IPC transport. Actual checks passed: the old malformed envelope is rejected; the corrected response survives parsing and returns the expected `data.artist.avatar`. Full source generation/identity and base-patch validation passed. UI/API/animation product code is unchanged in this correction. Full Windows integrated rerun remains pending.
