extends Node

const Movement = preload("res://scripts/shared/movement.gd")
const DataService = preload("res://scripts/server/data_service.gd")
const MAPS := ["lingshui", "eda", "panjin"]
const MAX_CONNECTIONS := 100
const MAX_PLAYERS := 50
const ChatRules = preload("res://scripts/shared/chat_rules.gd")
const Protocol = preload("res://scripts/shared/game_protocol.gd")
var listener := ENetConnection.new()
var data: Node
var connections: Array[Dictionary] = []
var players := {}
var worlds := {}
var tick := 0
var roster_dirty := true
var chat_last_accepted := {}
var chat_event_id := 0
var chat_events: Array[Dictionary] = []
var tick_samples: Array[int] = []

func _ready() -> void:
	Engine.max_fps = 60
	data = DataService.new()
	add_child(data)
	if not data.configure():
		push_error("Invalid DO_API_SERVER_URL or missing DO_API_KEY")
		get_tree().quit(1)
		return
	for id: String in MAPS:
		worlds[id] = get_node(id + "/World")
	var port_text := OS.get_environment("DO_GAME_SERVER_PORT")
	var port := 1949 if port_text.is_empty() else port_text.to_int()
	var address := "*"
	if port < 1 or port > 65535 or listener.create_host_bound(address, port, MAX_CONNECTIONS, 2) != OK:
		push_error("Cannot listen for game connections")
		get_tree().quit(1)
		return
	var certificate_path := OS.get_environment("DO_GAME_TLS_CERT")
	var key_path := OS.get_environment("DO_GAME_TLS_KEY")
	if OS.get_environment("DO_ENV") == "production" or not certificate_path.is_empty() or not key_path.is_empty():
		var certificate := X509Certificate.new()
		var key := CryptoKey.new()
		if certificate.load(certificate_path) != OK or key.load(key_path) != OK or listener.dtls_server_setup(TLSOptions.server(key, certificate)) != OK:
			push_error("Game DTLS certificate/key configuration failed")
			get_tree().quit(1)
			return
	print("Game ENet server listening ", address, ":", port)

func _process(delta: float) -> void:
	# Bound per-frame work even when a peer floods incoming packets.
	for event_index in 4096:
		var event := listener.service(0)
		if event[0] == ENetConnection.EVENT_NONE: break
		var peer: ENetPacketPeer = event[1]
		if event[0] == ENetConnection.EVENT_CONNECT:
			var now := Time.get_ticks_msec()
			peer.set_timeout(8, 3000, 15000)
			connections.append({"peer":peer, "created":now, "last":now, "window":now, "messages":0,
				"identity":{}, "authenticating":false, "closing":false, "body":null, "campus":"", "epoch":1,
				"seq":-1, "jump":0, "axis":Vector2.ZERO, "run":false, "yaw":0.0, "last_input":now,
				"chat_request":0, "announced":false, "replacing":false, "transfer":{}, "results":{}, "request_high":0, "frozen":false})
		else:
			var c := connection_for(peer)
			if event[0] == ENetConnection.EVENT_RECEIVE:
				var packet := peer.get_packet()
				if c.is_empty() or c.closing: continue
				var now := Time.get_ticks_msec()
				if now - c.window >= 1000:
					c.window = now
					c.messages = 0
				c.messages += 1
				if packet.size() > 2048 or c.messages > 40:
					close(c, 4002, "message limit")
					continue
				var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
				if not message is Dictionary or (event[3] == Protocol.REALTIME) != (message.get("type") == "input"):
					close(c, 4002, "invalid message or channel")
					continue
				handle(c, message)
			elif event[0] == ENetConnection.EVENT_DISCONNECT and not c.is_empty(): remove(c)
	for c in connections.duplicate():
		var now := Time.get_ticks_msec()
		if c.closing:
			if now - c.last > 1000:
				c.peer.reset()
				remove(c)
		elif c.identity.is_empty() and now - c.created > 5000: close(c, 4003, "handshake timeout")
		elif now - c.last > 15000: close(c, 4003, "idle timeout")
	for id: String in chat_last_accepted.keys():
		if ChatRules.remaining(chat_last_accepted[id], Time.get_ticks_msec()) == 0:
			chat_last_accepted.erase(id)
	flush_chat_events()
	var online: Array = []
	for c: Dictionary in players.values():
		var identity: Dictionary = c.identity
		online.append({"id":identity.id, "username":identity.username, "kind":identity.kind,
			"campus":c.campus, "joined_at":c.joined_at})
	data.report(delta, online)

