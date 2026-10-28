"""G70 incremental search/focus, hearts, exact record selection and restored FM entry."""
from pathlib import Path
import subprocess,shutil
root=Path(__file__).resolve().parents[1]
patch=(root/'patches/g70-stable-search-records-roam.patch').read_bytes().replace(b'\r\n',b'\n')
for line in patch.splitlines():
 if line.startswith(b'+++ b/'):
  target=Path(line[6:].decode('utf-8'))
  if target.exists():target.write_bytes(target.read_bytes().replace(b'\r\n',b'\n'))
subprocess.run(['git','apply','--check','-'],input=patch,check=True)
subprocess.run(['git','apply','-'],input=patch,check=True)
for name in ('PlaylistMagazine.h','PlaylistMagazine.cpp'):shutil.copyfile(root/'maintained/Qt/src'/name,Path('Qt/src')/name)
for name in ('RhineIcon','SideNavigation','RecordStack','PlaylistSearch','SongHeart','PlaylistMagazine'):shutil.copyfile(root/'maintained/Qt/qml'/f'{name}.qml',Path('Qt/qml')/f'{name}.qml')
qml=Path('Qt/qml/PlaylistMagazine.qml').read_text(encoding='utf-8')
assert 'id:searchHost' in qml and 'SongHeart {' in qml
assert 'G70 typing and deleting retain' in Path('Qt/tests/UiChecks.cpp').read_text(encoding='utf-8')
assert 'qml/PlaylistSearch.qml\n' in Path('Qt/CMakeLists.txt').read_text(encoding='utf-8')
print('G70: persistent live search editor, authoritative filled hearts, exact record targets and original FM session entry installed.')
