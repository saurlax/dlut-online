"""Build runtime LOD and collision assets from editable EDA Blender files.

The .blend files remain authoritative. This Blender-side tool keeps the source
meshes intact in Visual_LOD0 and regenerates three derived collections:
Visual_LOD1, Visual_PROXY and Collision. It then exports each collection to a
separate GLB so Godot can stream visual detail and load collision independently.
"""

import argparse
import sys
from pathlib import Path

import bpy
import bmesh


LOD0_COLLECTION = "Visual_LOD0"
LOD1_COLLECTION = "Visual_LOD1"
PROXY_COLLECTION = "Visual_PROXY"
COLLISION_COLLECTION = "Collision"
GENERATED_COLLECTIONS = (LOD1_COLLECTION, PROXY_COLLECTION, COLLISION_COLLECTION)


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", required=True, type=Path)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--feature")
    parser.add_argument("--no-save", action="store_true")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def remove_collection(name):
    collection = bpy.data.collections.get(name)
    if collection is None:
        return
    for obj in list(collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)


def ensure_lod0_collection():
    collection = bpy.data.collections.get(LOD0_COLLECTION)
    if collection is None:
        collection = bpy.data.collections.new(LOD0_COLLECTION)
        bpy.context.scene.collection.children.link(collection)
    generated_objects = {
        obj
        for name in GENERATED_COLLECTIONS
        for obj in (bpy.data.collections.get(name).objects if bpy.data.collections.get(name) else [])
    }
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or obj in generated_objects:
            continue
        if obj.name not in collection.objects:
            collection.objects.link(obj)
        for owner in list(obj.users_collection):
            if owner != collection:
                owner.objects.unlink(obj)
    return collection


def new_generated_collection(name):
    remove_collection(name)
    collection = bpy.data.collections.new(name)
    collection["dlut_generated"] = True
    bpy.context.scene.collection.children.link(collection)
    return collection


def visible(obj):
    return bool(obj.get("dlut_visible", True))


def collision_enabled(obj):
    return bool(obj.get("walk_collision", False))


def polygon_count(objects):
    return sum(len(obj.data.polygons) for obj in objects if obj.type == "MESH")


def duplicate_mesh(source, collection, suffix):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.animation_data_clear()
    obj.name = f"{source.name}{suffix}"
    collection.objects.link(obj)
    return obj


def apply_decimate(obj, ratio):
    if ratio >= 0.999 or len(obj.data.polygons) < 32:
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new(name="DLUT_LOD", type="DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = max(0.001, min(1.0, ratio))
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def make_convex_hull(obj):
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    result = bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    interior = list(result.get("geom_interior", [])) + list(result.get("geom_unused", []))
    if interior:
        bmesh.ops.delete(bm, geom=interior, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def make_lod(source_objects, collection, target_polygons, suffix):
    copies = [duplicate_mesh(obj, collection, suffix) for obj in source_objects if visible(obj)]
    total = polygon_count(copies)
    ratio = min(1.0, target_polygons / max(1, total))
    for obj in copies:
        obj["walk_collision"] = False
        obj["dlut_lod"] = suffix.lstrip("_").lower()
        apply_decimate(obj, ratio)
    return copies


def join_meshes(objects, name):
    if len(objects) < 2:
        return objects
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    return [joined]


def make_proxy(source_objects, collection):
    sources = [obj for obj in source_objects if visible(obj) and collision_enabled(obj)]
    if not sources:
        sources = [obj for obj in source_objects if visible(obj)]
    copies = [duplicate_mesh(obj, collection, "_PROXY") for obj in sources]
    for obj in copies:
        make_convex_hull(obj)
        obj["walk_collision"] = False
        obj["dlut_lod"] = "proxy"
    return join_meshes(copies, "BuildingProxy")


def make_collision(source_objects, collection, target_polygons):
    sources = [obj for obj in source_objects if collision_enabled(obj)]
    copies = [duplicate_mesh(obj, collection, "_collision") for obj in sources]
    total = polygon_count(copies)
    ratio = min(1.0, target_polygons / max(1, total))
    for obj in copies:
        apply_decimate(obj, ratio)
        obj["walk_collision"] = False
        obj["dlut_collision_proxy"] = True
        for slot in obj.material_slots:
            slot.material = None
    copies = join_meshes(copies, "BuildingCollision-colonly")
    if copies:
        apply_decimate(copies[0], target_polygons / max(1, polygon_count(copies)))
    return copies


def select_collection(collection):
    bpy.ops.object.select_all(action="DESELECT")
    for candidate in bpy.context.scene.collection.children:
        candidate.hide_viewport = False
        candidate.hide_render = False
    for obj in collection.all_objects:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
    if collection.all_objects:
        bpy.context.view_layer.objects.active = collection.all_objects[0]


def export_collection(collection, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    select_collection(collection)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )


def prepare_one(blend_path, runtime, save):
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    lod0 = ensure_lod0_collection()
    source_objects = [obj for obj in lod0.objects if obj.type == "MESH"]
    visible_polygons = polygon_count([obj for obj in source_objects if visible(obj)])
    collision_polygons = polygon_count([obj for obj in source_objects if collision_enabled(obj)])

    lod1 = new_generated_collection(LOD1_COLLECTION)
    proxy = new_generated_collection(PROXY_COLLECTION)
    collision = new_generated_collection(COLLISION_COLLECTION)

    lod1_target = min(900_000, max(30_000, int(visible_polygons * 0.50)))
    collision_target = min(30_000, max(5_000, int(collision_polygons * 0.03)))
    lod1_objects = make_lod(source_objects, lod1, lod1_target, "_LOD1")
    proxy_objects = make_proxy(source_objects, proxy)
    collision_objects = make_collision(source_objects, collision, collision_target)

    feature_id = blend_path.stem
    export_collection(lod0, runtime / f"{feature_id}.glb")
    export_collection(lod1, runtime / "lod1" / f"{feature_id}.glb")
    export_collection(proxy, runtime / "proxy" / f"{feature_id}.glb")
    export_collection(collision, runtime / "collision" / f"{feature_id}.glb")

    lod0.hide_viewport = False
    lod0.hide_render = False
    for collection in (lod1, proxy, collision):
        collection.hide_viewport = True
        collection.hide_render = True
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
    print(
        "STREAMING ASSET PASS: "
        f"{feature_id} lod0={visible_polygons} "
        f"lod1={polygon_count(lod1_objects)} proxy={polygon_count(proxy_objects)} "
        f"collision={polygon_count(collision_objects)}"
    )


def main():
    args = arguments()
    paths = sorted(args.sources.glob("*.blend"))
    if args.feature:
        paths = [args.sources / f"{args.feature}.blend"]
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(path)
        prepare_one(path, args.runtime, not args.no_save)


if __name__ == "__main__":
    main()
