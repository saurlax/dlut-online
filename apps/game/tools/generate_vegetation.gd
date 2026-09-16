extends SceneTree
## godot --headless --path apps/game --script tools/generate_vegetation.gd
func _initialize() -> void:
	var builder := preload("res://tools/build_vegetation.gd").new()
	for campus in ["lingshui", "eda", "panjin"]:
		builder.build(self,campus)
	quit()
