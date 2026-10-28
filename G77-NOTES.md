# G77 — Rhine message center

Scope: only the existing inbox, its drawer/conversations, message state, API allowlist, build integration and QA. G76 record animation, FM, player, queue and navigation implementations are unchanged.

## Audit and real API integration

The existing `GlobalTools.qml` inbox was disabled (`私信 · 尚未启用`); no message store or conversation page existed. A persistent `MessageCenter` list model and `MessageDrawer.qml` now supply these. Engine exposes the controller and connects destination actions to the existing dispatcher. Existing MusicApi -> Host -> private worker IPC -> pinned NetEase module transport is reused, including account-generation validity, Cookie scoping and acceptance. No webview, second login system or new service is introduced.

Pinned package: `@neteasecloudmusicapienhanced/api` 4.41.1; upstream tag commit `2db6684453297ee86dec0492842f2320b08182d9`. Its source modules and documentation were checked before implementation.

| Operation | Public route / worker module | Parameters | Actual upstream route / response consumed |
|---|---|---|---|
| Unread counts | `/pl/count` / `pl_count` | current authentication | `/api/pl/count`; numeric msg/comment/forward/notice; absent counts stay unknown |
| Private threads | `/msg/private` / `msg_private` | offset, limit 30 | `/api/msg/private/users`; msgs, fromUser/toUser, lastMsg JSON, lastMsgTime, newMsgCount |
| Comments | `/msg/comments` / `msg_comments` | own uid, before, limit 30 | `/api/v1/user/comments/{uid}`; comments, updateTime |
| Mentions | `/msg/forwards` / `msg_forwards` | offset, limit 30 | `/api/forwards/get`; forwards |
| Notices | `/msg/notices` / `msg_notices` | lasttime, limit 30 | `/api/msg/notices`; notices with notice JSON |
| Conversation | `/msg/private/history` / `msg_private_history` | other uid, before=time, limit 30 | `/api/msg/private/history`; msgs, time, more |
| Send text | `/send/text` / `send_text` | user_ids, msg | `/api/msg/private/send`; official module creates type=text and userIds array; explicit code 200 required |

All require a valid NetEase account; comments require the authenticated user's own UID. Unsupported platforms/login-required states are explicit. API/auth/transport failure text is replaced with a safe error; credentials and private message bodies are not logged.

## Behavior

- One right-side modal overlay; lightweight slide/fade; close/outside/Escape; no bottom-page navigation/rebuild. Responsive bounded width and height.
- Material follows reference C: bounded half-resolution static background capture, local blur, roughly 92% warm neutral tint, subtle edge/shadow. RHI supplies the blur; software renderer retains the readable tint. No full-window live blur.
- Four real, paged categories with server counters; stable-key same-order refresh updates rows in place. Polling only while open, every 45 seconds, plus explicit refresh; initial opening fetches the selected page and counters, not all histories.
- Thread summaries, actual avatar/profile badges, time and server unread counts. Missing avatar has one consistent fallback. Unknown message types are labelled, never simulated.
- Text conversation/history, older-page fetch, real send confirmation, duplicate-submit suppression, failed-send draft retention, conversation-specific in-memory drafts preserved across panel close/reopen. Account change clears all private state and rejects late replies.
- New conversations can start by entering another user's numeric ID. Sending to oneself is blocked. Ctrl+Enter sends; 1000-character limit.
- Received image messages render when the API supplies a picture URL. Song/album/playlist resources can use existing in-app destinations when recognized. Deleted/unrecognized notification targets show a clear limitation instead of opening an unrelated page.

## Explicit API limitations

The pinned dependency exposes no dedicated mark-all-read or per-message read/recipient-read-receipt module. “一键全读” explains that limitation and changes no counts; reading history refreshes server counts without assuming that the fetch marked messages read. No local fake clearing, guessed raw write endpoint, delivery/read receipt, image upload or fake successful send is implemented. Some notice/event types do not provide a supported in-app resource destination. Unknown count fields remain unknown. Drafts survive panel/conversation closure, not application termination.

## Validation

- Compiled actual MessageCenter.cpp with Qt against the existing asynchronous domain/transport fixture: four categories, real request parameters, count preservation, chronological history/paging, duplicate send, confirmation/failure, draft retention, redacted errors, malformed response, logout and stale-account isolation passed.
- Actual production drawer QML tested by desktop input: four tabs, typing, send, draft restore, refresh, close/outside and 960x540 / 1920x1080 resizing passed.
- Actual Qt Quick OpenGL RHI render on Mesa llvmpipe, using the basic render loop for the Python harness, passed; rendered screenshots inspected for readability/material. This is not a physical Windows GPU/frame-rate measurement.
- Clean G53 + all maintained overlays regenerated, installer assertions and JS syntax checked. G71 controller, G70 liked-state and G75 return-source regressions exercised separately.
- Windows workflow retains full MSVC build, native visual checks and offline packaged regression suite. Added a native Engine/Host/controller/QML message test and packaged real-NetEase-module IPC checks (upstream HTTP mocked). Native screenshots include `preview-message-center.png` and `preview-message-conversation.png`.

No real signed-in account or real recipient was used to send test messages. Live service permissions, full response variations, anti-spam limits and recipient delivery require account-based validation; offline success must not be described as live delivery success. Windows build outcome is reported separately from these local checks.

Changed implementation: MessageCenter.h/.cpp; MessageDrawer.qml; installer enable-g77.py (existing GlobalTools, Engine, CMake, worker allowlist and QA integration); apply-maintained.py. QA: G77-ui-checks.cppfrag, test-g77-model.py, test-g77-qml.py, source-verification markers and workflow label.
