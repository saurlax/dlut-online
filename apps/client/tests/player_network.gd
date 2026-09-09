extends SceneTree

const Network = preload("res://scripts/player_network.gd")
const Player = preload("res://scripts/player.gd")
var world: Node3D

func _initialize() -> void:
	_run.call_deferred()

func peer(id: String, campus: String) -> Node:
	var body := Player.new()
	body.guest_id = id
	world.add_child(body)
	body.set_physics_process(false)
	body.position = Vector3.ZERO
	var network := Network.new()
	world.add_child(network)
	network.configure(body, campus)
	network.start()
	return network

func _run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	world = Node3D.new()
	root.add_child(world)
	var a := peer("a".repeat(32), "lingshui")
	var b := peer("b".repeat(32), "lingshui")
	var c := peer("c".repeat(32), "panjin")
	await create_timer(1.0).timeout
	assert(a.welcomed and b.welcomed and c.welcomed)
	assert(a.remotes.size() == 1 and b.remotes.size() == 1 and c.remotes.is_empty())
	b.player.position = Vector3(3, 0, -5)
	b.player.rotation.y = 1.2
	await create_timer(0.8).timeout
	var remote: Node3D = a.remotes["b".repeat(32)]
	assert(remote.position.distance_to(b.player.position) < 0.1)
	assert(absf(remote.rotation.y - 1.2) < 0.05)
	b.socket.close()
	await create_timer(0.4).timeout
	assert(a.remotes.is_empty())
	await create_timer(2.0).timeout
	assert(b.welcomed and a.remotes.size() == 1)
	var replacement := peer("b".repeat(32), "panjin")
	await create_timer(0.8).timeout
	assert(not b.active and a.remotes.is_empty())
	assert(replacement.welcomed and c.remotes.size() == 1)
	print("PASS: two-way sync, interpolation, campus isolation, removal, reconnect, replacement")
	world.queue_free()
	await process_frame
	quit()
