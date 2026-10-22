"""Build original backpack art with Klei's installed animation/texture tools.

Requires Python 3 + Pillow and the official Don't Starve Mod Tools installation.
Inputs: assets/source/gb_pack_0.png ... gb_pack_3.png, transparent 4 x 3 grids.
Example: python tools/build_art.py --level 0 --work-dir ../.tools/art_build
The output contains build-only anim ZIPs and shared inventory/minimap atlases.
The original anim/backpack.zip supplies the backpack1/anim animation (frame 13).
This script only crops, resizes, packs and verifies images; it does not draw art.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parents[1]
# frame, duration, center x/y, width/height, from the installed swap_backpack
# build's swap_body symbol. Frame 10 lasts 3 frames, covering frame IDs 10..12.
# IDs 0..5 are front straps, 6..10 worn views, and 13 is the dropped backpack.
FRAMES = (
    (0, 1, -0.5, -52.275001525878906, 72, 60),
    (1, 1, -7.275000095367432, -53.32500076293945, 72, 68),
    (2, 1, 7.699999809265137, -51.95000076293945, 76, 60),
    (3, 1, -9.550000190734863, -59.75, 44, 68),
    (4, 1, 1.975000023841858, -57.29999923706055, 64, 52),
    (5, 1, -17.350000381469727, -54.125, 44, 68),
    (6, 1, -2.625, -45.474998474121094, 100, 100),
    (7, 1, -14.524999618530273, -48.92499923706055, 100, 104),
    (8, 1, 2.0, -45.54999923706055, 100, 104),
    (9, 1, -2.625, -45.474998474121094, 100, 100),
    (10, 3, -41.0, -51.400001525878906, 76, 108),
    (13, 1, -2.9000000953674316, -59.375, 168, 152),
)


def fit(image: Image.Image, size: tuple[int, int], padding: int = 0) -> Image.Image:
    """Contain the alpha-cropped art in a fixed, transparent geometry box."""
    # Generated transparent PNGs can contain isolated alpha 1..3 pixels across
    # blank margins. Exclude those from the crop bounds without modifying any
    # pixel inside the crop; otherwise the visible sprite becomes half-sized.
    bbox = image.getchannel("A").point(lambda alpha: 255 if alpha >= 8 else 0).getbbox()
    if bbox is None:
        raise ValueError("Empty sprite cell")
    image = image.crop(bbox)
    scale = min((size[0] - padding * 2) / image.width,
                (size[1] - padding * 2) / image.height)
    scaled = image.resize((max(1, round(image.width * scale)),
                           max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size)
    result.paste(scaled, ((size[0] - scaled.width) // 2, (size[1] - scaled.height) // 2))
    return result


def grid_bounds(sheet: Image.Image) -> tuple[list[int], list[int]]:
    """Find transparent cuts near the intended grid without discarding pixels.

    A tall key can cross a nominal row boundary while still being separated
    from the preceding sprite. Search only +/-8% of a cell, require a four-pixel
    transparent band, and keep the nearest valid cut. Connected/overlapping
    sprites are rejected rather than being clipped or silently separated.
    """
    if sheet.width % 4 or sheet.height % 3:
        raise ValueError("Expected exact 4 x 3 source dimensions")
    alpha = sheet.getchannel("A")

    def boundaries(axis: str, count: int, size: int) -> list[int]:
        span = size // count
        radius = int(span * .08)
        result = [0]
        for index in range(1, count):
            nominal = index * span
            candidates = sorted(range(nominal - radius, nominal + radius + 1),
                                key=lambda position: (abs(position - nominal), position))
            for position in candidates:
                strip = alpha.crop((position - 2, 0, position + 2, sheet.height)
                                   if axis == "x" else (0, position - 2, sheet.width, position + 2))
                if strip.getextrema()[1] < 8:
                    result.append(position)
                    break
            else:
                raise ValueError(f"No transparent {axis} grid gap near {nominal} (+/-{radius}); "
                                 "sprites may overlap or connect; fix source art")
        return result + [size]

    return boundaries("x", 4, sheet.width), boundaries("y", 3, sheet.height)


def run(command: list[str], cwd: Path | None = None) -> None:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            errors="replace", creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {command}\n"
                           f"{result.stdout}\n{result.stderr}")


def decode_tex(data: bytes) -> Image.Image:
    """Decode the official compiler's OpenGL BC3 primary mip for round-trip QA."""
    if data[:4] != b"KTEX":
        raise ValueError("Not a KTEX file")
    flags = struct.unpack_from("<I", data, 4)[0]
    pixel_format, mip_count = (flags >> 4) & 31, (flags >> 13) & 31
    if pixel_format != 2 or not mip_count:
        raise ValueError(f"Expected BC3 with mipmaps, got {pixel_format}/{mip_count}")
    width, height, _pitch, count = struct.unpack_from("<HHHI", data, 8)
    start = 8 + 10 * mip_count
    if count != ((width + 3) // 4) * ((height + 3) // 4) * 16:
        raise ValueError("Invalid BC3 primary mip length")
    image = Image.frombytes("RGBA", (width, height), data[start:start + count], "bcn", (3, "DXT5"))
    return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)


