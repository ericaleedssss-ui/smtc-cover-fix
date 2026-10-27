"""G65: root-level interactive queue, bounded artwork rows and real playlist actions.

Applied after all G64 assertions. The readable patch updates C++ behavior and
adds real-window interaction regression checks to the existing Windows QA.
"""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
patch = root / 'patches/g65-queue-interactions.patch'
subprocess.run(['git', 'apply', '--check', str(patch)], check=True)
subprocess.run(['git', 'apply', str(patch)], check=True)
shutil.copyfile(root / 'maintained/Qt/qml/PlayerQueueGlass.qml', 'Qt/qml/PlayerQueueGlass.qml')
main = Path('Qt/qml/Main.qml').read_text(encoding='utf-8')
assert main.index('id: glassQueueLoader') > main.index('id: inputLayer')
qml = Path('Qt/qml/PlayerQueueGlass.qml').read_text(encoding='utf-8')
assert 'WheelHandler {' in qml and 'layer.effect: ShaderEffect' in qml
assert 'sourceItem: songList' not in qml
assert 'encodeURIComponent(key)' in qml
assert 'queueCollectAll' in qml and 'queueCoverPlay_' in qml
print('G65: queue above page input, real row/cover/collection/removal controls, stable 40-row snapshots, real-window mutation checks.')
