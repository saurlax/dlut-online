@tool
extends EditorPlugin

class CampusExport extends EditorExportPlugin:
	const Catalog = preload("res://scripts/campus_catalog.gd")
	const MODEL := "res://assets/campuses/eda/models/development_campus.tscn"

	func _get_name() -> String:
		return "DOCampusPacks"

	func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
		if not features.has("web"):
			return
		var output := path.get_base_dir().path_join("campuses")
		DirAccess.make_dir_recursive_absolute(output)
		var manifest := {}
		for id in Catalog.CAMPUSES:
			if id == "lingshui":
				continue
			var result := build_pack(id, output)
			if result.is_empty():
				get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR,
					"Campus packs", "Failed to export campus: " + id)
				return
			manifest[id] = result
		add_file("res://campus_packs.json", JSON.stringify(manifest).to_utf8_buffer(), false)

	func build_pack(id: String, output: String) -> Dictionary:
		var temp := output.path_join("." + id + ".pck")
		var pack := PCKPacker.new()
		if pack.pck_start(temp) != OK:
			return {}
		var entry: Dictionary = Catalog.CAMPUSES[id]
		if pack.add_file(entry.scene, entry.scene) != OK:
			return {}
		if id == "eda":
			var binary := output.path_join(".model.scn")
			if ResourceSaver.save(load(MODEL), binary, ResourceSaver.FLAG_COMPRESS) != OK:
				return {}
			if pack.add_file(MODEL.get_basename() + ".scn", binary) != OK:
				return {}
			var remap := output.path_join(".model.remap")
			var file := FileAccess.open(remap, FileAccess.WRITE)
			file.store_string('[remap]\npath="%s.scn"\n' % MODEL.get_basename())
			file.close()
			if pack.add_file(MODEL + ".remap", remap) != OK:
				return {}
			for key in ["manifest", "roads"]:
				if pack.add_file(entry[key], entry[key]) != OK:
					return {}
		if pack.flush() != OK:
			return {}
		var sha := FileAccess.get_sha256(temp)
		var filename := id + "-" + sha + ".pck"
		var destination := output.path_join(filename)
		if DirAccess.rename_absolute(temp, destination) != OK:
			return {}
		for name in [".model.scn", ".model.remap"]:
			if FileAccess.file_exists(output.path_join(name)):
				DirAccess.remove_absolute(output.path_join(name))
		var file := FileAccess.open(destination, FileAccess.READ)
		return {"url": "campuses/" + filename, "sha256": sha, "bytes": file.get_length()}

var exporter: CampusExport

func _enter_tree() -> void:
	exporter = CampusExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