func close(c: Dictionary, code: int, _reason: String) -> void:
	if c.closing: return
	c.closing = true
	c.last = Time.get_ticks_msec()
	c.peer.peer_disconnect(code)
	remove_player(c)

func remove_player(c: Dictionary) -> void:
	if not c.identity.is_empty() and players.get(c.identity.id) == c:
		players.erase(c.identity.id)
		roster_dirty = true
		if c.get("announced", false) and not c.get("replacing", false):
			queue_chat_event(c, "left")
	if is_instance_valid(c.body):
		c.body.queue_free()
	c.body = null

func remove(c: Dictionary) -> void:
	remove_player(c)
	connections.erase(c)

func connection_for(peer: ENetPacketPeer) -> Dictionary:
	for c in connections:
		if c.peer == peer: return c
	return {}

func send(c: Dictionary, value: Dictionary) -> void:
	if c.closing: return
	if c.peer.send(Protocol.CONTROL, JSON.stringify(value).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE) != OK:
		close(c, 4003, "send limit")

func handle(c: Dictionary, m: Dictionary) -> void:
	var kind: String = str(m.get("type", ""))
	if c.identity.is_empty():
		if kind != "hello" or c.authenticating or m.get("version") != Protocol.VERSION or not m.get("ticket") is String or not m.get("campus", "lingshui") in MAPS:
			close(c, 4002, "invalid hello or version")
			return
		c.authenticating = true
		authenticate(c, m)
		return
	match kind:
		"heartbeat":
			c.last = Time.get_ticks_msec()
			send(c, {"type":"heartbeat"})
		"chat_send": receive_chat(c, m)
		"input": receive_input(c, m)
		"change_map": change_map(c, m)
		"map_ready", "map_cancel", "map_status", "map_resume": transfer_message(c, m)
		_: close(c, 4002, "unknown message")

func authenticate(c: Dictionary, m: Dictionary) -> void:
	var result: Dictionary = await data.post("/api/v1/game/tickets/consume", {"ticket":m.ticket})
	if not connections.has(c) or c.closing: return
	if result.get("status") != 200:
		close(c, 4003, "admission unavailable")
		return
	var identity: Dictionary = result.body
	if identity.get("kind") != "account":
		close(c, 4003, "account required")
		return
	if not players.has(identity.id) and players.size() >= MAX_PLAYERS:
		close(c, 4004, "server full")
		return
	var replacing := players.has(identity.id)
	if replacing:
		players[identity.id].replacing = true
		close(players[identity.id], 4001, "session replaced")
	c.identity = identity
	c.joined_at = int(Time.get_unix_time_from_system())
	c.campus = m.get("campus", "lingshui")
	c.body = CharacterBody3D.new()
	Movement.setup(c.body)
	worlds[c.campus].add_child(c.body)
	c.body.position = worlds[c.campus].get_meta("spawn")
	players[identity.id] = c
	c.last = Time.get_ticks_msec()
	roster_dirty = true
	var welcome := state(c)
	welcome.merge({"type":"welcome", "version":Protocol.VERSION, "username":identity.username, "admission_id":identity.admission_id, "roster":roster(c.campus)})
	send(c, welcome)
	if not c.closing:
		c.announced = true
		if not replacing: queue_chat_event(c, "joined")
	elif replacing:
		# The replacement failed after retiring its predecessor: the identity is offline.
		queue_chat_event(c, "left")


