# G78 — unified right drawers

## Delivered changes

- The existing queue rectangle (`NativeHud::queueBounds`) is the single geometry source for both messages and queue: same x/y/width/height, same stage scale and footer clearance. It is exposed while closed as `drawerBounds`, so opening one panel never derives its size from the other panel's visibility. Message text keeps a readable scale floor.
- Both panels use the same `DrawerFrost.qml`: reference-C warm opaque tint, bounded half-resolution blur snapshot, restrained edge/shadow and matching corners. Queue no longer uses the highly transparent liquid-glass shader. The existing acyclic lower-page capture is shared and enabled for either drawer; no whole-window live blur was added.
- `DrawerInputGate.qml` binds the actual underlying visual surfaces disabled while either drawer is visible, including close animation. This cancels active hover feedback/tooltips and passive HoverHandlers as well as blocking clicks. Queue and overlay content remain enabled. A full-window catcher consumes outside gestures and wheel events; outside clicks close only the active drawer. Previous enabled bindings are restored after dismissal. Window chrome decoration stays visible while its pointer surface is disabled.
- Message title/back/actions use fixed anchors, not a variable-width Row. Conversation changes cannot shift the close/refresh buttons. Composition area is shorter. Both conversation sides have avatars, short bubbles fit their content, and timestamps include hours/minutes with nearby messages grouped.
- Unicode emoji picker inserts into the actual draft and existing text-send path. Known NetEase bracket face text (including `[生气]`) gets a semantic Unicode rendering; unknown bracket text stays unchanged. This does not reproduce the complete proprietary sticker/animation collection.
- Created/collected playlist arrows use equal header widths. Collapsed navigation rail is centred on the actual expanded drawer, including its minimum-top constraint.

## Scope and API limits

No changes to playback, FM, record turns, song search or private message protocol/controller were needed. Text sends, history, drafts and API limitations remain as documented in G77. Received pictures render when a URL is supplied. The pinned 4.41.1 module inventory was checked again: it exposes text/song/album/playlist sending but no private-message image-upload/send module. No inert image-send button or fake success is shown. No real recipient was used for tests.

## Validation

- Real production QML tests passed for original message interactions plus emoji draft insertion.
- Production GlobalTools + queue + message drawer + pointer gate exercised together: opening through an actual press; no outside click-through or hover; close-only outside action; input restored afterward; message/queue bounds match; close button stable between list/conversation; equal section-arrow X; rail vertical centring; resize at 960x540, 1280x720 and 1920x1080.
- The same UI harness rendered through Qt Quick OpenGL RHI on Mesa llvmpipe with the actual bundled liquid-glass/fade shaders. Screenshots inspected. This is not a physical Windows GPU performance measurement.
- Production MessageCenter C++ fixture tests passed. Existing G71 song-list/search/heart and G75/G76 record motion/identity/cold-image/reverse tests passed.
- Clean pinned upstream + G53 + all maintained overlays regenerated; source provenance and unchanged playback/FM hashes verified. Queue QML is intentionally updated and now checked against the maintained source instead of its old immutable hash.
- Added Windows native checks for exact message/queue geometry, active drawer versus disabled background, outside-click close without opening the search underneath, and queue pointer isolation. Existing retained-page and actual-footer queue checks remain enabled.

Windows build result is separate from these local checks; the submitted workflow must finish before claiming Windows acceptance.

Implementation: DrawerFrost.qml, DrawerInputGate.qml, MessageDrawer.qml, PlayerQueueGlass.qml, SideNavigation.qml; enable-g78.py integrates existing Main/GlobalTools/NativeHud/CMake and native QA. Tests: G78-ui-checks.cppfrag, test-g78-drawers.py, updated message harness and source verification. Build artifact label: Rhine-G78-Unified-Drawers-Windows-x64.
