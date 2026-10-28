"""Exercise the actual G67 installer with Windows cp1252 fallback and LF/CRLF/mixed inputs.
Usage: python scripts/test-g67-windows-encoding.py /path/to/pristine-applied-G66
"""
import ast
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
base = Path(sys.argv[1]).resolve()
patch = (repo / 'patches/g67-independent-queue.patch').read_bytes().replace(b'\r\n', b'\n')
files = [line[6:].decode('utf-8') for line in patch.splitlines() if line.startswith(b'+++ b/')]
fixed = (repo / 'scripts/enable-g67.py').read_text(encoding='utf-8')
broken = fixed.replace("main = Path('Qt/qml/Main.qml').read_text(encoding='utf-8')",
                       "main = Path('Qt/qml/Main.qml').read_text()")
assert broken != fixed
wrapper = '''import io, runpy, sys
original = io.open
def windows_open(*args, **kwargs):
    mode = kwargs.get('mode', args[1] if len(args)>1 else 'r')
    encoding = kwargs.get('encoding', args[3] if len(args)>3 else None)
    if 'b' not in mode and encoding in (None, 'locale'):
        if len(args)>3:
            args = list(args); args[3] = 'cp1252'
        else:
            kwargs['encoding'] = 'cp1252'
    return original(*args, **kwargs)
io.open = windows_open
runpy.run_path(sys.argv[1], run_name='__main__')
'''
expected = None
for mode in ('lf', 'crlf', 'mixed'):
    for variant, installer_source in (('broken', broken), ('fixed', fixed)):
        with tempfile.TemporaryDirectory() as tmp:
            temp = Path(tmp)
            installer = temp / 'installer'
            (installer / 'scripts').mkdir(parents=True)
            (installer / 'patches').mkdir()
            (installer / 'maintained/Qt/qml').mkdir(parents=True)
            script = installer / 'scripts/enable-g67.py'
            script.write_text(installer_source, encoding='utf-8')
            for name in ('PlayerQueueGlass.qml', 'SideNavigation.qml', 'DiscoverGlass.qml'):
                shutil.copyfile(repo / 'maintained/Qt/qml' / name, installer / 'maintained/Qt/qml' / name)
            (installer / 'patches/g67-independent-queue.patch').write_bytes(
                patch if mode == 'lf' else patch.replace(b'\n', b'\r\n'))
            work = temp / 'source'
            work.mkdir()
            subprocess.run(['git', 'init', '--quiet', str(work)], check=True)
            for i, name in enumerate(files):
                raw = (base / name).read_bytes().replace(b'\r\n', b'\n')
                if mode == 'crlf' or (mode == 'mixed' and i % 2):
                    raw = raw.replace(b'\n', b'\r\n')
                target = work / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            result = subprocess.run([sys.executable, '-X', 'utf8=0', '-c', wrapper, str(script)], cwd=work,
                                    capture_output=True, text=True, encoding='utf-8')
            if variant == 'broken':
                assert result.returncode != 0 and 'UnicodeDecodeError' in result.stderr and 'cp1252.py' in result.stderr, result.stderr
                print('PASS:', mode, 'reproduces the exact Windows cp1252 installer failure')
                continue
            assert result.returncode == 0, result.stdout + result.stderr
            output = {name: (work / name).read_bytes() for name in files}
            assert all(b'\r\n' not in raw for raw in output.values())
            if expected is None: expected = output
            else: assert output == expected, mode
            print('PASS:', mode, 'fixed installer succeeds with cp1252 defaults; output matches LF baseline')

# Audit the production installer chain, rather than unrelated test/report scripts.
chain = (repo / 'scripts/apply-maintained.py').read_text(encoding='utf-8')
import re
names = ['apply-maintained.py', 'verify-build-source.py'] + re.findall(r'with_name\("(enable-[^"]+\.py)"\)', chain)
for name in names:
    tree = ast.parse((repo / 'scripts' / name).read_text(encoding='utf-8'))
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr in ('read_text', 'write_text'):
            assert any(k.arg == 'encoding' for k in node.keywords), (name, node.lineno)
print('PASS: all active installer and source-verification text reads/writes specify encoding')
