"""Build CC0 MakeHuman samples in Blender; no MPFB program code is embedded.

blender --background --factory-startup --python build_samples.py -- --inputs PATH
The input directory is populated by fetch_sources.py. Output is an offline GLB;
pack_samples.gd converts it to the runtime TSCN and binary mesh resources.
"""
import argparse
import gzip
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[4]
MORPHS = {
    "face_width": "head/head-scale-horiz",
    "chin_width": "chin/chin-width",
    "nose_width": "nose/nose-scale-horiz",
    "mouth_width": "mouth/mouth-scale-horiz",
}


def read_obj(path):
    vertices, uv, faces, groups = [], [], [], {}
    group = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "v":
            vertices.append(Vector(tuple(map(float, fields[1:4]))))
        elif fields[0] == "vt":
            uv.append(tuple(map(float, fields[1:3])))
        elif fields[0] == "g":
            group = fields[1]
        elif fields[0] == "f":
            corners = [tuple(int(n) - 1 if n else -1 for n in f.split("/")) for f in fields[1:]]
            faces.append((group, corners))
            groups.setdefault(group, set()).update(c[0] for c in corners)
    return vertices, uv, faces, groups


def target(path, count):
    result = [Vector() for _ in range(count)]
    with gzip.open(path, "rt") as file:
        for line in file:
            fields = line.split()
            if fields and not fields[0].startswith("#"):
                result[int(fields[0])] = Vector(tuple(map(float, fields[1:4])))
    return result


def read_clothing(path, body):
    info, mapping, deleted = {}, [], set()
    section = "header"
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if not fields or fields[0].startswith("#"):
            continue
        if fields[0] == "verts":
            section = "verts"
        elif fields[0] == "delete_verts":
            section = "delete"
        elif section == "header" or not fields[0].lstrip("-").isdigit():
            info[fields[0]] = fields[1:]
        elif section == "verts":
            if len(fields) == 1:
                mapping.append(([int(fields[0])], [1.0], Vector()))
            elif len(fields) == 9:
                mapping.append((list(map(int, fields[:3])), list(map(float, fields[3:6])), Vector(tuple(map(float, fields[6:9])))))
            else:
                raise ValueError(f"Unsupported mapping in {path}: {line}")
        else:
            index = 0
            while index < len(fields):
                if index + 2 < len(fields) and fields[index + 1] == "-":
                    deleted.update(range(int(fields[index]), int(fields[index + 2]) + 1))
                    index += 3
                else:
                    deleted.add(int(fields[index]))
                    index += 1
    scale = Vector((1, 1, 1))
    for axis, key in enumerate(["x_scale", "y_scale", "z_scale"]):
        if key in info:
            a, b, distance = info[key]
            scale[axis] = abs(body[int(a)][axis] - body[int(b)][axis]) / float(distance)
    vertices = [sum((body[i] * w for i, w in zip(ids, weights)), Vector()) + Vector(tuple(offset[a] * scale[a] for a in range(3))) for ids, weights, offset in mapping]
    return info, mapping, deleted, vertices


def make_material(path, texture_dir, label):
    existing = bpy.data.materials.get(label)
    if existing:
        return existing
    fields = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        tokens = line.split()
        if tokens and not tokens[0].startswith("#"):
            fields[tokens[0]] = tokens[1:]
    material = bpy.data.materials.new(label)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = 0.78
    if "diffuseTexture" in fields:
        texture_path = (path.parent / " ".join(fields["diffuseTexture"])).resolve()
        if not texture_path.exists():
            raise FileNotFoundError(texture_path)
        image = bpy.data.images.load(str(texture_path), check_existing=True)
        if max(image.size) > 2048:
            ratio = 2048 / max(image.size)
            image.scale(round(image.size[0] * ratio), round(image.size[1] * ratio))
        image.filepath_raw = str(texture_dir / (label + ".png"))
        image.file_format = "PNG"
        image.save()
        node = material.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        material.node_tree.links.new(node.outputs["Color"], shader.inputs["Base Color"])
        if label.startswith(("Hair", "Brows", "Lashes", "Eyes")):
            material.node_tree.links.new(node.outputs["Alpha"], shader.inputs["Alpha"])
            material.surface_render_method = "DITHERED"
    return material


