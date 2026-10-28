"""G73: remove the per-render playlist rescan introduced with the magazine page.

PlaylistMagazine already listens to MusicLibrary::invalidated. Calling sync() again
from Engine::step() makes the model compare songs, likes and record collections
on every render step and emits QML change notifications even when nothing changed.
"""
from pathlib import Path

engine = Path("Qt/src/Engine.cpp")
source = engine.read_text(encoding="utf-8")
needle = "    m_magazine->sync();\n"
count = source.count(needle)
if count != 1:
    raise RuntimeError(f"Expected exactly one per-step magazine sync, found {count}")
source = source.replace(
    needle,
    "    // PlaylistMagazine syncs from MusicLibrary::invalidated; never rescan it per render step.\n",
    1,
)
engine.write_text(source, encoding="utf-8")
print("G73 removed per-render playlist rescans.")
