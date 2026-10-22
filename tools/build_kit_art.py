"""Compile three original expansion-tool sprites with the official Klei tools.

Python 3 + Pillow and Don't Starve Mod Tools are required for rebuilding only.
The player installation uses the resulting anim ZIP and inventory XML/TEX.
"""
from pathlib import Path
import argparse
import io
import json
import hashlib
import struct
import shutil
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from PIL import Image, ImageChops, ImageStat
from build_art import ROOT, fit, run, decode_tex, reconstruct, premultiply


def build(level, toolroot, work):
    name = f"gb_upgrade_{level}"
    stage = work / name
    stage.mkdir(parents=True, exist_ok=True)
    source = ROOT / "assets/source" / f"{name}.png"
    sheet = Image.open(source).convert("RGBA")
    ground = fit(sheet, (96, 96), 2)
    icon = fit(sheet, (128, 128), 8)
    buildxml = ET.Element("Build", name=name)
    symbol = ET.SubElement(buildxml, "Symbol", name="kit")
    ET.SubElement(symbol, "Frame", framenum="0", duration="1", x="0", y="-48",
                  w="96", h="96", image="kit")
    animxml = ET.Element("Anims")
    anim = ET.SubElement(animxml, "anim", name="idle", root=name, framerate="30")
    frame = ET.SubElement(anim, "frame", x="0", y="-48", w="96", h="96")
    ET.SubElement(frame, "element", name="kit", frame="0", layername="kit", z_index="0",
                  m_a="1", m_b="0", m_c="0", m_d="1", m_tx="0", m_ty="0")
    png = io.BytesIO()
    ground.save(png, format="PNG")
    srczip = stage / f"{name}.zip"
    with zipfile.ZipFile(srczip, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("kit.png", png.getvalue())
        archive.writestr("build.xml", ET.tostring(buildxml))
        archive.writestr("animation.xml", ET.tostring(animxml))
    compiled = stage / "compiled"
    run([str(toolroot / "buildtools/windows/Python27/python.exe"), "-B",
         str(toolroot / "tools/scripts/buildanimation.py"), str(srczip), "--force",
         "--platform", "opengl", "--textureformat", "bc3", "--hardalphatextureformat", "bc3",
         "--outputdir", str(compiled)])
    resultzip = compiled / "anim" / f"{name}.zip"
    with zipfile.ZipFile(resultzip) as archive:
        stream = io.BytesIO(archive.read("build.bin"))
        def read(fmt):
            return struct.unpack("<" + fmt, stream.read(struct.calcsize("<" + fmt)))
        def string():
            return stream.read(read("I")[0]).decode("ascii")
        assert read("4sIII") == (b"BILD", 6, 1, 1)
        assert string() == name
        atlases = [decode_tex(archive.read(string())) for _ in range(read("I")[0])]
        symbolhash, count = read("II")
        assert count == 1
        builtframe = read("IIffffII")
        assert builtframe[:6] == (0, 1, 0, -48, 96, 96)
        vertices = [read("6f") for _ in range(read("I")[0])]
        restored = reconstruct({"vertices": vertices}, atlases, builtframe)
        error = ImageStat.Stat(ImageChops.difference(premultiply(ground), restored)).mean
        assert max(error[:3]) < 12 and error[3] < 5, error
        assert archive.read("anim.bin")[:8] == struct.pack("<4sI", b"ANIM", 4)
        restored.save(stage / "ground-decoded.png")
    iconpng = stage / f"{name}.png"
    icon.save(iconpng)
    icontex = stage / f"{name}.tex"
    run([str(toolroot / "tools/bin/TextureConverter.exe"), "--format", "bc3", "--platform", "opengl",
         "--mipmap", "--premultiply", "-i", str(iconpng), "-o", str(icontex)])
    restored = decode_tex(icontex.read_bytes())
    error = ImageStat.Stat(ImageChops.difference(premultiply(icon), restored)).mean
    assert max(error[:3]) < 12 and error[3] < 5, error
    restored.save(stage / "icon-decoded.png")
    atlas = ET.Element("Atlas")
    ET.SubElement(atlas, "Texture", filename=f"{name}.tex")
    elements = ET.SubElement(atlas, "Elements")
    ET.SubElement(elements, "Element", name=f"{name}.tex", u1="0.00390625", u2="0.99609375",
                  v1="0.00390625", v2="0.99609375")
    for folder in ("anim", "images"):
        (ROOT / folder).mkdir(exist_ok=True)
    shutil.copy2(resultzip, ROOT / "anim" / resultzip.name)
    shutil.copy2(icontex, ROOT / "images" / icontex.name)
    ET.ElementTree(atlas).write(ROOT / "images" / f"{name}.xml", encoding="utf-8", xml_declaration=True)
    (stage / "verification.json").write_text(json.dumps({"source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "bank": name, "build": name, "animation": "idle", "ground_size": [96, 96], "icon_error": error}, indent=2))
    print(name + ": ground animation/build and inventory BC3 round trip passed")
    return icon


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod-tools", type=Path, default=Path("D:/Program Files (x86)/Steam/steamapps/common/Don't Starve Mod Tools/mod_tools"))
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="gb_kit_art_") as temporary:
        work = (args.work_dir or Path(temporary)).resolve()
        preview = Image.new("RGBA", (384, 128))
        for level in range(1, 4):
            preview.paste(build(level, args.mod_tools.resolve(), work), ((level - 1) * 128, 0))
        preview.save(ROOT / "assets/kits-preview.png")