def create_mesh(name, vertices, uv, faces, material, rig, weights, shapes, convert):
    used = sorted({c[0] for _, face in faces for c in face})
    remap = {original: index for index, original in enumerate(used)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([convert(vertices[i]) for i in used], [], [[remap[c[0]] for c in face] for _, face in faces])
    mesh.update()
    mesh.materials.append(material)
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon, (_, face) in zip(mesh.polygons, faces):
        polygon.use_smooth = True
        for loop_index, corner in zip(polygon.loop_indices, face):
            if len(corner) > 1 and corner[1] >= 0:
                layer.data[loop_index].uv = uv[corner[1]]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    modifier = obj.modifiers.new("Skin", "ARMATURE")
    modifier.object = rig
    groups = {bone.name: obj.vertex_groups.new(name=bone.name) for bone in rig.data.bones}
    for original in used:
        influence = sorted(((n, max(0, w)) for n, w in weights[original].items() if w > 0), key=lambda pair: pair[1], reverse=True)[:4]
        total = sum(w for _, w in influence)
        if total <= 0:
            raise ValueError(f"Unweighted vertex {name}:{original}")
        for bone, weight in influence:
            groups[bone].add([remap[original]], weight / total, "REPLACE")
    if shapes:
        obj.shape_key_add(name="Basis")
        for key, delta in shapes.items():
            shape = obj.shape_key_add(name=key)
            for index, original in enumerate(used):
                shape.data[index].co = convert(vertices[original] + delta[original])
    return obj


def build_rig(definition, body, groups, convert):
    armature = bpy.data.armatures.new("Humanoid")
    obj = bpy.data.objects.new("Humanoid", armature)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, item in definition.items():
        bone = armature.edit_bones.new(name)
        for end in ["head", "tail"]:
            point = item[end]
            indices = groups[point["cube_name"]] if point["strategy"] == "CUBE" else point["vertex_indices"]
            setattr(bone, end, convert(sum((body[i] for i in indices), Vector()) / len(indices)))
        bone.roll = item["roll"]
    for name, item in definition.items():
        if item["parent"]:
            armature.edit_bones[name].parent = armature.edit_bones[item["parent"]]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def add_test_animations(rig):
    """Deliberately small authored binding-test cycles, not captured locomotion."""
    scene = bpy.context.scene
    scene.render.fps = 30
    rig.animation_data_create()
    for clip, frames, amplitude in [("idle", 60, 0), ("walk", 30, 0.35), ("run", 22, 0.62)]:
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        for frame in range(1, frames + 2):
            phase = 2 * math.pi * (frame - 1) / frames
            for pose in rig.pose.bones:
                pose.rotation_mode = "QUATERNION"
                pose.rotation_quaternion = Quaternion()
                pose.location = Vector()
            for side, sign in [("l", 1), ("r", -1)]:
                for part, angle in [("thigh", math.sin(phase) * amplitude * sign), ("calf", max(0, -math.sin(phase) * sign) * amplitude * 1.4), ("upperarm", -math.sin(phase) * amplitude * sign * 0.6)]:
                    pose = rig.pose.bones[f"{part}_{side}"]
                    basis = pose.bone.matrix_local.to_quaternion()
                    world = Quaternion((1, 0, 0), angle)
                    if part == "upperarm":
                        direction = pose.bone.tail_local - pose.bone.head_local
                        relaxed = direction.rotation_difference(Vector((sign * 0.14, 0, -1)))
                        world = world @ relaxed
                    pose.rotation_quaternion = basis.inverted() @ world @ basis
            rig.pose.bones["pelvis"].location.y = (1 - math.cos(phase * 2)) * amplitude * 0.018
            for pose in rig.pose.bones:
                pose.keyframe_insert("rotation_quaternion", frame=frame, group=pose.name)
                if pose.name == "pelvis":
                    pose.keyframe_insert("location", frame=frame, group=pose.name)
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 1, action)
        rig.animation_data.action = None
    for pose in rig.pose.bones:
        pose.rotation_quaternion = Quaternion()
        pose.location = Vector()


