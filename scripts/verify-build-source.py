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
checks = {
    'Qt/qml/Main.qml': ['active: rhine.state.queueOpen === true',
                        'active: rhine.state.modal === "discover"',
                        'queueDiscoverTile', 'queueProfileTile', 'queueCollectionOverlay', 'objectName: "nativeHit_" + modelData.action'],
    'Qt/src/NativeHudController.cpp': ['queueOpen = !queueOpen;',
                                      'if (kind == "player") { queueOpen = true; return; }'],
    'Qt/src/NativeHudMusic.cpp': ['if (queueCollectionOpen) {'],
    'Qt/tests/UiChecks.cpp': ['Following page actually scrolls before opening the queue', 'clickQueueButton();',
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
    'queue_patch_sha256': hashlib.sha256((maintained / 'patches/g67-independent-queue.patch').read_bytes()).hexdigest(),
}
args.stamp.write_text(json.dumps(stamp, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'G68 source verified: workflow and maintained checkout both {actual}; independent overlay and retained-page QA installed.')
