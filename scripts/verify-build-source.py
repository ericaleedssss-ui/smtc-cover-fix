"""Fail the release if the maintained checkout or generated overlay source is stale."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--stamp', type=Path, required=True)
args = parser.parse_args()
maintained = Path(__file__).resolve().parents[1]
expected = os.environ['GITHUB_SHA']
actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=maintained, text=True).strip()
if actual != expected:
    raise SystemExit(f'Maintained source mismatch: workflow={expected}, checkout={actual}')

source = args.source.resolve()
protected_g70 = {'Qt/src/MusicPlayer.cpp': '08c2c1fe6a2f013118ac8461c09d651f2417ba34a5f71be42b4625f8a999ffc7', 'Qt/src/MusicPlayer.h': '52efbeb7f2eb1161ddf9458f814bc8afbf2d478d7ed0fb76e5ecec97965d7a83', 'Qt/src/NativeHudPlayer.cpp': '581160e2820922e69d7c43a11a4abc6de3c785b0e747d86325672ad09d8f7ed1', 'Qt/src/NativeHudController.cpp': '74041330e44aa32627e6e6da1ff3df22e584144ea97764cc11e488b421069887', 'Qt/qml/LyricsReading.qml': '7e91a10eda232acfd8b119f73829435974b72b3e76cf5d38033f0ebe77dd54ce', 'Qt/qml/PlayerQueueGlass.qml': '0523b9da818f349e1d0b254d2bd9cd8d60730cff43f0e528c2e7bb54298008c7'}
for name, expected_hash in protected_g70.items():
    if hashlib.sha256((source / name).read_bytes().replace(b'\r\n',b'\n')).hexdigest() != expected_hash:
        raise SystemExit(f"Protected G70 playback source changed: {name}")

checks = {
    'Qt/qml/Main.qml': ['active: rhine.state.queueOpen === true',
                        'active: rhine.state.modal === "discover"',
                        'queueDiscoverTile', 'queueProfileTile', 'queueCollectionOverlay', 'objectName: "nativeHit_" + modelData.action', 'sourceItem:magazineLoader', 'id:globalTools'],
    'Qt/src/NativeHudController.cpp': ['queueOpen = !queueOpen;',
                                      'if (kind == "player") { queueOpen = true; return; }'],
    'Qt/src/NativeHudMusic.cpp': ['if (queueCollectionOpen) {'],
    'Qt/tests/UiChecks.cpp': ['G71 one back exits', 'G71 shared account bar', 'G70 typing and deleting retain', 'G70 leaving FM restores', 'Following page actually scrolls before opening the queue', 'clickQueueButton();', 'G68 retention', 'G69 real right-click opens shared song menu',
                            'queue retains the same Following instance, scroll, filter, query and loaded data'],
}
for name, markers in checks.items():
    text = (source / name).read_text(encoding='utf-8')
    for marker in markers:
        if marker not in text:
            raise SystemExit(f'Stale generated source: {name}: missing {marker}')
for name in ('PlayerQueueGlass.qml', 'SideNavigation.qml', 'DiscoverGlass.qml'):
    if (source / 'Qt/qml' / name).read_bytes() != (maintained / 'maintained/Qt/qml' / name).read_bytes():
        raise SystemExit(f'Maintained QML was not installed: {name}')

stamp = {
    'workflow_commit': expected,
    'maintained_commit': actual,
    'upstream_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip(),
    'generated_sha256': {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in checks},
    'magazine_controller_sha256': hashlib.sha256((source / 'Qt/src/PlaylistMagazine.cpp').read_bytes()).hexdigest(),
    'search_qml_sha256': hashlib.sha256((source / 'Qt/qml/PlaylistSearch.qml').read_bytes()).hexdigest(),
    'records_qml_sha256': hashlib.sha256((source / 'Qt/qml/RecordStack.qml').read_bytes()).hexdigest(),
    'magazine_qml_sha256': hashlib.sha256((source / 'Qt/qml/PlaylistMagazine.qml').read_bytes()).hexdigest(),
    'queue_patch_sha256': hashlib.sha256((maintained / 'patches/g67-independent-queue.patch').read_bytes()).hexdigest(),
}
args.stamp.write_text(json.dumps(stamp, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'G71 source verified: workflow and maintained checkout both {actual}; independent overlay and retained-page QA installed.')
