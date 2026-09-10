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
				c.peer.send(0, JSON.stringify({"type":"hello", "version":3, "ticket":c.ticket, "campus":"panjin"}).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE)
			elif event[0] == ENetConnection.EVENT_DISCONNECT:
				c.code = event[2]
			elif event[0] == ENetConnection.EVENT_RECEIVE:
				var packet: PackedByteArray = c.peer.get_packet()
				if event[3] == 1:
					var snapshot := Protocol.read_snapshot(packet)
					assert(not snapshot.is_empty() and packet.size() <= 832)
					c.snapshots += 1
					c.bytes += packet.size()
					c.last_snapshot = snapshot
				else:
					c.messages.append(JSON.parse_string(packet.get_string_from_utf8()))
	return false

func http(path: String, payload: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 5
	assert(request.request(base_url+path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)) == OK)
	var result: Array = await request.request_completed
	request.queue_free()
	assert(result[1] == 201)
	return JSON.parse_string(result[3].get_string_from_utf8())

func connect_client(id := "", ticket_override := "") -> Dictionary:
	id_counter += 1
	if id.is_empty(): id = "%032x" % (1000 + id_counter)
	var issued := await http("/api/v1/game/tickets", {"id":id, "version":3})
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
	var c := {"id":id, "ticket":issued.ticket if ticket_override.is_empty() else ticket_override, "host":host, "peer":peer, "messages":[], "code":0, "snapshots":0, "bytes":0, "last_snapshot":{}, "seq":0}
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

func wait_close(c: Dictionary, code: int) -> void:
	var deadline := Time.get_ticks_msec()+6000
	while c.code == 0 and Time.get_ticks_msec() < deadline: await process_frame
	assert(c.code == code, "wrong disconnect code: " + str(c.code))
	c.host.destroy()
	clients.erase(c)

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	base_url = OS.get_environment("DO_SERVER_URL")
	assert(not base_url.is_empty())
	var a := await connect_client()
	var welcome := await wait_message(a,"welcome")
	assert(welcome.version == 3)
	# A spent ticket cannot authenticate another peer.
	var replay := await connect_client("", a.ticket)
	await wait_close(replay,4003)
	send(a,{"type":"change_map","request_id":1,"campus":"eda"})
	var prepare := await wait_message(a,"map_prepare")
	send(a,{"type":"map_ready","transfer_id":prepare.transfer_id})
	var entered := await wait_message(a,"map_entered")
	assert(entered.map_epoch == 2 and entered.campus == "eda")
	send(a,{"type":"map_cancel","transfer_id":prepare.transfer_id})
	assert((await wait_message(a,"map_entered")).map_epoch == 2)
	# Old epoch input must not change the accepted sequence.
	send(a,{"type":"input","map_epoch":1,"seq":999,"axis":[1,0],"run":true,"yaw":0,"jump":0})
	await create_timer(0.3).timeout
	for state: Dictionary in a.last_snapshot.players:
		if state.id == a.id: assert(state.seq == -1)
	await create_timer(1).timeout
	var replacement := await connect_client(a.id)
	await wait_message(replacement,"welcome")
	await wait_close(a,4001)
	send(replacement,{"type":"input","map_epoch":1,"seq":1,"axis":[0,0],"run":false,"yaw":0,"jump":0,"position":[999,0,0]})
	await wait_close(replacement,4002)
	# The server remains bounded with 50 active peers; snapshots stay fresh.
	for i in 50:
		var c := await connect_client()
		await wait_message(c,"welcome")
	var extra := await connect_client()
	await wait_close(extra,4004)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 30000:
		for c in clients:
			c.seq += 1
			send(c,{"type":"input","map_epoch":1,"seq":c.seq,"axis":[sin(c.seq*0.05),cos(c.seq*0.05)],"run":true,"yaw":0,"jump":0})
		await create_timer(0.055).timeout
	var bytes := 0
	for c in clients:
		assert(c.snapshots > 100,"healthy peer lost snapshots")
		bytes += int(c.bytes)
		c.peer.peer_disconnect()
		c.host.flush()
		c.host.destroy()
	clients.clear()
	print("PASS: ENet tickets/replay, map epochs, late cancel, identity replacement, forged input, 50 players, full capacity; snapshot Mbps=", bytes*8.0/30/1000000)
	quit()
