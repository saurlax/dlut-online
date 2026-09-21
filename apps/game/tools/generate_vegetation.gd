extends SceneTree
## godot --headless --path apps/game --script tools/generate_vegetation.gd
func _initialize() -> void:
	var builder := preload("res://tools/build_vegetation.gd").new()
	for campus in ["lingshui", "eda", "panjin"]:
		if not OS.get_cmdline_user_args().is_empty() and campus not in OS.get_cmdline_user_args(): continue
		builder.build(self,campus)
	quit()
