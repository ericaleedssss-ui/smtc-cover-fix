"""G69: shared capsule, virtual playlist magazine, record browsing and captured song context actions."""
from pathlib import Path
import subprocess,shutil
root=Path(__file__).resolve().parents[1]
patch=(root/'patches/g69-magazine-playlist.patch').read_bytes().replace(b'\r\n',b'\n')
for line in patch.splitlines():
    if line.startswith(b'+++ b/'):
        target=Path(line[6:].decode('utf-8'))
        if target.exists():target.write_bytes(target.read_bytes().replace(b'\r\n',b'\n'))
subprocess.run(['git','apply','--check','-'],input=patch,check=True)
subprocess.run(['git','apply','-'],input=patch,check=True)
for name in ('PlaylistMagazine.h','PlaylistMagazine.cpp'):
    shutil.copyfile(root/'maintained/Qt/src'/name,Path('Qt/src')/name)
for name in ('RhineIcon','GlobalTools','RecordStack','SongContextMenu','PlaylistMagazine','PlayerQueueGlass','DiscoverGlass'):
    shutil.copyfile(root/'maintained/Qt/qml'/f'{name}.qml',Path('Qt/qml')/f'{name}.qml')
main=Path('Qt/qml/Main.qml').read_text(encoding='utf-8')
assert 'sourceItem:magazineLoader' in main
assert 'GlobalTools {anchors.fill:parent' in main
assert 'visible: rhine.state.queueCollectionOpen === true' in main
assert 'active: rhine.state.queueOpen === true' in main
cmake=Path('Qt/CMakeLists.txt').read_text(encoding='utf-8')
assert 'qml/PlaylistMagazine.qml' in cmake and 'qml/SongContextMenu.qml' in cmake
print('G69: virtual playlist magazine, shared global tools, bounded real collection stack, captured context actions and serial downloads installed.')
