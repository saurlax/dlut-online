extends SceneTree

const Session = preload("res://scripts/client/guest_session.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(Session.prepare())
	var id: String = Session.guest_id
	var username: String = Session.username
	assert(Session.valid_id(id))
	assert(not Session.valid_id("invalid"))
	assert(not Session.valid_id("G".repeat(15)))
	assert(username.begins_with("游客") and username.length() == 8)
	assert(Session.prepare() and Session.guest_id == id)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	current_scene.hud.enter_campus()
	assert(current_scene.player.guest_id == id)
	assert(current_scene.player.username == username)
	current_scene.hud.pause_exploration()
	current_scene.hud.enter_campus()
	assert(current_scene.player.guest_id == id)
	change_scene_to_file("res://scenes/campuses/panjin.tscn")
	await process_frame
	await process_frame
	assert(current_scene.player.guest_id == id)
	assert(current_scene.player.username == username)
	assert(not current_scene.hud.overlay.visible)
	print("PASS: guest ID, nickname, resume and campus identity")
	quit()