def parse_build(data: bytes) -> dict:
    stream = io.BytesIO(data)

    def read(fmt):
        return struct.unpack(fmt, stream.read(struct.calcsize(fmt)))

    def string():
        return stream.read(read("<I")[0]).decode("ascii")

    magic, version, symbols, frame_count = read("<4sIII")
    if (magic, version, symbols, frame_count) != (b"BILD", 6, 1, len(FRAMES)):
        raise ValueError("Unexpected build header")
    name = string()
    atlases = [string() for _ in range(read("<I")[0])]
    symbol_hash, count = read("<II")
    if symbol_hash != 3067666734 or count != len(FRAMES):
        raise ValueError("Expected swap_body with 12 frames")
    frames = [read("<IIffffII") for _ in range(count)]
    vertices = [read("<6f") for _ in range(read("<I")[0])]
    hashes = {read("<I")[0]: string() for _ in range(read("<I")[0])}
    if hashes.get(symbol_hash) != "swap_body" or stream.read():
        raise ValueError("Invalid build symbol table")
    return {"name": name, "atlases": atlases, "frames": frames, "vertices": vertices}


def reconstruct(build: dict, atlases: list[Image.Image], frame: tuple) -> Image.Image:
    _index, _duration, x, y, width, height, start, count = frame
    canvas = Image.new("RGBA", (round(width), round(height)))
    if count % 6:
        raise ValueError("Unexpected triangle count")
    vertices = build["vertices"][start:start + count]
    for offset in range(0, count, 6):
        top_left, top_right, bottom_left = vertices[offset:offset + 3]
        atlas = atlases[round(top_left[5])]
        left, top = round(top_left[3] * atlas.width), round((1 - top_left[4]) * atlas.height)
        right, bottom = round(top_right[3] * atlas.width), round((1 - bottom_left[4]) * atlas.height)
        region = atlas.crop((left, top, right, bottom))
        dest = (round(top_left[0] - x + width / 2), round(top_left[1] - y + height / 2))
        canvas.paste(region, dest)
    return canvas


def premultiply(image: Image.Image) -> Image.Image:
    r, g, b, a = image.split()
    return Image.merge("RGBA", (ImageChops.multiply(r, a), ImageChops.multiply(g, a),
                                 ImageChops.multiply(b, a), a))


