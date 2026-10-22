"""Build a clean loose-file Workshop payload and a new versioned ZIP."""
from pathlib import Path
import hashlib
import shutil
import sys
import zipfile

source = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(source / "tools"))
from release_manifest import release_files, version, verify_payload

dist = source / "dist"
payload = dist / source.name
archive = dist / f"{source.name}_v{version(source)}.zip"
digest_file = archive.with_suffix(".zip.sha256")
assert not archive.exists() and not digest_file.exists(), "Do not overwrite an existing release"
files = release_files(source)
expected = {file.relative_to(source) for file in files}
if payload.exists():
    unexpected = {file.relative_to(payload) for file in payload.rglob("*") if file.is_file()} - expected
    assert not unexpected, "Unexpected staged files: " + str(sorted(unexpected))
dist.mkdir(exist_ok=True)
with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED) as zipped:
    for file in files:
        zipped.write(file, source.name + "/" + file.relative_to(source).as_posix())
with zipfile.ZipFile(archive) as zipped:
    assert zipped.testzip() is None
    assert len(zipped.namelist()) == len(files)
for file in files:
    target = payload / file.relative_to(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(file, target)
verify_payload(payload, source)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
with digest_file.open("x", encoding="ascii") as destination:
    destination.write(digest + "  " + archive.name + "\n")
print("Built", archive, digest)
