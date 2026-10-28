# G71 — ordered collection sessions and lighter playlist/account UI

Base: successful G70 `02daf3581326b859756b9bace15031ca9c08368d` (run `40660153678`). Work began from clean bootstrap/source checkpoints. The G70 music player, private-FM controller/transport, lyric reader, queue and bottom-bar sources are protected by normalized text hashes in the build-source verifier.

## Changes

- The persistent search editor still submits every edit immediately and demand-loads all current playlist IDs. The compact caption now expands and collapses, keeps a nonempty query/result set when collapsed, shows a clear affordance, and exposes an I-beam over the editable area. A page-scoped outside-press observer excludes the editor and rejects its own press before deferring blur, allowing the clicked control to receive the action.
- Collection metadata is ordered by the existing created-playlist, collected-playlist and collected-album order, with exact provider/kind keys and an external entry anchor when needed. Only current/previous/next covers are rendered at full size. Existing personal-list APIs retain their initial 2,000-item metadata limit; real offsets and more/count flags now allow later pages rather than silently stopping at that first page. No full collection of high-resolution images is fetched.
- At an incomplete page boundary the UI requests the existing pager and does not pretend the last loaded item is the true end. Once complete, neighbours wrap naturally. Hover targets, thumbnails and names remain bound to exact keys. The 520ms directional transition and reduced-motion guard remain; the next page is prepared on entering each new target, not only the first hover.
- Cover selection uses a separate `music:collection-browse` action. It replaces the current directory's browse content while preserving its original parent/entry selection/return tab, and updates only the matching existing history target. It does not append a history entry, replay ESC, clear the stack, play music or replace the queue. Ordinary detail links retain their existing history path; album targets keep the existing album page.
- The playlist hero is shorter while keeping track row height/artwork unchanged. Title, folded real description, creator/tags/date and counts form the information group. Buttons are constrained to the main cover's bottom, regardless of description length. A bounded scrollable popup displays full plain-text descriptions.
- The sticky identity uses a small cover/title/play action without a full-width glass panel. The shared top bar uses actual cached account name/avatar, independent profile/menu targets, a conservative verified membership label, search/settings, and a clearly disabled private-message placeholder. Existing window controls retain their real actions and receive reserved space; the title-bar drag region excludes the account controls.
- Account menu items reuse existing filtered profile collections (the saved manager on other providers), settings, QR login and logout routes. Switching accounts explains that playback stops and requires the in-app dialog. NetEase membership is shown only as generic VIP when the real account response confirms a positive VIP type; SVIP rank and expiry are not invented. Unsupported profile providers are labelled/disabled; local music opens its existing library.
- The two supplied heart PNGs are copied unchanged into compiled `/icons` resources. QML and native list hearts use those same RGBA assets, preserve their colors/aspect ratio, and share the confirmed like-state/mutation logic. No optimistic fake-success state was added.

## Actual build path

G53 and the existing installers through G70, then `scripts/enable-g71.py`. Existing upstream modifications/resource registration/client tests are in `patches/g71-ordered-collections-account.patch`; maintained QML/controller sources and the original PNGs are copied into the reconstructed app. The Node runner includes the G71 paging/account tests. Exact triggering-SHA source verification remains enabled.

## Local checks passed

- Complete clean pinned-upstream reconstruction; LF/CRLF/mixed incremental installer output equality; build-source positive/negative checks.
- Real Qt 6.12 QML mouse/keyboard harness at 1400×900, 960×540, 960×720 and 1920×1080, with an explicit offline 4,080-track model. Typing/deleting/paste/cut/clear/no-result/reentry, noisy model resets, I-beam, retained-query collapse/reopen, compact-caption readability, short/long/empty-description button alignment, readable description popup, real account-menu action strings and window-button clearance passed.
- Ordered cover choices across more than three items, exact hover names/keys, auxiliary thumbnails, retained animation object, rapid-click suppression and reduced-motion double clicks passed.
- Compiled production PlaylistMagazine/MusicData/queue code with Qt model tester: existing bulk/queue/download/search regressions plus full ordered neighbours, later collection pages, no premature wrap and final wrap passed.
- Compiled actual collection navigation helper and actual parent-inheritance block: five consecutive replacements retain one original entry, selection and return tab; album kind and invalid-target rejection passed.
- Seven Node client tests passed, including real raw metadata fields, page offsets/more/count handling, actual account-avatar/VIP-type preservation and real string tags.
- Production native resource loader checked separately with Qt RGBA resources; original PNG bytes are retained and reused through the cache.
- Changed C++ controller/account/library/directory/HUD units and real-window QA source passed local syntax checks. Full Host.cpp cannot be syntax-checked against the available Qt 6.4 headers because pre-existing code uses newer QStyleHints APIs; the new resource-loader method is compiled separately. The full app uses Qt 6.12 on Windows.
- Existing real queue mouse/wheel/page/play/remove/collection tests and retained Following/profile QML tests passed. Repository/resource audit passed.

The rapid-reset QML fixture can print the same Qt DelegateModel cancellation diagnostic seen in G70; state/action/focus assertions pass. Fixtures do not prove live-account service availability, every membership entitlement, or Windows GPU appearance/performance.

## Pending build acceptance

New Windows actual-window checks cover persistent/collapsed search, description open/close, avatar/profile and account playlist actions, and one-step return from the collection browsing session. They have not run locally. Existing private-FM/queue/player/lyrics acceptance checks remain in the Windows suite unchanged. Submit one Windows build and stop once it is triggered, per the user's instruction.
