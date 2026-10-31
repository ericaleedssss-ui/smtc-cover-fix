# Outer rim and etched seat material preview

The selected B material is installed in `maintained/`. This Python / Qt
preview reads those production QML and shader files and modifies temporary
copies only, exposing fixed material constants as interactive controls.
There is no second maintained candidate shader or QML copy here.

The outer band uses a rounded charcoal PVC profile, fine filtered grain,
pressed seam and paired anisotropic reflection fans. Width is adjustable. The etched
seat is opaque warm ivory with a restrained warm-silver reflection and
pressed inner/outer shoulders, referencing the independent centre piece.

The production screen-space depth-of-field, fading and glass clipping pass
is preserved verbatim, with an assertion checking this before compilation.
Both materials pass through that same existing effect.

Run `preview.py` with `%TEMP%/rhine-motion-qa/venv/Scripts/python.exe` for
interactive controls. Add `--capture` to write images to `output/` and exit.
The dependency checkout defaults to `%TEMP%/rhine-motion-qa/upstream`.
No network or real account is used; the geometric album artwork is a fixture.

`output/comparison.png` shows the original white/clear material, then two
candidate band widths with the opaque satin seat. B is the selected `.038`
normalized radius width. All captures use the same
framing, lighting, cover angle and unchanged focal fade.

Validated locally with the existing PySide6 / D3D11 setup: shaders compiled
to GLSL, HLSL and MSL; the actual QML loaded and captures completed with no
captured QML runtime errors. Production `test-g86-qml.py` passes on D3D11,
including pause/play/reversal, loading isolation, rapid/queued replacements,
persistent deck identity, late/missing artwork, four layouts and reduced motion.
The full original focal mask and glass clipping checks are retained.

Opaque material physically obscures more of the moving sheets below it.
The ripple test now checks the source alpha motion independently (maximum
80/255) and requires visible motion in the assembled scene (maximum 4/255,
aggregate 57234), while retaining the separate lyric-area limit (measured
2/255). Timing, sheet generation and motion controls were not changed.

The production change adds no texture, offscreen layer, blur pass or timer.
The fixed cast-shadow projection is aligned with the upper-right key; its
existing lift dependency, arm pivot, path, duration and easing remain intact.
Material noise is restricted to visible material regions, with derivatives
computed before spatial branches to preserve stable edge filtering.

Local `frameSwapped` intervals and CPU submit callbacks are measured with
the existing `record-material-v2/benchmark.py`, sequentially on the same
D3D11 setup. Metrics are recorded alongside this file. They are not GPU
timings and do not replace packaged-app or live-account acceptance. The
pause/play stage includes an approximately 106 ms on-demand-rendering idle
gap in both old and new versions; it is not an active-animation frame.

Final normal switching: baseline p95 8.548 ms / max 12.820 ms; candidate
p95 8.606 ms / max 10.340 ms. Dark switching: baseline p95 8.502 ms /
max 10.453 ms; candidate p95 8.633 ms / max 9.957 ms. Neither final run
had a switching interval over 25 ms. The initial candidate had one 27.272 ms
dark interval; its complete metrics are retained rather than discarded.
After restricting material work to its visible regions, the final run above
had no such interval. Short runs cannot establish universal performance.
