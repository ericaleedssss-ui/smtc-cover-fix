# Record material experiment ? not applied to production

The selected material is now installed in `maintained/`. The build pipeline is
unchanged. The shader/QML copies here preserve the reviewed study; runtime uses
the maintained files. Do not edit these copies as a second source of truth.
Based on production 24f7a8a, with fixed lighting, filtered vinyl grooves, softer
sidewall/contact shadow, metallic tonearm shading, cover varnish, small independent
paper centre + collar, and a displaced blurred cover reflection on glass.
Left focal fade is deliberately weaker, following the user's latest preference.
No added render target, shader pass, external asset or network request.
The existing nine-tap shadow pass now also approximates reflected cover colour/shape;
its phase follows the existing shared spin clock. This is an artistic approximation,
not a physically accurate reflection. No peripheral paper sticker was implemented.

## Reproduce (PowerShell, PySide6 6.10.1 with qsb/rcc/qmlcachegen)

Set RHINE_MATERIAL_REPO to the repository root,
RHINE_TEST_SOURCE to the fixed upstream checkout (including Assets/fonts), and
RHINE_TEST_OUTPUT to a writable output directory. Set QT_QPA_PLATFORM=windows,
QT_QUICK_BACKEND=rhi, QSG_RHI_BACKEND=d3d11. Run preview.py or benchmark.py.
Preview uses an original geometric test cover, never real album art.
Benchmark uses the same locally decoded circular fixtures for both candidates.

## Validation and limits

Production test-g86-qml.py was run against the candidate on D3D11: motion,
rapid/queued swaps, late/missing covers, four layouts, lyrics, actions, hidden
motion and rounded clipping passed. Only its explicit mask expectation changed
for the intentionally weaker fade: x=.35 brightness 134, x=.5 brightness 195.
No tests were removed. Production test code is unchanged.

Sequential baseline/candidate benchmark at 1540x700 logical pixels (2x capture),
normal and dark mode, six song changes with three rapid additional selections,
then three dark changes. Switching p95: baseline 8.558 ms, final 8.559 ms;
latest production switching p95 8.471 ms, max 12.645 ms, no switching interval
>25 ms. Final headshell uses warm satin shading; broad left shadows and dark-cover
reflections are attenuated. Full D3D11 UI regression passed before submission.
The 500ms animation endpoint check now waits for completion with a bounded 900ms
deadline, preserving intermediate motion/reversal checks.
Metrics are frameSwapped wall intervals and CPU render submission callbacks,
NOT GPU timer-query results. A ~100 ms interval in pause/play exists in both
versions and includes the on-demand render idle gap after pause settles; it
must not be interpreted as an animation stall or silently discarded.
These short local offline runs do not prove universal stutter-free operation,
network performance, lower-end GPU performance or packaged-app acceptance.

Final images: ~/.codex/generated_images/rhine-material-study/material-study-03.png
and material-study-03-dark.png. Previous v2 images are superseded.
