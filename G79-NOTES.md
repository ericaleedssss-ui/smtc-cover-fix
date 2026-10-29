# G79 — archive playlist showcase and footer heart consistency

## Scope and final direction

The user's final instructions override the initial copied fixed-size constraint: the archive playlist panel may be enlarged to match the spacious second reference. The new panel occupies x=120, y=160, width=stageWidth-168, height=680 in the existing 1080-unit stage. It retains the existing LiquidGlass material/background and archive navigation/footer. Only playlist selections in archive mode outside a directory use this presentation; song, artist, detail, profile, message, queue and FM pages keep their previous layout.

`PlaylistShowcase.qml` places information on the left and the selected playlist's actual cover stack on the right. It reuses `RecordStack.qml` with an opt-in editorial pose (main slight tilt, unequal rear offsets/angles). Defaults and the 460ms identity-preserving turn/decode/cache logic are unchanged for the existing detail page. It never substitutes song art for playlist cover art.

## Real actions and data

`PlaylistShowcase` is a presentation adapter over existing MusicLibrary/MusicApi/MusicPlayer. It loads the selected playlist through existing `detail`, and incrementally completes missing song metadata through `songs` in batches of 100. Requests are account/selection scoped. Metadata completion is serial and leaves playback/append available; it computes total duration only from a complete, valid duration set. Errors/omitted metadata display an unavailable duration, never a partial sum presented as the total.

Play-all and shuffle build the complete queue from actual playlist song IDs, including existing deferred-song entries for metadata not yet loaded, with playlist provenance. Existing MusicPlayer playback, shuffle and enqueueMany implementations perform the operations. Cover selection uses existing selectResult, preserving library/physical selection alignment. Collector writes reuse MusicLibrary::mutate and actual playlist/subscribe; cancellation requires confirmation and a captured playlist identity. Shared cache/current/list fields update only on success. Own playlists remain non-collectable.

The more menu provides real playlist details, append-to-queue, copy-link and retry. Creator opens the actual user page when its ID exists. Retry invalidates stale metadata and request generations without reloading the application.

## Input

- Enter: play all in overview; play the selected song while browsing tracks.
- Space: shuffle the selected playlist.
- F: collect, or open confirmation to cancel collection.
- Tab: switch overview/description versus the scrollable track list.
- Left/right: switch playlists through the same RecordStack turn mechanism.
- Up/down: show the track list and move the song selection, loading missing metadata as needed.
- Wheel in overview: switch playlists. Wheel in track mode: scroll tracks instead, including otherwise-unclaimed archive wheel events; it cannot accidentally change playlists at list boundaries.
- Track list has a short top/bottom alpha mask using the existing magazine-edge shader, with a software-rendering row-opacity fallback. There is no extra frosted layer over the songs.
- Context menus/confirmation dialogs suppress the card shortcuts; Escape closes those overlays first. Buttons do not steal Space from the documented shortcut. Native search/navigation keys retain their original focus owner.

## Footer

NativeHudPlayer uses exactly the existing song-like-on.png / song-like-off.png assets at the same 24-unit size as SongHeart. Unknown initial state is shown as pending rather than confirmed unliked; the existing shared ensureLikedIDs request is initialized for playing tracks. Writes still use music:like-current and the original cache/refresh logic. Pending writes disable repeated footer clicks. FM dislike retains the existing action and uses the same off-heart artwork plus its existing diagonal rejection stroke. The comment action, both count positions, transport and FM mechanics are unchanged.

## Validation and limits

- Compiled the actual new C++ adapter against explicit asynchronous Qt domain fixtures: playlist-only art, complete deferred queue, shuffle/append, song selection and metadata completion, duration honesty, canonical cover selection, confirmed subscription/unsubscription, copy, failures and stale/account responses passed. Player/domain fixture methods are not a live service delivery test.
- Exercised the actual QML with mouse and real key/wheel events at 1600x900, 960x540, 960x720 and 1920x1080. Play/menu actions, Space/F/Tab/arrows/Enter, wheel routing, forward/reverse cover turns and stable image source passed.
- The same component rendered with actual Qt Quick OpenGL RHI on Mesa llvmpipe and the bundled glass/list-mask shaders; screenshots inspected. This is not a physical Windows GPU frame-rate measurement.
- Existing G71/G75/G76 QML regression checks passed, including search/hearts, both cover directions, stable identity and delayed cold-image turns.
- Clean upstream + G53 + G57–G79 overlay reconstruction and source verification run before submission. The only changed protected playback file is NativeHudPlayer.cpp for the explicitly requested artwork; its expected hash is updated. MusicPlayer/FM/controller/lyrics files remain protected and unchanged.
- Windows native QA checks the real archive adapter/Host metadata, right-side stack and copy-link action. Existing directory/detail, queue, message and player tests remain enabled.

Build artifact: Rhine-G79-Playlist-Showcase-Windows-x64. The Windows workflow result is separate from local checks. Per user instruction, stop after submission; do not poll the build.
