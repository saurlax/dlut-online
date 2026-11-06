"""Blender worker for build_pixel_buildings.py; bake registered facade colors."""

import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector


def loft(job, name, rings):
    origin = job["origin"]
    count = len(rings[0][1])
    vertices = [(x - origin[0], -(z - origin[2]), height) for height, ring in rings for x, z in ring]
    faces = [tuple(reversed(range(count))), tuple(range((len(rings) - 1) * count, len(rings) * count))]
    for row in range(len(rings) - 1):
        for i in range(count):
            a = row * count + i
            b = row * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def prism(job, name, ring, height):
    return loft(job, name, [(0, ring), (height, ring)])


def curved_shells(job):
    profile = job["profile"]
    registration = profile["osm_registration"]
    ellipse = registration["curve_refinement"]["ellipse"]
    cx, cz = ellipse["center_xz"]
    rx, rz = ellipse["radii_m"]
    angle = ellipse["rotation_rad"]
    cosine, sine = math.cos(angle), math.sin(angle)
    points = job["geometry"]["points"]
    ring = []
    angles = []
    for index in range(64):
        t = index * 2 * math.pi / 64
        ring.append((cx + rx * math.cos(t) * cosine - rz * math.sin(t) * sine,
                     cz + rx * math.cos(t) * sine + rz * math.sin(t) * cosine))
        angles.append(t)
    if job["id"] == "77927":
        wing = [points[i] for i in [0, 1, 2, 3, 4, 22, 23, 24]]
        return [prism(job, "C round body", ring, profile["height"]), prism(job, "C straight wing", wing, profile["height"])]
    envelope = registration["rotunda_envelope"]
    controls = []
    for i in ellipse["source_vertices"]:
        dx, dz = points[i][0] - cx, points[i][1] - cz
        t = math.atan2((-dx * sine + dz * cosine) / rz, (dx * cosine + dz * sine) / rx) % (2 * math.pi)
        controls.append((t, envelope["vertex_weights"].get(str(i), 0)))
    controls.sort()
    controls = [(controls[-1][0] - 2 * math.pi, controls[-1][1])] + controls + [(controls[0][0] + 2 * math.pi, controls[0][1])]
    upper = []
    for t, (x, z) in zip(angles, ring):
        a, b = next((a, b) for a, b in zip(controls, controls[1:]) if a[0] <= t <= b[0])
        weight = a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0])
        normal = Vector((math.cos(t) / rx * cosine - math.sin(t) / rz * sine,
                         math.cos(t) / rx * sine + math.sin(t) / rz * cosine)).normalized()
        upper.append((x + normal.x * envelope["top_outset"] * weight, z + normal.y * envelope["top_outset"] * weight))
    rotunda = loft(job, "Library round hall", [(0, ring), (envelope["start_y"], ring), (envelope["top_y"], upper)])
    connector = registration["lower_connector"]
    def between(a, b, t):
        return (points[a][0] + (points[b][0] - points[a][0]) * t, points[a][1] + (points[b][1] - points[a][1]) * t)
    east = between(1, 2, connector["east_split"])
    west = between(38, 0, connector["west_split"])
    return [rotunda,
            prism(job, "Library upper wing", [east, points[2], points[37], points[38], west], profile["wing_height"]),
            prism(job, "Library lower connector", [points[0], points[1], east, west], connector["height"]),
            prism(job, "Library tower", [points[i] for i in registration["tower"]["vertices"]], registration["tower"]["height"])]


def opaque_colors(colors):
    for material in bpy.data.materials:
        material.use_nodes = True
        nodes = material.node_tree.nodes
        nodes.clear()
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        output = nodes.new("ShaderNodeOutputMaterial")
        material.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
        bsdf.inputs["Base Color"].default_value = (*colors[material.name][:3], 1)
        bsdf.inputs["Alpha"].default_value = 1
        bsdf.inputs["Metallic"].default_value = 0


def main():
    jobs = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
    for job in jobs:
        directory = Path(job["directory"])
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(directory / "details.glb"))
        detailed = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        opaque_colors(job["colors"])
        bodies = {obj["dlut_original_name"]: obj for obj in detailed}
        shells = []
        if job["id"] in {"77917", "77927"}:
            shells = curved_shells(job)
        else:
            for name in job["baseSource"]["objects"]:
                source = bodies[name]
                shell = source.copy()
                shell.data = source.data.copy()
                shell.parent = None
                shell.matrix_world = source.matrix_world.copy()
                bpy.context.scene.collection.objects.link(shell)
                shells.append(shell)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in shells:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = shells[0]
        bpy.ops.object.join()
        shell = bpy.context.object
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        mesh = bmesh.new()
        mesh.from_mesh(shell.data)
        bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.001)
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
        mesh.to_mesh(shell.data)
        mesh.free()
        # Welded structural faces can be simplified without filling concavities
        # or replacing the actual roof profile with a convex hull.
        dissolve = shell.modifiers.new("Structural planes", "DECIMATE")
        dissolve.decimate_type = "DISSOLVE"
        dissolve.angle_limit = math.radians(1.5)
        dissolve.delimit = set()
        bpy.ops.object.modifier_apply(modifier=dissolve.name)
        triangles = sum(len(face.vertices) - 2 for face in shell.data.polygons)
        if triangles > 3000:
            reduce = shell.modifiers.new("Curved shell budget", "DECIMATE")
            reduce.ratio = min(1, 3000 / triangles)
            reduce.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=reduce.name)
        area = sum(face.area for face in shell.data.polygons)
        resolution = min(2048, max(256, math.ceil(math.sqrt(area / 0.65) * 8 / 64) * 64))
        image = bpy.data.images.new(f"Pixel facade {job['id']}", width=resolution, height=resolution, alpha=False)
        image.generated_color = (0.52, 0.49, 0.43, 1)
        material = bpy.data.materials.new(f"Pixel exterior {job['id']}")
        material.use_nodes = True
        material.diffuse_color = (1, 1, 1, 1)
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
        bsdf.inputs["Roughness"].default_value = 1
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.interpolation = "Closest"
        material.node_tree.nodes.active = texture
        shell.data.materials.clear()
        shell.data.materials.append(material)
        for face in shell.data.polygons:
            face.material_index = 0
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.008)
        bpy.ops.object.mode_set(mode="OBJECT")
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 1
        scene.render.bake.use_selected_to_active = True
        scene.render.bake.cage_extrusion = 0.6
        scene.render.bake.max_ray_distance = 1.8
        scene.render.bake.margin = 3
        scene.render.bake.use_clear = False
        bpy.ops.object.select_all(action="DESELECT")
        for obj in detailed:
            obj.select_set(True)
        shell.select_set(True)
        bpy.context.view_layer.objects.active = shell
        print(f"BAKING {job['id']}: {resolution}x{resolution}, {len(shell.data.polygons)} base faces", flush=True)
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
        material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
        bpy.ops.object.select_all(action="DESELECT")
        shell.select_set(True)
        bpy.context.view_layer.objects.active = shell
        shell.name = f"PixelBuilding_{job['id']}"
        bpy.ops.export_scene.gltf(filepath=str(directory / "baked.glb"), export_format="GLB",
                                  use_selection=True, export_yup=True, export_extras=False,
                                  export_animations=False, export_cameras=False, export_lights=False)
        print(f"BAKED {job['id']}", flush=True)


main()