func receive_chat(c: Dictionary, m: Dictionary) -> void:
	if players.get(c.identity.id) != c or not integer(m.get("request_id")): return
	var request := int(m.request_id)
	if request <= c.chat_request: return
	c.chat_request = request
	c.last = Time.get_ticks_msec()
	var body := ChatRules.text(m.get("text"))
	if m.size() != 3 or body.is_empty():
		send(c, {"type":"chat_result", "request_id":request, "error":"invalid_text", "retry_ms":0})
		return
	var retry := ChatRules.remaining(chat_last_accepted.get(c.identity.id, -ChatRules.INTERVAL_MS), c.last)
	if retry > 0:
		send(c, {"type":"chat_result", "request_id":request, "error":"rate_limited", "retry_ms":retry})
		return
	chat_last_accepted[c.identity.id] = c.last
	queue_chat_event(c, "message", body, request)

func queue_chat_event(c: Dictionary, kind: String, body := "", request := 0) -> void:
	chat_event_id += 1
	chat_events.append({"type":"chat_event", "event_id":chat_event_id, "kind":kind,
		"id":c.identity.id, "username":ChatRules.player_name(c.identity.username), "text":body, "request_id":request})

func flush_chat_events() -> void:
	# A failed send can enqueue a departure. Finish the current broadcast first
	# so every peer sees events in the same order, including slow-peer failures.
	while not chat_events.is_empty():
		var event: Dictionary = chat_events.pop_front()
		for c: Dictionary in players.values():
			if c.get("announced", false): send(c, event)

func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func integer(value: Variant) -> bool:
	return finite_number(value) and float(value) >= 0 and float(value) <= 9007199254740991.0 and floorf(float(value)) == float(value)

func receive_input(c: Dictionary, m: Dictionary) -> void:
	if not integer(m.get("seq")) or not integer(m.get("jump")) or not finite_number(m.get("yaw")) or absf(float(m.yaw)) > TAU or not m.get("run") is bool or not m.get("axis") is Array or m.axis.size() != 2 or not finite_number(m.axis[0]) or not finite_number(m.axis[1]) or m.has("position") or m.has("delta") or m.has("speed"):
		close(c, 4002, "invalid input")
		return
	if m.get("map_epoch") != c.epoch or m.seq <= c.seq or c.frozen: return
	c.seq = int(m.seq)
	c.axis = Vector2(clampf(float(m.axis[0]), -1.0, 1.0), clampf(float(m.axis[1]), -1.0, 1.0)).limit_length()
	c.run = m.run
	c.yaw = float(m.yaw)
	c.last_input = Time.get_ticks_msec()
	c.last = c.last_input
	# Consume the edge on the next physics tick, even when not grounded.
	if int(m.jump) > c.jump:
		c.jump_pending = true
		c.jump = int(m.jump)

func _physics_process(delta: float) -> void:
	var begin := Time.get_ticks_usec()
	tick += 1
	for c: Dictionary in players.values():
		if not c.transfer.is_empty() and c.transfer.status == "preparing" and Time.get_ticks_msec() - c.transfer.started > 180000:
			cancel_map(c)
		if not c.transfer.is_empty() and c.transfer.status == "committing":
			c.campus = c.transfer.target
			c.body.reparent(worlds[c.campus], false)
			c.body.position = worlds[c.campus].get_meta("spawn")
			finish_transfer(c, "entered")
		if c.frozen: continue
		c.body.rotation.y = c.yaw
		var axis: Vector2 = c.axis if Time.get_ticks_msec() - c.last_input <= 500 else Vector2.ZERO
		Movement.step(c.body, axis, c.run, c.get("jump_pending", false), delta, worlds[c.campus].get_meta("spawn"))
		c.jump_pending = false
	if tick % 6 == 0:
		for campus: String in MAPS:
			var states: Array = []
			for c: Dictionary in players.values():
				if c.campus == campus: states.append(state(c))
			var packets := Protocol.snapshots(campus, tick, states)
			for c: Dictionary in players.values():
				if c.campus != campus: continue
				if roster_dirty: send(c, {"type":"roster", "campus":campus, "server_tick":tick, "roster":roster(campus)})
				# No reliable retransmission or queued historical snapshots.
				for packet in packets: c.peer.send(Protocol.REALTIME, packet, 0)
		roster_dirty = false
	tick_samples.append(Time.get_ticks_usec() - begin)
	if tick_samples.size() >= 3600:
		tick_samples.sort()
		print("Game tick p95_us=", tick_samples[int(tick_samples.size() * 0.95)], " players=", players.size())
		tick_samples.clear()

