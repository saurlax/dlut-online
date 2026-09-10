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
				c.peer.send(0, JSON.stringify({"type":"hello", "version":4, "ticket":c.ticket, "campus":"panjin"}).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE)
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

func connect_client() -> Dictionary:
	id_counter += 1
	var id := OS.get_environment("DO_TEST_ACCOUNT_ID_" + str(id_counter))
	var issued := await http("/api/v1/game/tickets", {"id":id, "version":4})
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
		assert(welcome.version == 4)
		send(c,{"type":"change_map","request_id":1,"campus":"eda"})
		var prepare := await wait_message(c,"map_prepare")
		send(c,{"type":"map_ready","transfer_id":prepare.transfer_id})
		var entered := await wait_message(c,"map_entered")
		assert(entered.map_epoch == 2 and entered.campus == "eda")
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 2000:
		for c in clients:
			c.seq += 1
			send(c,{"type":"input","map_epoch":2,"seq":c.seq,"axis":[0,1],"run":false,"yaw":0,"jump":0})
		await create_timer(0.1).timeout
	for c in clients:
		assert(c.code == 0 and c.snapshots > 0,"client disconnected or received no snapshots")
		var confirmed := false
		for state: Dictionary in c.last_snapshot.players:
			if state.id == c.id and state.map_epoch == 2 and state.seq > 0:
				confirmed = true
		assert(confirmed,"snapshot did not confirm input in the destination campus")
		c.peer.peer_disconnect()
		c.host.flush()
		c.host.destroy()
	clients.clear()
	print("PASS: ENet smoke, two clients, tickets, map travel, input acknowledgement and snapshots")
	quit()
