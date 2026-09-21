extends SceneTree
## Local asset/skin regression check; no campus, account or server is loaded.

const Avatar = preload("res://scripts/client/character_avatar.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var first := Avatar.new()
	var second := Avatar.new()
	root.add_child(first)
	root.add_child(second)
	first.set_face_parameter(&"face_width", 1.0)
	for mesh in second.meshes:
		var shape := mesh.find_blend_shape_by_name(&"face_width_incr")
		if shape >= 0:
			assert(mesh.get_blend_shape_value(shape) == 0.0, "Avatar values must be per instance")
	for sample in range(2):
		first.set_sample(sample)
		assert(first.face_values[&"face_width"] == 1.0)
		var skeleton := first.model.find_child("Skeleton3D", true, false) as Skeleton3D
		assert(skeleton != null and skeleton.get_bone_count() == 53)
		for parameter in first.FACE_PARAMETERS:
			for value in [-1.0, 1.0]:
				first.set_face_parameter(parameter, value)
				for mesh in first.meshes:
					if mesh.name not in [&"Body0", &"Body1"]:
						continue
					for direction in ["decr", "incr"]:
						var index := mesh.find_blend_shape_by_name(String(parameter) + "_" + direction)
						assert(index >= 0, "Every face control must have both shapes on both outfit bodies")
						var expected := maxf(-value if direction == "decr" else value, 0.0)
						assert(is_equal_approx(mesh.get_blend_shape_value(index), expected))
			first.set_face_parameter(parameter, 0.0)
		first.set_face_parameter(&"face_width", 1.0)
		for outfit in range(2):
			first.set_outfit(outfit)
			var visible_count := 0
			for mesh in first.meshes:
				assert(not mesh.skeleton.is_empty() and mesh.skeleton != NodePath(".."), "Persist an explicit skeleton path independently of project compatibility defaults")
				if mesh.visible:
					visible_count += 1
				assert(mesh.get_node(mesh.skeleton) == skeleton, "All garments must share the skeleton")
				assert(mesh.skin.get_bind_count() == 53)
			assert(visible_count == 7, "One masked body and outfit plus five accessories")
			for motion in [&"idle", &"walk", &"run"]:
				first.set_motion(motion)
				first.animation_player.advance(0.21)
				assert(first.animation_player.current_animation == motion)
				var clip := first.animation_player.get_animation(motion)
				assert(clip.loop_mode == Animation.LOOP_LINEAR)
				for fraction in [0.0, 0.25, 0.5, 0.75]:
					first.animation_player.seek(clip.length * fraction, true)
					skeleton.force_update_all_bone_transforms()
					for mesh in first.meshes:
						if mesh.visible:
							_check_skin(mesh, skeleton)
		first.set_motion(&"idle")
		first.animation_player.advance(0.21)
		first.animation_player.seek(0.5, true)
		skeleton.force_update_all_bone_transforms()
		var calf := skeleton.find_bone("calf_l")
		var idle := first.animation_player.get_animation(&"idle")
		var idle_track := idle.find_track(NodePath("Humanoid/Skeleton3D:calf_l"), Animation.TYPE_ROTATION_3D)
		assert(idle_track >= 0)
		assert(skeleton.get_bone_pose_rotation(calf).angle_to(idle.rotation_track_interpolate(idle_track, 0.5)) < 0.002, "Returning to idle must apply its authored knee pose")
		for side in ["l", "r"]:
			var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_" + side)).origin
			var elbow := skeleton.get_bone_global_pose(skeleton.find_bone("lowerarm_" + side)).origin
			assert((elbow - shoulder).normalized().y < -0.7, "Idle must retain the authored relaxed arms")
	first.set_skin(0.8, 0.5)
	assert(first.skin_materials.size() == 2)
	for material in first.skin_materials:
		assert(is_equal_approx(material.get_shader_parameter("skin_depth"), 0.8))
	for material in second.skin_materials:
		assert(is_equal_approx(material.get_shader_parameter("skin_depth"), 0.0), "Skin materials must be per instance")
	first.set_sample(0)
	assert(first.skin_depth == 0.8)
	first.set_face_parameter(&"nose_width", INF)
	assert(first.face_values[&"nose_width"] == 0.0)
	first.set_face_parameter(&"nose_width", -4.0)
	assert(first.face_values[&"nose_width"] == -1.0)
	first.reset_appearance()
	assert(first.outfit_index == 0 and first.motion == &"idle")
	assert(first.skin_depth == 0.0 and first.skin_warmth == 0.0)
	for value in first.face_values.values():
		assert(value == 0.0)
	var network := root.get_node_or_null("GameNetwork")
	if network != null:
		assert(not network.active and network.host == null and network.pending_connection == null)
	first.free()
	second.free()
	print("Character assets: two samples, two outfits, shared skins, bounded animation and instance isolation passed")
	quit()

func _check_skin(mesh: MeshInstance3D, skeleton: Skeleton3D) -> void:
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		assert(bones.size() == vertices.size() * 4 and weights.size() == bones.size())
		for index in vertices.size():
			var point := Vector3.ZERO
			var total := 0.0
			for influence in range(4):
				var weight := weights[index * 4 + influence]
				var binding := bones[index * 4 + influence]
				assert(binding >= 0 and binding < mesh.skin.get_bind_count())
				assert(is_finite(weight) and weight >= 0.0)
				var bone := mesh.skin.get_bind_bone(binding)
				point += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(binding) * vertices[index]) * weight
				total += weight
			assert(absf(total - 1.0) < 0.002, "Skin weights must be normalized")
			assert(point.is_finite() and point.length() < 3.0, "Skin must remain within the character bounds")
