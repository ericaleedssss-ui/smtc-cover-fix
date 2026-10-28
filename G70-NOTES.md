# G70 — stable playlist interactions and original private FM entry

Incremental base: successful G69 `36a2c8b7436dc6401e92cf6d92ca91b9659e5d5f` (Windows run `40649245553`). No replacement of the playlist, player, queue or library architecture.

## Root causes and changes

### Live search

The G69 input bound `text` directly to a delayed backend query while its 180ms timer was still pending. Unrelated state notifications could overwrite the editing buffer. More importantly, the editor lived in a ListView header that could be destroyed during a filtering model reset, including a zero-result transition.

The compact/expanding search control now lives in the persistent page layer and follows the header's scroll position. It sends every text change immediately, including deletion, paste and clear. It has no delayed edit timer or backend-to-active-buffer binding. Session changes restore the correct folder query without submitting an old edit. The reserved toolbar area keeps the filter and track layout fixed during expansion.

Filtering always uses the latest query against song, artist and album metadata. Existing account/directory generation guards protect metadata pages; async work never supplies a saved query or independent stale result set. Demand loading covers all IDs, including search entered before initial details finish loading. Clear cancels remaining search demand work; an already requested metadata page may finish safely. Failure releases busy state, explains incomplete results and permits the next query/retry. Completed empty searches show an explicit no-results label.

### Hearts

Shared QML SongHeart/RhineIcon rendering uses a red filled heart for liked songs and a gray outline otherwise, in a fixed Like column next to duration. The existing native detail track table uses matching geometry/colors and captured row-ID actions. Clicks reuse MusicLibrary::like; there is no optimistic fake success. Pending writes disable repeated clicks; failure keeps confirmed state. Authoritative liked IDs take precedence over stale liked-shelf metadata. A cached ID set also avoids repeated linear membership lookups in the playlist model.

### Record browsing

The existing record stack and 520ms animation are retained. Hover opens a deliberate fan with separate exposed-strip hit areas. Raising/highlighting artwork does not enlarge a hit area over its neighbour. Target information shows name/type/creator where available; a small thumbnail strip provides an explicit alternative. Hover expansion is held with a short exit delay rather than circular hover/visibility bindings. The data panel moves aside gently while the fan is open.

The stack/animation is also retained outside resetting list delegates. The chosen key and rear snapshot stay immutable during the transition. Repeated clicks are ignored during animation, with a short guard even when reduced motion navigates immediately. Actual existing collection/history navigation remains responsible for metadata, playlist/album destination and return state. Playback/queue are never touched by record selection. Candidate source/order remains real/stable and bounded to three covers.

### Private FM

Git history confirmed the correct G57/G58 entry in `scripts/enable-g57-ui.py` and `enable-g58.py`. Later maintained sidebar copies restored the old `discover(tab)` path, so the FM session engine remained present but the visible entry opened a static grid. The sidebar and legacy `discover:tab:roam` route now invoke the original `roam:start` action. Existing active sessions reopen their lyric view without resetting the saved queue.

Explicit player/roam navigation now clears `directoryInfo` before following the playing song. This avoids the G69 passive-playback retention guard incorrectly retaining playlist metadata in the lyric view. Ordinary playlist playback still retains its page.

The original personalized `/personal/fm/mode` engine, one-pick refill, saved normal queue/position/mode, lyric-entry signal, footer controls and `/fm_trash` feedback remain in use. Next/previous cannot invalidate an in-flight feedback operation and strand its loading state. Rejected dislike feedback keeps the current song and releases loading; confirmed feedback requests a fresh recommendation. No older full file was copied over current code.

## Build path

`G53 → existing maintained installers through G69 → scripts/enable-g70.py`.

G70 modifies existing C++/resource registration through `patches/g70-stable-search-records-roam.patch`; shared QML and PlaylistMagazine sources are copied from maintained files. Exact triggering-SHA checkout and source hashing remain enabled. New Windows actual-window assertions cover search editing/focus/zero results, real like mutation failure/success/unlike, thumbnail navigation, and FM entry/refill/dislike/exit from a retained playlist.

## Local validation

- Full clean pinned-upstream reconstruction through the G70 installer; source verifier positive/negative checks.
- Incremental installer tested on LF, CRLF and mixed source/patch checkouts with identical outputs.
- Qt 6.12 production QML event harness at 1400×900, 960×720 and 1920×1080, 4,080-row fixture, virtual delegate bound, sticky header and existing row/context actions.
- Actual mouse/keyboard events for append/delete/paste/clear/repeated searches, metadata notifications and real model resets, no-match input focus and folder reentry.
- Every rear cover's independent hit area and target label, actual thumbnail navigation, retained stack across model resets, rapid-click suppression and reduced-motion double-click guard.
- Compiled actual PlaylistMagazine/MusicData/queue implementation with Qt model tester and controlled API boundary: full-page latest-query search, clear during requests, artist/album matches, failed-load release and successful following search, authoritative hearts, plus existing queue/bulk/download fixture regressions.
- Compiled production like method: server-ID direction, confirmed like/unlike, failed like/unlike, unknown-state fetch and logged-out refusal.
- Compiled production FM session methods: personalized service route, ongoing refill, real captured dislike ID, next during feedback, rejected/confirmed feedback, exact normal queue/song/index/mode/position/paused restoration, late reply/account guards.
- Changed QML accepted by Qt 6.12 cache compiler. Changed C++ and Windows UI-check source pass local syntax checks with Qt 6.4 headers and the existing forward declaration for newer QAudioBufferOutput.
- Existing queue interaction/retained Following/profile QML tests and repository/resource audit.

The local Qt 6.12 reset stress harness prints a DelegateModel cancellation diagnostic during rapid zero-row resets; its input, identity, action, row-count and focus assertions pass. It does not represent live-account or GPU validation.

New G70 Windows actual-window checks have been added but have not run locally. Windows/GPU and real-account acceptance remain pending the single submitted Windows build. No claim is made that local API/audio fixtures prove live recommendation quality or account permissions. Stop after triggering that build, as requested.

## First Windows G70 run: exact FM restoration fix

Run `40658005001` compiled successfully. Its actual-window search typing/deletion/paste/clear/focus checks, real like rejection/like/unlike checks, exact thumbnail choice, FM entry from a playlist, continuous FM skip and real dislike dispatch all passed. The remaining failed check was exact ordinary-context restoration after leaving FM; it is retained unchanged, with per-field diagnostic booleans added.

The old leaveRoam called the general play(previousSong, previousQueue, previousIndex) path. That path intentionally treats its source argument as a new playlist: it deduplicates identities, maps queue provenance onto the selected song and can replace heart mode. These operations are appropriate for new playback selection but not for restoring an immutable saved context. The corrected restoration reinstates the original queue/current/index/mode, then resumes media through a narrowly scoped restoration flag that skips only this queue-selection block. Normal manual playback and in-session FM picks use the existing path. Returning to an empty/incompatible ordinary context invokes the existing stop implementation before restoring its empty snapshot.

The local FM regression now compiles the actual production play queue-selection prefix in addition to the real FM session methods; only media preparation remains a fixture boundary. The old code reproducibly fails a mixed-origin duplicate queue. The fix passes exact order/duplicate/source preservation, original duplicate index/current metadata/heart-mode restoration and empty-session stop, alongside existing refill, feedback, pause/position and stale-reply tests. The earlier simplified play fixture did not cover this queue-normalization boundary.
