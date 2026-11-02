"""Verify the standalone application without fetching or applying old patches.

The historical baseline is immutable evidence. Use --compare-baseline only for
this migration's equivalence check; subsequent development edits app/ directly.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'app'
parser = argparse.ArgumentParser()
parser.add_argument('--compare-baseline', action='store_true')
parser.add_argument('--stamp', type=Path)
args = parser.parse_args()

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inventory(root):
    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
        cwd=root).decode('utf-8').split('\0')
    return {name: digest(root/name) for name in sorted(set(names))
            if name and (root/name).is_file()}

actual = inventory(APP)
assert actual, 'Standalone source tree is empty'
for name in ['CMakeLists.txt', 'Qt/CMakeLists.txt', 'package.json', 'package-lock.json',
             'Qt/src/main.cpp', 'Qt/src/PlatformWindows.cpp', 'Qt/tests/UiChecks.cpp',
             'Assets/fonts/RhineMiSans-regular.otf', 'LICENSE', 'NOTICE',
             'licenses/source-manifest.json', 'MusicBridge/upstream/LICENSE',
             'MusicBridge/package-lock.json', 'vendor/taglib/taglib-2.1.1.tar.gz',
             'vendor/utfcpp/utfcpp-4.0.6.tar.gz']:
    assert name in actual, 'Missing standalone build input: '+name

baseline = json.loads((ROOT/'migration/source-baseline.json').read_text(encoding='utf-8'))
expected = dict(baseline['files'])
validation_changes = ROOT/'migration/ui-validation-changes.json'
if validation_changes.exists():
    for name, change in json.loads(validation_changes.read_text(encoding='utf-8')).items():
        assert name in {'Qt/tests/UiChecks.cpp', 'Qt/tests/TaskbarChecks.cpp'}, 'Unexpected migration exception: '+name
        assert change['before_sha256'] == expected[name], 'Validation exception has the wrong baseline: '+name
        expected[name] = change['after_sha256']
if args.compare_baseline:
    added = sorted(set(actual)-set(expected))
    missing = sorted(set(expected)-set(actual))
    changed = sorted(name for name in actual.keys() & expected.keys() if actual[name] != expected[name])
    assert not (added or missing or changed), json.dumps(dict(added=added, missing=missing, changed=changed))

head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
if os.environ.get('GITHUB_SHA'):
    assert head == os.environ['GITHUB_SHA'], 'Checkout does not match this workflow commit'
stamp = dict(commit=head, application_directory='app', files=actual,
             baseline_commit=baseline['maintained_commit'],
             baseline_equal=actual == baseline['files'],
             migration_equal=actual == expected,
             historical_patches_required=False)
if args.stamp:
    args.stamp.parent.mkdir(parents=True, exist_ok=True)
    args.stamp.write_text(json.dumps(stamp,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Standalone source: {len(actual)} files; verified migration inputs match: {stamp["migration_equal"]}; no reconstruction step.')
