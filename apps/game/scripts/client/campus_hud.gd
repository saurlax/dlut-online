extends CanvasLayer

@export var login_only := false
var loading_campus := false

const Account = preload("res://scripts/client/account_session.gd")
var account_login: Node
var cancel_login: Button
var identity_label: Label
var email_input: LineEdit
var password_input: LineEdit
var network: Node

const Catalog = preload("res://scripts/shared/campus_catalog.gd")
const MapView = preload("res://scripts/client/campus_map.gd")
var campus: Node3D
var minimap: Control
var map_overlay: ColorRect
var map_was_playing := false
var switching := false
var player: CharacterBody3D
var overlay: ColorRect
var crosshair: Control
var enter_button: Button
var has_entered := false
var capture_pending := false
var capture_elapsed := 0.0
var transfer_panel: VBoxContainer
var transfer_status: Label
var transfer_target := ""
var root_control: Control
var player_status: HBoxContainer
var username_label: Label
var latency_label: Label
const WorldChat = preload("res://scripts/client/world_chat.gd")
var chat: Control
var chat_was_playing := false
var chat_was_drag_look := false
var chat_mouse_mode := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if login_only:
		Engine.max_fps = 60
		build(null, null)

func build(body: CharacterBody3D, world: Node3D) -> void:
	player = body
	campus = world
	root_control = Control.new()
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/CampusSans.ttf")
	theme.default_font_size = 15
	root_control.theme = theme
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	for size in [Vector2(10,2),Vector2(2,10)]:
		var line := ColorRect.new()
		line.color = Color(1,1,1,0.7)
		line.size = size
		line.position = -size/2
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(line)
	crosshair.hide()
	overlay = ColorRect.new()
	overlay.color = Color("111b20")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 320
	column.add_theme_constant_override("separation",20)
	center.add_child(column)
	var cover_title := Label.new()
	cover_title.text = "DLUT Online"
	cover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_title.add_theme_font_size_override("font_size",48)
	column.add_child(cover_title)
	identity_label = Label.new()
	identity_label.name = "AccountIdentity"
	identity_label.custom_minimum_size.x = 360
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(identity_label)
	identity_label.text = "使用 DLUT Online 账号登录"
	email_input = LineEdit.new()
	email_input.name = "LoginEmail"
	email_input.placeholder_text = "邮箱"
	email_input.custom_minimum_size.y = 48
	email_input.max_length = 254
	column.add_child(email_input)
	password_input = LineEdit.new()
	password_input.name = "LoginPassword"
	password_input.placeholder_text = "密码"
	password_input.secret = true
	password_input.secret_character = "*"
	password_input.custom_minimum_size.y = 48
	column.add_child(password_input)
	email_input.text_submitted.connect(func(_value: String): password_input.grab_focus())
	password_input.text_submitted.connect(func(_value: String): _begin_login())
	enter_button = Button.new()
	enter_button.name = "EnterCampus"
	enter_button.text = "登录"
	enter_button.custom_minimum_size.y = 52
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d3e1bb")
	style.set_corner_radius_all(5)
	enter_button.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("e7efd8")
	enter_button.add_theme_stylebox_override("hover",hover)
	enter_button.add_theme_stylebox_override("pressed",style)
	enter_button.add_theme_color_override("font_color",Color("243d30"))
	enter_button.add_theme_color_override("font_hover_color",Color("243d30"))
	enter_button.add_theme_color_override("font_pressed_color",Color("243d30"))
	enter_button.pressed.connect(_begin_login)
	column.add_child(enter_button)
	account_login = Account.new()
	add_child(account_login)
	account_login.status_changed.connect(_login_status)
	account_login.authenticated.connect(_account_authenticated)
	cancel_login = Button.new()
	cancel_login.text = "取消登录"
	cancel_login.flat = true
	cancel_login.hide()
	cancel_login.pressed.connect(func():
		account_login.cancel()
		_login_status("已取消，可重新登录")
	)
	column.add_child(cancel_login)
	var register_link := LinkButton.new()
	register_link.text = "没有账号？先去 dlut.online 注册"
	register_link.uri = "https://dlut.online/register"
	column.add_child(register_link)
	network = get_node("/root/GameNetwork")
	if login_only:
		if Account.restore_attempted and network.status_text != "未连接":
			identity_label.text = network.status_text
		account_login.restore.call_deferred()
		return
	network.configure(player, campus.campus_id)
	network.status_changed.connect(_network_status)
	network.connected.connect(_network_connected)
	network.login_required.connect(_show_login)
	network.map_prepared.connect(_network_map_prepared)
	network.map_failed.connect(_network_map_failed)
	network.map_finished.connect(_network_map_finished)
	build_map()
	build_player_status()
	chat = WorldChat.new()
	root_control.add_child(chat)
	chat.configure(network)
	chat.editing_finished.connect(_chat_finished)
	minimap.visible = Catalog.started
	if Catalog.started or Catalog.arriving:
		Catalog.arriving = false
		enter_campus()
	elif not Account.token.is_empty():
		_account_authenticated.call_deferred()
	else:
		account_login.restore.call_deferred()

