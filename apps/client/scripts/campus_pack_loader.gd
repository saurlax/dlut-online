extends Node

signal completed(success: bool)

const MANIFEST := "res://campus_packs.json"
static var mounted: Dictionary = {}
var request: HTTPRequest
var entry: Dictionary = {}
var campus_id := ""
var active := false
var downloaded := 0
var total := 0
var temporary := ""
var base_url := ""
var manifest_path := MANIFEST
var failure_reason := ""

func is_available(id: String) -> bool:
	return not FileAccess.file_exists(manifest_path) or mounted.has(id) or id == "lingshui"

func start(id: String) -> void:
	cancel()
	failure_reason = ""
	if is_available(id):
		completed.emit(true)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest.has(id):
		failure_reason = "Campus missing from manifest"
		completed.emit(false)
		return
	entry = manifest[id]
	campus_id = id
	total = int(entry.bytes)
	downloaded = 0
	active = true
	if base_url.is_empty() and OS.has_feature("web"):
		# Read-only bootstrap location; all downloading and travel use Godot nodes.
		base_url = str(JavaScriptBridge.eval("new URL('.', window.location.href).href"))
	request = HTTPRequest.new()
	request.timeout = 120
	request.body_size_limit = total
	request.accept_gzip = false
	add_child(request)
	DirAccess.make_dir_recursive_absolute("user://campus_packs")
	temporary = "user://campus_packs/" + str(get_instance_id()) + ".part"
	if not OS.has_feature("web"):
		request.download_file = temporary
	request.request_completed.connect(_download_completed)
	if request.request(base_url + str(entry.url)) != OK:
		finish(false)

func _process(_delta: float) -> void:
	if active and is_instance_valid(request):
		downloaded = request.get_downloaded_bytes()

func _download_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not active:
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and OS.has_feature("web"):
		var download := FileAccess.open(temporary, FileAccess.WRITE)
		if download != null:
			download.store_buffer(body)
			download.close()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(temporary):
		failure_reason = "HTTP result %d, status %d, local file available=%s" % [result, code, str(FileAccess.file_exists(temporary))]
		finish(false)
		return
	var file := FileAccess.open(temporary, FileAccess.READ)
	var size := file.get_length()
	file.close()
	var sha := FileAccess.get_sha256(temporary)
	if size != total or sha != str(entry.sha256):
		failure_reason = "Invalid pack: %d/%d bytes, SHA-256 match=%s" % [size, total, str(sha == str(entry.sha256))]
		finish(false)
		return
	var path := "user://campus_packs/" + str(entry.sha256) + ".pck"
	if DirAccess.rename_absolute(temporary, path) != OK:
		failure_reason = "Cannot rename downloaded pack"
		finish(false)
		return
	temporary = ""
	if not ProjectSettings.load_resource_pack(path, false):
		DirAccess.remove_absolute(path)
		failure_reason = "Cannot mount downloaded pack"
		finish(false)
		return
	mounted[campus_id] = true
	downloaded = total
	finish(true)

func finish(success: bool) -> void:
	if not success:
		push_warning("Campus pack " + campus_id + ": " + failure_reason)
	active = false
	cleanup_request()
	completed.emit(success)

func cleanup_request() -> void:
	if is_instance_valid(request):
		request.cancel_request()
		if request.request_completed.is_connected(_download_completed):
			request.request_completed.disconnect(_download_completed)
		request.queue_free()
		request = null
	if not temporary.is_empty() and FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	temporary = ""

func cancel() -> void:
	active = false
	cleanup_request()

func _exit_tree() -> void:
	cancel()
