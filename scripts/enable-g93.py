"""Install the cached vector tonearm; preserve existing player/navigation logic."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
shutil.copyfile(root/'maintained/Qt/qml/RecordTonearm.qml','Qt/qml/RecordTonearm.qml')
p=Path('Qt/CMakeLists.txt');s=p.read_text(encoding='utf-8')
a='    qml/NowPlayingPanel.qml\n';assert s.count(a)==1;s=s.replace(a,a+'    qml/RecordTonearm.qml\n')
a='set_source_files_properties(qml/NowPlayingPanel.qml';assert s.count(a)==1;s=s.replace(a,'set_source_files_properties(qml/RecordTonearm.qml PROPERTIES QT_RESOURCE_ALIAS RecordTonearm.qml)\n'+a)
p.write_text(s,encoding='utf-8')
print('G93: broad visible vinyl annulus and upper-right cached vector tonearm installed.')
