"""Check the candidate ZIP against the deployed app, preserving existing audits."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

parser=argparse.ArgumentParser()
parser.add_argument('--app',type=Path,required=True)
parser.add_argument('--zip',type=Path,required=True)
parser.add_argument('--report',type=Path,required=True)
args=parser.parse_args()
app=args.app.resolve()
with zipfile.ZipFile(args.zip) as archive:
    files={name:hashlib.sha256(archive.read(name)).hexdigest()
           for name in archive.namelist() if not name.endswith('/')}
expected={app.name+'/'+p.relative_to(app).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
          for p in app.rglob('*') if p.is_file() and p.relative_to(app).parts[0]!='data'}
assert files == expected, 'Distribution ZIP does not match the deployed application'
for name in ['resources/LICENSE','resources/NOTICE','resources/MusicBridge/NODE-LICENSE']:
    assert app.name+'/'+name in files, 'Missing distributed attribution: '+name
report=dict(files=len(files),archive_sha256=hashlib.sha256(args.zip.read_bytes()).hexdigest(),
            deployed_files=expected,personal_data_excluded=True)
args.report.parent.mkdir(parents=True,exist_ok=True)
args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f'Portable ZIP: {len(files)} files match deployed application; license notices present.')
