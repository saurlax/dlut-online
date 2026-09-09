extends Node

signal status_changed(value: String)
signal map_prepared(campus: String)
signal map_failed()
signal map_finished()
const RemotePlayer = preload("res://scripts/remote_player.gd")
const Guest = preload("res://scripts/guest_session.gd")
const Catalog = preload("res://scripts/campus_catalog.gd")
var player: CharacterBody3D
var campus_id := "lingshui"
var socket := WebSocketPeer.new()
var remotes := {}
var names := {}
var active := false
var started := false
var welcomed := false
var sent_hello := false
var connecting := false
var elapsed := 0.0
var heartbeat_elapsed := 0.0
var last_received := 0
var retry_in := 0.0
var retry_delay := 1.0
var status_text := "未连接"
var ticket := ""
var epoch := 1
var sequence := 0
var jump_sequence := 0
var admission_id := ""
var transfer_id := ""
var target := ""
var request_id := 0
var transfer_phase := ""
var cancel_pending := false
var load_generation := 0
var control_elapsed := 0.0
var history := {}
var was_active := false
var restore_playing := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(body: CharacterBody3D, campus: String) -> void:
	_clear_remotes()
	player = body
	campus_id = campus
	player.network_ready = false
	if not transfer_id.is_empty():
		if transfer_phase == "loading":
			transfer_phase = "ready"
			_send({"type":"map_ready", "transfer_id":transfer_id})

func start() -> void:
	if started: return
	started = true
	active = true
	_connect()

func set_status(value: String) -> void:
	if value != status_text:
		status_text = value
		status_changed.emit(value)

func base_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin")
		return origin if origin is String else ""
	return preload("res://scripts/desktop_config.gd").read().get("server_url", "")

func _connect() -> void:
	if connecting: return
	connecting = true
	set_status("连接中")
	var url := base_url()
	var request := HTTPRequest.new()
	request.timeout = 5
	request.body_size_limit = 4096
	add_child(request)
	var error := request.request(url + "/api/v1/game/tickets", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"id":Guest.guest_id, "version":2}))
	var result: Array = []
	if error == OK: result = await request.request_completed
	request.queue_free()
	connecting = false
	if result.is_empty() or result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 201:
		_disconnected()
		return
	var payload: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if not payload is Dictionary or not payload.get("ticket") is String:
		_disconnected()
		return
	ticket = payload.ticket
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 1048576
	socket.outbound_buffer_size = 16384
	socket.max_queued_packets = 64
	welcomed = false
	sent_hello = false
	last_received = Time.get_ticks_msec()
	if socket.connect_to_url(url.replace("https://", "wss://").replace("http://", "ws://") + "/ws") != OK: _disconnected()

func _disconnected() -> void:
	if retry_in > 0: return
	_clear_remotes()
	if is_instance_valid(player): player.network_ready = false
	welcomed = false
	load_generation += 1
	transfer_id = ""
	transfer_phase = ""
	target = ""
	history.clear()
	var code := socket.get_close_code()
	if code in [4001,4002,4004]:
		active = false
		set_status({4001:"游客身份已在另一页面连接",4002:"版本不兼容，请刷新或更新",4004:"服务器人数已满"}[code])
		map_failed.emit()
		return
	socket.close()
	retry_in = retry_delay
	retry_delay = minf(10.0, retry_delay * 2)
	set_status("连接断开，正在重连")
	map_failed.emit()

func _send(message: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if socket.get_current_outbound_buffered_amount() > 8192:
			socket.close()
			_disconnected()
			return
		socket.send_text(JSON.stringify(message))

func _process(delta: float) -> void:
	if not active or connecting: return
	if retry_in > 0:
		retry_in -= delta
		if retry_in <= 0:
			retry_in = 0
			_connect()
		return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_disconnected()
		return
	if Time.get_ticks_msec() - last_received > 15000:
		_disconnected()
		return
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	if not sent_hello:
		_send({"type":"hello", "version":2, "ticket":ticket, "campus":campus_id})
		ticket = ""
		sent_hello = true
	while socket.get_available_packet_count() > 0:
		var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if value is Dictionary:
			last_received = Time.get_ticks_msec()
			message(value)
	if not welcomed: return
	heartbeat_elapsed += delta
	if heartbeat_elapsed >= 5:
		heartbeat_elapsed = 0
		_send({"type":"heartbeat"})
	if not transfer_phase.is_empty():
		control_elapsed += delta
		if control_elapsed >= 2 and not transfer_id.is_empty():
			control_elapsed = 0
			_send({"type":"map_status", "transfer_id":transfer_id})
		return
	if not is_instance_valid(player): return
	var moving: bool = player.playing and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.drag_look)
	elapsed += delta
	if elapsed >= 0.05 or (was_active and not moving):
		elapsed = 0
		sequence += 1
		history[sequence] = player.position
		while history.size() > 80: history.erase(history.keys()[0])
		var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if moving else Vector2.ZERO
		_send({"type":"input", "seq":sequence, "axis":[axis.x,axis.y], "yaw":wrapf(player.rotation.y,-PI,PI),
			"run":moving and Input.is_action_pressed("run"), "jump":player.jump_sequence, "map_epoch":epoch})
	was_active = moving

