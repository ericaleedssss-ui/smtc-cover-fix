"""Apply G69 to the committed applied-G68 baseline in LF/CRLF/mixed checkouts.
Usage: test-g69-patch-eol.py /path/to/committed-applied-G68
"""
from pathlib import Path
import subprocess,sys,shutil,tempfile
repo=Path(__file__).resolve().parents[1];base=Path(sys.argv[1]).resolve()
patch=(repo/'patches/g69-magazine-playlist.patch').read_bytes().replace(b'\r\n',b'\n')
files=[line[6:].decode() for line in patch.splitlines() if line.startswith(b'+++ b/')]
expected=None
for mode in ('lf','crlf','mixed'):
 with tempfile.TemporaryDirectory() as tmp:
  tmp=Path(tmp);installer=tmp/'installer';(installer/'scripts').mkdir(parents=True);(installer/'patches').mkdir()
  shutil.copytree(repo/'maintained',installer/'maintained');shutil.copyfile(repo/'scripts/enable-g69.py',installer/'scripts/enable-g69.py')
  (installer/'patches/g69-magazine-playlist.patch').write_bytes(patch if mode=='lf' else patch.replace(b'\n',b'\r\n'))
  work=tmp/'source';work.mkdir();subprocess.run(['git','init','--quiet',str(work)],check=True)
  for i,name in enumerate(files):
   result=subprocess.run(['git','show','HEAD:'+name],cwd=base,capture_output=True)
   if result.returncode:continue # new G69 files have no G68 baseline
   raw=result.stdout.replace(b'\r\n',b'\n')
   if mode=='crlf' or (mode=='mixed' and i%2):raw=raw.replace(b'\n',b'\r\n')
   target=work/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  subprocess.run([sys.executable,str(installer/'scripts/enable-g69.py')],cwd=work,check=True,stdout=subprocess.DEVNULL)
  result={name:(work/name).read_bytes() for name in files}
  assert all(b'\r\n' not in data for data in result.values())
  if expected is None:expected=result
  else:assert result==expected,mode
  print('PASS:',mode,'G69 patch and checkout produce identical source bytes')
