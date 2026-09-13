@tool
extends ColorRect
## Presentation only; this scene never authenticates or creates a player.

const BACKDROP_PATH := "res://scenes/ui/campus_backdrop.tscn"
@export_enum("Login", "Main menu") var preview_page: int = 0:
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

func _ready() -> void:
	resized.connect(_layout)
	_layout()
	show_account_page(preview_page == 1)
	if background_enabled:
		if not Engine.is_editor_hint(): Engine.max_fps = 60
		background_requested = ResourceLoader.load_threaded_request(BACKDROP_PATH) == OK

func _layout() -> void:
	var factor: float = minf(size.x / 1280.0, size.y / 720.0)
	$Composition.scale = Vector2.ONE * factor
	$Composition.position = (size - Vector2(1280, 720) * factor) * 0.5

func _process(delta: float) -> void:
	if background_requested and ResourceLoader.load_threaded_get_status(BACKDROP_PATH) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		background_requested = false
		var scene: PackedScene = ResourceLoader.load_threaded_get(BACKDROP_PATH)
		if scene != null and background_enabled:
			backdrop = scene.instantiate()
			$Background/Viewport.add_child(backdrop)
			backdrop.set_shot(preview_shot)
	if is_instance_valid(backdrop):
		if (not Engine.is_editor_hint() or animate_preview) and is_visible_in_tree():
			backdrop.advance(delta)
		$ShotFade.color.a = backdrop.fade_alpha() if not Engine.is_editor_hint() or animate_preview else 0.0

func show_account_page(authenticated: bool) -> void:
	$Composition/Form.position.y = 510.0 if authenticated else 290.0
	$Composition/Form/Fields/AccountIdentity.visible = not authenticated
	$Composition/Form/Fields/LoginEmail.visible = not authenticated
	$Composition/Form/Fields/LoginPassword.visible = not authenticated
	$Composition/Form/Fields/Register.visible = not authenticated
	$Composition/Form/Fields/EnterCampus.text = "进入游戏" if authenticated else "登录"
	$Composition/Form/Fields/AccountIdentity.text = "" if authenticated else "使用 DLUT Online 账号登录"
