"""Run the existing packaged UI regression with the original offline fixture."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--app',type=Path,default=ROOT/'app/output/windows/RHINE MUSIC DATABASE')
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--geometry',default=os.environ.get('RHINE_QA_GEOMETRY'),
    help='Optional Qt initial geometry; verify placement manually on mixed-DPI desktops first')
args=parser.parse_args()
app=args.app.resolve();qa=args.output.resolve();qa.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'migration/comments-fixture.json',qa/'comments-fixture.json')
command=[str(app/'RHINE MUSIC DATABASE.exe'),'--frosted-self-test',str(qa)]
if args.geometry:
    command.extend(['-qwindowgeometry',args.geometry])
result=subprocess.run(command,
    cwd=app,timeout=360,capture_output=True,text=True,encoding='utf-8',errors='replace')
(qa/'stdout.txt').write_text(result.stdout,encoding='utf-8')
(qa/'stderr.txt').write_text(result.stderr,encoding='utf-8')
print(result.stdout)
print(result.stderr)
assert not any('NowPlayingPanel.qml:' in line and ('TypeError:' in line or 'ReferenceError:' in line)
    for line in result.stdout.splitlines()+result.stderr.splitlines()),'Now-playing QML runtime error'
result.check_returncode()
assert (qa/'preview-on.png').is_file(),'Packaged UI check did not render its preview'
