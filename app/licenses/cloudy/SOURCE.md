# Cloudy Source Port

- Upstream: https://github.com/nya-owo/cloudy
- Pinned commit: `250da6df710fef0534e06ae518b52c5e22dd2e31`
- Upstream authors: nya-owo and Cloudy contributors; retain upstream Git history for authorship.
- License: GNU Affero General Public License v3.0, included as `LICENSE`.
- Local adaptation date: 2026-11-08.

## Adapted Sources

`internal/app/ui_pane.go` and `ui_songmenu.go` supply the song-menu geometry,
rows, replacement submenus and entrance curve in `SongContextMenu.qml`.
Transport, menu and capsule SVG markup from `icons.go` and `style_icons.go`
is reused in `RhineIcon.qml`. `keys.go` supplies the lyric size/offset/settings
capsules. `ui_comments.go` supplies the detail-only `SongComments.qml` layout;
loading, pagination and comment likes use Rhine's existing service adapter.
`internal/lyrics/lyrics.go` supplies the finite LRC line interval and weighted
estimated word timing adapted in `LyricsController.cpp`. Real timed words
are preserved. Standard lyrics use upstream per-word brightness interpolation.
Artist/album credit navigation and idle lyric following use native Qt adapters.
The retired native song-detail renderer has been removed.

`internal/app/ui_stage.go` and `internal/app/ui_stage_styles.go` are ported
to `Qt/qml/StageLayout.js` and `Qt/qml/LyricStage.qml`. The port preserves
the seeded random generator, analytic spring, word spacing, word timing,
phrase splitting, stepped rows, tilt partitions, and character pulse.
Go/MyGo view construction is replaced with Qt Quick delegates and text
measurement. Qt uses explicit pixel sizes and available-area fitting.
Cloudy's artwork and application name are not copied.

The heart SVG path from `internal/app/icons.go` is copied unchanged as
`cloudyHeart` in `Qt/qml/RhineIcon.qml`, including the 1.75 stroke width,
round caps/joins and solid liked state. The detail button uses the upstream
22-pixel icon and 38-pixel hit area. The like spring and particle burst have
not yet been ported. Detail layout and lyric hover from `ui_nowplaying.go`
are adapted to Qt, with a frameless per-line play/time target as requested.

Cloudy's README credits https://github.com/chthollyphile/folia-major as the
lyric-animation reference. Its source identifies Folia's analytic spring
(stiffness 200, damping 20). This port adapts Cloudy's implementation;
no additional Folia source has been copied directly.

The 0.6-second seeded spark trajectories, normal/last-word particle counts,
deceleration, streak width and fade from `stageSparks` are adapted as Qt scene
items, with a persisted on/off preference and reduced-motion suppression.
The lyric clock, backdrop fog and progress smoke now advance on render frames.
The port is incomplete: hot-comment interludes and guide drawing have not
yet been ported. Other pages currently contain
independent adaptations, not a complete source transplant or verified 1:1 match.

`internal/app/ui_wall.go` is adapted to `Qt/qml/SongWall.qml`: layout,
current-track centering, alternating seven-second row sway, hover/press/current
scales, caption overlay and visible-cell rendering. Qt Flickable supplies drag
inertia; its physics are not identical to MyGo's 800 ms drag spring. Frost is
currently a tinted fade, not the reference's progressive backdrop blur.

`internal/app/ui_nowplaying.go` opening/closing timing, cubic Bezier curves,
fixed-size clipping reveal and staged body opacity are adapted in
`Qt/qml/Main.qml` and `Qt/qml/SongDetailPage.qml`. Shared-element cover/control
flights are now adapted, including smoothstep handovers, native player-button
suppression, interrupted reversal and mapped destination geometry. Rounded reveal clipping is implemented with
a transient Qt Quick layer mask, released at the resting state.

`internal/app/ui_settings.go` supplies the effects groups, descriptions,
navigation geometry, cross-category effects search and panel structure in
`SettingsPage.qml` and `VisualEffectsSettings.qml`. `power_saver.go` supplies
the saved-effects restore logic in `Engine.cpp`. Other settings categories
are not complete source ports. Settings entrance/exit is retained during the
280 ms dialog transition. Playback now has real Qt audio-output selection,
source sleep-timer choices and an after-current-song option; podcast playback
speed uses the source choices and is applied only to episodes. Normalization,
full effects, captions and other settings rows remain incomplete.

`ui_player.go` transport behavior is adapted to independent shuffle and repeat
controls in `MusicPlayer` and the detail view. `ui_float.go` supplies continuous
word-color interpolation and cover-derived desktop lyric colors. Desktop geometry,
toolbar appearance and cross-window flights are not complete source ports.

The unchanged LXGW WenKai Regular/Medium fonts and OFL.txt from
`resources/fonts` are bundled under `vendor/cloudy-fonts` and `resources/fonts`.
They remain licensed under SIL Open Font License 1.1, independently of AGPL.
The interface-font chooser retains existing local-font import support.

`backdrop.go` fog source and `ui_player.go` progress smoke are adapted in
`Qt/shaders/cloudyFog.frag` and `ProgressSmoke.qml`. The Qt audio adapter
retains the low-frequency RMS used by fog and additionally ports Cloudy's
1024-point Hann FFT / 24 logarithmic bands from `internal/player/stream.go`.
`ui_kit.go` barState/step/group/drawBars and `ui_pages.go` nowPlayingBars are
adapted in the shared `PlayingBars.qml`: real PCM drives list and player
indicators, with the original rise/fall smoothing and squared group response.
Qt supplies decoded mono samples, playback timestamps and a bounded cache
cleared on seek/source change. Analysis is suppressed when hidden or reduced.
`artwork.go` shrink/dominantColor is adapted in `NowPlaying.cpp`, with cached
tints and track/account-generation guards.

## Combined Application

### 2026-11-08 source layout follow-up

The fourteen unchanged upstream UI/font/icon/player files and their hashes are retained
in `app/vendor/cloudy-ui-reference/`. This batch adapts stageBar natural title
layout; wallPane's 72/112 DIP progressive frost, Gaussian sigma 16/14 and exact
backdropOver smoothstep; foldHead/orderChip controls; and coverCardOf geometry.
Original heart, filled heart, sort and headset SVG markup is used directly.
The pinned MyGo dependency's MIT progressive blur source and license are
retained there under `mygo-glass/`; Qt shaders adapt its level composition.
This records the current scoped port, not whole-application pixel parity.

The subsequent five-pane alignment batch also adapts nowPlayingBody,
lyricsPane, queuePane, stage and commentsPane coordinates, artistLinks, and
imports the original iconX/iconTrash SVGs. RHINE's explicit user preference
overrides link decoration: hover brightens text without an underline.
See migration/UI-NOWPLAYING-ALIGNMENT-20261108.md for implementation and evidence.

The application incorporating these adapted sources is offered under
AGPL-3.0-only. Pre-existing MIT notices and all separately licensed third-party
components remain intact; this does not erase their original licenses.
`app/LICENSE` retains the original RhineLabUI MIT notice. The combined-work
AGPL text is in this directory and is packaged under `resources/third-party/cloudy`.

For any future distribution, retain these notices and provide the complete
corresponding source (including build and installation scripts and modifications)
as required by AGPL section 6. A source archive for only the Cloudy files is not
sufficient. If a modified version supports remote network interaction, also
comply with section 13. Personal local use alone does not require publishing
the private worktree. Commercial use is not the criterion for these obligations.
