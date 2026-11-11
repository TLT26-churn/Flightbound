"""Build and byte-verify one portable addon ZIP. Never installs or publishes."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import zipfile
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'Flightbound'
toc=(ADDON/'Flightbound.toc').read_text()
version=re.search(r'^## Version: (\d+\.\d+\.\d+)$',toc,re.M).group(1)
assert f'F.version = "{version}"' in (ADDON/'Data.lua').read_text()
assert '## Interface: 16001' in toc
loaded=[line for line in toc.splitlines() if line and not line.startswith('#')]
assert set(loaded)=={'Data.lua','IdleGame.lua','IdleAudio.lua','IdleUI.lua','IdleMain.lua'}
assert {p.name for p in ADDON.glob('*.lua')}==set(loaded), 'Obsolete runtime code present'
for name in loaded:
    subprocess.run(['luajit','-b',str(ADDON/name),'/dev/null'],check=True)
paths=sorted(p for p in ADDON.rglob('*') if p.is_file())
names={p.relative_to(ADDON).as_posix() for p in paths}
assert len({s.lower() for s in names})==len(names),'Case-insensitive collision'
for path in paths:
    assert not path.is_symlink() and path.suffix.lower() in {'.lua','.toc','.md','.tga','.ogg'}
    if path.suffix=='.tga':
        with Image.open(path) as im:
            assert all(n>0 and n&(n-1)==0 for n in im.size),(path,im.size)
    if path.suffix=='.ogg':assert path.read_bytes().startswith(b'OggS')
for scene in Path('/tmp').glob('flightbound-idle-*.json'):
    data=json.loads(scene.read_text())
    if 'items' not in data:continue
    for item in data['items']:
        if item.get('file'):
            name=item['file'].replace('Interface\\AddOns\\Flightbound\\','').replace('\\','/')
            assert name in names,(scene,name)
output=ROOT/'dist'/f'Flightbound-{version}.zip';output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for path in paths:
        info=zipfile.ZipInfo('Flightbound/'+path.relative_to(ADDON).as_posix(),(2026,1,1,0,0,0))
        info.external_attr=0o100644<<16
        archive.writestr(info,path.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for path in paths:assert archive.read('Flightbound/'+path.relative_to(ADDON).as_posix())==path.read_bytes()
receipt={'version':version,'file':output.name,'files':len(paths),'bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'interface':16001}
output.with_suffix('.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
