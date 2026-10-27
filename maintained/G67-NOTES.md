# G67: independent queue overlay

Base: G66 202b92da8709ef3f5f5a2dba00d6306f4ecafc4b.

The queue previously called openModal("player"), replacing Discover/Profile Loaders and resetting query/list offset. queueOpen now controls only the foreground queue. Legacy openModal("player") callers open that independent layer without entering the modal stack. Queue bounds and lightweight row exports are independent of modalBounds. Normal page drawing, modal motion and Loader activation do not change on queue toggles.

Queue collection uses a separate queueCollectionOpen picker over the retained live page and queue. It reads existing account-created playlists and uses the existing MusicLibrary::playlistTracks mutation, immutable selected entries, account checks and failure retry behavior. Closing the picker keeps the queue open; Escape/back closes the front layer first. A source action intentionally closes the queue and invokes the existing internal route. Unknown sources remain non-navigable.

The G66 live half-resolution queue-sized captures now include active Reading, Comments, Recommendations, Discover and Profile root surfaces in their z order, before navigation. No queue/picker is a source. Captures of inactive surfaces are not instantiated. This is live scenegraph sampling, not a static page replacement. Existing glass shaders are unchanged.

Local verification: actual production QML Loader block and actual Discover/Profile/Queue components, real mouse/wheel events at 720/1080 heights; Following instance/tab/filter/data/scroll retained over repeated queue/collection/pick/close cycles; independent Profile Loader; existing queue play/cover/hover/scroll/pagination/remove/clear action routing; comment lifecycle regression; QML cache compilation; LF/CRLF/mixed patch installer; clean pinned-upstream + G53 + complete maintained chain and repository audit.

Windows UiChecks additionally exercise real NativeHud/Engine queue state, retained Following instance/scroll/data/query/filter, secondary collection overlay, source navigation and existing playback/mutation assertions. These run during the submitted Windows build. Local QML tests use a spy backend and software rendering; they do not prove Windows D3D performance, live account API success or hardware visual quality. Windows results and hands-on visual QA remain pending when the build is submitted; do not report them as passed.

Local commands (PySide6 required):
- python scripts/test-g67-overlay.py /path/to/applied-source
- python scripts/test-g67-queue.py /path/to/applied-source
- python scripts/test-g66-lifecycle.py /path/to/applied-source
- python scripts/test-g67-patch-eol.py /path/to/pristine-applied-G66
