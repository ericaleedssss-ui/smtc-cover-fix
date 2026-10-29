# G89 — a recognisable record and visible travelling ripples

## Changes

- `maintained/Qt/qml/NowPlayingPanel.qml`: keep the same original glass bounds/material. Fit a still-large record inside the right region so its thin edge is visible. Separate the platter from the halo compositing field: left-side halo attenuation no longer dissolves the platter itself. Lighten the contact shadow, restore a thin rim, a small central hub and stationary sheen; only album artwork rotates. Keep the existing transparent artwork treatment.
- `maintained/Qt/shaders/recordAtmosphere.frag`: narrow artwork feather from `.455–.50` to `.495–.50`, restore a defined rim/highlight and replace four overlapping broad bands with three separated travelling soft fronts. These can reach slightly into the lyrics but use a strong left attenuation. No new blur, timers or audio analysis. Playback state still drives animation; this is not beat detection.
- In the same QML component, album title now follows actual song-title height with a 7-unit gap. It is clickable only with a usable album ID. Lyrics increase from 17 to 22 design units, use 78-unit minimum rows and follow the current row at the start of the existing 161-unit viewport, giving roughly the current and next lyric with translations. Wheel browsing, hover time, click seek and both fades remain. Long lines may wrap and reduce the visible row count.
- More moves out of the action capsules into a quiet text entry beside the lower-right detail link. No double circular background or ellipsis. The original menu remains, positioned within the card.
- `maintained/Qt/src/NowPlaying.cpp`: identity-checked album action. `scripts/enable-g89.py` and `scripts/apply-maintained.py`: connect `player:song-album` to the existing album directory/details path using the **playing** song's real ID/provider, never the unrelated browsed selection. Preserve transport and record normal return history.
- `scripts/test-g86-qml.py`: actual album click/layout, relocated More, larger lyrics, four viewport sizes, and real GPU pixel comparisons at different ripple phases. `scripts/test-g86-model.py`: production model emits the new album action. `scripts/test-g89-album.py`: compile the production album-handler body with actual MusicData normalization and explicit navigation fixtures.
- `scripts/verify-build-source.py`: reviewed native navigation hash. `.github/workflows/build-smtc.yml`: G89 readable labels/artifact only, embedded patches untouched.

## Actual validation

Local OpenGL QML/shader test passed. Compared rendered frames at phases .03 and .18 with the artwork and other animation frozen: maximum halo-region channel change 30/255, aggregate sampled change 39702; maximum lyric-area change 1/255. This verifies an actually changing rendered ripple, not merely an animated property. Inspected both real frame captures: platter remains defined and stationary, with the moving atmosphere around it. Test artwork is an explicit offline fixture and is not shipped.

The same QML checks cover four window sizes, original glass identity and disabled-background sampling, fixed perspective at four artwork orientations, pause/hidden stop, lyrics scroll/follow/seek, album/title clicks, comments/heart/share/collection, More and the existing global now-playing shortcut. Software QML also checked; full optical effects require the GPU backend.

Production NowPlaying C++ model and playing-album route fixtures passed, including different browsed vs playing album IDs, missing/zero album IDs and unchanged song/queue/position. Changed native files receive syntax checking against actual project headers (local multimedia backend opaque), plus integrated Main QML release bytecode/source and embedded-patch checks.

Complete Windows build/integrated UI run, live album API responses and signed-in account operations remain pending at submission. The source uses the existing album flow; no live-service success is claimed. Physical GPU performance and the user's visual acceptance remain to be checked. Other footer controls, collection covers, roaming and navigation design are not redesigned in this change.
