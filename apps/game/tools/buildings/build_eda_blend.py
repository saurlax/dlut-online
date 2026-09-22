"""Create editable Blender sources from the one-time Godot building extraction.

Run with Blender, not regular Python:
  blender --background --factory-startup --python \
    apps/game/tools/buildings/build_eda_blend.py -- \
    --input .local/eda-buildings \
    --output references/eda/buildings/blender \
    --runtime apps/game/assets/campuses/eda/models/buildings

Each .blend keeps one building in local coordinates. The same invocation also
exports GLB files used directly by Godot. Subsequent edits use --export-only so
the existing Blender files remain the source of truth. No GDScript generates or
rewrites building geometry.
"""

import argparse
import json
import struct
import sys
import tempfile
from pathlib import Path

import bpy


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--export-only", action="store_true")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def blender_compatible_glb(source):
    """Remove Godot's optional visibility extension unsupported by Blender 5.1."""
    data = source.read_bytes()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError(f"Unsupported GLB header: {source}")
    offset = 12
    chunks = []
    while offset < len(data):
        size, kind = struct.unpack_from("<II", data, offset)
        payload = data[offset + 8 : offset + 8 + size]
        chunks.append((kind, payload))
        offset += 8 + size
    document = json.loads(chunks[0][1].rstrip(b" \t\r\n\0"))
    extension = "KHR_node_visibility"
    for key in ("extensionsUsed", "extensionsRequired"):
        if key in document:
            document[key] = [name for name in document[key] if name != extension]
            if not document[key]:
                del document[key]
    for node in document.get("nodes", []):
        if extension in node.get("extensions", {}):
            del node["extensions"][extension]
            if not node["extensions"]:
                del node["extensions"]
    payload = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    payload += b" " * (-len(payload) % 4)
    chunks[0] = (chunks[0][0], payload)
    body = b"".join(struct.pack("<II", len(chunk), kind) + chunk for kind, chunk in chunks)
    target = Path(tempfile.gettempdir()) / f"dlut-{source.stem}-blender.glb"
    target.write_bytes(struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body)
    return target


def stamp_scene(record):
    scene = bpy.context.scene
    scene["dlut_campus"] = "eda"
    scene["dlut_feature_id"] = record["id"]
    scene["dlut_display_name"] = record["name"]
    scene["dlut_origin_x"] = record["origin"][0]
    scene["dlut_origin_y"] = record["origin"][1]
    scene["dlut_origin_z"] = record["origin"][2]
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    node_records = {item["name"]: item for item in record["nodes"]}
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        obj["dlut_feature_id"] = record["id"]
        obj["dlut_original_name"] = obj.name
        source = node_records.get(obj.name)
        if source:
            for key, value in source.get("metadata", {}).items():
                obj[key] = value
            obj["dlut_visible"] = source.get("visible", True)
    for obj in list(scene.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def export_glb(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_yup=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )


def main():
    args = arguments()
    args.output.mkdir(parents=True, exist_ok=True)
    args.runtime.mkdir(parents=True, exist_ok=True)
    if args.export_only:
        records = [{"id": path.stem, "name": path.stem} for path in sorted(args.output.glob("*.blend"))]
    else:
        if args.input is None:
            raise ValueError("--input is required for the one-time migration")
        records = json.loads((args.input / "buildings.json").read_text(encoding="utf-8"))["buildings"]
    for record in records:
        feature_id = record["id"]
        blend_path = args.output / f"{feature_id}.blend"
        reset_scene()
        if args.export_only:
            if not blend_path.exists():
                raise FileNotFoundError(blend_path)
            bpy.ops.wm.open_mainfile(filepath=str(blend_path))
        else:
            source = args.input / "source" / f"{feature_id}.glb"
            bpy.ops.import_scene.gltf(filepath=str(blender_compatible_glb(source)))
            stamp_scene(record)
            bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
        export_glb(args.runtime / f"{feature_id}.glb")
        print(f"BLENDER BUILDING PASS: {feature_id} {record['name']}")


if __name__ == "__main__":
    main()
