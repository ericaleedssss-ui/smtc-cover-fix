"""G66: simultaneous layered glass and actual per-entry queue provenance."""
from pathlib import Path
import subprocess
import shutil

root = Path(__file__).resolve().parents[1]
patch = (root / 'patches/g66-layered-glass-provenance.patch').read_bytes().replace(b'\r\n', b'\n')
for line in patch.splitlines():
    if line.startswith(b'+++ b/'):
        target = Path(line[6:].decode('utf-8'))
        raw = target.read_bytes()
        normalized = raw.replace(b'\r\n', b'\n')
        if raw != normalized:
            target.write_bytes(normalized)
subprocess.run(['git', 'apply', '--check', '-'], input=patch, check=True)
subprocess.run(['git', 'apply', '-'], input=patch, check=True)
shutil.copyfile(root / 'maintained/Qt/qml/PlayerQueueGlass.qml', 'Qt/qml/PlayerQueueGlass.qml')
main = Path('Qt/qml/Main.qml').read_text(encoding='utf-8')
assert 'background: queueGlassBackdrop' in main
assert 'model: glassQueueLoader.active ? [baseVisual, sideNavigation] : []' in main
assert main.index('id: glassQueueLoader') > main.index('id: inputLayer')
qml = Path('Qt/qml/PlayerQueueGlass.qml').read_text(encoding='utf-8')
assert 'case "link":' in qml and 'actionable: track.sourceLink' in qml
assert 'text: "来源："' not in qml
print('G66: nonblocking queue glass, bounded acyclic lower-layer sampling, captured per-entry origins and hover source navigation.')
