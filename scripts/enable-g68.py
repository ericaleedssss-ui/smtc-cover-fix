"""G68: exercise the actual footer queue entry in Windows retained-page QA."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
patch = (root / 'patches/g68-footer-entry-qa.patch').read_bytes().replace(b'\r\n', b'\n')
for line in patch.splitlines():
    if line.startswith(b'+++ b/'):
        target = Path(line[6:].decode())
        target.write_bytes(target.read_bytes().replace(b'\r\n', b'\n'))
subprocess.run(['git', 'apply', '--check', '-'], input=patch, check=True)
subprocess.run(['git', 'apply', '-'], input=patch, check=True)
print('G68: Windows retained-page QA opens and closes the queue through actual footer mouse events.')

patch = (root / 'patches/g68-retained-scroll-qa.patch').read_bytes().replace(b'\r\n', b'\n')
target = Path('Qt/tests/UiChecks.cpp')
target.write_bytes(target.read_bytes().replace(b'\r\n', b'\n'))
subprocess.run(['git', 'apply', '--check', '-'], input=patch, check=True)
subprocess.run(['git', 'apply', '-'], input=patch, check=True)
print('G68: assert settled wheel baseline and report each retained-page field in Windows QA.')
