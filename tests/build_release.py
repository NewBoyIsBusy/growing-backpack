"""Build a clean loose-file Workshop payload and versioned ZIP."""
from pathlib import Path
import hashlib
import re
import shutil
import zipfile

source = Path(__file__).resolve().parents[1]
info = (source / "modinfo.lua").read_text(encoding="utf-8")
version = re.search(r'version\s*=\s*"([^"]+)"', info).group(1)
assert re.search(r"^forcemanifest\s*=\s*false\s*$", info, re.M)
dist = source / "dist"
payload = dist / source.name
files = [source / name for name in ("modinfo.lua", "modmain.lua", "README.md", "CHANGELOG.md")]
files += sorted((source / "scripts").rglob("*.lua"))
files.append(source / "assets/workshop-preview.jpg")
for file in files:
    target = payload / file.relative_to(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(file, target)
archive = dist / f"{source.name}_v{version}.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for file in files:
        z.write(file, source.name + "/" + file.relative_to(source).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".zip.sha256").write_text(digest + "  " + archive.name + "\n", encoding="ascii")
print("Built", archive, digest)
