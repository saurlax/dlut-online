@tool
extends EditorPlugin

class CampusExport extends EditorExportPlugin:
	const Catalog = preload("res://scripts/campus_catalog.gd")
	const Builder = preload("res://tools/campus_packs/grid_builder.gd")

	func _get_name() -> String:
		return "DOCampusPacks"

	func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
		if not features.has("web"): return
		var output := path.get_base_dir().path_join("campuses")
		DirAccess.make_dir_recursive_absolute(output)
		var manifest := {}
		for id: String in Catalog.CAMPUSES:
			var result := Builder.new().build(id,output)
			if id == "lingshui":
				for file: String in result.files:
					add_file(file,FileAccess.get_file_as_bytes(result.files[file]),false)
			else:
				manifest[id] = result.pack
		add_file("res://campus_packs.json",JSON.stringify(manifest).to_utf8_buffer(),false)

	func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
		if not features.has("web"): return
		if path.begins_with("res://assets/campuses/") or path.begins_with("res://scenes/campuses/"):
			skip()

var exporter: CampusExport

func _enter_tree() -> void:
	exporter = CampusExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