func message(m: Dictionary) -> void:
	match m.get("type"):
		"welcome":
			if m.get("id") != Guest.guest_id: return
			welcomed = true
			retry_delay = 1
			admission_id = m.admission_id
			names.clear()
			apply_roster(m.get("roster", []))
			apply_self(m, true)
			set_status("已连接")
		"snapshot":
			if m.get("campus") != campus_id: return
			if m.has("roster"): apply_roster(m.roster)
			_apply_snapshot(m.get("players", []))
		"map_prepare":
			if int(m.get("request_id", -1)) != request_id or transfer_phase == "": return
			if not transfer_id.is_empty(): return
			transfer_id = m.transfer_id
			if cancel_pending:
				_send({"type":"map_cancel", "transfer_id":transfer_id})
			else:
				transfer_phase = "preparing"
				map_prepared.emit(target)
		"map_entered", "map_cancelled": finish_map(m)
		"map_error":
			if int(m.get("request_id", -1)) != request_id: return
			transfer_phase = ""
			target = ""
			if is_instance_valid(player): player.network_ready = true
			map_failed.emit()

func apply_roster(roster: Array) -> void:
	for entry: Dictionary in roster: names[entry.id] = entry.username

func apply_self(m: Dictionary, reset: bool) -> void:
	if not is_instance_valid(player): return
	var p := Vector3(m.position[0],m.position[1],m.position[2])
	var v := Vector3(m.velocity[0],m.velocity[1],m.velocity[2])
	if reset:
		epoch = int(m.map_epoch)
		sequence = 0
		player.jump_sequence = int(m.get("jump",0))
		history.clear()
		player.position = p
		player.velocity = v
		player.rotation.y = float(m.yaw)
	else:
		var ack := int(m.seq)
		if history.has(ack):
			var correction: Vector3 = p - history[ack]
			player.correct_position(correction)
			for key in history.keys():
				if key <= ack: history.erase(key)
				else: history[key] += correction
	player.network_ready = true

func _apply_snapshot(states: Array) -> void:
	var present := {}
	for entry: Dictionary in states:
		if entry.id == Guest.guest_id:
			if transfer_phase.is_empty() and entry.map_epoch == epoch: apply_self(entry, false)
			elif not transfer_id.is_empty() and not entry.get("transfer", {}).is_empty():
				var result: Dictionary = entry.transfer
				if result.get("type") in ["map_entered","map_cancelled"]: finish_map(result)
			continue
		if not transfer_phase.is_empty() or not is_instance_valid(player): continue
		present[entry.id] = true
		var point := Vector3(entry.position[0],entry.position[1],entry.position[2])
		if not remotes.has(entry.id):
			var remote := RemotePlayer.new()
			player.get_parent().add_child(remote)
			remote.configure(names.get(entry.id,""),point,float(entry.yaw))
			remotes[entry.id] = remote
		remotes[entry.id].update_target(point,float(entry.yaw))
	for id in remotes.keys():
		if not present.has(id):
			if is_instance_valid(remotes[id]): remotes[id].queue_free()
			remotes.erase(id)

func request_map(id: String, resume: bool) -> bool:
	if not welcomed or not transfer_phase.is_empty(): return false
	request_id += 1
	target = id
	transfer_id = ""
	transfer_phase = "requested"
	cancel_pending = false
	restore_playing = resume
	player.network_ready = false
	_send({"type":"change_map", "request_id":request_id, "campus":id})
	return true

func cancel_map() -> void:
	if transfer_phase.is_empty(): return
	cancel_pending = true
	load_generation += 1
	if not transfer_id.is_empty(): _send({"type":"map_cancel", "transfer_id":transfer_id})

func load_target(id: String) -> void:
	transfer_phase = "loading"
	load_generation += 1
	var generation := load_generation
	var path: String = Catalog.CAMPUSES[id].scene
	if ResourceLoader.load_threaded_request(path) != OK:
		cancel_map()
		map_failed.emit()
		return
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if generation != load_generation: return
	if generation != load_generation: return
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		cancel_map()
		map_failed.emit()
		return
	var scene: PackedScene = ResourceLoader.load_threaded_get(path)
	_clear_remotes()
	Catalog.arriving = true
	if get_tree().change_scene_to_packed(scene) != OK:
		cancel_map()
		map_failed.emit()

func finish_map(m: Dictionary) -> void:
	if transfer_id.is_empty() or m.get("transfer_id") != transfer_id or transfer_phase == "restoring": return
	load_generation += 1
	var generation := load_generation
	if campus_id != m.campus:
		transfer_phase = "restoring"
		var path: String = Catalog.CAMPUSES[m.campus].scene
		if ResourceLoader.load_threaded_request(path) != OK: return
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			if generation != load_generation: return
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			map_failed.emit()
			return
		Catalog.arriving = true
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path))
		await get_tree().process_frame
		await get_tree().process_frame
	if generation != load_generation or not is_instance_valid(player) or campus_id != m.campus: return
	apply_self(m, true)
	apply_roster(m.get("roster", []))
	if m.type == "map_cancelled": _send({"type":"map_resume", "transfer_id":transfer_id})
	transfer_id = ""
	transfer_phase = ""
	target = ""
	map_finished.emit()

func _clear_remotes() -> void:
	for remote in remotes.values():
		if is_instance_valid(remote): remote.queue_free()
	remotes.clear()
