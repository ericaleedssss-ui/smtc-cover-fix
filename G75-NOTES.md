# G75 continuous record handoff and UI spacing

Based on G74 and its album-reader compatibility fix. Keeps the 460ms InOutCubic turn, cover sizing, asymmetric side poses, canonical collection order and search/player/roam paths.

## Changes
- Use the four existing visual slots for actual, distinct record identities. Capture each card pose before turning. A exits, B becomes the left card, C becomes the main card and the real D from the collection sequence enters on the right; reverse traversal follows the same ownership rule. No duplicate main-cover overlay or end-of-animation image reassignment is used.
- Entry is a delayed, lower angled insertion, while exit travels outward/upward and fades earlier. The old main cover stays opaque. Freeze card identities through navigation handoff. Suppress synthetic hover/collapse events at the handoff.
- Decode the two lookahead images without painting them; metadata still comes from the existing collection pager. If a new neighbour is unavailable, never invent one; a later result uses the entry transition.
- Keep the track-list fade layer, shorten the bottom fade to 22 scaled pixels and remove the separate sticky-header glass/tint surface. Cull the offscreen hero. Increase heart/time spacing without changing title, artist or album widths, and add a small title/description spacer.
- Show a subdued actual return-source label under the existing brand. Keep the original history entry through cover browsing. Update the profile return target as the record key changes, including loading states, while preserving nested song back navigation.

## Validation
Production QML mouse/key tests at 1400x900, 960x540, 960x720 and 1920x1080 with 4,080 rows. Sample both turn directions, retain object identity, assert the old main never fades, verify true D entry, check the final frame against idle geometry and check again after backend navigation. Capture a local contact sheet for visual inspection. Run compiled controller/lookahead, return-source and replacement-history tests, shader compilation, clean overlay installation, source-provenance checks and existing metadata tests.

The local QML checks use Qt's software renderer and synthetic offline covers. They verify geometry/event continuity, not real-account latency or target-GPU frame pacing. Windows build and native UI regression results are reported by the linked workflow; triggering a build does not mean it has passed.
