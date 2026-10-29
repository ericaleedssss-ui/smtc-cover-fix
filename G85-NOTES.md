# G85 archive metadata and column controller

Incremental changes on the successful G84 build cb19ddf. Original glass bounds/material, background, cover animation and footer transport design remain unchanged.

- Metadata uses natural content widths: avatar and individually linked artist names, tags separated by /, track count, and actual creation date. Long artist names reuse the existing ping-pong marquee. Album dates are publication dates because the API does not supply an album creation date; absent tags/date remain visibly unavailable. Full labels are available on hover when truncated.
- Collection heart uses the existing user-supplied song-like-on/off artwork. Soft hover feedback covers title, artists, creator avatar, rows and existing action buttons.
- Existing native column actions back a small QML controller, centered below the shared archive card: previous / dynamic position+name / next, plus a thin animated progress line. No blur or large container. The separate next-item down arrow aligns with the card left edge. Source count/order and keyboard/wheel actions are unchanged.
- Remove obsolete landing navigation ticks/hints, duplicate native Tab block and archive footer session/credit text. Native directory navigation and footer remain intact.
- The real MusicLibrary::followPlayback now retains archive browsing selection/content when transport selects a track. Explicit detail/lyrics opening and the existing detail/roaming follow behavior remain unchanged.

Validation: QML cache compilation and actual software/OpenGL rendering at 1600x900, 960x540, 960x720, 1920x1080; compact row fits, nav center/spacing/down alignment, actual navigation clicks, dynamic numbering, selected heart artwork, artist links, scroll exceptions and record transitions. Compile/run the actual production followPlayback method against archive/detail/roaming cases; original adapter model regression and existing detail QML regression. API fixture checks creation/publication dates and real tags. Windows UI self-test additionally emits the real player's trackSelected signal and requires archive selection, folder, mode and QML content identity to remain stable. Clean source and embedded patch integrity checks protect original glass/playback files.

Reference figures 2/3/4 mentioned in the request were not attached to this turn; layout follows the written requirements. Live API availability of tags/creation date and physical Windows GPU behavior still require acceptance. Windows build result is reported separately.

Changed files: maintained/Qt/qml/{ArtistMarquee,PlaylistShowcase,ArchiveNavigator}.qml; maintained/G79-ui-checks.cppfrag; maintained/Qt/tests/g82-archive-client.mjs; scripts/{apply-maintained,enable-g85,verify-build-source,test-g79-qml,test-g85-playback}.py; workflow labels/build info; this note. NativeHud.cpp, MusicDirectory.cpp and Main.qml integrations are applied by enable-g85.py.