func _begin_login() -> void:
	if enter_button.disabled: return
	if not Account.token.is_empty():
		_account_authenticated()
	else:
		var password := password_input.text
		password_input.clear()
		account_login.begin(email_input.text, password)

func _login_status(value: String) -> void:
	if loading_campus: return
	identity_label.text = value
	enter_button.disabled = account_login.waiting
	cancel_login.visible = account_login.waiting
	email_input.editable = not account_login.waiting
	password_input.editable = not account_login.waiting

func _account_authenticated() -> void:
	if loading_campus or Account.token.is_empty(): return
	password_input.clear()
	email_input.editable = false
	password_input.editable = false
	cancel_login.hide()
	enter_button.disabled = true
	if login_only:
		_load_initial_campus()
		return
	player.player_id = Account.player_id
	player.username = Account.username
	network.start()

func _load_initial_campus() -> void:
	loading_campus = true
	identity_label.text = "加载中"
	var path: String = Catalog.CAMPUSES.lingshui.scene
	if ResourceLoader.load_threaded_request(path) == OK:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		# Consume failed requests too, so retry can start a fresh load.
		var scene: PackedScene = ResourceLoader.load_threaded_get(path)
		if scene != null:
			if get_tree().change_scene_to_packed(scene) == OK:
				return
	loading_campus = false
	identity_label.text = "加载失败，请重试"
	enter_button.disabled = false

func _network_status(value: String) -> void:
	if not Catalog.started:
		identity_label.text = value
		enter_button.disabled = network.active

func _network_connected() -> void:
	# A reconnect must not resume a paused or unfocused player.
	if Catalog.started: return
	enter_campus()
	if DisplayServer.get_name() != "headless" and not DisplayServer.window_is_focused():
		pause_exploration()

func _show_login() -> void:
	switching = false
	transfer_panel.hide()
	pause_exploration()
	minimap.hide()
	enter_button.disabled = false
	cancel_login.hide()
	identity_label.text = network.status_text
	email_input.editable = true
	password_input.editable = true
	password_input.clear()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")

func enter_campus() -> void:
	if Account.token.is_empty() or not network.welcomed: return
	player.player_id = Account.player_id
	player.username = Account.username
	Catalog.started = true
	has_entered = true
	overlay.hide()
	minimap.show()
	crosshair.show()
	map_overlay.hide()
	player.playing = true
	player.drag_look = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	capture_pending = true
	capture_elapsed = 0
	enter_button.release_focus()

func pause_exploration() -> void:
	capture_pending = false
	if is_instance_valid(map_overlay):
		map_overlay.hide()
	player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.hide()
	overlay.visible = not Catalog.started

