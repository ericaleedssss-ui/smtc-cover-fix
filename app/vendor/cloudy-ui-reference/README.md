# Cloudy UI source baseline

These twenty-one Go files are byte-for-byte copies from `internal/app`,
`internal/player` and `internal/netease/songtags.go` at
https://github.com/nya-owo/cloudy/tree/250da6df710fef0534e06ae518b52c5e22dd2e31.
`SOURCE.json` records their SHA-256 hashes. Upstream license: AGPL-3.0-only,
preserved at `../../licenses/cloudy/LICENSE`.

Production uses Qt Quick. These source files are the retained baseline;
the Qt adapters, rather than the Go files, are compiled into RHINE:

| Source | Adapter |
| --- | --- |
| `icons.go` SVG markup | `Qt/qml/RhineIcon.qml` (original SVG strings) |
| `ui_nowplaying.go` stageBar | `Qt/qml/SongDetailPage.qml` |
| `ui_main.go` topBar / `ui_nowplaying.go` nowPlayingBody, lyricsPane, queuePane | `Qt/qml/SongDetailPage.qml`, `Qt/qml/SongQueue.qml` |
| `ui_player.go` artistLinks | `Qt/qml/RhineCreditLine.qml` (user override: hover brightness, never underline) |
| `ui_player.go` scrubber lens (hover/held only, 30×18 capsule, Clear glass, 1.25 held scale, shadow) | `Qt/qml/GlassSeekThumb.qml`; bottom player and both detail sliders; actual MyGo Clear lens/tone/rim shader adapter, deferred reveal after the existing track-change trail |
| `ui_stage.go` stage | `Qt/qml/LyricStage.qml`, `Qt/qml/SongDetailPage.qml` |
| `ui_comments.go` commentsPane/commentRow | `Qt/qml/SongComments.qml` |
| `ui_wall.go` wallPane/wallSong | `Qt/qml/SongWall.qml`, `Qt/shaders/cloudyWallFrost.frag` |
| `ui_mine.go` foldHead/orderChip/foldGrid | `Qt/qml/UserProfile.qml` |
| `ui_expand.go` motionPane duration / easing | `Qt/qml/RhineContentMotion.qml` (ready-gated Qt fade and light movement) |
| `ui_effects.go`, `auto_effects.go`, `netease/songtags.go` | `Qt/qml/SoundEffectsDialog.qml`, `Qt/src/SoundEffects.cpp` |
| `player/effects.go`, `player/reverb.go`, `player/spatial.go` | `Qt/src/AudioEffects.h`, real decoded PCM output in `AudioPlayer.cpp` |
| `ui_pages.go` coverCardOf/coverFill | `Qt/qml/UserProfile.qml` |
| `ui_kit.go` barState/step/group/drawBars; `ui_pages.go` nowPlayingBars | `Qt/qml/PlayingBars.qml`, shared by song lists and the player shortcut |
| `player/stream.go` spectrum/feed/analyze/fft | `Qt/src/AudioSpectrum.h`, decoded PCM adapter in `AudioPlayer.cpp` |

The spectrum adapter retains the 1024-point Hann FFT, 24 logarithmic bands,
normalization, frequency tilt and source bar response. Qt supplies decoded
mono PCM and playback timestamps; a bounded cache is cleared on seeks/source
changes. Full-motion foreground playback enables analysis; pause decays to rest.
The stage-style selector is intentionally merged into the selected stage tab,
and hover explanatory tooltips are suppressed, following RHINE user preferences.

`mygo-glass/` preserves the actual progressive blur implementation used by
Cloudy's pinned UI dependency, under its original MIT license. RHINE ports
its doubling sigma levels, variance addition and gradient weighting to Qt
texture passes (`cloudyGaussian.frag`, `cloudyBlurLevel.frag`). The Gaussian
sampling is a Qt adapter; this is not a claim of identical GPU output.

It also preserves `glass.go`, `glass.glsl` and `pixels.go`. The seek lens uses
their Clear material (`low=.125`, `high=1.082`, 1 DIP blur, bezel half the
short side, refraction 1.6×bezel, rim .35) and the original lens/normal/tone/rim
equations in `Qt/shaders/clearSeekGlass.frag`. Qt captures background and the
live progress rail separately, composites them before the lens, and uses a
small Gaussian sampling kernel. No painted white gradient or highlight strips.
The rail is evaluated from the shared live Canvas geometry/colors before
refraction; sibling-local coordinates avoid QML mapToItem returning the initial
zero origin. Hover restores upstream's 6 DIP line and a neutral high-contrast
played color, while the idle feathered sage rail is preserved.

Run `python migration/import-cloudy-ui-reference.py` from the project root
to reproduce the Cloudy snapshots and the additional original SVG imports
from the pinned local checkout.
