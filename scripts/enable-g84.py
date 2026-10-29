"""G84: retain archive content across native lane handoffs."""
from pathlib import Path

def edit(file,old,new):
 p=Path(file);s=p.read_text(encoding='utf-8');assert s.count(old)==1,(file,old[:90]);p.write_text(s.replace(old,new),encoding='utf-8')
edit('Qt/src/NativeHud.cpp','            {"currentKind", m_music->current["kind"]},','            {"archiveCollection", !m_music->directory && m_music->selectedLane>=2 && m_music->current.isEmpty()},\n            {"currentKind", m_music->current["kind"]},')
edit('Qt/qml/Main.qml','collection:(rhine.state.currentKind==="playlist"||rhine.state.currentKind==="album")&&!rhine.state.directoryOpen','collection:(rhine.state.archiveCollection===true||rhine.state.currentKind==="playlist"||rhine.state.currentKind==="album")&&!rhine.state.directoryOpen')
print('G84: persistent collection component across native column handoffs.')
