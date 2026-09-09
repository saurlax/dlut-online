extends Node

signal status_changed(value: String)
const RemotePlayer = preload("res://scripts/remote_player.gd")
var player: CharacterBody3D
var campus_id := ""
var socket := WebSocketPeer.new()
var remotes: Dictionary = {}
var active := false
var started := false
var sent_hello := false
var welcomed := false
var elapsed := 0.0
var retry_in := 0.0
var retry_delay := 1.0
var connection_age := 0.0
var status_text := "未连接"

func configure(body: CharacterBody3D, campus: String) -> void:
	player = body
	campus_id = campus

func set_status(value: String) -> void:
	if value != status_text:
		status_text = value
		status_changed.emit(value)

func start() -> void:
	if started:
		return
	started = true
	active = true
	_connect()

func _connect() -> void:
	var server_url := ""
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin")
		if origin is String:
			server_url = origin
	else:
		var config: Dictionary = preload("res://scripts/desktop_config.gd").read()
		server_url = config.get("server_url", "")
	if server_url.is_empty():
		active = false
		set_status("服务器地址无效")
		return
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 1024 * 1024
	socket.max_queued_packets = 32
	sent_hello = false
	welcomed = false
	connection_age = 0.0
	set_status("连接中")
	var error := socket.connect_to_url(server_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws")
	if error != OK:
		_disconnected()

func _disconnected() -> void:
	_clear_remotes()
	welcomed = false
	if socket.get_close_code() == 4001:
		active = false
		set_status("游客身份已在另一页面连接")
		return
	retry_in = retry_delay
	retry_delay = minf(10.0, retry_delay * 2)
	set_status("连接断开，正在重连")

func _state(kind: String) -> Dictionary:
	var p := player.global_position
	return {"type": kind, "id": player.guest_id, "campus": campus_id,
		"position": [p.x, p.y, p.z], "yaw": wrapf(player.rotation.y, -PI, PI)}

func _process(delta: float) -> void:
	if not active:
		return
	if retry_in > 0:
		retry_in -= delta
		if retry_in <= 0:
			_connect()
		return
	socket.poll()
	connection_age += delta
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_disconnected()
		return
	if connection_age > 15:
		socket.close()
		_disconnected()
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not sent_hello:
		socket.send_text(JSON.stringify(_state("hello")))
		sent_hello = true
	while socket.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if not message is Dictionary:
			continue
		connection_age = 0
		if message.get("type") == "welcome" and message.get("id") == player.guest_id:
			welcomed = true
			retry_delay = 1.0
			set_status("已连接")
		elif welcomed and message.get("type") == "snapshot" and message.get("players") is Array:
			_apply_snapshot(message.players)
	elapsed += delta
	if welcomed and elapsed >= 0.1:
		elapsed = 0
		socket.send_text(JSON.stringify(_state("state")))

func _apply_snapshot(states: Array) -> void:
	var present: Dictionary = {}
	for entry in states:
		if not entry is Dictionary or entry.get("campus") != campus_id or entry.get("id") == player.guest_id:
			continue
		if not entry.get("id") is String or not entry.get("username") is String or not entry.get("position") is Array or entry.position.size() != 3:
			continue
		var id: String = entry.id
		present[id] = true
		var point := Vector3(entry.position[0], entry.position[1], entry.position[2])
		if not remotes.has(id):
			var remote := RemotePlayer.new()
			get_parent().add_child(remote)
			remote.configure(entry.username, point, float(entry.yaw))
			remotes[id] = remote
		remotes[id].update_target(point, float(entry.yaw))
	for id in remotes.keys():
		if not present.has(id):
			remotes[id].queue_free()
			remotes.erase(id)

func _clear_remotes() -> void:
	for remote in remotes.values():
		remote.queue_free()
	remotes.clear()

func _exit_tree() -> void:
	active = false
	socket.close(1000, "leaving campus")
