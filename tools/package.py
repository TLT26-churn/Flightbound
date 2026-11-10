"""Build the installable, portable Flightbound ZIP from this checkout."""
from pathlib import Path
import hashlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "Flightbound"
toc = (ADDON / "Flightbound.toc").read_text()
version = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc, re.M).group(1)
assert f'F.version = "{version}"' in (ADDON / "Data.lua").read_text()
for line in toc.splitlines():
    if line and not line.startswith("#"):
        assert (ADDON / line).is_file(), f"Missing manifest file: {line}"
paths = sorted(p for p in ADDON.rglob("*") if p.is_file())
allowed = {".lua", ".toc", ".md", ".txt", ".tga", ".ttf", ".ogg"}
for path in paths:
    assert path.suffix.lower() in allowed and not path.is_symlink(), path
output = ROOT / "dist" / f"Flightbound-{version}.zip"
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in paths:
        archive.write(path, "Flightbound/" + path.relative_to(ADDON).as_posix())
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for path in paths:
        assert archive.read("Flightbound/" + path.relative_to(ADDON).as_posix()) == path.read_bytes()
print(f"{output.name}: {len(paths)} files, {output.stat().st_size} bytes")
print("SHA256:", hashlib.sha256(output.read_bytes()).hexdigest())