func _input(event: InputEvent) -> void:
	if not Catalog.started:
		return
	if is_instance_valid(chat) and chat.editing:
		if event is InputEventKey:
			chat.observe_key(event)
			if event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_cancel"):
				chat.finish()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _chat_available():
		chat_was_playing = player.playing or capture_pending
		chat_was_drag_look = player.drag_look
		chat_mouse_mode = Input.mouse_mode
		capture_pending = false
		player.stop()
		crosshair.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		chat.begin()
		get_viewport().set_input_as_handled()
		return
	if switching:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M):
			cancel_transfer()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if map_overlay.visible:
			close_map()
		elif not player.playing and not capture_pending:
			enter_campus()
		else:
			pause_exploration()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		chat_was_playing = false
		if switching:
			map_was_playing = false
			player.stop()
		else:
			pause_exploration()

func _process(delta: float) -> void:
	_update_player_status_visibility()
	if is_instance_valid(chat):
		chat.visible = _chat_visible()
		if chat.editing and not _chat_available():
			chat_was_playing = false
			chat.finish()
	if not is_instance_valid(player):
		return
	if switching: return
	if capture_pending:
		capture_elapsed += delta
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			capture_pending = false
			player.drag_look = false
			has_entered = true
			player.playing = true
			overlay.hide()
			crosshair.show()
		elif capture_elapsed > 1.5:
			capture_pending = false
			has_entered = true
			player.drag_look = true
			player.playing = true
			overlay.hide()
			crosshair.show()
	elif player.playing and not player.drag_look and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		pause_exploration()

