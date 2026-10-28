# G69 — playlist magazine and shared song actions

Base: verified G68 commit `7d7015e74fb7a595cc77e5e5532df6138cde19cf`.
Upstream remains pinned to `b8b8ad5ed661fa32404731f1b09f7c37d34bf070`.

## Changes

- One shared glass capsule provides working Search, My Music and Settings actions. A compact brand replaces the large global heading. Ordinary detail pages use one back icon; existing ESC and overlay priority remain in the backend.
- Playlist details use a virtual QAbstractListModel/ListView with a scrolling magazine header, real creator/date/count fields, comments/subscribers, search/filter, and a separate compact sticky header. Song rows are at least 58px, with cover playback, individual artist links, album links, likes and more actions.
- At most three real accessible collection covers are selected in stable order from the already loaded personal library and the previously visited folder. Missing/duplicate covers are omitted. No synthetic cover is installed in production.
- The 520ms record extraction animation navigates through real internal history. Reduced motion switches immediately. It never changes playback or the queue. Albums retain their existing detail page.
- Per-folder scroll/search/filter/tab state survives navigation and independent queue/picker overlays. Cancelled detail requests are resumed when returning to an unfinished folder; generation checks discard out-of-order replies.
- The shared song context menu captures the clicked scope, source index and identity. It supports play, play next, real comments/count, existing collection picker, authorized download, song share/copy, and permission-dependent removal. Playlist, queue, discovery, profile, recommendation and native HUD list surfaces use the same controller. A changed queue index cannot silently target a different song.
- Playlist more actions share the real ID, enter multiselect, or append the full playlist. Append-all loads all metadata pages, skips unavailable/duplicate entries and preserves the current song/index. Mutations run sequentially in bounded 100-ID requests with confirmation for deletion and failure feedback.
- NetEase downloads request an authorized standard-quality download URL, stream one file at a time, reject HTML/trial/ungranted responses, and commit complete files atomically under Downloads/RhineMusic. Existing files are retained. Cancellation/account changes invalidate outstanding replies and discard partial files.
- G68 independent queue state and bounded acyclic live glass sampling are retained. The magazine is included as a lower live surface for the queue; opening the queue does not replace the page.

## Actual build path

`G53 patch → scripts/apply-maintained.py → scripts/enable-g69.py → patches/g69-magazine-playlist.patch + maintained/Qt/...`.

New QML/core files are copied from maintained sources. Existing upstream changes are applied by the G69 patch. CMake registers the new controller and QML resources. The Node test runner includes the new client tests. The workflow continues fetching the exact triggering SHA, writes source hashes, and includes new real-window checks.

## Checks executed locally

- Full rebuild of source from a clean pinned-upstream checkout through the entire patch chain: passed.
- Actual G69 installer on LF, CRLF and mixed checkouts/patch files: byte-identical outputs.
- Build source verifier: correct source accepted; wrong commit, stale overlay source and stale maintained queue rejected.
- Qt 6.12 production QML event harness, with an explicit offline 4,080-row model: passed at 1400×900, 960×720 and 1920×1080. Real mouse events exercise cover play, row context menu/next, global search and exposed rear-cover navigation. Sticky header appears; fewer than 60 row delegates are retained; one record click causes one navigation after the animation. Dark/reduced-motion bindings are exercised.
- Compiled production PlaylistMagazine.cpp, MusicData.cpp and production enqueueMany implementation against Qt Core/Network/Test and explicit domain fixtures: passed with QAbstractItemModelTester. Includes stable collection order, no unnecessary resets, immutable collection capture, append/dedup/no playback, clicked-song targeting, owner permissions, confirmed/rejected deletion, stale social replies, scroll restoration, all-page loading, 205-song three-chunk deletion, account cancellation, and local HTTP streaming success/HTML rejection/cancellation.
- Executed the production detail-request helper with controlled out-of-order replies: duplicate requests suppressed; old A/B responses discarded; returning to cancelled A resumes and completes consistently; failures stop without retry loops.
- Existing G67 queue QML interaction and retained Following/profile overlay tests: passed, including queue wheel/play/collect/close and original page instance/filter/scroll retention. The overlay fixture now explicitly supplies the new inactive magazine Loader.
- All ten changed QML components accepted by the Qt 6.12 cache compiler.
- Nine changed production C++ units and UiChecks.cpp passed local syntax checks using Qt 6.4 development headers. A forward declaration stub covers QAudioBufferOutput, which was introduced after those headers; this is not a full Qt 6.12 application build.
- Three new Node client tests passed: actual metadata/missing fields, privilege joining by song ID, full playlist IDs/rights without playback. Existing selected pure-client regressions passed.
- Public-source repository audit and whitespace checks: passed.

Reproducible local commands (from this patch repository):

```sh
python scripts/test-g69-model.py /path/to/applied/source --qt-prefix /path/to/qt/usr
python scripts/test-g69-navigation.py /path/to/applied/source --qt-prefix /path/to/qt/usr
python scripts/test-g69-qml.py /path/to/applied/source
python scripts/test-g69-patch-eol.py /path/to/committed/applied-G68
python scripts/test-g67-queue.py /path/to/applied/source
python scripts/test-g67-overlay.py /path/to/applied/source
python scripts/test-build-source.py /path/to/applied/source
```

## Pending Windows/live verification

No Windows build has been triggered for G69, as requested. The new Windows real-window checks are added but have not run. They exercise actual row right-click/copy/next, cover playback retaining the playlist, independent queue/page-instance/scroll retention, and real internal cover navigation/back without playback changes.

Local tests use explicitly synthetic offline account/data/API boundaries; they do not prove live-account mutation permissions, paid-track downloads, all provider variants, or GPU frame time/refraction quality. The offline preview shows actual QML layout with test art and a plain test background, not the live architectural scene. Final visual/performance and real-account acceptance require the pending Windows build/run.

## First Windows run and batch-check correction

Run `40647708446` compiled and deployed successfully. All G69 real-window checks passed: real right-click/copy/next, cover playback retaining the playlist, retained queue/page/scroll, record navigation/back without playback changes. Existing Following/profile/glass/source/interaction checks also passed.

The run stopped at the legacy queue collect-all assertion, which compared the final request alone with the full 4,079-song snapshot. G69 intentionally submits at most 100 IDs per request. The corrected Windows fixture accumulates every successful request, compares exact ordered IDs and uniqueness against the immutable snapshot, checks destination and add operation, verifies the 41 bounded requests, and checks that a rejected first request stops the chain while preserving the full selection for a deliberate retry. No production behavior or acceptance check was disabled.

An additional compiled test executes the unchanged production playlistTracks/playlistTracksPage methods and actual MusicData implementation with an asynchronous mutation boundary. It tests 4,079 IDs, completion only after the last batch, second-batch failure, deliberate retry, account change and the 101-song boundary.

```sh
python scripts/test-g69-collection.py /path/to/applied/source --qt-prefix /path/to/qt/usr
```

Live-account acceptance and final GPU/performance assessment remain pending.
