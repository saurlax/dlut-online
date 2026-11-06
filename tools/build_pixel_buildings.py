"""Rebuild campus buildings as low-poly shells with native pixel UV atlases.

python tools/build_pixel_buildings.py origin/3d
Requires Blender and tools/requirements.txt. Only reads archived local objects.
"""

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import shutil
import struct
import subprocess

from PIL import Image, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "apps/game/assets/campuses/eda/"
TEMP = ROOT / ".local/hd2d/building-bake"
BASE_OBJECTS = {
    "77914": ["Building", "InformationEntry"],
    "77917": ["Rotunda", "LibraryHighWing", "Library_connector_render_Solid"],
    "77921": ["EDA_comprehensive_grey_masonry_Solid", "ComprehensiveAnnexLower", "ComprehensiveAnnexUpper", "ComprehensiveAnnexRoof"],
    "77923": ["EDA_gym_stone_Solid", "EDA_gym_pale_wall_Solid", "EDA_gym_metal_roof_Solid"],
    "77925": ["EDA_academic_77796f_Solid", "EDA_A_atrium_floor_Solid", "EDA_A_atrium_wall_Solid", "EDA_A_atrium_glass_Solid"],
    "77927": ["EDA_academic_74776e_registered_curve_Solid"],
    "77928": ["EDA_academic_656c66_Solid", "EDA_B_courtyard_brick_Solid", "EDA_B_courtyard_pale_Solid"],
    "77931": ["EDA_residence_pale_tile_Solid"],
    "77933": ["EDA_residence_pale_tile_Solid"],
    "77935": ["EDA_residence_pale_tile_Solid"],
    "77937": ["EDA_residence_pale_tile_Solid"],
    "77938": ["EDA_residence_pale_tile_Solid"],
    "77941": ["Building", "Roof"],
    "77943": ["EDA_dining_buff_masonry_Solid"],
    "2304982": ["Seventh_white_cladding_Solid", "LowPodiumParapet"],
}


def archived(ref, path):
    return subprocess.check_output(["git", "show", f"{ref}:{path}"], cwd=ROOT)


def source_model(ref, ident, tier, target):
    path = PREFIX + f"models/buildings/{tier}/{ident}.glb"
    pointer = archived(ref, path).decode()
    digest = pointer.split("oid sha256:")[1].split()[0]
    cache = ROOT / ".git/lfs/objects" / digest[:2] / digest[2:4] / digest
    data = cache.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f"Invalid cached model: {ident}/{tier}")
    target.write_bytes(data)
    return {"path": path, "sha256": digest}


