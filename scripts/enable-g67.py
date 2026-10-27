"""G67: independent global queue and collection overlays; retain live underlying pages."""
from pathlib import Path
import subprocess, shutil
root = Path(__file__).resolve().parents[1]
patch = (root / 'patches/g67-independent-queue.patch').read_bytes().replace(b'\r\n', b'\n')
for line in patch.splitlines():
    if line.startswith(b'+++ b/'):
        target = Path(line[6:].decode())
        target.write_bytes(target.read_bytes().replace(b'\r\n', b'\n'))
subprocess.run(['git', 'apply', '--check', '-'], input=patch, check=True)
subprocess.run(['git', 'apply', '-'], input=patch, check=True)
for name in ('PlayerQueueGlass.qml', 'SideNavigation.qml', 'DiscoverGlass.qml'):
    shutil.copyfile(root / 'maintained/Qt/qml' / name, Path('Qt/qml') / name)
main = Path('Qt/qml/Main.qml').read_text()
assert 'active: rhine.state.queueOpen === true' in main
assert 'active: rhine.state.modal === "discover"' in main
assert 'queueDiscoverTile' in main and 'queueProfileTile' in main
print('G67: queue/picker are independent overlays; live page captures remain acyclic and bounded.')
