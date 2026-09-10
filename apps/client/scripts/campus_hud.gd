extends CanvasLayer

const GuestSession = preload("res://scripts/guest_session.gd")
var identity_label: Label
var network: Node

const Catalog = preload("res://scripts/campus_catalog.gd")
const MapView = preload("res://scripts/campus_map.gd")
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
	identity_label.name = "GuestIdentity"
	identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(identity_label)
	_prepare_guest()
	enter_button = Button.new()
	enter_button.name = "EnterCampus"
	enter_button.text = "游客登录"
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
	enter_button.pressed.connect(enter_campus)
	column.add_child(enter_button)
	network = get_node("/root/GameNetwork")
	network.configure(player, campus.campus_id)
	network.map_prepared.connect(_network_map_prepared)
	network.map_failed.connect(_network_map_failed)
	network.map_finished.connect(_network_map_finished)
	build_map()
	minimap.visible = Catalog.started
	if Catalog.started or Catalog.arriving:
		Catalog.arriving = false
		enter_campus()

func _prepare_guest() -> bool:
	var ready := GuestSession.prepare()
	identity_label.text = GuestSession.username if ready else "请重试"
	return ready

func enter_campus() -> void:
	if not _prepare_guest():
		return
	player.guest_id = GuestSession.guest_id
	player.username = GuestSession.username
	network.start()
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
		if switching:
			map_was_playing = false
			player.stop()
		else:
			pause_exploration()

func _process(delta: float) -> void:
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
	if Catalog.started and not switching and not player.playing and not map_overlay.visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			enter_campus()
			get_viewport().set_input_as_handled()

func _connection_status_changed(value: String) -> void:
	var label: Label = map_overlay.get_node("ConnectionStatus")
	label.text = value
