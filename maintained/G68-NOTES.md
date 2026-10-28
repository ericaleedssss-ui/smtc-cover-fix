# G68: build the triggering commit, not the stale G66 branch

The published G67 workflow (run 40602818911) cloned the hard-coded branch rhine-g66-layered-glass-origin before applying maintained changes. Its logs show the G66 installers, without the G67 installer or retained-Following tests. The artifact label was G67, but the independent queue overlay code and tests were not built. The earlier claim that the Windows run validated G67 was incorrect.

The maintained bootstrap now fetches and checks out GITHUB_SHA, the exact commit whose workflow is executing. No branch name needs to be updated for future builds. Before compiling, verify-build-source.py fails if the checkout revision differs from the workflow revision, the generated queue/page architecture is stale, maintained QML was not installed, or the actual Windows retained-page regression is absent. It emits a source stamp; MAINTAINED-SOURCE.json is included alongside the downloadable portable ZIP.

The existing G67 independent overlay implementation is retained unchanged. In particular, Discover/Following/Profile and other normal pages retain their live Loader instances, and collection remains a secondary queue overlay. Source navigation stays intentional.

Local validation: clean pinned-upstream + G53 + full maintained application; source stamp verification; deliberate stale-checkout and stale-generated-source rejection; production QML queue/collection/Following/Profile interactions; existing queue and comment lifecycle regressions. Windows D3D rendering, compiled controller/mutation tests and hands-on behavior are pending the submitted Windows build. Stop work after submission as requested.

The Windows retained-Following test now opens AND closes the queue via real mouse events on the actual native HUD footer hit item (nativeHit_player:open), rather than invoking only backend.action("player:open"). The QML addition is an objectName for test discovery; control behavior is unchanged.
