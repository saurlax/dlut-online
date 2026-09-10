extends SceneTree
const Protocol = preload("res://scripts/shared/game_protocol.gd")
const Guest = preload("res://scripts/client/guest_session.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	assert(Guest.prepare())
	var states: Array = []
	for i in 50:
		states.append({"id":Guest.guest_id if i == 0 else ("%015x" % i).to_upper(), "position":[float(i),0.0,0.0], "velocity":[0.0,0.0,0.0], "yaw":0.25, "seq":-1, "jump":0, "map_epoch":1})
	var packets := Protocol.snapshots("lingshui",10,states)
	assert(packets.size() == 5)
	var decoded: Array = []
	for packet in packets:
		assert(packet.size() <= 820)
		var part := Protocol.read_snapshot(packet)
		decoded.append_array(part.players)
		assert(Protocol.read_snapshot(packet.slice(0,packet.size()-1)).is_empty())
	assert(decoded.size() == 50 and decoded[0].id == Guest.guest_id and decoded[49].position[0] == 49)
	assert(decoded[0].seq == -1 and decoded[0].yaw == 0.25)
	var network := root.get_node("GameNetwork")
	network.welcomed = true
	# An incomplete tick cannot remove players or advance the accepted state.
	for i in 4: network.receive_snapshot(packets[i])
	assert(network.applied_tick == -1)
	network.receive_snapshot(packets[4])
	assert(network.applied_tick == 10)
	for packet in Protocol.snapshots("lingshui",9,states): network.receive_snapshot(packet)
	assert(network.applied_tick == 10)
	for state: Dictionary in states: state.map_epoch = 2
	for packet in Protocol.snapshots("lingshui",11,states): network.receive_snapshot(packet)
	assert(network.applied_tick == 10,"A future/old map epoch must not mutate current state")
	print("PASS: bounded binary snapshots, loss/incomplete ticks, stale ticks and map epoch isolation")
	quit()
