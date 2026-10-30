# G94 — clear vinyl track bands, without a tonearm

Incremental implementation of the approved preview: remove the instantiated tonearm, preserve the exact G88 cover geometry, existing glass, layout and all playback/navigation/API logic. The old cached RecordTonearm resource remains registered for compatibility with the ordered overlays but is not instantiated or rendered.

## Files

- `maintained/Qt/qml/NowPlayingPanel.qml`: remove the arm plane; replace the filled lower-edge rectangle with a narrow shaded physical sidewall shader, and reduce the cast-shadow opacity from .18 to .10. Artwork dimensions, centre, tilt and artwork-only rotation remain unchanged.
- `maintained/Qt/shaders/recordAtmosphere.frag`: replace dense periodic fine grooves with five separated recessed boundaries and paired directional highlights across broad smooth bands. Slightly lower body opacity (.28 plus a .06 local reflection, previously .32 plus .10) and keep a readable warm translucent pigment. Outer thickness uses a restrained dark lower sidewall rather than a glowing rim; the aperture has a regular shaded inner wall. Shared progressive defocus uses nine fixed texture samples instead of five, increasing only toward the lyric side; all physical layers and sheen still share the original continuous alpha fade and rounded clipping. No additional render layer, timer or dependency.
- `scripts/test-g86-qml.py`: verify absence of the arm and the physical sidewall mode; retain exact geometry, clipping, stationary base/spinning print, playback state and existing interaction tests.
- `.github/workflows/build-smtc.yml`: G94 job/artifact labels and build notes only; embedded patch bytes unchanged.

## Actual validation

Clean source generation and source identity/protected-glass verification passed. Actual production QML release bytecode compilation passed, including integrated Main. Shader compilation passed for GLSL 150/300es, HLSL 50 and MSL 12. Embedded gzip CRC, canonical patch SHA and git diff checks passed.

Existing real QML tests passed using both software rendering and OpenGL RHI, with four window sizes, exact G88 dimensions, absence of the tonearm, fixed platter and artwork-only spin, pause/hidden animation stop, retained glass identity, song updates, lyric scroll/follow/seek, likes/comments/share/More/collection/details/album and global now-playing entry. Inspected the actual RHI-rendered frame using explicit offline QA artwork; fixture artwork is not shipped. The actual framebuffer probe retained partial visibility through the left/middle and clipped the rounded corners. The neutral light animation changed actual pixels (maximum delta 27, sampled aggregate 41567), while lyric-area maximum change was 3.

These checks do not establish pixel identity with an AI preview, live API behavior, Windows packaging success or physical-machine performance. Windows build/native tests and the user's visual acceptance remain pending at submission. Stop after submitting the build, as requested.
