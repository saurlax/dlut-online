extends CanvasLayer

@export var login_only := false
var loading_campus := false
const Graphics = preload("res://scripts/client/graphics_settings.gd")
const GraphicsPanel = preload("res://scripts/client/graphics_panel.gd")
var settings_panel: ColorRect
var settings_button: Button

const MenuScene = preload("res://scenes/ui/login_menu.tscn")
const MenuTheme = preload("res://assets/ui/campus_theme.tres")

const LocalSession = preload("res://scripts/client/local_session.gd")
var multiplayer_requested := false
var local_load_generation := 0
var singleplayer_button: Button
var multiplayer_button: Button
var menu_status: Label

const Account = preload("res://scripts/client/account_session.gd")
var account_login: Node
var cancel_login: Button
var identity_label: Label
var email_input: LineEdit
var password_input: LineEdit
var register_link: LinkButton
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
		build(null, null)

func build(body: CharacterBody3D, world: Node3D) -> void:
	player = body
	campus = world
	root_control = get_node_or_null("Interface")
	if root_control == null:
		root_control = Control.new()
		root_control.name = "Interface"
		add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = MenuTheme
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
	overlay = root_control.get_node_or_null("Menu")
	if overlay == null:
		overlay = MenuScene.instantiate()
		overlay.background_enabled = login_only
		root_control.add_child(overlay)
	overlay.show_account_page(true)
	singleplayer_button = overlay.get_node("Composition/Modes/Singleplayer")
	multiplayer_button = overlay.get_node("Composition/Modes/Multiplayer")
	menu_status = overlay.get_node("Composition/Modes/Status")
	singleplayer_button.pressed.connect(_begin_singleplayer)
	multiplayer_button.pressed.connect(_begin_multiplayer)
	var fields: VBoxContainer = overlay.get_node("Composition/Form/Fields")
	identity_label = fields.get_node("AccountIdentity")
	email_input = fields.get_node("LoginEmail")
	password_input = fields.get_node("LoginPassword")
	enter_button = fields.get_node("EnterCampus")
	cancel_login = fields.get_node("CancelLogin")
	register_link = fields.get_node("Register")
	email_input.text_submitted.connect(func(_value: String): password_input.grab_focus())
	password_input.text_submitted.connect(func(_value: String): _begin_login())
	enter_button.pressed.connect(_begin_login)
	account_login = Account.new()
	add_child(account_login)
	account_login.status_changed.connect(_login_status)
	account_login.authenticated.connect(_account_authenticated)
	cancel_login.pressed.connect(_cancel_login)
	network = get_node("/root/GameNetwork")
	network.menu_required.connect(_show_login)
	_build_settings()
	Graphics.apply_all(get_tree())
	if login_only:
		if network.status_text != "未连接": menu_status.text = network.status_text
		return
	if player.touch_enabled:
		var touch := preload("res://scripts/client/touch_controls.gd").new()
		touch.player = player
		root_control.add_child(touch)
		touch.pause_requested.connect(pause_exploration)
	if LocalSession.enabled:
		build_map()
		Catalog.entry_requested = false
		Catalog.arriving = false
		enter_campus()
		if DisplayServer.get_name() != "headless" and not DisplayServer.window_is_focused():
			pause_exploration()
		return
	network.configure(player, campus.campus_id)
	network.status_changed.connect(_network_status)
	network.connected.connect(_network_connected)
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
		_account_authenticated()
		if Catalog.entry_requested:
			Catalog.entry_requested = false
			_begin_login.call_deferred()
	else:
		account_login.restore.call_deferred()

func _begin_singleplayer() -> void:
	if loading_campus: return
	_cancel_login()
	LocalSession.enabled = true
	_load_initial_campus()

func _begin_multiplayer() -> void:
	if loading_campus or multiplayer_requested: return
	LocalSession.enabled = false
	multiplayer_requested = true
	if not Account.token.is_empty():
		_load_initial_campus()
		return
	overlay.show_account_page(false)
	cancel_login.show()
	await account_login.restore()
	if multiplayer_requested and not loading_campus and Account.token.is_empty():
		email_input.grab_focus()

func _cancel_login() -> void:
	account_login.cancel()
	multiplayer_requested = false
	password_input.clear()
	enter_button.disabled = false
	email_input.editable = true
	password_input.editable = true
	overlay.show_account_page(true)

func _begin_login() -> void:
	if enter_button.disabled or loading_campus: return
	if not Account.token.is_empty():
		enter_button.disabled = true
		if login_only:
			_load_initial_campus()
		else:
			player.player_id = Account.player_id
			player.username = Account.username
			network.start()
	else:
		var password := password_input.text
		password_input.clear()
		account_login.begin(email_input.text, password)