func state(c: Dictionary) -> Dictionary:
	var p: Vector3 = c.body.position
	var v: Vector3 = c.body.velocity
	return {"id":c.identity.id, "campus":c.campus, "map_epoch":c.epoch, "position":[p.x,p.y,p.z],
		"velocity":[v.x,v.y,v.z], "yaw":c.body.rotation.y, "seq":c.seq, "jump":c.jump,
		"server_tick":tick, "transfer":c.transfer.get("result", {})}

func roster(campus: String) -> Array:
	var result: Array = []
	for c: Dictionary in players.values():
		if c.campus == campus: result.append({"id":c.identity.id, "username":c.identity.username})
	return result

func change_map(c: Dictionary, m: Dictionary) -> void:
	if not integer(m.get("request_id")): return
	var key := str(int(m.request_id))
	if c.results.has(key):
		send(c, c.results[key])
		return
	if m.request_id <= c.request_high:
		send(c, {"type":"map_error", "error":"old_request", "request_id":m.request_id})
		return
	if c.frozen:
		send(c, {"type":"map_error", "error":"busy", "request_id":m.request_id})
		return
	c.request_high = int(m.request_id)
	if not m.get("campus") in MAPS:
		send(c, {"type":"map_error", "error":"invalid_map", "request_id":m.request_id})
		return
	c.frozen = true
	c.axis = Vector2.ZERO
	c.body.velocity = Vector3.ZERO
	c.transfer = {"id":Crypto.new().generate_random_bytes(16).hex_encode(), "request_id":int(m.request_id),
		"target":m.campus, "started":Time.get_ticks_msec(), "status":"preparing"}
	var reply := {"type":"map_prepare", "transfer_id":c.transfer.id, "request_id":c.transfer.request_id, "campus":m.campus}
	remember(c, reply)

func remember(c: Dictionary, reply: Dictionary) -> void:
	c.transfer.result = reply
	c.results[str(c.transfer.request_id)] = reply
	while c.results.size() > 16: c.results.erase(c.results.keys()[0])
	send(c, reply)

func transfer_message(c: Dictionary, m: Dictionary) -> void:
	if c.transfer.is_empty() or m.get("transfer_id") != c.transfer.id: return
	c.last = Time.get_ticks_msec()
	match m.type:
		"map_ready":
			if c.transfer.status == "preparing":
				c.transfer.status = "committing"
			else: send(c, c.transfer.result)
		"map_cancel":
			if c.transfer.status == "preparing": cancel_map(c)
			else: send(c, c.transfer.result)
		"map_resume":
			if c.transfer.status == "cancelled": c.frozen = false
			send(c, c.transfer.result)
		"map_status": send(c, c.transfer.result)

func cancel_map(c: Dictionary) -> void:
	finish_transfer(c, "cancelled")

func finish_transfer(c: Dictionary, status: String) -> void:
	c.epoch += 1
	c.seq = -1
	c.jump = 0
	c.jump_pending = false
	c.axis = Vector2.ZERO
	c.body.velocity = Vector3.ZERO
	c.frozen = status == "cancelled"
	c.transfer.status = status
	roster_dirty = true
	var reply := state(c)
	reply.erase("transfer")
	reply.merge({"type":"map_" + status, "transfer_id":c.transfer.id, "request_id":c.transfer.request_id, "roster":roster(c.campus)})
	remember(c, reply)
