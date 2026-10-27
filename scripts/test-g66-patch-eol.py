"""Apply the actual G66 installer to LF, CRLF and mixed G65 sources.

Usage: python scripts/test-g65-patch-eol.py /path/to/pristine-applied-G65
The test makes disposable copies; it does not edit the input source tree.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
base = Path(sys.argv[1]).resolve()
patch = (repo / 'patches/g66-layered-glass-provenance.patch').read_bytes().replace(b'\r\n', b'\n')
files = [line[6:].decode() for line in patch.splitlines() if line.startswith(b'+++ b/')]
expected = None
for mode in ('lf', 'crlf', 'mixed'):
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        installer = temp / 'installer'
        (installer / 'scripts').mkdir(parents=True)
        (installer / 'patches').mkdir()
        (installer / 'maintained/Qt/qml').mkdir(parents=True)
        shutil.copyfile(repo / 'scripts/enable-g66.py', installer / 'scripts/enable-g66.py')
        shutil.copyfile(repo / 'maintained/Qt/qml/PlayerQueueGlass.qml', installer / 'maintained/Qt/qml/PlayerQueueGlass.qml')
        # Reproduce Windows' CRLF checkout of the patch itself as well.
        (installer / 'patches/g66-layered-glass-provenance.patch').write_bytes(
            patch if mode == 'lf' else patch.replace(b'\n', b'\r\n'))
        work = temp / 'source'
        work.mkdir()
        subprocess.run(['git', 'init', '--quiet', str(work)], check=True)
        for name in files:
            raw = (base / name).read_bytes().replace(b'\r\n', b'\n')
            if mode == 'crlf' or (mode == 'mixed' and name not in ('Qt/src/MusicLibrary.h', 'Qt/src/MusicMutation.cpp')):
                raw = raw.replace(b'\n', b'\r\n')
            target = work / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        subprocess.run([sys.executable, str(installer / 'scripts/enable-g66.py')], cwd=work, check=True)
        result = {name: (work / name).read_bytes() for name in files}
        assert all(b'\r\n' not in raw for raw in result.values())
        if expected is None:
            expected = result
        else:
            assert result == expected, mode + ': source output differs from LF baseline'
        print('PASS: ' + mode + ' patch/source -> identical patched source bytes')