def preview(images: list[Image.Image], path: Path) -> None:
    sheet = Image.new("RGBA", (800, 600), (210, 210, 210, 255))
    draw = ImageDraw.Draw(sheet)
    for i, image in enumerate(images):
        x, y = (i % 4) * 200, (i // 4) * 200
        draw.text((x + 8, y + 8), str(FRAMES[i][0]), fill="black")
        sheet.alpha_composite(image, (x + (200 - image.width) // 2, y + (200 - image.height) // 2))
    sheet.save(path)


def build_level(level: int, toolroot: Path, output: Path, work: Path) -> dict:
    name = f"gb_pack_{level}"
    source = ROOT / "assets/source" / f"{name}.png"
    stage = work / name
    stage.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as opened:
        sheet = opened.convert("RGBA")
    columns, rows = grid_bounds(sheet)
    cells, frames = [], []
    root = ET.Element("Build", name=name)
    symbol = ET.SubElement(root, "Symbol", name="swap_body")
    source_zip = stage / f"{name}.zip"
    with zipfile.ZipFile(source_zip, "w", zipfile.ZIP_DEFLATED) as archive:
        for i, (index, duration, x, y, width, height) in enumerate(FRAMES):
            col, row = i % 4, i // 4
            cell = sheet.crop((columns[col], rows[row], columns[col + 1], rows[row + 1]))
            cell_w, cell_h = cell.size
            bounds = cell.getchannel("A").point(lambda alpha: 255 if alpha >= 8 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"{source}: empty cell {i} / frame {index}")
            if bounds[0] < 2 or bounds[1] < 2 or bounds[2] > cell_w - 2 or bounds[3] > cell_h - 2:
                raise ValueError(f"{source}: visible art touches grid edge at row {row + 1}, "
                                 f"column {col + 1} / frame {index}, bounds={bounds}; fix source art")
            cells.append(cell)
            frame = fit(cell, (width, height))
            frames.append(frame)
            frame.save(stage / f"swap_body_{index}.png")
            png = io.BytesIO()
            frame.save(png, format="PNG")
            archive.writestr(f"swap_body_{index}.png", png.getvalue())
            ET.SubElement(symbol, "Frame", framenum=str(index), duration=str(duration),
                          x=str(x), y=str(y), w=str(width), h=str(height), image=f"swap_body_{index}")
        archive.writestr("build.xml", ET.tostring(root, encoding="utf-8", xml_declaration=True))
    visible_pixels = sheet.getchannel("A").point(lambda alpha: 255 if alpha >= 8 else 0).histogram()[255]
    sliced_pixels = sum(cell.getchannel("A").point(lambda alpha: 255 if alpha >= 8 else 0).histogram()[255]
                        for cell in cells)
    if sliced_pixels != visible_pixels or len(cells) != 12:
        raise ValueError("Grid slicing did not preserve all visible source pixels")
    python27 = toolroot / "buildtools/windows/Python27/python.exe"
    compiler = toolroot / "tools/scripts/buildanimation.py"
    compiled = stage / "compiled"
    run([str(python27), "-B", str(compiler), str(source_zip), "--force", "--platform", "opengl",
         "--textureformat", "bc3", "--hardalphatextureformat", "bc3", "--outputdir", str(compiled)])
    compiled_zip = compiled / "anim" / f"{name}.zip"
    with zipfile.ZipFile(compiled_zip) as archive:
        build = parse_build(archive.read("build.bin"))
        if build["name"] != name:
            raise ValueError("Build name mismatch")
        atlases = [decode_tex(archive.read(path)) for path in build["atlases"]]
        decoded = []
        errors = []
        for expected, actual, original in zip(FRAMES, build["frames"], frames, strict=True):
            if any(abs(a - b) > 0.0001 for a, b in zip(expected, actual[:6], strict=True)):
                raise ValueError(f"Changed frame geometry: {actual}")
            restored = reconstruct(build, atlases, actual)
            decoded.append(restored)
            mean_error = ImageStat.Stat(ImageChops.difference(premultiply(original), restored)).mean
            if max(mean_error[:3]) > 12 or mean_error[3] > 5:
                raise ValueError(f"Texture round trip failed at frame {expected[0]}: {mean_error}")
            errors.append({"frame": expected[0], "mean_rgba_error": mean_error})
        preview(frames, stage / "frames-before.png")
        preview(decoded, stage / "frames-decoded.png")
    icon = fit(cells[-1], (128, 128), padding=8)
    icon_path = stage / f"{name}.png"
    icon.save(icon_path)
    icon_tex = stage / f"{name}.tex"
    converter = toolroot / "tools/bin/TextureConverter.exe"
    run([str(converter), "--swizzle", "--format", "bc3", "--platform", "opengl", "--mipmap",
         "--premultiply", "-i", str(icon_path), "-o", str(icon_tex)])
    icon_decoded = decode_tex(icon_tex.read_bytes())
    error = ImageStat.Stat(ImageChops.difference(premultiply(icon), icon_decoded)).mean
    if max(error[:3]) > 12 or error[3] > 5:
        raise ValueError(f"Icon round trip failed: {error}")
    icon_decoded.save(stage / "icon-decoded.png")
    atlas = ET.Element("Atlas")
    ET.SubElement(atlas, "Texture", filename=f"{name}.tex")
    elements = ET.SubElement(atlas, "Elements")
    # Inventory uses .tex; the map alias follows the game's existing .png names.
    for extension in ("tex", "png"):
        ET.SubElement(elements, "Element", name=f"{name}.{extension}",
                      u1="0.00390625", u2="0.99609375", v1="0.00390625", v2="0.99609375")
    (output / "anim").mkdir(parents=True, exist_ok=True)
    (output / "images").mkdir(parents=True, exist_ok=True)
    shutil.copy2(compiled_zip, output / "anim" / compiled_zip.name)
    shutil.copy2(icon_tex, output / "images" / icon_tex.name)
    ET.ElementTree(atlas).write(output / "images" / f"{name}.xml", encoding="utf-8", xml_declaration=True)
    report = {"level": level, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "source_size": list(sheet.size), "source_columns": columns, "source_rows": rows,
              "source_visible_pixels": visible_pixels, "sliced_visible_pixels": sliced_pixels,
              "frame_count": len(frames), "frame_errors": errors,
              "icon_mean_rgba_error": error, "preview": str(stage / "frames-decoded.png")}
    (stage / "verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"{name}: verified 12 frames, build geometry, BC3 round trip, inventory/map icon")
    print(f"  QA: {stage / 'frames-decoded.png'}")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--level", type=int, choices=range(4), help="Build just one level; default builds all four")
    parser.add_argument("--mod-tools", type=Path, default=Path(os.environ.get("DST_MOD_TOOLS",
                        "D:/Program Files (x86)/Steam/steamapps/common/Don't Starve Mod Tools/mod_tools")))
    parser.add_argument("--output-dir", type=Path, default=ROOT)
    parser.add_argument("--work-dir", type=Path, help="Keep intermediate PNGs and decoded QA previews here")
    args = parser.parse_args()
    toolroot = args.mod_tools.resolve()
    if (toolroot / "mod_tools").is_dir():
        toolroot /= "mod_tools"
    for relative in ("buildtools/windows/Python27/python.exe", "tools/scripts/buildanimation.py",
                     "tools/bin/TextureConverter.exe"):
        if not (toolroot / relative).is_file():
            parser.error(f"Missing official tool: {toolroot / relative}")
    levels = range(4) if args.level is None else [args.level]
    for level in levels:
        if not (ROOT / "assets/source" / f"gb_pack_{level}.png").is_file():
            parser.error(f"Missing source gb_pack_{level}.png; use --level for a partial build")
    with tempfile.TemporaryDirectory(prefix="gb_art_") as temporary:
        work = (args.work_dir or Path(temporary)).resolve()
        for level in levels:
            build_level(level, toolroot, args.output_dir.resolve(), work)


if __name__ == "__main__":
    main()
