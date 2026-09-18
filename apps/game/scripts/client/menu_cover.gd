@tool
extends ColorRect
## Presentation only; this scene never authenticates or creates a player.

const BACKDROP_PATH := "res://scenes/ui/campus_backdrop.tscn"
@export_enum("Login", "Main menu") var preview_page: int = 1:
	set(value):
		preview_page = value
		if is_node_ready(): show_account_page(value == 1)
@export_enum("Main building", "Bochuan library", "Lingxi library") var preview_shot: int = 0:
	set(value):
		preview_shot = value
		if is_instance_valid(backdrop): backdrop.set_shot(value)
@export var animate_preview := false
var background_enabled := true
var backdrop: Node3D
var background_requested := false
var loading := false
var preparing := false

func _ready() -> void:
	resized.connect(_layout)
	_layout()
	show_account_page(preview_page == 1)
	if background_enabled:
		$StartupLoading/Retry.pressed.connect(_start_loading)
		_start_loading()

func _layout() -> void:
	var factor: float = minf(size.x / 1280.0, size.y / 720.0)
	$Composition.scale = Vector2.ONE * factor
	$Composition.position = (size - Vector2(1280, 720) * factor) * 0.5

func _process(delta: float) -> void:
	if background_requested:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(BACKDROP_PATH, progress)
		if not progress.is_empty():
			$StartupLoading/Progress.value = maxf($StartupLoading/Progress.value, float(progress[0]) * 90.0)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			background_requested = false
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_prepare_background()
			else:
				ResourceLoader.load_threaded_get(BACKDROP_PATH)
				_loading_failed()
	if is_instance_valid(backdrop):
		if not loading and (not Engine.is_editor_hint() or animate_preview) and is_visible_in_tree():
			backdrop.advance(delta)
		$ShotFade.color.a = backdrop.fade_alpha() if not Engine.is_editor_hint() or animate_preview else 0.0

func show_account_page(authenticated: bool) -> void:
	$Composition/Form.visible = not authenticated
	$ModalShade.visible = not authenticated
	$Composition/Modes.visible = authenticated
	$Composition/Form/Fields/AccountIdentity.text = "使用 DLUT Online 账号登录"

func _start_loading() -> void:
	if background_requested or preparing: return
	loading = not Engine.is_editor_hint()
	$StartupLoading.visible = loading
	$Composition.visible = not loading
	$StartupLoading/Progress.value = 0
	$StartupLoading/Status.text = "加载中"
	$StartupLoading/Retry.hide()
	background_requested = ResourceLoader.load_threaded_request(BACKDROP_PATH) == OK
	if not background_requested: _loading_failed()

func _prepare_background() -> void:
	preparing = true
	$StartupLoading/Progress.value = 95
	await get_tree().process_frame
	var scene: PackedScene = ResourceLoader.load_threaded_get(BACKDROP_PATH)
	if scene == null:
		preparing = false
		_loading_failed()
		return
	backdrop = scene.instantiate()
	$Background/Viewport.add_child(backdrop)
	backdrop.set_shot(preview_shot)
	$StartupLoading/Progress.value = 98
	# Keep the cover until the instantiated background has rendered, including GPU setup.
	for frame in 2:
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	$StartupLoading/Progress.value = 100
	await get_tree().process_frame
	preparing = false
	loading = false
	$StartupLoading.hide()
	$Composition.show()

func _loading_failed() -> void:
	preparing = false
	$StartupLoading/Status.text = "加载失败，请重试"
	$StartupLoading/Retry.show()
