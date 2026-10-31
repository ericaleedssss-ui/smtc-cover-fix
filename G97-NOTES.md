# G97 — coordinated tonearm and record transitions

The playing arm moves slightly upward/right and is 4% longer than G96 so more of it is exposed. Its entire sampled shaft/headshell sweep stays outside the etched title ring and printed cover. Original glass, artwork size/placement, perspective, lyrics, footer and playback/navigation operations are retained.

## Motion ownership

- A single bound arm target owns pause/resume and record-change clearance. A 500 ms sine easing moves from the current pose, including reversals; repeated player/lyric notifications never stop or restart the arm. Same-song buffering retains the last stable pose. A new song still loading keeps the arm clear until actual playback is ready.
- Record replacement prepares decoded incoming artwork and waits for arm clearance before one 650 ms sine-eased swap. Two persistent physical decks exchange roles, preserving loaded images and text instead of copying the incoming cover back to a different renderer at handoff. Both decks use the shared rotation clock.
- Latest selection replaces a target while preparing. During a running swap, the two painted identities stay frozen and the latest selection is queued for the next swap; the arm remains out across chained swaps. Returning to the original song during preparation cancels the unnecessary replacement.
- Missing artwork waits at most 1800 ms before allowing a bare vinyl fallback. A new song never borrows the previous song's cover. Late real artwork fades in. Metadata updates with identical title/artist do not rebuild every etched glyph. Identical lyric-scroll targets no longer restart the follow animation. The adapter exposes loading separately and emits one playback notification per sync rather than two.
- Reduced motion settles without interpolation. Preparation is guarded against synchronous zero-duration animation callbacks.

## Verification

Actual production QML was loaded and exercised on Windows with PySide6/Qt 6.10.1, software rendering and hardware D3D11 on an NVIDIA GeForce RTX 3080 Ti. Release QML bytecode and all existing shader targets (GLSL/HLSL/MSL) compiled. The regression covers intermediate pause/resume poses, reversal continuity, repeated backend updates, buffering, new-song loading, rapid/queued/cancelled replacements, pause during replacement, retained deck identity, missing/late artwork and reduced motion. Existing four-layout geometry, original-glass identity, lyric wheel/follow/seek, title/album links, shared song actions, global shortcut, pause/hidden rotation and rounded clipping checks also passed. Inspected actual rendered artwork and upper-right arm placement. Offline fixture covers are used only by tests.

Framebuffer probes account for display pixel ratio. The unchanged fade shader's outer-edge tolerance covers 1x OpenGL and 2x D3D antialiasing; rounded-corner clipping and partial edge opacity remain required. Actual hardware light-phase differences remain small in the lyric region (maximum 2/255 in the final local check).

Windows native UI self-tests additionally exercise the real C++ player adapter through arm intermediate poses, notifications, reversal, buffering and rapid song replacement. CI now rejects NowPlayingPanel TypeError/ReferenceError output even if other UI checkpoints succeed. Job, ZIP and artifact labels identify G97; embedded base patch CRC/SHA and canonical bytes remain unchanged.

Complete Qt 6.12/MSVC build, native integrated checks and portable packaging run in CI. Local QML/fixture checks are not a claim of live-account validation or measured end-to-end frame-rate improvement; final subjective smoothness and placement are reviewed in the downloadable player.
