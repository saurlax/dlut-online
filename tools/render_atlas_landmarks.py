"""Blender worker: near-front native pixel building sprites from registered models."""
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

jobs=json.loads(Path(sys.argv[sys.argv.index("--")+1]).read_text(encoding="utf-8"))
for job in jobs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=job["file"])
    points=[obj.matrix_world@Vector(corner) for obj in bpy.context.scene.objects if obj.type=="MESH" for corner in obj.bound_box]
    low=Vector([min(p[i] for p in points) for i in range(3)]);high=Vector([max(p[i] for p in points) for i in range(3)])
    center=(low+high)/2;radius=max(high-low)
    cam=bpy.data.objects.new("Atlas camera",bpy.data.cameras.new("Atlas camera"));bpy.context.scene.collection.objects.link(cam)
    elevation=math.radians(job.get("elevation",26))
    cam.location=center+Vector((0,-math.cos(elevation),math.sin(elevation)))*radius*2
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.clip_end=10000
    rotation=cam.rotation_euler.to_matrix().transposed()
    projected=[rotation@(p-center) for p in points]
    span=[max(p[i] for p in projected)-min(p[i] for p in projected) for i in range(2)]
    density=min(1.5,248/max(span))
    width=max(16,math.ceil((span[0]*density+4)/8)*8);height=max(16,math.ceil((span[1]*density+4)/8)*8)
    scene=bpy.context.scene;scene.camera=cam;scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='FLAT';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=False
    scene.view_settings.view_transform='Standard'
    scene.display.render_aa='OFF';scene.render.film_transparent=True
    scene.render.resolution_x=width;scene.render.resolution_y=height;scene.render.resolution_percentage=100
    cam.data.ortho_scale=1
    # Ortho scale follows sensor fit; sample the frame after setting the render aspect.
    frame=cam.data.view_frame(scene=scene)
    frame_span=[max(p[i] for p in frame)-min(p[i] for p in frame) for i in range(2)]
    cam.data.ortho_scale=max((span[i]+4/density)/frame_span[i] for i in range(2))
    projected_center=Vector([(max(p[i] for p in projected)+min(p[i] for p in projected))/2 for i in range(2)]+[0])
    cam.location+=cam.rotation_euler.to_matrix()@projected_center
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    path=Path(job['output']);path.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    print("ATLAS ICON "+job['id'],flush=True)