func build_player_status() -> void:
	player_status = HBoxContainer.new()
	player_status.name = "PlayerStatus"
	player_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(player_status)
	player_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	player_status.offset_left = -256
	player_status.offset_right = -16
	player_status.offset_top = 0
	player_status.offset_bottom = 0
	player_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	player_status.add_theme_constant_override("separation", 8)
	username_label = Label.new()
	username_label.name = "Username"
	username_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	username_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	latency_label = Label.new()
	latency_label.name = "Latency"
	for label in [username_label, latency_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_color", Color("eef2f5"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
		player_status.add_child(label)
	network.connection_quality_changed.connect(_connection_quality_changed)
	overlay.visibility_changed.connect(_update_player_status_visibility)
	map_overlay.visibility_changed.connect(_update_player_status_visibility)
	_connection_quality_changed(network.connection_state, network.round_trip_time_ms)

func _connection_quality_changed(state: String, rtt_ms: int) -> void:
	username_label.text = Account.account_username if not Account.account_username.strip_edges().is_empty() else "用户名不可用"
	var color := Color("cbd5df")
	match state:
		"connected":
			latency_label.text = "%d ms" % rtt_ms
			color = Color("7ee2a8") if rtt_ms < 100 else (Color("f4d477") if rtt_ms < 200 else Color("ff8585"))
		"measuring": latency_label.text = "测量中"
		_:
			latency_label.text = {"stale":"连接异常", "reconnecting":"正在重连"}.get(state, "连接已断开")
			color = Color("ff8585")
	latency_label.add_theme_color_override("font_color", color)
	_update_player_status_visibility()

func _update_player_status_visibility() -> void:
	if not is_instance_valid(player_status): return
	player_status.visible = Catalog.started and not Account.token.is_empty() and not overlay.visible and not map_overlay.visible and not switching and network.transfer_phase.is_empty()

func build_map() -> void:
	minimap = MapView.new()
	minimap.name = "Minimap"
	root_control.add_child(minimap)
	minimap.position = Vector2(20,20)
	minimap.size = Vector2(148,148)
	minimap.configure(campus,true)
	minimap.pressed.connect(toggle_map)
	map_overlay = ColorRect.new()
	map_overlay.name = "CampusSelection"
	map_overlay.color = Color(0.025,0.04,0.035,0.94)
	root_control.add_child(map_overlay)
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var map := MapView.new()
	map.name = "FullCampusMap"
	map_overlay.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.configure(campus,false)
	var campuses := VBoxContainer.new()
	campuses.name = "CampusList"
	map_overlay.add_child(campuses)
	campuses.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	campuses.offset_left = -228
	campuses.offset_right = -28
	campuses.offset_top = 28
	campuses.add_theme_constant_override("separation",10)
	for id in Catalog.CAMPUSES:
		var button := Button.new()
		button.name = "Travel_"+id
		button.text = Catalog.CAMPUSES[id].title
		button.custom_minimum_size = Vector2(200,48)
		button.disabled = id == campus.campus_id
		button.pressed.connect(teleport.bind(id))
		campuses.add_child(button)
	var connection_status := Label.new()
	connection_status.name = "ConnectionStatus"
	map_overlay.add_child(connection_status)
	connection_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	connection_status.offset_left = 24
	connection_status.offset_right = 440
	connection_status.offset_top = -44
	connection_status.offset_bottom = -20
	connection_status.text = network.status_text
	network.status_changed.connect(_connection_status_changed)
	var logout_button := Button.new()
	logout_button.text = "退出登录"
	logout_button.flat = true
	map_overlay.add_child(logout_button)
	logout_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	logout_button.offset_left = -140
	logout_button.offset_right = -24
	logout_button.offset_top = -52
	logout_button.offset_bottom = -16
	logout_button.pressed.connect(func(): network.require_login("已退出，请重新登录"))
	transfer_panel = VBoxContainer.new()
	transfer_panel.name = "CampusTransfer"
	map_overlay.add_child(transfer_panel)
	transfer_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	transfer_panel.offset_left = -180
	transfer_panel.offset_right = 180
	transfer_panel.offset_top = -160
	transfer_panel.offset_bottom = -24
	transfer_panel.add_theme_constant_override("separation", 8)
	transfer_status = Label.new()
	transfer_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transfer_panel.add_child(transfer_status)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(cancel_transfer)
	transfer_panel.add_child(cancel_button)
	transfer_panel.hide()
	map_overlay.hide()

func toggle_map() -> void:
	if is_instance_valid(chat) and chat.editing: return
	if switching:
		cancel_transfer()
		return
	if map_overlay.visible:
		close_map()
		return
	map_was_playing = player.playing or capture_pending
	capture_pending = false
	player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.hide()
	crosshair.hide()
	map_overlay.show()

func close_map() -> void:
	map_overlay.hide()
	if map_was_playing:
		enter_campus()
	elif Catalog.started:
		crosshair.hide()

func teleport(id: String) -> void:
	if switching or not Catalog.CAMPUSES.has(id) or id == campus.campus_id:
		return
	if not map_overlay.visible:
		map_was_playing = player.playing or capture_pending
	switching = true
	transfer_target = id
	player.stop()
	capture_pending = false
	if not network.request_map(id, true):
		_network_map_failed()
		return
	map_overlay.show()
	overlay.hide()
	crosshair.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	transfer_panel.show()
	transfer_status.text = "加载中"

func _network_map_prepared(id: String) -> void:
	if not switching or transfer_target != id: return
	network.load_target(id)

func cancel_transfer() -> void:
	network.cancel_map()
	switching = false
	transfer_panel.hide()
	transfer_target = ""
	close_map()

func _network_map_failed() -> void:
	switching = false
	transfer_panel.hide()
	transfer_target = ""

func _network_map_finished() -> void:
	_network_map_failed()
	if network.restore_playing:
		enter_campus()
	else:
		pause_exploration()

func _exit_tree() -> void:
	if is_instance_valid(network) and network.player == player:
		network.player = null


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(chat) and chat.editing: return
	if Catalog.started and not switching and not player.playing and not map_overlay.visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			enter_campus()
			get_viewport().set_input_as_handled()

func _connection_status_changed(value: String) -> void:
	var label: Label = map_overlay.get_node("ConnectionStatus")
	label.text = value

func _chat_visible() -> bool:
	return Catalog.started and not Account.token.is_empty() and not overlay.visible and not map_overlay.visible and not switching and network.transfer_phase.is_empty()

func _chat_available() -> bool:
	return _chat_visible() and network.welcomed

func _chat_finished(resume: bool) -> void:
	if resume and chat_was_playing and _chat_available() and (DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()):
		player.playing = true
		player.drag_look = chat_was_drag_look
		Input.mouse_mode = chat_mouse_mode
		crosshair.show()
	else:
		player.stop()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		crosshair.hide()
