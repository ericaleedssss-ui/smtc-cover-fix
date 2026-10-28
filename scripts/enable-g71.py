"""Incremental G71: ordered record session, compact account UI and user heart art."""
from pathlib import Path
import subprocess,shutil
root=Path(__file__).resolve().parents[1]
patch=(root/'patches/g71-ordered-collections-account.patch').read_bytes().replace(b'\r\n',b'\n')
for line in patch.splitlines():
 if line.startswith(b'+++ b/'):
  target=Path(line[6:].decode('utf-8'))
  if target.exists():target.write_bytes(target.read_bytes().replace(b'\r\n',b'\n'))
subprocess.run(['git','apply','--check','-'],input=patch,check=True)
subprocess.run(['git','apply','-'],input=patch,check=True)
for p in ('Qt/qml/GlobalTools.qml','Qt/qml/PlaylistMagazine.qml','Qt/qml/PlaylistSearch.qml','Qt/qml/RecordStack.qml','Qt/qml/SongHeart.qml','Qt/qml/RhineIcon.qml','Qt/src/PlaylistMagazine.cpp','Qt/src/PlaylistMagazine.h','Assets/icons/song-like-on.png','Assets/icons/song-like-off.png'):
 target=Path(p);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/'maintained'/p,target)
assert 'music:collection-browse:' in Path('Qt/src/PlaylistMagazine.cpp').read_text(encoding='utf-8')
assert 'browseCollection(item)' in Path('Qt/src/NativeHudMusic.cpp').read_text(encoding='utf-8')
assert 'id:globalTools' in Path('Qt/qml/Main.qml').read_text(encoding='utf-8')
print('G71: ordered paged collections, replacement browsing history, lightweight account/header controls and user-provided hearts installed.')