def build(inputs, output, sex):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    data = inputs / "base-data/src/mpfb/data"
    assets = inputs / "system-assets"
    base, uv, faces, groups = read_obj(data / "3dobjs/base.obj")
    body = [p.copy() for p in base]
    for filename in [f"asian-{sex}-young", f"universal-{sex}-young-averagemuscle-averageweight"]:
        delta = target(data / f"targets/macrodetails/{filename}.target.gz", len(base))
        body = [p + d for p, d in zip(body, delta)]
    body_indices = groups["body"]
    floor = min(body[i].y for i in body_indices)
    height = max(body[i].y for i in body_indices) - floor
    scale = (1.75 if sex == "male" else 1.65) / height

    def convert(p):
        return (p.x * scale, -p.z * scale, (p.y - floor) * scale)

    raw_weights = json.loads((data / "rigs/standard/weights.game_engine.json").read_text())["weights"]
    weights = [{} for _ in body]
    for bone, influences in raw_weights.items():
        for index, weight in influences:
            weights[index][bone] = weight
    definition = json.loads((data / "rigs/standard/rig.game_engine.json").read_text())
    rig = build_rig(definition, body, groups, convert)
    shapes = {f"{name}_{direction}": [p * 0.5 for p in target(data / f"targets/{path}-{direction}.target.gz", len(body))] for name, path in MORPHS.items() for direction in ["decr", "incr"]}
    texture_dir = ROOT / "apps/game/assets/characters/textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    skin = make_material(assets / f"skins/young_asian_{sex}/young_asian_{sex}.mhmat", texture_dir, f"Skin_{sex}")

    def clothing(asset_path, name, material_override=None):
        path = assets / asset_path
        info, mapping, deleted, vertices = read_clothing(path, body)
        _, cloth_uv, cloth_faces, _ = read_obj(path.parent / info["obj_file"][0])
        if len(vertices) != max(c[0] for _, f in cloth_faces for c in f) + 1:
            raise ValueError(f"Clothing vertex count mismatch: {path}")
        cloth_weights, cloth_shapes = [], {key: [] for key in shapes}
        for ids, factors, _ in mapping:
            combined = {}
            for i, factor in zip(ids, factors):
                for bone, weight in weights[i].items():
                    combined[bone] = combined.get(bone, 0) + weight * factor
            cloth_weights.append(combined)
            for key, deltas in shapes.items():
                cloth_shapes[key].append(sum((deltas[i] * factor for i, factor in zip(ids, factors)), Vector()))
        material_path = assets / material_override if material_override else path.parent / info["material"][0]
        label = name if name in ["Shoes", "Eyes", "Brows", "Lashes"] else name + "_" + sex
        material = make_material(material_path, texture_dir, label)
        # Only facial accessories need facial shape keys; clothes keep a fixed body.
        create_mesh(name, vertices, cloth_uv, cloth_faces, material, rig, cloth_weights, cloth_shapes if name in ["Hair", "Eyes", "Brows", "Lashes"] else {}, convert)
        return deleted

    shoe_mask = clothing("clothes/shoes05/shoes05.mhclo", "Shoes")
    for index in range(2):
        asset = f"{sex}_casualsuit0{index + 1}"
        deleted = clothing(f"clothes/{asset}/{asset}.mhclo", f"Outfit{index}") | shoe_mask
        body_faces = [(g, f) for g, f in faces if g == "body" and not any(c[0] in deleted for c in f)]
        create_mesh(f"Body{index}", body, uv, body_faces, skin, rig, weights, shapes, convert)
    hair = "short02" if sex == "male" else "ponytail01"
    clothing(f"hair/{hair}/{hair}.mhclo", "Hair")
    clothing("eyes/high-poly/high-poly.mhclo", "Eyes", "eyes/materials/brown.mhmat")
    clothing("eyebrows/eyebrow001/eyebrow001.mhclo", "Brows")
    clothing("eyelashes/eyelashes01/eyelashes01.mhclo", "Lashes")
    add_test_animations(rig)
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(output / f"student_{sex}.glb"), export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS", export_optimize_animation_size=False, export_morph=True, export_skins=True, export_yup=True, export_apply=False)
    print(f"Built student_{sex}: {len(rig.data.bones)} bones, {len(shapes)} face targets")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / ".local/characters/generated")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from fetch_sources import MANIFEST, verify
    verify(args.inputs.resolve(), json.loads(MANIFEST.read_text(encoding="utf-8")))
    args.output.mkdir(parents=True, exist_ok=True)
    for gender in ["male", "female"]:
        build(args.inputs.resolve(), args.output.resolve(), gender)
