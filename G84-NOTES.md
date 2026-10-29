# G84 archive handoff, wheel latency and artist pixels

Incremental changes on G83; original glass, footer controls, detail-page record-turn geometry and roaming remain unchanged.

- Archive group exit/entry: 64 logical pixels, 0.90 scale, 170ms out / 270ms in; reverse by column order. Lane identity participates even when the selected key is unchanged. Reuse card identities and retain image content instead of clearing four cards at the handoff.
- Preserve the collection Loader through temporary native visibility changes and empty column selections. Actual song/directory views retain their original content behavior.
- Wheel bursts coalesce to one recent direction (750ms expiry) instead of replaying four complete turns. Reset fractional carry between gestures. A slow non-target image no longer blocks an archive turn. Request 512px NetEase CDN thumbnails using the same URL for painting and preload; keep async decode at group commit.
- Artist lookup starts independently of full album tracks, favors /artist/detail over potentially generic subscription artwork, falls back to /artists on missing URL or image failure, and rejects stale selection/account replies. Preserve subscription artist identities when detail omits them. Host.loadCover downloads/decodes a 96px avatar through the shared native cache; QML receives decoded PNG pixels. Inflight lookup is deduplicated. No album artwork substitutes for artist portraits.

Validation: actual C++ adapter compiled and ran with decoded PNG / failed-image fallback / stale request fixtures; QML cache precompile and real software/OpenGL rendering exercised middle-of-animation displacement, reverse groups, cold front images, slow non-target images, Loader identity, independent scroll regions and rapid input. Existing G71/G74/G75/G76 detail-view regression retained. Clean pinned-source overlay and protected-source verification passed. Windows build submitted separately; live signed-in CDN/artist behavior and physical Windows GPU performance remain user acceptance items.

Files: maintained/Qt/qml/{ArchiveReading,PlaylistShowcase,RecordStack}.qml; maintained/Qt/src/PlaylistShowcase.{cpp,h}; maintained/G79-ui-checks.cppfrag; scripts/{apply-maintained,enable-g84,test-g79-model,test-g79-qml,verify-build-source}.py; workflow label/artifact names; this note.

Build submission correction: restore the canonical embedded G53 gzip payload after a version-label replacement altered base64 content. Verify gzip CRC and SHA256 for both workflow payloads, require Rhine payload byte equality to patches/G53-base.patch, and run this integrity check from source verification. No application behavior changed in the build-only correction.
