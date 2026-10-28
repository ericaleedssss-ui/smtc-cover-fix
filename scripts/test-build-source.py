"""Regression for the mislabeled G67 release: reject stale checkout and stale applied source."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
repo = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
verify = repo / 'scripts/verify-build-source.py'

def run(root, stamp, sha):
    return subprocess.run([sys.executable, str(verify), '--source', str(root), '--stamp', str(stamp)],
                          env={**os.environ, 'GITHUB_SHA': sha}, capture_output=True, text=True)

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    stamp = tmp / 'source.json'
    result = run(source, stamp, head)
    assert result.returncode == 0, result.stdout + result.stderr
    value = json.loads(stamp.read_text())
    assert value['workflow_commit'] == value['maintained_commit'] == head
    assert len(value['generated_sha256']) == 4
    print('PASS: matching checkout and generated overlay source emit an exact commit/hash stamp')
    stamp.unlink()
    result = run(source, stamp, '0' * 40)
    assert result.returncode != 0 and 'Maintained source mismatch' in result.stderr and not stamp.exists()
    print('PASS: workflow/maintained commit mismatch prevents release')
    stale = tmp / 'stale'
    for name in value['generated_sha256']:
        target = stale / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, target)
    for name in ('PlayerQueueGlass.qml', 'SideNavigation.qml', 'DiscoverGlass.qml'):
        shutil.copyfile(source / 'Qt/qml' / name, stale / 'Qt/qml' / name)
    for name in ('Qt/src/MusicPlayer.cpp','Qt/src/MusicPlayer.h','Qt/src/NativeHudPlayer.cpp','Qt/src/NativeHudController.cpp','Qt/qml/LyricsReading.qml'):
        target=stale/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,target)
    main = stale / 'Qt/qml/Main.qml'
    actual = main.read_text()
    main.write_text(actual.replace('active: rhine.state.queueOpen === true', 'active: rhine.state.modal === "player"'))
    result = run(stale, stamp, head)
    assert result.returncode != 0 and 'Stale generated source' in result.stderr and not stamp.exists()
    print('PASS: pre-G67 mutually exclusive modal source prevents release')
    main.write_text(actual)
    qml = stale / 'Qt/qml/PlayerQueueGlass.qml'
    qml.write_text(qml.read_text().replace('actionName: "queue-close"', 'actionName: "close-modal"'))
    result = run(stale, stamp, head)
    assert result.returncode != 0 and ('Maintained QML was not installed' in result.stderr or 'Protected G70 playback source changed' in result.stderr) and not stamp.exists()
    print('PASS: stale maintained queue component prevents release')
