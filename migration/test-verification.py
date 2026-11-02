"""Meaningful negative tests for the migration's provenance/package guards."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[1]
def run(args,**kwargs):
    return subprocess.run([sys.executable,*map(str,args)],capture_output=True,text=True,**kwargs)

with tempfile.TemporaryDirectory(prefix='rhine-migration-check-') as temporary:
    temp=Path(temporary)
    # Use a tiny isolated Git repository; never alter real application files.
    checkout=temp/'checkout';app=checkout/'app';app.mkdir(parents=True)
    migration=checkout/'migration';migration.mkdir()
    shutil.copyfile(ROOT/'migration/verify-source.py',migration/'verify-source.py')
    baseline=json.loads((ROOT/'migration/source-baseline.json').read_text(encoding='utf-8'))
    required=['CMakeLists.txt','Qt/CMakeLists.txt','package.json','package-lock.json',
              'Qt/src/main.cpp','Qt/src/PlatformWindows.cpp','Qt/tests/UiChecks.cpp',
              'Assets/fonts/RhineMiSans-regular.otf','LICENSE','NOTICE',
              'licenses/source-manifest.json','MusicBridge/upstream/LICENSE',
              'MusicBridge/package-lock.json','vendor/taglib/taglib-2.1.1.tar.gz',
              'vendor/utfcpp/utfcpp-4.0.6.tar.gz']
    hashes={}
    for name in required:
        p=app/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture\n')
        hashes[name]=hashlib.sha256(p.read_bytes()).hexdigest()
    (migration/'source-baseline.json').write_text(json.dumps(dict(maintained_commit=baseline['maintained_commit'],files=hashes)))
    subprocess.run(['git','init','-q'],cwd=checkout,check=True)
    subprocess.run(['git','-c','user.name=Migration test','-c','user.email=test@localhost','commit','--allow-empty','-qm','test'],cwd=checkout,check=True)
    env={k:v for k,v in os.environ.items() if k!='GITHUB_SHA'}
    assert run([migration/'verify-source.py','--compare-baseline'],env=env).returncode==0
    (app/'Qt/src/main.cpp').write_bytes(b'changed\n')
    assert run([migration/'verify-source.py','--compare-baseline'],env=env).returncode!=0
    # Ordinary future source changes are permitted; only migration equivalence
    # uses the frozen baseline. They still must match the workflow commit.
    assert run([migration/'verify-source.py'],env=env).returncode==0
    assert run([migration/'verify-source.py'],env={**env,'GITHUB_SHA':'0'*40}).returncode!=0
    print('PASS: changed baseline and wrong workflow commit are rejected; future app edits remain possible.')

    deployed=temp/'RHINE MUSIC DATABASE'
    for name in ['resources/LICENSE','resources/NOTICE','resources/MusicBridge/NODE-LICENSE','RHINE MUSIC DATABASE.exe']:
        p=deployed/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
    archive=temp/'app.zip'
    def pack(extra=False):
        with zipfile.ZipFile(archive,'w') as z:
            for p in deployed.rglob('*'):
                if p.is_file():z.write(p,deployed.name+'/'+p.relative_to(deployed).as_posix())
            if extra:z.writestr(deployed.name+'/data/account.dpapi',b'forbidden fixture')
    pack()
    command=[ROOT/'migration/verify-package.py','--app',deployed,'--zip',archive,'--report',temp/'package.json']
    assert run(command).returncode==0
    pack(extra=True)
    assert run(command).returncode!=0
    print('PASS: portable archive equality passes; unexpected account data is rejected.')
