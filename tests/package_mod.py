"""Package runtime files and install, checking previous release files before updates."""
from pathlib import Path
import shutil
import zipfile
import re

SOURCE = Path(__file__).resolve().parents[1]
version = re.search(r'version\s*=\s*"([^"]+)"', (SOURCE / "modinfo.lua").read_text(encoding="utf-8")).group(1)
ARCHIVE = SOURCE.parent / f"growing_backpack_v{version}.zip"
DEST = Path("D:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/mods/growing_backpack")
files = [SOURCE / "modinfo.lua", SOURCE / "modmain.lua", SOURCE / "README.md"]
files += sorted((SOURCE / "scripts").rglob("*.lua"))
assert not ARCHIVE.exists(), f"Archive already exists: {ARCHIVE}"
if DEST.exists():
    old_version = re.search(r'version\s*=\s*"([^"]+)"', (DEST / "modinfo.lua").read_text(encoding="utf-8")).group(1)
    previous_archive = SOURCE.parent / f"growing_backpack_v{old_version}.zip"
    assert previous_archive.exists(), "Previous release archive is required before updating installed files"
    with zipfile.ZipFile(previous_archive) as previous:
        for name in previous.namelist():
            relative = Path(name).relative_to(SOURCE.name)
            installed = DEST / relative
            assert installed.is_file() and installed.read_bytes() == previous.read(name), f"Local changes detected: {installed}"
with zipfile.ZipFile(ARCHIVE, "x", zipfile.ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, Path(SOURCE.name) / file.relative_to(SOURCE))
with zipfile.ZipFile(ARCHIVE) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(files)
DEST.mkdir(exist_ok=True)
for file in files:
    target = DEST / file.relative_to(SOURCE)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(file, target)
    assert target.read_bytes() == file.read_bytes()
print(f"Verified {len(files)} runtime/documentation files")
print(f"Archive: {ARCHIVE}")
print(f"Installed: {DEST}")
