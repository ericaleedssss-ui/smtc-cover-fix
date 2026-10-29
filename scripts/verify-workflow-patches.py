"""Check embedded workflow patch bytes before submitting a build.

Read only the simple PATCH_PART/PATCH_SHA256 environment scalar lines; no YAML
package is needed on Windows CI. Version labels must never modify these bytes.
"""
from pathlib import Path
import base64
import gzip
import hashlib
import re

root=Path(__file__).resolve().parents[1]
workflow=(root/'.github/workflows/build-smtc.yml').read_text(encoding='utf-8')
blocks=re.findall(r'(?ms)^        PATCH_PART_000:.*?^        PATCH_SHA256: [^\n]+',workflow)
assert len(blocks)==2,'Expected Rhine and overlay embedded patches'
for index,block in enumerate(blocks):
    parts=re.findall(r'^        (PATCH_PART_\d+): ([A-Za-z0-9+/=]+)\s*$',block,re.M)
    assert parts and len(parts)==len(set(k for k,_ in parts))
    decoded=gzip.decompress(base64.b64decode(''.join(v for _,v in sorted(parts)),validate=True))
    expected=re.search(r'^        PATCH_SHA256: ([a-f0-9]{64})',block,re.M).group(1)
    assert hashlib.sha256(decoded).hexdigest()==expected,'Embedded patch hash mismatch'
    if index==0:assert decoded==(root/'patches/G53-base.patch').read_bytes(),'Rhine canonical patch mismatch'
    print(f'Workflow patch {index+1}: gzip CRC, SHA256 and canonical bytes verified ({len(decoded)} bytes)')