func _login_status(value: String) -> void:
	if loading_campus: return
	identity_label.text = value
	enter_button.disabled = account_login.waiting
	cancel_login.show()
	email_input.editable = not account_login.waiting
	password_input.editable = not account_login.waiting

func _account_authenticated() -> void:
	if loading_campus or Account.token.is_empty(): return
	password_input.clear()
	enter_button.disabled = false
	if login_only:
		if multiplayer_requested: _load_initial_campus()
	else:
		overlay.show_account_page(true)

func _load_initial_campus() -> void:
	loading_campus = true
	overlay.show_account_page(true)
	singleplayer_button.disabled = true
	multiplayer_button.disabled = true
	enter_button.disabled = true
	menu_status.text = "加载中"
	Catalog.entry_requested = true
	var generation: int = network.connection_generation
	identity_label.show()
	identity_label.text = "加载中"
	var path: String = Catalog.CAMPUSES.lingshui.scene
	if ResourceLoader.load_threaded_request(path) == OK:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			if generation != network.connection_generation or not Catalog.entry_requested: return
		# Consume failed requests too, so retry can start a fresh load.
		var scene: PackedScene = ResourceLoader.load_threaded_get(path)
		if generation != network.connection_generation or not Catalog.entry_requested: return
		if scene != null:
			if get_tree().change_scene_to_packed(scene) == OK:
				return
	loading_campus = false
	Catalog.entry_requested = false
	menu_status.text = "加载失败，请重试"
	multiplayer_requested = false
	singleplayer_button.disabled = false
	multiplayer_button.disabled = false
	enter_button.disabled = false

func _network_status(value: String) -> void:
	if not Catalog.started:
		identity_label.show()
		identity_label.text = value
		menu_status.text = value
		singleplayer_button.disabled = true
		multiplayer_button.disabled = true
		enter_button.disabled = network.active

func _network_connected() -> void:
	# A reconnect must not resume a paused or unfocused player.
	if Catalog.started: return
	enter_campus()
	if DisplayServer.get_name() != "headless" and not DisplayServer.window_is_focused():
		pause_exploration()

func _show_login() -> void:
	if login_only:
		loading_campus = false
		_cancel_login()
		singleplayer_button.disabled = false
		multiplayer_button.disabled = false
		menu_status.text = network.status_text
		return
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
	if LocalSession.enabled:
		player.network_ready = true
	else:
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.touch_enabled else Input.MOUSE_MODE_CAPTURED
	capture_pending = not player.touch_enabled
	capture_elapsed = 0
	get_viewport().gui_release_focus()

func pause_exploration() -> void:
	capture_pending = false
	if is_instance_valid(map_overlay):
		map_overlay.hide()
	player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.hide()
	overlay.visible = not Catalog.started

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo and event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if _settings_open():
		if event.is_action_pressed("ui_cancel"):
			settings_panel.dismiss()
			get_viewport().set_input_as_handled()
		return
	if login_only and overlay.get_node("Composition/Form").visible and event.is_action_pressed("ui_cancel"):
		_cancel_login()
		get_viewport().set_input_as_handled()
		return
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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings_open():
			settings_panel.dismiss()
			return
		if login_only:
			_cancel_login()
		elif switching:
			cancel_transfer()
		elif map_overlay.visible:
			close_map()
		elif player.playing:
			pause_exploration()
		else:
			enter_campus()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(player):
		chat_was_playing = false
		if switching:
			map_was_playing = false
			player.stop()
		else:
			pause_exploration()

func _process(delta: float) -> void:
	if is_instance_valid(settings_button):
		settings_button.visible = _settings_available() and not _settings_open()
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
	elif not player.touch_enabled and player.playing and not player.drag_look and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
	player_status.visible = Catalog.started and not Account.token.is_empty() and not overlay.visible and not map_overlay.visible and not _settings_open() and not switching and network.transfer_phase.is_empty()

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
	connection_status.visible = not LocalSession.enabled
	connection_status.text = network.status_text
	network.status_changed.connect(_connection_status_changed)
	var logout_button := Button.new()
	logout_button.text = "返回首页" if LocalSession.enabled else "退出登录"
	logout_button.flat = true
	map_overlay.add_child(logout_button)
	logout_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	logout_button.offset_left = -140
	logout_button.offset_right = -24
	logout_button.offset_top = -52
	logout_button.offset_bottom = -16
	logout_button.pressed.connect(_leave_mode)
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
	if LocalSession.enabled: _build_local_environment()
	map_overlay.hide()
	root_control.move_child(settings_panel, -1)

