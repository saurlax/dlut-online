extends SceneTree
## Convert offline Blender output to editor-visible runtime resources.

const OUTPUT := "res://assets/characters"

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: --script tools/characters/pack_samples.gd -- GENERATED_DIRECTORY")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("models"))
	for sample in ["male", "female"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(arguments[0].path_join("student_%s.glb" % sample), state)
		if error != OK:
			push_error("Cannot import sample: %s" % error)
			quit(1)
			return
		var root := document.generate_scene(state)
		root.name = "Student" + sample.capitalize()
		var model_skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			# Name the skeleton explicitly: ".." can be omitted by PackedScene
			# when the host uses the pre-4.6 default, breaking modern projects.
			instance.skeleton = NodePath(String(instance.get_path_to(model_skeleton.get_parent())).path_join(String(model_skeleton.name)))
			for surface in instance.mesh.get_surface_count():
				var original := instance.mesh.surface_get_material(surface)
				var label: String = original.resource_name
				var material := StandardMaterial3D.new()
				material.resource_name = label
				material.albedo_texture = load(OUTPUT.path_join("textures/%s.png" % label))
				if material.albedo_texture == null:
					push_error("Missing texture: " + label)
					quit(1)
					return
				material.roughness = 0.8
				if label.begins_with("Hair"):
					material.albedo_color = Color(0.16, 0.14, 0.13)
				if label.begins_with("Hair") or label.begins_with("Brows") or label.begins_with("Lashes") or label == "Eyes":
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					material.alpha_scissor_threshold = 0.35
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
				instance.mesh.surface_set_material(surface, material)
			if String(instance.name) in ["Brows", "Lashes"]:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mesh_path := OUTPUT.path_join("models/%s_%s.res" % [sample, instance.name])
			if ResourceSaver.save(instance.mesh, mesh_path, ResourceSaver.FLAG_COMPRESS) != OK:
				quit(1)
				return
			instance.mesh = load(mesh_path)
			if instance.name == "Body1" or instance.name == "Outfit1":
				instance.visible = false
		for node in root.find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
			var skeleton_path := String(root.get_path_to(skeleton))
			print(sample, " animations: ", player.get_animation_list())
			for animation_name in player.get_animation_list():
				if animation_name != "RESET":
					var animation := player.get_animation(animation_name)
					animation.loop_mode = Animation.LOOP_LINEAR
					# glTF omits constant tracks. Every clip must still reset bones
					# moved by other clips, e.g. the calf when returning to idle.
					for bone in skeleton.get_bone_count():
						var bone_path := NodePath(skeleton_path + ":" + skeleton.get_bone_name(bone))
						if animation.find_track(bone_path, Animation.TYPE_ROTATION_3D) < 0:
							var track := animation.add_track(Animation.TYPE_ROTATION_3D)
							animation.track_set_path(track, bone_path)
							animation.rotation_track_insert_key(track, 0.0, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
						if skeleton.get_bone_name(bone) == "pelvis" and animation.find_track(bone_path, Animation.TYPE_POSITION_3D) < 0:
							var track := animation.add_track(Animation.TYPE_POSITION_3D)
							animation.track_set_path(track, bone_path)
							animation.position_track_insert_key(track, 0.0, skeleton.get_bone_rest(bone).origin)
		var packed := PackedScene.new()
		if packed.pack(root) != OK or ResourceSaver.save(packed, OUTPUT.path_join("models/student_%s.tscn" % sample)) != OK:
			quit(1)
			return
		root.free()
	quit()
