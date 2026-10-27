# G66: layered glass and queue provenance

Queue visibility no longer hides the underlying navigation rail, reading glass,
or song-detail glass. The queue remains above navigation at z=350. It samples a
bounded composite of the actual page and navigation layers; neither source
includes the queue itself. Two half-resolution tiles cover only the queue and
its sampling margin, and are released when the queue closes. This establishes
an acyclic rendering graph instead of repeated raw-background samples.

Rows now show cover/title/artist/duration. Hover reveals source, collection,
and removal. Unknown sources remain disabled with an honest tooltip. Source
records contain explicit route/type/id/title/provider plus whitelisted route
parameters. They are captured by actual directory, discovery, result-list and
profile selections, not reconstructed from album membership or the current UI.
One-click directory playback also stamps deferred entries. Metadata cache hits,
async details, previous/next, append and mixed-queue replay preserve records.
Navigation uses existing directory/discovery/search/likes/profile handlers and
does not play a track or replace the queue. Legacy entries without saved
provenance remain unknown; history serialization already retains saved fields.

Validation performed locally: Qt 6.12 QML compilation; real QML mouse, hover,
wheel and page tests with 4,080 entries; repeated visibility checks at 720p and
1080p; known-source button dispatch and unknown-source no-op; original modal
rail hiding; LF/CRLF/mixed patch equivalence; clean upstream-to-G66 patch chain
and repository/project audits.

Additional compiled Windows checks cover per-entry provenance, one-click queue
creation, append, duplicate manual replay, mixed queue replay, metadata cache,
async enrichment, directory types, search/daily navigation and actual Loader
identity before/during/after the queue. Windows CI runs those checks after
compilation. Local software-renderer tests do not establish RHI visual quality,
GPU timings or authenticated online API behavior; these remain CI/device QA.

## Windows lifecycle follow-up

The first G66 run compiled and deployed successfully but access-violated in
Qt6QmlModels during the album-comments-to-track transition. This follow-up
stabilizes featured comment models, hides the comments page before deferred
teardown, and replaces the new QObject-array capture Repeater with two fixed
captures. The precise Windows crash root is not established by local software
rendering. No Windows QA assertion is removed; transition log boundaries were
added for diagnosis. Local coverage includes 40 page exits, 160 unrelated state
updates retaining featured delegates, wheel events, QML compilation and the
existing layered-glass/source test. A Windows rerun is still required.
