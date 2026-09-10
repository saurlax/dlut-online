extends Node

signal status_changed(value: String)
signal map_prepared(campus: String)
signal map_failed()
signal map_finished()
const RemotePlayer = preload("res://scripts/client/remote_player.gd")
const Guest = preload("res://scripts/client/guest_session.gd")
const Catalog = preload("res://scripts/shared/campus_catalog.gd")
var player: CharacterBody3D
var campus_id := "lingshui"
const Protocol = preload("res://scripts/shared/game_protocol.gd")
var host: ENetConnection
var socket: ENetPacketPeer
var close_code := 0
var snapshot_tick := -1
var snapshot_parts := {}
var applied_tick := -1
var roster_tick := -1
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
	return preload("res://scripts/client/desktop_config.gd").read().get("server_url", "")

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
		JSON.stringify({"id":Guest.guest_id, "version":Protocol.VERSION}))
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
	var destination := Protocol.endpoint(str(payload.get("game_server_url", "")))
	var config := preload("res://scripts/client/desktop_config.gd").read()
	if destination.is_empty() or (config.get("environment") == "production" and not destination.secure):
		close_code = 4002
		_disconnected()
		return
	ticket = payload.ticket
	host = ENetConnection.new()
	if host.create_host(1, 2) != OK:
		_disconnected()
		return
	if destination.secure:
		var options := TLSOptions.client()
		var ca_path := OS.get_environment("DO_GAME_TLS_CA")
		if not ca_path.is_empty():
			var certificate := X509Certificate.new()
			if certificate.load(ca_path) != OK:
				_disconnected()
				return
			options = TLSOptions.client(certificate)
		if host.dtls_client_setup(destination.host, options) != OK:
			_disconnected()
			return
	socket = host.connect_to_host(destination.host, destination.port, 2)
	if socket == null:
		_disconnected()
		return
	socket.set_timeout(8, 3000, 15000)
	close_code = 0
	welcomed = false
	sent_hello = false
	snapshot_tick = -1
	applied_tick = -1
	roster_tick = -1
	snapshot_parts.clear()
	last_received = Time.get_ticks_msec()

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
	var code := close_code
	if host != null:
		host.destroy()
		host = null
	socket = null
	if code in [4001,4002,4004]:
		active = false
		set_status({4001:"游客身份已在另一客户端连接",4002:"版本不兼容，请更新客户端",4004:"服务器人数已满"}[code])
		map_failed.emit()
		return
	retry_in = retry_delay
	retry_delay = minf(10.0, retry_delay * 2)
	set_status("连接断开，正在重连")
	map_failed.emit()

func _send(message: Dictionary) -> void:
	if socket == null or socket.get_state() != ENetPacketPeer.STATE_CONNECTED: return
	var realtime: bool = message.get("type") == "input"
	if socket.send(Protocol.REALTIME if realtime else Protocol.CONTROL, JSON.stringify(message).to_utf8_buffer(), 0 if realtime else ENetPacketPeer.FLAG_RELIABLE) != OK:
		_disconnected()

func _process(delta: float) -> void:
	if not active or connecting: return
	if retry_in > 0:
		retry_in -= delta
		if retry_in <= 0:
			retry_in = 0
			_connect()
		return
	if host == null: return
	for event_index in 512:
		if host == null: return
		var event := host.service(0)
		if event[0] == ENetConnection.EVENT_NONE: break
		if event[0] == ENetConnection.EVENT_DISCONNECT or event[0] == ENetConnection.EVENT_ERROR:
			close_code = int(event[2])
			_disconnected()
			return
		if event[0] == ENetConnection.EVENT_CONNECT:
			_send({"type":"hello", "version":Protocol.VERSION, "ticket":ticket, "campus":campus_id})
			ticket = ""
			sent_hello = true
		elif event[0] == ENetConnection.EVENT_RECEIVE:
			var packet := socket.get_packet()
			if packet.size() > 32768: continue
			last_received = Time.get_ticks_msec()
			if event[3] == Protocol.REALTIME:
				receive_snapshot(packet)
			else:
				var value: Variant = JSON.parse_string(packet.get_string_from_utf8())
				if value is Dictionary: message(value)
	if Time.get_ticks_msec() - last_received > 15000:
		_disconnected()
		return
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
		"roster":
			if m.get("campus") == campus_id and int(m.get("server_tick", -1)) > roster_tick:
				roster_tick = int(m.server_tick)
				apply_roster(m.get("roster", []))
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

func receive_snapshot(packet: PackedByteArray) -> void:
	var part := Protocol.read_snapshot(packet)
	if part.is_empty() or not welcomed or not transfer_phase.is_empty() or part.campus != campus_id or part.tick <= applied_tick or part.tick < snapshot_tick: return
	if part.tick > snapshot_tick:
		snapshot_tick = part.tick
		snapshot_parts.clear()
	snapshot_parts[part.part] = part.players
	if snapshot_parts.size() != part.parts: return
	var states: Array = []
	for i in int(part.parts): states.append_array(snapshot_parts[i])
	# Snapshot and reliable control use independent channels: verify local epoch first.
	var own := false
	for state: Dictionary in states:
		if state.id == Guest.guest_id:
			if state.map_epoch != epoch: return
			own = true
	if not own: return
	applied_tick = part.tick
	_apply_snapshot(states)

func apply_roster(roster: Array) -> void:
	names.clear()
	for entry: Dictionary in roster: names[entry.id] = entry.username

func apply_self(m: Dictionary, reset: bool) -> void:
	if not is_instance_valid(player): return
	var p := Vector3(m.position[0],m.position[1],m.position[2])
	var v := Vector3(m.velocity[0],m.velocity[1],m.velocity[2])
	if reset:
		epoch = int(m.map_epoch)
		roster_tick = maxi(roster_tick, int(m.server_tick))
		applied_tick = int(m.server_tick)
		snapshot_tick = applied_tick
		snapshot_parts.clear()
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
			continue
		if not transfer_phase.is_empty() or not is_instance_valid(player): continue
		present[entry.id] = true
		var point := Vector3(entry.position[0],entry.position[1],entry.position[2])
		if not remotes.has(entry.id):
			if not names.has(entry.id): continue
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
