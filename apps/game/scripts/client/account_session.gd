extends Node

signal status_changed(value: String)
signal authenticated()

static var token := ""
static var player_id := ""
static var username := ""
var waiting := false
var generation := 0
var pending: HTTPRequest

static func clear() -> void:
	token = ""
	player_id = ""
	username = ""

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
	var current := generation
	waiting = true
	status_changed.emit("正在登录")
	var http := HTTPRequest.new()
	http.timeout = 15
	http.body_size_limit = 32768
	add_child(http)
	pending = http
	var error := http.request(url + "/api/collections/users/auth-with-password", ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, JSON.stringify({"identity": email.strip_edges(), "password": password}))
	password = ""
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
		if result[1] == 429:
			status_changed.emit("登录过于频繁，请稍后重试")
		elif result[1] in [400, 401, 403]:
			status_changed.emit("登录失败，请检查邮箱和密码，并确认邮箱已验证、账号可用")
		else:
			status_changed.emit("登录服务暂时不可用，请稍后重试")
		return
	var body: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	var record: Dictionary = body.get("record", {}) if body is Dictionary and body.get("record") is Dictionary else {}
	if not body is Dictionary or not body.get("token") is String or body.token.is_empty() or not record.get("id") is String or not record.get("display_name") is String or record.get("verified") != true or record.get("disabled", false) == true or RegEx.create_from_string("^[a-z0-9]{15}$").search(record.id) == null:
		status_changed.emit("登录结果无效，请重新登录")
		return
	token = body.token
	player_id = record.id
	username = record.display_name
	authenticated.emit()
