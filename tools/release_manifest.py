"""Shared, read-only manifest for local ZIPs and Workshop runtime verification."""
from pathlib import Path
import re
import struct

SOURCE = Path(__file__).resolve().parents[1]
ART_NAMES = tuple(f"gb_pack_{level}" for level in range(4)) + tuple(
    f"gb_upgrade_{level}" for level in range(1, 4)
) + ("gb_preservation_kit", "gb_freshness_kit")


def version(source=SOURCE):
    info = (source / "modinfo.lua").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"(\d+\.\d+\.\d+)"\s*$', info, re.M)
    assert match, "Expected an explicit semantic version in modinfo.lua"
    assert re.search(r"^forcemanifest\s*=\s*false\s*$", info, re.M), "Loose-file packages require forcemanifest = false"
    return match.group(1)


def runtime_files(source=SOURCE):
    files = [source / "modinfo.lua", source / "modmain.lua"]
    files += sorted((source / "scripts").rglob("*.lua"))
    for name in ART_NAMES:
        files.append(source / "anim" / (name + ".zip"))
        files.extend(source / "images" / (name + extension) for extension in (".xml", ".tex"))
    missing = [str(file.relative_to(source)) for file in files if not file.is_file()]
    assert not missing, "Build all four backpacks and five tools first; missing: " + ", ".join(missing)
    for name in ART_NAMES:
        data = (source / "images" / (name + ".tex")).read_bytes()
        assert data[:4] == b"KTEX" and struct.unpack_from("<HH", data, 8) == (64, 64), \
            "Rebuild the 64-pixel inventory icon: " + name
    return files


def release_files(source=SOURCE):
    files = runtime_files(source) + [source / name for name in (
        "README.md", "CHANGELOG.md", "assets/workshop-preview.jpg",
        "assets/tiers-preview.png", "assets/kits-preview.png",
    )]
    assert all(file.is_file() for file in files), "Missing release documentation or preview"
    assert len(files) == len(set(files)), "Duplicate release entries"
    return files


def verify_payload(folder, source=SOURCE):
    files = release_files(source)
    expected = {file.relative_to(source) for file in files}
    actual = {file.relative_to(folder) for file in folder.rglob("*") if file.is_file()}
    assert actual == expected, "Staging manifest differs from the current release: " + str(actual ^ expected)
    for file in files:
        staged = folder / file.relative_to(source)
        assert staged.read_bytes() == file.read_bytes(), "Stale staged file: " + str(staged)
    return files
