extends Node

signal status_changed(value: String)
signal authenticated()

const Store = preload("res://scripts/client/credential_store.gd")
static var token := ""
static var player_id := ""
static var username := ""
static var token_origin := ""
static var restore_attempted := false
var waiting := false
var generation := 0
var pending: HTTPRequest

static func clear() -> void:
	token = ""
	player_id = ""
	username = ""
	token_origin = ""

static func forget_saved() -> Dictionary:
	var origin := token_origin
	if origin.is_empty(): origin = preload("res://scripts/client/desktop_config.gd").read().get("server_url", "")
	return await Store.request("delete", origin)

func _exit_tree() -> void:
	cancel()

func cancel() -> void:
	generation += 1
	waiting = false
	if is_instance_valid(pending):
		pending.cancel_request()
		pending.queue_free()
	pending = null

func api_url() -> String:
	return preload("res://scripts/client/desktop_config.gd").read().get("server_url", "")

func restore() -> void:
	if restore_attempted or waiting or not token.is_empty(): return
	restore_attempted = true
	var url := api_url()
	if url.is_empty(): return
	generation += 1
	var current := generation
	waiting = true
	status_changed.emit("正在恢复登录")
	var saved := await Store.request("read", url)
	if current != generation: return
	if not saved.ok:
		waiting = false
		status_changed.emit("使用 DLUT Online 账号登录" if saved.get("missing", false) or saved.get("unsupported", false) else "无法读取已保存登录，请输入邮箱和密码")
		return
	await _authenticate(url, "/api/collections/users/auth-refresh", {}, saved.value, current, true)

func begin(email: String, password: String) -> void:
	if waiting: return
	clear()
	if email.strip_edges().is_empty() or password.is_empty():
		status_changed.emit("请输入邮箱和密码")
		return
	var url := api_url()
	if url.is_empty():
		status_changed.emit("登录服务配置无效")
		return
	generation += 1
	waiting = true
	status_changed.emit("正在登录")
	var credentials := {"identity": email.strip_edges(), "password": password}
	password = ""
	await _authenticate(url, "/api/collections/users/auth-with-password", credentials, "", generation, false)

func _authenticate(url: String, path: String, body: Dictionary, bearer: String, current: int, restoring: bool) -> void:
	var http := HTTPRequest.new()
	http.timeout = 15
	http.body_size_limit = 32768
	add_child(http)
	pending = http
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not bearer.is_empty(): headers.append("Authorization: Bearer " + bearer)
	var error := http.request(url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	body.clear()
	bearer = ""
	var result: Array = []
	if error == OK: result = await http.request_completed
	if current != generation: return
	pending = null
	http.queue_free()
	waiting = false
	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS:
		status_changed.emit("无法连接登录服务，请稍后重试")
		return
	if result[1] != 200:
		if restoring and result[1] in [400, 401, 403, 404]:
			# Queue deletion before exposing manual login, preserving write order.
			Store.request("delete", url)
			clear()
			status_changed.emit("登录已失效，请重新登录")
		elif result[1] == 429:
			status_changed.emit("登录过于频繁，请稍后重试")
		elif result[1] in [400, 401, 403]:
			status_changed.emit("登录失败，请检查邮箱和密码，并确认邮箱已验证、账号可用")
		else:
			status_changed.emit("登录服务暂时不可用，请稍后重试")
		return
	var payload: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	var record: Dictionary = payload.get("record", {}) if payload is Dictionary and payload.get("record") is Dictionary else {}
	if not payload is Dictionary or not payload.get("token") is String or payload.token.is_empty() or not record.get("id") is String or not record.get("display_name") is String or record.get("verified") != true or record.get("disabled", false) == true or RegEx.create_from_string("^[a-z0-9]{15}$").search(record.id) == null:
		if restoring: Store.request("delete", url)
		status_changed.emit("登录结果无效，请重新登录")
		return
	token = payload.token
	player_id = record.id
	username = record.display_name
	token_origin = url
	# Queue the write before emitting success; logout queues its deletion after it.
	_save(url, token)
	authenticated.emit()

func _save(origin: String, value: String) -> void:
	var result := await Store.request("write", origin, value)
	if not result.ok and is_inside_tree() and token == value and token_origin == origin:
		status_changed.emit("本次已登录，但无法保存登录状态")
