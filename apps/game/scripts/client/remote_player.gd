extends Node3D

var target_position := Vector3.ZERO
var target_yaw := 0.0
var limbs: Array[Node3D] = []
var stride := 0.0

func configure(username: String, point: Vector3, yaw: float) -> void:
	name = "RemotePlayer"
	position = point
	rotation.y = yaw
	update_target(point, yaw)
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = Color("526b77")
	shirt.roughness = 0.9
	var trousers := StandardMaterial3D.new()
	trousers.albedo_color = Color("303942")
	trousers.roughness = 1
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("be967d")
	var torso := CapsuleMesh.new()
	torso.radius = 0.23
	torso.height = 0.62
	_part(self, torso, shirt, Vector3(0, 1.18, 0))
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.30
	_part(self, head, skin, Vector3(0, 1.65, 0))
	# A small nose makes facing direction readable without expensive textures.
	var nose := SphereMesh.new()
	nose.radius = 0.035
	nose.height = 0.07
	_part(self, nose, skin, Vector3(0, 1.65, -0.13))
	for side in [-1.0, 1.0]:
		_limb(Vector3(side * 0.13, 0.93, 0), 0.86, 0.09, trousers)
		_limb(Vector3(side * 0.29, 1.43, 0), 0.63, 0.065, shirt)
	var label := Label3D.new()
	label.text = username
	label.font = preload("res://assets/fonts/CampusSans.ttf")
	label.font_size = 48
	label.pixel_size = 0.004
	label.position.y = 2.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)

func _part(parent: Node3D, mesh: Mesh, material: Material, point: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = point
	parent.add_child(instance)

func _limb(point: Vector3, length: float, radius: float, material: Material) -> void:
	var pivot := Node3D.new()
	pivot.position = point
	add_child(pivot)
	limbs.append(pivot)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	_part(pivot, mesh, material, Vector3(0, -length / 2, 0))

func update_target(point: Vector3, yaw: float) -> void:
	target_position = point
	target_yaw = yaw

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	# Shared spawn points must not put another player's head inside the view.
	visible = camera == null or camera.global_position.distance_to(global_position + Vector3(0, 1.6, 0)) > 0.6
	var moving := Vector2(target_position.x - position.x, target_position.z - position.z).length() > 0.025
	if position.distance_to(target_position) > 10:
		position = target_position
	else:
		position = position.lerp(target_position, 1.0 - exp(-15.0 * delta))
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-15.0 * delta))
	stride += delta * 10.0
	for i in limbs.size():
		var swing := sin(stride) * 0.4 * (1.0 if i in [0, 3] else -1.0) if moving else 0.0
		limbs[i].rotation.x = lerpf(limbs[i].rotation.x, swing, 1.0 - exp(-15.0 * delta))
