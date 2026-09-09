extends SceneTree
const Catalog = preload("res://scripts/campus_catalog.gd")
const Loader = preload("res://scripts/campus_pack_loader.gd")
const Streamer = preload("res://scripts/campus_streamer.gd")
var ended := false
var succeeded := false
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)
		quit(1)
		assert(condition,message)

func _initialize() -> void:
	_run.call_deferred()

func settled(stream: Node) -> void:
	while stream.pending_count > 0:
		check(not stream.has_failures(),"Nearby chunk download must succeed")
		await process_frame

func _run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	check(not ResourceLoader.exists("res://assets/campuses/lingshui/models/lingshui_campus.tscn"),"Full Lingshui model must be excluded from Web startup")
	check(not ResourceLoader.exists("res://assets/campuses/eda/models/development_campus.tscn"),"Full EDA model must be excluded from Web startup")
	var url := OS.get_cmdline_user_args()[0]
	Streamer.resource_base_url = url
	var loader := Loader.new()
	root.add_child(loader)
	loader.base_url = url
	loader.completed.connect(func(ok: bool): ended = true; succeeded = ok)
	for id: String in Catalog.CAMPUSES:
		ended = false
		loader.start(id)
		while not ended: await process_frame
		check(succeeded,"Campus bootstrap must download")
		var scene: Node3D = load(Catalog.CAMPUSES[id].scene).instantiate()
		root.add_child(scene)
		var stream: Node = scene.streamer
		check(stream.active,"All three campuses must use a grid")
		check(stream.grid.cell_size == 100,"Grid size must be 100 metres")
		check(not stream.grid.chunks.is_empty(),"Campus must have detail packs")
		stream.suspend()
		check(stream.instances.is_empty(),"Collision test must run without any streamed details")
		for i in 30: await physics_frame
		if id == "lingshui":
			var ray := PhysicsRayQueryParameters3D.create(Vector3(99,4,-12),Vector3(99,4,-30))
			check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Structural collision must exist before detail downloads")
		stream.resume()
		await settled(stream)
		check(scene.player.is_on_floor(),"Bootstrap collisions must support spawn")
		var initial_count: int = stream.instances.size()
		check(initial_count > 0,"Spawn neighborhood must load details")
		check(stream.downloaded == stream.total,"Nearby progress must reach total")
		var original: Vector3 = scene.player.position
		var saved: WeakRef = weakref(stream.instances.values()[0])
		scene.player.position = Vector3(10000,5,10000)
		stream.refresh()
		await process_frame
		check(stream.instances.is_empty() and saved.get_ref() == null,"Distant instances must be freed")
		stream.loader.base_url = "http://127.0.0.1:1/"
		scene.player.position = original
		stream.refresh()
		await settled(stream)
		check(stream.instances.size() == initial_count,"Returning must reuse mounted chunks without HTTP")
		# Exercise failure + retry using a real pack under an isolated cache key.
		var key: String = stream.wanted.keys()[0]
		var entry: Dictionary = stream.grid.chunks[key].duplicate()
		var cache_key := id + "/" + str(entry.sha256)
		Loader.mounted.erase(cache_key)
		stream.instances[key].queue_free()
		stream.instances.erase(key)
		stream.grid.chunks[key].url = "campuses/missing.pck"
		stream.loader.base_url = url
		stream.refresh()
		while not stream.has_failures(): await process_frame
		stream.grid.chunks[key] = entry
		stream.retry()
		await settled(stream)
		check(stream.instances.size() == initial_count,"Retry must restore nearby details")
		var previous: WeakRef = weakref(stream)
		scene.queue_free()
		await process_frame
		check(previous.get_ref() == null,"Leaving campus must free streamer and cancel requests")
		print("GRID PASS ",id,": ",initial_count," spawn packs / ",stream_count(id)," total")
	print("PASS: three campus grids, startup, collision, unloading, reuse, HTTP failure and retry")
	quit(failures)

func stream_count(id: String) -> int:
	var grid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://grid_"+id+".json"))
	return grid.chunks.size()
