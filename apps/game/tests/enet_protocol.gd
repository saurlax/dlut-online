extends SceneTree

const Protocol = preload("res://scripts/shared/game_protocol.gd")
var clients: Array[Dictionary] = []
var base_url := ""
var id_counter := 0

func _initialize() -> void: _run.call_deferred()

func _process(_delta: float) -> bool:
	for c in clients:
		for i in 512:
			var event: Array = c.host.service(0)
			if event[0] == ENetConnection.EVENT_NONE: break
			if event[0] == ENetConnection.EVENT_CONNECT:
				c.peer.send(0, JSON.stringify({"type":"hello", "version":Protocol.VERSION, "ticket":c.ticket, "campus":"panjin"}).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE)
			elif event[0] == ENetConnection.EVENT_DISCONNECT:
				c.code = event[2]
			elif event[0] == ENetConnection.EVENT_RECEIVE:
				var packet: PackedByteArray = c.peer.get_packet()
				if event[3] == 1:
					var snapshot := Protocol.read_snapshot(packet)
					assert(not snapshot.is_empty() and packet.size() <= 820)
					c.snapshots += 1
					c.last_snapshot = snapshot
				else:
					c.messages.append(JSON.parse_string(packet.get_string_from_utf8()))
	return false

func http(path: String, payload: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 5
	assert(request.request(base_url+path, ["Content-Type: application/json", "Authorization: Bearer " + OS.get_environment("DO_TEST_ACCOUNT_TOKEN_" + str(id_counter))], HTTPClient.METHOD_POST, JSON.stringify(payload)) == OK)
	var result: Array = await request.request_completed
	request.queue_free()
	assert(result[1] == 201)
	return JSON.parse_string(result[3].get_string_from_utf8())

func connect_client(account_index := 0) -> Dictionary:
	id_counter = account_index if account_index > 0 else id_counter + 1
	var id := OS.get_environment("DO_TEST_ACCOUNT_ID_" + str(id_counter))
	var issued := await http("/api/v1/game/tickets", {"id":id, "version":Protocol.VERSION})
	var destination := Protocol.endpoint(issued.game_server_url)
	var host := ENetConnection.new()
	assert(host.create_host(1,2) == OK)
	if destination.secure:
		var options := TLSOptions.client()
		var ca := OS.get_environment("DO_GAME_TLS_CA")
		if not ca.is_empty():
			var certificate := X509Certificate.new()
			assert(certificate.load(ca) == OK)
			options = TLSOptions.client(certificate)
		assert(host.dtls_client_setup(destination.host, options) == OK)
	var peer := host.connect_to_host(destination.host,destination.port,2)
	assert(peer != null)
	var c := {"id":id, "ticket":issued.ticket, "host":host, "peer":peer, "messages":[], "code":0, "snapshots":0, "last_snapshot":{}, "seq":0}
	clients.append(c)
	return c

func wait_message(c: Dictionary, kind: String) -> Dictionary:
	var deadline := Time.get_ticks_msec()+5000
	while Time.get_ticks_msec() < deadline:
		for m: Dictionary in c.messages:
			if m.get("type") == kind:
				c.messages.erase(m)
				return m
		await process_frame
	assert(false, "missing " + kind)
	return {}

func wait_chat(c: Dictionary, kind: String, id: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		for m: Dictionary in c.messages:
			if m.get("type") == "chat_event" and m.kind == kind and m.id == id:
				c.messages.erase(m)
				return m
		await process_frame
	assert(false, "missing chat " + kind)
	return {}

func send(c: Dictionary, value: Dictionary) -> void:
	var realtime: bool = value.get("type") == "input"
	assert(c.peer.send(1 if realtime else 0, JSON.stringify(value).to_utf8_buffer(), 0 if realtime else ENetPacketPeer.FLAG_RELIABLE) == OK)

func _run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	base_url = OS.get_environment("DO_API_SERVER_URL")
	assert(not base_url.is_empty())
	for i in 2:
		var c := await connect_client()
		var welcome := await wait_message(c,"welcome")
		assert(welcome.version == Protocol.VERSION)
		await wait_chat(c, "joined", c.id)
		send(c,{"type":"change_map","request_id":1,"campus":"eda"})
		var prepare := await wait_message(c,"map_prepare")
		send(c,{"type":"map_ready","transfer_id":prepare.transfer_id})
		var entered := await wait_message(c,"map_entered")
		assert(entered.map_epoch == 2 and entered.campus == "eda")
	var first: Dictionary = clients[0]
	var second: Dictionary = clients[1]
	await wait_chat(first, "joined", second.id)
	# Reliable chat reaches both campuses, including a client mid-transfer.
	send(second, {"type":"change_map", "request_id":2, "campus":"panjin"})
	var preparing := await wait_message(second, "map_prepare")
	send(first, {"type":"chat_send", "request_id":1, "text":"123123"})
	var echo := await wait_chat(first, "message", first.id)
	var received := await wait_chat(second, "message", first.id)
	assert(echo.event_id == received.event_id and received.text == "123123")
	send(first, {"type":"chat_send", "request_id":2, "text":"too soon"})
	var rejected := await wait_message(first, "chat_result")
	assert(rejected.error == "rate_limited" and rejected.retry_ms > 0)
	send(second, {"type":"map_ready", "transfer_id":preparing.transfer_id})
	await wait_message(second, "map_entered")
	await create_timer(1.05).timeout
	send(first, {"type":"chat_send", "request_id":3, "text":"世界 [color=red]白色[/color]"})
	echo = await wait_chat(first, "message", first.id)
	received = await wait_chat(second, "message", first.id)
	assert(received.text == "世界 [color=red]白色[/color]" and echo.event_id == received.event_id)
	send(first, {"type":"chat_send", "request_id":4, "text":"forged", "username":"Other"})
	assert((await wait_message(first, "chat_result")).error == "invalid_text")
	for c in clients:
		for m: Dictionary in c.messages:
			assert(m.get("type") != "chat_event", "No rejected chat or map-travel presence events")
	# Return the second client to the same map for the existing motion checks.
	send(second, {"type":"change_map", "request_id":3, "campus":"eda"})
	preparing = await wait_message(second, "map_prepare")
	send(second, {"type":"map_ready", "transfer_id":preparing.transfer_id})
	await wait_message(second, "map_entered")
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 2000:
		for c in clients:
			c.seq += 1
			send(c,{"type":"input","map_epoch":2 if c == first else 4,"seq":c.seq,"axis":[0,1],"run":false,"yaw":0,"jump":0})
		await create_timer(0.1).timeout
	for c in clients:
		assert(c.code == 0 and c.snapshots > 0,"client disconnected or received no snapshots")
		var confirmed := false
		for state: Dictionary in c.last_snapshot.players:
			if state.id == c.id and state.map_epoch == (2 if c == first else 4) and state.seq > 0:
				confirmed = true
		assert(confirmed,"snapshot did not confirm input in the destination campus")
	var replacement := await connect_client(1)
	await wait_message(replacement, "welcome")
	await create_timer(0.2).timeout
	assert(first.code == 4001)
	for m: Dictionary in second.messages:
		assert(m.get("type") != "chat_event", "Replacement must not report departure or arrival")
	replacement.peer.peer_disconnect()
	replacement.host.flush()
	await wait_chat(second, "left", first.id)
	await create_timer(0.2).timeout
	for m: Dictionary in second.messages:
		assert(m.get("type") != "chat_event", "Departure is emitted only once")
	# Failed admission never appears as an online player.
	var denied := second.duplicate(true)
	denied.host = ENetConnection.new()
	assert(denied.host.create_host(1, 2) == OK)
	denied.peer = denied.host.connect_to_host(second.peer.get_remote_address(), second.peer.get_remote_port(), 2)
	denied.ticket = "invalid-ticket"
	denied.messages = []
	denied.code = 0
	clients.append(denied)
	var deadline := Time.get_ticks_msec() + 5000
	while denied.code == 0 and Time.get_ticks_msec() < deadline: await process_frame
	assert(denied.code == 4003)
	for m: Dictionary in second.messages:
		assert(m.get("type") != "chat_event", "Failed admission has no presence events")
	await create_timer(1.05).timeout
	var idle := await connect_client(1)
	await wait_message(idle, "welcome")
	await wait_chat(idle, "joined", idle.id)
	await wait_chat(second, "joined", idle.id)
	deadline = Time.get_ticks_msec() + 18000
	var departed := false
	while Time.get_ticks_msec() < deadline:
		send(second, {"type":"heartbeat"})
		for m: Dictionary in second.messages:
			if m.get("type") == "chat_event" and m.kind == "left" and m.id == idle.id:
				second.messages.erase(m)
				departed = true
				break
		if departed: break
		await create_timer(0.5).timeout
	assert(departed, "Idle timeout broadcasts departure to remaining players")
	for c in clients:
		c.host.destroy()
	clients.clear()
	print("PASS: ENet smoke, two clients, tickets, map travel, input acknowledgement, snapshots, world chat, rate limit and presence")
	quit()