def pixel_atlas(image):
    """Preserve baked facade features and add restrained native material grain."""
    image = image.convert("RGB")
    material = Image.open(ROOT / "apps/web/public/campuses/eda/materials/wall-0.png").convert("L")
    grain = ImageOps.autocontrast(material).resize((32, 32), Image.Resampling.NEAREST)
    repeat = Image.new("L", image.size)
    for y in range(0, image.height, 32):
        for x in range(0, image.width, 32):
            repeat.paste(grain, (x, y))
    # Grain has at most +/-3 brightness levels. Geometry and window edges come
    # entirely from the archived, documented model, not from invented facades.
    bias = repeat.point(lambda value: round(125 + value * 6 / 255))
    texture = ImageChops.add(image, Image.merge("RGB", (bias, bias, bias)), offset=-128)
    return texture.quantize(colors=48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def finish_model(path, destination, texture_path):
    data = path.read_bytes()
    json_length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + json_length])
    binary = data[20 + json_length + 8:]
    image = document["images"][0]
    image_view = image.pop("bufferView")
    view = document["bufferViews"][image_view]
    offset = view.get("byteOffset", 0)
    atlas = pixel_atlas(Image.open(BytesIO(binary[offset:offset + view["byteLength"]])))
    texture_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(texture_path, optimize=True)
    image["uri"] = f"textures/{texture_path.name}"
    image.pop("mimeType", None)
    # Keep geometry in GLB and the editable pixel atlas in a separate PNG.
    packed = bytearray()
    views = []
    remap = {}
    for index, view in enumerate(document["bufferViews"]):
        if index == image_view:
            continue
        packed.extend(b"\0" * (-len(packed) % 4))
        start = view.get("byteOffset", 0)
        new_view = {**view, "byteOffset": len(packed)}
        packed.extend(binary[start:start + view["byteLength"]])
        remap[index] = len(views)
        views.append(new_view)
    for accessor in document["accessors"]:
        if "bufferView" in accessor:
            accessor["bufferView"] = remap[accessor["bufferView"]]
    document["bufferViews"] = views
    document["buffers"][0]["byteLength"] = len(packed)
    for sampler in document.get("samplers", []):
        sampler.update(magFilter=9728, minFilter=9728, wrapS=33071, wrapT=33071)
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    packed.extend(b"\0" * (-len(packed) % 4))
    result = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(encoded) + 8 + len(packed))
    result += struct.pack("<I4s", len(encoded), b"JSON") + encoded
    result += struct.pack("<I4s", len(packed), b"BIN\0") + packed
    destination.write_bytes(result)
    triangles = sum(document["accessors"][primitive["indices"]]["count"] // 3
                    for mesh in document["meshes"] for primitive in mesh["primitives"])
    return {"triangles": triangles, "bytes": len(result), "texture": f"models/textures/{texture_path.name}",
            "textureSize": list(atlas.size), "textureBytes": texture_path.stat().st_size,
            "paletteColors": len(atlas.getcolors())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_ref")
    parser.add_argument("--only", nargs="+")
    parser.add_argument("--output", type=Path, default=ROOT / "apps/web/public/campuses/eda/models")
    parser.add_argument("--blender", default=shutil.which("blender") or "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe")
    args = parser.parse_args()
    commit = subprocess.check_output(["git", "rev-parse", args.source_ref], cwd=ROOT).decode().strip()
    assets = json.loads(archived(commit, PREFIX + "data/building_assets.json"))
    geometry = {b["id"]: b for b in json.loads((ROOT / "references/eda/geometry.json").read_text(encoding="utf-8"))["buildings"]}
    library = json.loads(archived(commit, "references/eda/buildings/library_information_profiles.json"))["77917"]
    academic_c = json.loads(archived(commit, "references/eda/buildings/academic_facades.json"))["77927"]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    TEMP.mkdir(parents=True, exist_ok=True)
    jobs = []
    for building in assets["buildings"]:
        ident = building["id"]
        if ident == "96575" or (args.only and ident not in args.only):
            continue
        directory = TEMP / ident
        directory.mkdir(exist_ok=True)
        details = source_model(commit, ident, "lod1", directory / "details.glb")
        data = (directory / "details.glb").read_bytes()
        length = struct.unpack_from("<I", data, 12)[0]
        document = json.loads(data[20:20 + length])
        colors = {material["name"]: material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1]) for material in document["materials"]}
        jobs.append({"id": ident, "directory": str(directory), "origin": building["origin"],
                     "baseSource": {**details, "objects": BASE_OBJECTS[ident]}, "detailSource": details, "colors": colors,
                     "geometry": geometry[ident], "profile": library if ident == "77917" else academic_c if ident == "77927" else None})
    job_file = TEMP / "jobs.json"
    job_file.write_text(json.dumps(jobs), encoding="utf-8")
    subprocess.run([args.blender, "-b", "--python-exit-code", "1", "--python", str(ROOT / "tools/bake_hd2d_buildings.py"),
                    "--", str(job_file)], cwd=ROOT, check=True)
    manifest = {"sourceCommit": commit, "coordinateFrame": "meters; x east, y up, z south",
                "ground": "Existing flat grid; archived terrain elevation is not applied.",
                "geometrySource": {"path": "references/eda/geometry.json", "sha256": hashlib.sha256((ROOT / "references/eda/geometry.json").read_bytes()).hexdigest()},
                "method": "Rebuilt structural shells; unlit facade-color bake at native pixel resolution; 48-color UV atlases.",
                "buildings": []}
    for job in jobs:
        ident = job["id"]
        stats = finish_model(Path(job["directory"]) / "baked.glb", output / f"{ident}.glb", output / "textures" / f"{ident}.png")
        record = {"id": ident, "file": f"models/{ident}.glb", "origin": job["origin"],
                  "baseSource": job["baseSource"], "detailSource": job["detailSource"], **stats}
        if ident in {"77917", "77927"}:
            record["profileSource"] = "references/eda/buildings/" + ("library_information_profiles.json" if ident == "77917" else "academic_facades.json")
        manifest["buildings"].append(record)
        print(f"PIXEL BUILDING {ident}: {stats['triangles']} triangles, {stats['bytes']} + {stats['textureBytes']} bytes", flush=True)
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
