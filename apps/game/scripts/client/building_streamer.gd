@tool
extends Node

const BUILDING_ROOT := "res://assets/campuses/eda/models/buildings"
const LOD0_DISTANCE := 190.0
const LOD0_UNLOAD_DISTANCE := 260.0
const LOD1_DISTANCE := 400.0
const LOD1_UNLOAD_DISTANCE := 500.0
const COLLISION_DISTANCE := 240.0
const COLLISION_UNLOAD_DISTANCE := 320.0
const CHECK_INTERVAL := 0.25

var campus_model: Node3D
var records: Array[Dictionary] = []
var states: Dictionary = {}
var requests: Array[Dictionary] = []
var requested: Dictionary = {}
var pending: Dictionary = {}
var instantiate_thread := Thread.new()
var instantiate_payload: Dictionary = {}
var elapsed := 0.0

func _ready() -> void:
	call_deferred("_initialize")

func _exit_tree() -> void:
	if instantiate_thread.is_started():
		var orphan := instantiate_thread.wait_to_finish() as Node
		if orphan != null:
			orphan.free()

func _initialize() -> void:
	campus_model = get_parent().get_node_or_null("CampusModel") as Node3D
	if campus_model == null:
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/campuses/eda/data/building_assets.json"
	))
	if data is not Dictionary:
		return
	for value: Variant in data.get("buildings", []):
		if value is Dictionary:
			records.append(value)
	if Engine.is_editor_hint():
		for record in records:
			_load_editor_preview(record)
		set_process(false)
		return
	for record in records:
		var feature_id := str(record.id)
		states[feature_id] = {"proxy": null, "detail": null, "tier": "", "collision": null}
		_queue_request(feature_id, "proxy")

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or campus_model == null:
		return
	_poll_pipeline()
	elapsed += delta
	if elapsed < CHECK_INTERVAL:
		return
	elapsed = 0.0
	var player := get_parent().get("player") as CharacterBody3D
	if player == null:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	for record in records:
		var feature_id := str(record.id)
		var origin: Array = record.origin
		var distance := player_xz.distance_to(Vector2(float(origin[0]), float(origin[2])))
		_update_distance(feature_id, distance)

func _update_distance(feature_id: String, distance: float) -> void:
	var state: Dictionary = states[feature_id]
	var tier := str(state.tier)
	if distance <= LOD0_DISTANCE:
		_queue_request(feature_id, "lod0", true)
	elif tier == "lod0" and distance > LOD0_UNLOAD_DISTANCE:
		_clear_detail(feature_id)
		tier = ""
	elif distance <= LOD1_DISTANCE and tier != "lod0":
		_queue_request(feature_id, "lod1")
	elif tier == "lod1" and distance > LOD1_UNLOAD_DISTANCE:
		_clear_detail(feature_id)
	if distance <= COLLISION_DISTANCE:
		_queue_request(feature_id, "collision", true)
	elif state.collision != null and distance > COLLISION_UNLOAD_DISTANCE:
		(state.collision as Node).queue_free()
		state.collision = null

func _queue_request(feature_id: String, tier: String, priority := false) -> void:
	var state: Dictionary = states.get(feature_id, {})
	if state.is_empty():
		return
	if tier == "proxy" and state.proxy != null:
		return
	if tier == "collision" and state.collision != null:
		return
	if tier in ["lod0", "lod1"] and str(state.tier) == tier:
		return
	var key := feature_id + ":" + tier
	if requested.has(key):
		return
	requested[key] = true
	var request := {"id": feature_id, "tier": tier, "path": _path_for(feature_id, tier), "key": key}
	if priority:
		requests.push_front(request)
	else:
		requests.append(request)

func _path_for(feature_id: String, tier: String) -> String:
	if tier == "lod0":
		return "%s/%s.glb" % [BUILDING_ROOT, feature_id]
	return "%s/%s/%s.glb" % [BUILDING_ROOT, tier, feature_id]

func _poll_pipeline() -> void:
	if instantiate_thread.is_started():
		if instantiate_thread.is_alive():
			return
		var instance := instantiate_thread.wait_to_finish() as Node3D
		_mount(instantiate_payload, instance)
		instantiate_payload = {}
		instantiate_thread = Thread.new()
		return
	if not pending.is_empty():
		var path := str(pending.path)
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		var payload := pending
		pending = {}
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			requested.erase(payload.key)
			push_error("Building load failed: " + path)
			return
		var packed := ResourceLoader.load_threaded_get(path) as PackedScene
		if packed == null:
			requested.erase(payload.key)
			return
		instantiate_payload = payload
		if instantiate_thread.start(_instantiate_scene.bind(packed)) != OK:
			instantiate_payload = {}
			_mount(payload, packed.instantiate() as Node3D)
		return
	if requests.is_empty():
		return
	pending = requests.pop_front()
	if ResourceLoader.load_threaded_request(str(pending.path)) != OK:
		requested.erase(pending.key)
		pending = {}

func _instantiate_scene(packed: PackedScene) -> Node:
	return packed.instantiate()

func _mount(payload: Dictionary, instance: Node3D) -> void:
	requested.erase(payload.key)
	var feature_id := str(payload.id)
	var tier := str(payload.tier)
	var placeholder := campus_model.get_node_or_null("Feature_" + feature_id) as Node3D
	if placeholder == null or instance == null or not states.has(feature_id):
		if instance != null:
			instance.queue_free()
		return
	var state: Dictionary = states[feature_id]
	instance.name = tier.capitalize()
	placeholder.add_child(instance)
	if tier == "proxy":
		if state.proxy != null:
			(state.proxy as Node).queue_free()
		state.proxy = instance
		instance.visible = state.detail == null
	elif tier == "collision":
		if state.collision != null:
			(state.collision as Node).queue_free()
		state.collision = instance
	else:
		if tier == "lod1" and str(state.tier) == "lod0":
			instance.queue_free()
			return
		if state.detail != null:
			(state.detail as Node).queue_free()
		state.detail = instance
		state.tier = tier
		if state.proxy != null:
			(state.proxy as Node3D).visible = false

func _clear_detail(feature_id: String) -> void:
	var state: Dictionary = states[feature_id]
	if state.detail != null:
		(state.detail as Node).queue_free()
	state.detail = null
	state.tier = ""
	if state.proxy != null:
		(state.proxy as Node3D).visible = true

func _load_editor_preview(record: Dictionary) -> void:
	var feature_id := str(record.id)
	var packed := load(_path_for(feature_id, "lod0")) as PackedScene
	var placeholder := campus_model.get_node_or_null("Feature_" + feature_id) as Node3D
	if packed != null and placeholder != null:
		var instance := packed.instantiate() as Node3D
		instance.name = "Lod0"
		placeholder.add_child(instance)
