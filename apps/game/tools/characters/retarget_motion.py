"""Bake CC0 Quaternius locomotion onto the project's MakeHuman skeleton."""
import bpy
from mathutils import Quaternion


def add_library_animations(target, source_path):
    clips = {"idle": "Idle_A", "walk": "Walk", "run": "Jog"}
    with bpy.data.libraries.load(str(source_path), link=False) as (available, loaded):
        loaded.objects = ["Armature"]
        loaded.actions = list(clips.values())
    source = loaded.objects[0]
    bpy.context.collection.objects.link(source)
    source.animation_data_clear()
    source.animation_data_create()
    target.animation_data_create()
    actions = dict(zip(clips.values(), loaded.actions))
    names = {b.name: b.name for b in target.data.bones if b.name in source.data.bones}
    for target_name, source_name in {"Root": "root", "neck": "neck_01"}.items():
        if target_name in target.data.bones:
            names[target_name] = source_name
    corrections = {}
    for name, other in names.items():
        tb, sb = target.data.bones[name], source.data.bones[other]
        rest = tb.matrix_local.to_quaternion()
        alignment = Quaternion() if name in ["Root", "pelvis", "spine_01", "spine_02", "spine_03", "neck", "neck_01", "head"] else (tb.tail_local - tb.head_local).rotation_difference(sb.tail_local - sb.head_local)
        corrections[name] = alignment @ rest
    scene = bpy.context.scene
    scene.render.fps = 24
    ratio = target.data.bones["pelvis"].head_local.z / source.data.bones["pelvis"].head_local.z
    for output_name, input_name in clips.items():
        source.animation_data.action = actions[input_name]
        if actions[input_name].slots:
            source.animation_data.action_slot = actions[input_name].slots[0]
        source.animation_data.use_nla = False
        target.animation_data.use_nla = False
        result = bpy.data.actions.new(output_name)
        target.animation_data.action = result
        start, end = map(int, actions[input_name].frame_range)
        for frame in range(start, end + 1):
            scene.frame_set(frame)
            desired = {}
            for pose in target.pose.bones:
                pose.rotation_mode = "QUATERNION"
                pose.location = (0, 0, 0)
                local_rest = pose.bone.matrix_local.to_quaternion()
                if pose.parent:
                    local_rest = pose.parent.bone.matrix_local.to_quaternion().inverted() @ local_rest
                parent = desired[pose.parent.name] if pose.parent else Quaternion()
                if pose.name in names:
                    sp = source.pose.bones[names[pose.name]]
                    rotation = sp.matrix.to_quaternion() @ sp.bone.matrix_local.to_quaternion().inverted() @ corrections[pose.name]
                    # The source has a stylized forward head/torso baseline.
                    pitch = -0.45 if pose.name in ["head", "neck", "neck_01"] else (-0.15 if pose.name in ["spine_02", "spine_03"] else 0.0)
                    rotation = Quaternion((1, 0, 0), pitch) @ rotation
                    pose.rotation_quaternion = local_rest.inverted() @ parent.inverted() @ rotation
                else:
                    pose.rotation_quaternion = Quaternion()
                    rotation = parent @ local_rest
                desired[pose.name] = rotation
                if pose.name == "pelvis":
                    offset = source.pose.bones["pelvis"].head - source.data.bones["pelvis"].head_local
                    pose.location = pose.bone.matrix_local.to_3x3().inverted() @ (offset * ratio)
                    pose.keyframe_insert("location", frame=frame + 1)
                pose.keyframe_insert("rotation_quaternion", frame=frame + 1)
        track = target.animation_data.nla_tracks.new()
        track.name = output_name
        track.strips.new(output_name, 1, result)
        target.animation_data.action = None
    target.animation_data.use_nla = True
    bpy.data.objects.remove(source, do_unlink=True)
