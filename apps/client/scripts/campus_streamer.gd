extends Node3D

const Loader = preload("res://scripts/campus_pack_loader.gd")
const CELL_SIZE := 100.0
const LOAD_RADIUS := 2
const KEEP_RADIUS := 3
var player: CharacterBody3D
var campus_id := ""
var grid: Dictionary = {}
var loader: Node
var instances := {}
var wanted := {}
var failed := {}
var current := ""
var elapsed := 0.0
var downloaded := 0
var total := 0
var pending_count := 0
var active := false
static var resource_base_url := ""

func configure(body: CharacterBody3D, id: String) -> void:
	player = body
	campus_id = id
	var path := "res://grid_" + id + ".json"
	if not FileAccess.file_exists(path): return
	grid = JSON.parse_string(FileAccess.get_file_as_string(path))
	loader = Loader.new()
	add_child(loader)
	loader.base_url = resource_base_url
	loader.completed.connect(_completed)
	active = true
	refresh()

func nearby(radius: int) -> Dictionary:
	var result := {}
	var center := Vector2i(floori(player.position.x/CELL_SIZE),floori(player.position.z/CELL_SIZE))
	for x in range(center.x-radius,center.x+radius+1):
		for z in range(center.y-radius,center.y+radius+1):
			for key: String in grid.cells.get("%d,%d" % [x,z],[]):
				var distance := Vector2(x-center.x,z-center.y).length_squared()
				result[key] = minf(result.get(key,INF),distance)
	return result

func refresh() -> void:
	if not active: return
	wanted = nearby(LOAD_RADIUS)
	var keep := nearby(KEEP_RADIUS)
	for key: String in instances.keys():
		if not keep.has(key):
			instances[key].queue_free()
			instances.erase(key)
	if not current.is_empty() and not wanted.has(current):
		loader.cancel()
		current = ""
	update_progress()

func update_progress() -> void:
	total = 0
	downloaded = 0
	pending_count = 0
	for key: String in wanted:
		var bytes := int(grid.chunks[key].bytes)
		total += bytes
		if instances.has(key): downloaded += bytes
		else:
			pending_count += 1
			if key == current: downloaded += mini(bytes,loader.downloaded)

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	if elapsed >= 0.2:
		elapsed = 0
		refresh()
	if current.is_empty():
		var next := ""
		var distance := INF
		for key: String in wanted:
			if not instances.has(key) and not failed.has(key) and wanted[key] < distance:
				next = key
				distance = wanted[key]
		if not next.is_empty():
			current = next
			var entry: Dictionary = grid.chunks[next]
			loader.start_entry(campus_id + "/" + str(entry.sha256),entry)
	update_progress()

func _completed(success: bool) -> void:
	var key := current
	current = ""
	if key.is_empty() or not active or not wanted.has(key): return
	if not success:
		failed[key] = true
		return
	var packed: PackedScene = load(grid.chunks[key].scene)
	if packed == null:
		failed[key] = true
		return
	var node := packed.instantiate()
	add_child(node)
	instances[key] = node

func has_failures() -> bool:
	for key: String in failed:
		if wanted.has(key): return true
	return false

func retry() -> void:
	failed.clear()

func suspend() -> void:
	active = false
	current = ""
	if is_instance_valid(loader): loader.cancel()

func resume() -> void:
	active = not grid.is_empty()
	refresh()

func _exit_tree() -> void:
	active = false
	if is_instance_valid(loader): loader.cancel()