func toggle_map() -> void:
	if _settings_open(): return
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
	if LocalSession.enabled:
		_load_local_campus(id)
		return
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
	local_load_generation += 1
	if not LocalSession.enabled: network.cancel_map()
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
	if _settings_open(): return
	if is_instance_valid(chat) and chat.editing: return
	if Catalog.started and not switching and not player.playing and not map_overlay.visible:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			enter_campus()
			get_viewport().set_input_as_handled()

func _connection_status_changed(value: String) -> void:
	var label: Label = map_overlay.get_node("ConnectionStatus")
	label.text = value

func _chat_visible() -> bool:
	return Catalog.started and not Account.token.is_empty() and not overlay.visible and not map_overlay.visible and not _settings_open() and not switching and network.transfer_phase.is_empty()

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

func _leave_mode() -> void:
	if not LocalSession.enabled:
		network.require_login("已退出，请重新登录")
		return
	local_load_generation += 1
	player.stop()
	Catalog.started = false
	Catalog.arriving = false
	Catalog.entry_requested = false
	LocalSession.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")

func _load_local_campus(id: String) -> void:
	local_load_generation += 1
	var generation := local_load_generation
	map_overlay.show()
	crosshair.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	transfer_panel.show()
	transfer_status.text = "加载中"
	var path: String = Catalog.CAMPUSES[id].scene
	if ResourceLoader.load_threaded_request(path) == OK:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var scene: PackedScene = ResourceLoader.load_threaded_get(path)
		if generation != local_load_generation: return
		if scene != null and get_tree().change_scene_to_packed(scene) == OK: return
	if generation != local_load_generation: return
	switching = false
	transfer_status.text = "加载失败，请重试"

func _build_local_environment() -> void:
	var panel := PanelContainer.new()
	panel.name = "LocalEnvironment"
	map_overlay.add_child(panel)
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size.x = 264
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.065, 0.96)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 12)
	panel.add_child(fields)
	var time_label := Label.new()
	time_label.text = "时间 %02d:%02d" % [LocalSession.minutes / 60, LocalSession.minutes % 60]
	fields.add_child(time_label)
	var time_slider := HSlider.new()
	time_slider.name = "Time"
	time_slider.max_value = 1439
	time_slider.step = 1
	time_slider.value = LocalSession.minutes
	time_slider.custom_minimum_size = Vector2(240, 32)
	fields.add_child(time_slider)
	time_slider.value_changed.connect(func(value: float):
		LocalSession.minutes = int(value)
		LocalSession.revision += 1
		time_label.text = "时间 %02d:%02d" % [LocalSession.minutes / 60, LocalSession.minutes % 60]
	)
	var weather_label := Label.new()
	weather_label.text = "天气"
	fields.add_child(weather_label)
	var weather_select := OptionButton.new()
	weather_select.name = "Weather"
	weather_select.custom_minimum_size.y = 44
	fields.add_child(weather_select)
	for title in LocalSession.WEATHER:
		weather_select.add_item(title, LocalSession.WEATHER[title])
	weather_select.select(weather_select.get_item_index(LocalSession.weather_code))
	weather_select.item_selected.connect(func(index: int):
		LocalSession.weather_code = weather_select.get_item_id(index)
		LocalSession.revision += 1
	)

func _settings_open() -> bool:
	return is_instance_valid(settings_panel) and settings_panel.visible

func _settings_available() -> bool:
	if loading_campus or switching: return false
	if login_only:
		return not overlay.loading and overlay.get_node("Composition/Modes").visible
	return Catalog.started and not overlay.visible and not map_overlay.visible and not (is_instance_valid(chat) and chat.editing)

func _build_settings() -> void:
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.icon = preload("res://assets/ui/settings.svg")
	settings_button.tooltip_text = "设置"
	settings_button.accessibility_name = "设置"
	root_control.add_child(settings_button)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -76
	settings_button.offset_right = -20
	settings_button.offset_top = 20
	settings_button.offset_bottom = 76
	if is_instance_valid(player) and player.touch_enabled:
		# Keep the existing touch pause target free.
		settings_button.offset_left -= 96
		settings_button.offset_right -= 96
	settings_panel = GraphicsPanel.new()
	root_control.add_child(settings_panel)
	settings_button.pressed.connect(func():
		if not _settings_available(): return
		if is_instance_valid(player): pause_exploration()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		settings_panel.open()
		settings_button.hide()
	)
	settings_panel.closed.connect(func():
		# Closing returns to cursor/pause mode. A separate world click or Esc resumes.
		settings_button.show()
		settings_button.grab_focus()
	)
