extends SceneTree

const Loader = preload("res://scripts/campus_pack_loader.gd")
const Streamer = preload("res://scripts/campus_streamer.gd")
const Catalog = preload("res://scripts/campus_catalog.gd")
var finished := false
var succeeded := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		quit(1)
		assert(condition, message)

func download(loader: Node, id: String) -> bool:
	finished = false
	loader.start(id)
	while not finished:
		await process_frame
	return succeeded

func write_manifest(data: Dictionary, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	check(FileAccess.file_exists(Loader.MANIFEST), "Run against the exported Web PCK")
	check(not FileAccess.file_exists(Catalog.CAMPUSES.eda.scene), "EDA scene must be absent from initial pack")
	check(not FileAccess.file_exists(Catalog.CAMPUSES.eda.manifest), "EDA data must be absent from initial pack")
	check(not FileAccess.file_exists(Catalog.CAMPUSES.panjin.scene), "Panjin must be absent from initial pack")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Loader.MANIFEST))
	var loader := Loader.new()
	root.add_child(loader)
	loader.base_url = OS.get_cmdline_user_args()[0]
	loader.manifest_path = "user://test_campus_packs.json"
	loader.completed.connect(func(ok: bool):
		succeeded = ok
		finished = true)
	var wrong := manifest.duplicate(true)
	wrong.panjin.url = "campuses/missing.pck"
	write_manifest(wrong, loader.manifest_path)
	check(not await download(loader, "panjin"), "404 must fail")
	check(not loader.active and loader.temporary.is_empty(), "Failure must clean up temporary download")
	wrong = manifest.duplicate(true)
	wrong.panjin.sha256 = "0".repeat(64)
	write_manifest(wrong, loader.manifest_path)
	check(not await download(loader, "panjin"), "Hash mismatch must fail")
	check(not Loader.mounted.has("panjin"), "Damaged pack must not mount")
	write_manifest(manifest, loader.manifest_path)
	loader.start("eda")
	var temporary: String = loader.temporary
	loader.cancel()
	check(not loader.active and not FileAccess.file_exists(temporary), "Cancel must stop and clean up")
	check(await download(loader, "panjin"), "Retry with valid pack must succeed")
	check(loader.is_available("panjin"), "Mounted pack must be reused")
	loader.base_url = "http://127.0.0.1:1/"
	check(await download(loader, "panjin"), "Already mounted pack must work without network")
	loader.base_url = OS.get_cmdline_user_args()[0]
	check(await download(loader, "eda"), "EDA pack must load")
	Streamer.resource_base_url = OS.get_cmdline_user_args()[0]
	change_scene_to_file(Catalog.CAMPUSES.eda.scene)
	for i in 60:
		await physics_frame
	check(current_scene.manifest.features.size() == 27, "Downloaded EDA must retain all features")
	check(current_scene.player.is_on_floor(), "Downloaded campus spawn must be grounded")
	current_scene.hud.enter_campus()
	for id in ["lingshui", "panjin", "eda"]:
		var previous: WeakRef = weakref(current_scene)
		current_scene.hud.teleport(id)
		for i in 45:
			await physics_frame
		check(previous.get_ref() == null, "Old campus must unload")
		check(current_scene.campus_id == id, "Travel must arrive at destination")
		check(current_scene.player.is_on_floor(), "Destination must be grounded")
		check(current_scene.find_children("*", "Camera3D", true, false).size() == 1, "Only one camera may remain")
	DirAccess.remove_absolute(loader.manifest_path)
	print("PASS: minimal initial pack, HTTP failure, hash failure, cancel, retry, reuse, downloaded campus and travel")
	quit()
