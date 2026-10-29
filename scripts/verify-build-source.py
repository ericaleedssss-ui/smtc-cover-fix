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
import runpy
runpy.run_path(str(maintained/'scripts/verify-workflow-patches.py'))
expected = os.environ['GITHUB_SHA']
actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=maintained, text=True).strip()
if actual != expected:
    raise SystemExit(f'Maintained source mismatch: workflow={expected}, checkout={actual}')

source = args.source.resolve()
protected_g70 = {'Qt/src/MusicPlayer.cpp': '08c2c1fe6a2f013118ac8461c09d651f2417ba34a5f71be42b4625f8a999ffc7', 'Qt/src/MusicPlayer.h': '52efbeb7f2eb1161ddf9458f814bc8afbf2d478d7ed0fb76e5ecec97965d7a83', 'Qt/src/NativeHudPlayer.cpp': '5c4e9b1588c35d8546f1e618639d7fe8c1595319509a6e19d12e804859fb1677', 'Qt/src/NativeHudController.cpp': 'df2cfc3e020fde270f9cf86a9a209e980c246f43e58f764e3766ad0d096c704e', 'Qt/qml/LyricsReading.qml': '7e91a10eda232acfd8b119f73829435974b72b3e76cf5d38033f0ebe77dd54ce'}
for name, expected_hash in protected_g70.items():
    if hashlib.sha256((source / name).read_bytes().replace(b'\r\n',b'\n')).hexdigest() != expected_hash:
        raise SystemExit(f"Protected G70 playback source changed: {name}")

# G81 deliberately restores the original material rather than imitating it.
original_glass = {'Qt/qml/LiquidGlass.qml': 'b6b8cef48917c4d409bc396a6be55e0cd6064be0363715d3d42d1ad8c4df6682',
                  'Qt/shaders/liquidGlass.frag': '484ff6b30a0cd034735b34bd260f2fc55e1c746d79ae72105797ad5e05c3c861'}
for name, expected_hash in original_glass.items():
    if hashlib.sha256((source/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest() != expected_hash:
        raise SystemExit(f'Original archive glass material changed: {name}')

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

for name in ('Qt/src/MessageCenter.cpp','Qt/src/MessageCenter.h','Qt/qml/MessageDrawer.qml','Qt/qml/DrawerFrost.qml','Qt/qml/DrawerInputGate.qml','Qt/qml/PlaylistShowcase.qml','Qt/qml/RecordStack.qml','Qt/qml/ArtistMarquee.qml','Qt/qml/ArchiveNavigator.qml','Qt/qml/ArchiveReading.qml','Qt/qml/ArchiveActionIcon.qml','Qt/shaders/archiveIcon.frag','Qt/src/PlaylistShowcase.cpp','Qt/src/PlaylistShowcase.h','Qt/src/NowPlaying.cpp','Qt/src/NowPlaying.h','Qt/qml/NowPlayingPanel.qml','Qt/shaders/recordAtmosphere.frag'):
    if (source/name).read_bytes().replace(b'\r\n',b'\n') != (maintained/'maintained'/name).read_bytes().replace(b'\r\n',b'\n'):
        raise SystemExit(f'G77 message source not installed: {name}')
for name,marker in [('Qt/src/Engine.cpp','m_messages = new MessageCenter'),('Qt/qml/GlobalTools.qml','controller:rhine.messages'),('MusicBridge/worker.cjs',"'/send/text': 'send_text'"),('Qt/tests/UiChecks.cpp','G77 text send is confirmed by Host')]:
    if marker not in (source/name).read_text(encoding='utf-8'):raise SystemExit(f'G77 missing integration: {name}')

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
