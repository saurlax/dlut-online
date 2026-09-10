extends Node

signal status_changed(value: String)
signal authenticated()

static var token := ""
static var player_id := ""
static var username := ""
var waiting := false
var listener: TCPServer
var peer: StreamPeerTCP
var received := PackedByteArray()
var peer_started := 0
var deadline := 0
var verifier := ""
var state := ""
var request_id := ""
var generation := 0
var exchanging := false

static func clear() -> void:
	token = ""
	player_id = ""
	username = ""

func _exit_tree() -> void:
	cancel()

func cancel() -> void:
	generation += 1
	waiting = false
	exchanging = false
	if peer != null: peer.disconnect_from_host()
	peer = null
	if listener != null: listener.stop()
	listener = null
	verifier = ""
	state = ""
	request_id = ""
	received.clear()

func api_url() -> String:
	return preload("res://scripts/client/desktop_config.gd").read().get("server_url", "")

func post(path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15
	http.body_size_limit = 16384
	add_child(http)
	var error := http.request(api_url() + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	var result: Array = []
	if error == OK: result = await http.request_completed
	http.queue_free()
	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS: return {}
	var payload: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	return {"status": result[1], "body": payload if payload is Dictionary else {}}

func begin() -> void:
	cancel()
	clear()
	if api_url().is_empty():
		status_changed.emit("登录服务配置无效")
		return
	listener = TCPServer.new()
	if listener.listen(0, "127.0.0.1") != OK:
		cancel()
		status_changed.emit("无法接收网页登录结果，请重试")
		return
	verifier = Crypto.new().generate_random_bytes(32).hex_encode()
	state = Crypto.new().generate_random_bytes(32).hex_encode()
	waiting = true
	deadline = Time.get_ticks_msec() + 300000
	var current := generation
	status_changed.emit("正在打开网页登录")
	var result := await post("/api/v1/auth/requests", {"challenge": verifier.sha256_text(), "state": state,
		"redirect_uri": "http://127.0.0.1:%d/callback" % listener.get_local_port()})
	if current != generation: return
	if result.get("status") != 201:
		cancel()
		status_changed.emit("无法发起登录，请稍后重试")
		return
	request_id = str(result.body.get("request", ""))
	var path: String = str(result.body.get("login_path", ""))
	if request_id.is_empty() or not path.begins_with("/login?request=") or OS.shell_open(api_url() + path) != OK:
		cancel()
		status_changed.emit("无法打开浏览器，请重试")
		return
	status_changed.emit("请在网页完成登录，完成后返回游戏")

func _process(_delta: float) -> void:
	if not waiting: return
	if Time.get_ticks_msec() >= deadline:
		cancel()
		status_changed.emit("网页登录已超时，请重新登录")
		return
	if exchanging or listener == null: return
	if peer == null:
		if not listener.is_connection_available(): return
		peer = listener.take_connection()
		peer_started = Time.get_ticks_msec()
		received.clear()
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - peer_started > 3000:
		peer.disconnect_from_host()
		peer = null
		return
	var count := peer.get_available_bytes()
	if count > 0:
		var data := peer.get_data(mini(count, 8193))
		if data[0] != OK: return
		received.append_array(data[1])
	if received.size() > 8192:
		respond(false)
		return
	var raw := received.get_string_from_utf8()
	if not raw.contains("\r\n\r\n"): return
	var first := raw.get_slice("\r\n", 0).split(" ")
	if first.size() != 3 or first[0] != "GET" or not first[1].begins_with("/callback?"):
		respond(false)
		return
	var params := {}
	for pair in first[1].get_slice("?", 1).split("&"):
		var key := pair.get_slice("=", 0).uri_decode()
		if params.has(key):
			respond(false)
			return
		params[key] = pair.get_slice("=", 1).uri_decode()
	if params.get("state") != state or params.get("request") != request_id or str(params.get("code", "")).is_empty():
		respond(false)
		return
	exchanging = true
	var current := generation
	var result := await post("/api/v1/auth/exchange", {"request": request_id, "code": params.code, "verifier": verifier})
	if current != generation: return
	var body: Dictionary = result.get("body", {})
	var record: Dictionary = body.get("record", {}) if body.get("record") is Dictionary else {}
	if result.get("status") != 200 or not body.get("token") is String or not record.get("id") is String or not record.get("display_name") is String:
		respond(false)
		cancel()
		status_changed.emit("登录授权失效，请重新登录")
		return
	token = body.token
	player_id = record.id
	username = record.display_name
	respond(true)
	cancel()
	DisplayServer.window_move_to_foreground()
	authenticated.emit()

func respond(success: bool) -> void:
	if peer == null: return
	var message := "登录完成，请返回 DLUT Online。" if success else "此登录请求无效，请返回游戏重新登录。"
	var html := ("<!doctype html><html lang=\"zh-CN\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><title>DLUT Online</title><body><h1>DLUT Online</h1><p>" + message + "</p></body></html>").to_utf8_buffer()
	var headers := "HTTP/1.1 %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; frame-ancestors 'none'\r\nConnection: close\r\n\r\n" % ["200 OK" if success else "400 Bad Request", html.size()]
	peer.put_data(headers.to_utf8_buffer())
	peer.put_data(html)
	peer.disconnect_from_host()
	peer = null
