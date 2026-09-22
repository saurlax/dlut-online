@tool
extends Node

const Collision = preload("res://scripts/shared/campus_collision.gd")
const BUILDING_ROOT := "res://assets/campuses/eda/models/buildings"
const LOAD_DISTANCE := 220.0
const UNLOAD_DISTANCE := 300.0
const CHECK_INTERVAL := 0.35

var campus_model: Node3D
var records: Array[Dictionary] = []
var loaded: Dictionary = {}
var pending_id := ""
var pending_path := ""
var elapsed := 0.0

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	campus_model = get_parent().get_node_or_null("CampusModel") as Node3D
	if campus_model == null:
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/campuses/eda/data/building_assets.json"))
	if data is not Dictionary:
		return
	for value: Variant in data.get("buildings", []):
		if value is Dictionary:
			records.append(value)
	if Engine.is_editor_hint():
		for record in records:
			_load_editor_preview(record)
		set_process(false)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or campus_model == null:
		return
	if not pending_id.is_empty():
		_poll_pending()
		return
	elapsed += delta
	if elapsed < CHECK_INTERVAL:
		return
	elapsed = 0.0
	var player := get_parent().get("player") as CharacterBody3D
	if player == null:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for record in records:
		var feature_id := str(record.id)
		var origin: Array = record.origin
		var distance := player_xz.distance_to(Vector2(float(origin[0]), float(origin[2])))
		if loaded.has(feature_id):
			if distance > UNLOAD_DISTANCE:
				_unload(feature_id)
		elif distance <= LOAD_DISTANCE and distance < nearest_distance:
			nearest = record
			nearest_distance = distance
	if not nearest.is_empty():
		_request(nearest)

func _request(record: Dictionary) -> void:
	pending_id = str(record.id)
	pending_path = "%s/%s.glb" % [BUILDING_ROOT, pending_id]
	if ResourceLoader.load_threaded_request(pending_path) != OK:
		pending_id = ""
		pending_path = ""

func _poll_pending() -> void:
	var status := ResourceLoader.load_threaded_get_status(pending_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var feature_id := pending_id
	var path := pending_path
	pending_id = ""
	pending_path = ""
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Building load failed: " + path)
		return
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		return
	_mount(feature_id, packed.instantiate() as Node3D)

func _mount(feature_id: String, instance: Node3D) -> void:
	var placeholder := campus_model.get_node_or_null("Feature_" + feature_id) as Node3D
	if placeholder == null or instance == null:
		if instance != null:
			instance.queue_free()
		return
	instance.name = "BuildingModel"
	placeholder.add_child(instance)
	loaded[feature_id] = instance
	if not Engine.is_editor_hint():
		Collision.build_feature(instance)

func _unload(feature_id: String) -> void:
	var instance := loaded.get(feature_id) as Node3D
	loaded.erase(feature_id)
	if instance != null:
		instance.queue_free()

func _load_editor_preview(record: Dictionary) -> void:
	var feature_id := str(record.id)
	var path := "%s/%s.glb" % [BUILDING_ROOT, feature_id]
	var packed := load(path) as PackedScene
	if packed != null:
		_mount(feature_id, packed.instantiate() as Node3D)
