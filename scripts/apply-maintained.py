"""Apply source-controlled UI and discovery changes onto the pinned G53 codebase.

This runs *after* the original G53 patch was applied to the upstream Rhine sources.
Our maintained files are readable and reviewable instead of another packed blob.
"""
from pathlib import Path
import shutil

maintained = Path(__file__).resolve().parents[1] / "maintained"

for relative in (
    "Qt/qml/SideNavigation.qml",
    "Qt/qml/DiscoverGlass.qml",
    "Qt/src/MusicDiscover.cpp",
):
    origin = maintained / relative
    target = Path(relative)
    if not origin.is_file() or not target.is_file():
        raise RuntimeError(f"Missing maintained source or G53 target: {relative}")
    shutil.copyfile(origin, target)
    print("Maintained", relative)

controller = Path("Qt/src/NativeHudController.cpp")
content = controller.read_text(encoding="utf-8")
old = """            discover.open(parts.value(2).toInt());
            closeModal(false);"""
new = """            const auto index = parts.value(2).toInt();
            // Discover's followed-user cards navigate to the real user profile,
            // rather than attempting to open a user as a music directory.
            if (index >= 0 && index < discover.items.size() &&
                discover.items.at(index).toObject()["kind"].toString() == "user") {
                const auto uid = discover.items.at(index).toObject()["id"].toString();
                closeModal(false);
                if (!uid.isEmpty()) { action("profile:open:" + uid); }
            } else {
                discover.open(index);
                closeModal(false);
            }"""
count = content.count(old)
if count != 1:
    raise RuntimeError(f"Expected exactly one G53 discover routing anchor, found {count}")
controller.write_text(content.replace(old, new, 1), encoding="utf-8")
print("Routed followed users to profile viewer")

# The G53 bridge whitelists explicit upstream NetEase API modules.
# Browsing podcast stations and followed users needs two more real routes.
worker = Path("MusicBridge/worker.cjs")
worker_source = worker.read_text(encoding="utf-8")
worker_anchor = "const routes = Object.freeze({"
if worker_source.count(worker_anchor) != 1:
    raise RuntimeError("NetEase route whitelist anchor changed")
worker_source = worker_source.replace(
    worker_anchor,
    worker_anchor + "\n    '/dj/hot': 'dj_hot',\n    '/user/follows': 'user_follows',\n    '/personal/fm/mode': 'personal_fm_mode',",
    1,
)
worker.write_text(worker_source, encoding="utf-8")
print("Enabled podcasts and followed-user NetEase endpoints")

# Podcast stations are not ordinary music playlists. Fetch their program tracks
# using the dj/program API already authorized in the historical G53 bridge.
netease = Path("MusicBridge/client/netease.mjs")
client_source = netease.read_text(encoding="utf-8")
client_anchor = """    async detail(value, valid = () => true) {
        if (value.kind === 'song') {"""
client_change = """    async detail(value, valid = () => true) {
        if (value.kind === 'radio') {
            const result = await this.request(
                '/dj/program',
                { rid: value.id, limit: 30, offset: 0 },
                [200],
                valid,
            );
            const programs = Array.isArray(result.programs) ? result.programs : [];
            const tracks = parsed(programs.map((p) => p.mainSong || {}), 'song');
            return [value, tracks, tracks.map((song) => String(song.id))];
        }
        if (value.kind === 'song') {"""
if client_source.count(client_anchor) != 1:
    raise RuntimeError("NetEase detail route anchor changed")
netease.write_text(client_source.replace(client_anchor, client_change, 1), encoding="utf-8")
print("Enabled real NetEase podcast program lists")

nav = Path("Qt/qml/SideNavigation.qml").read_text(encoding="utf-8")
assert "import QtQuick.Shapes" in nav
assert "PathSvg { path: navigation.iconPath(glyph.name) }" in nav
assert "navigation.expanded ? 18 * navigation.unit : -navigation.drawerWidth" in nav
assert 'label: "创建的歌单  " + parent.count' in nav
assert '"播客"' in nav and '"漫游"' in nav and '"关注"' in nav
assert 'text: "我的"' in nav
assert '"创建的歌单  ("' not in nav
assert 'opacity: 1' in nav.split('component NavRow: Item {', 1)[1]
discover = Path("Qt/src/MusicDiscover.cpp").read_text(encoding="utf-8")
assert 'route = "/personal/fm/mode";' in discover
assert 'route = "/simi/song";' not in discover
assert 'parameters = {{"mode", "DEFAULT"}, {"limit", 30}};' in discover
print("Navigation invariants verified.")

# Scrobble is kept in a separate reviewable patch so the user interface
# and server-side listening history remain independently testable.
import subprocess
import sys
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-scrobble.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g57.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g57-ui.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g58.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g59.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g60.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g61.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g62.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g63.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g64.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g65.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g66.py"))], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g66-lifecycle.py"))], check=True)
print("G57 UI and private radio applied successfully.")



subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g67.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g68.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g69.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g70.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g71.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g73.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g74.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g75.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g76.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g77.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g78.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g79.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g81.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g82.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g83.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g84.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g85.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g86.py"))], check=True)

subprocess.run([sys.executable, str(Path(__file__).with_name("enable-g88.py"))], check=True)
