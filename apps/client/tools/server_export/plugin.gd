@tool
extends EditorPlugin

class ServerExport extends EditorExportPlugin:
	func _get_name() -> String: return "DOServer"

	func _export_begin(features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		if features.has("dedicated_server"):
			# The project autoload remains resolvable without client dependencies.
			add_file("res://scripts/player_network.gd", "extends Node\n".to_utf8_buffer(), false)

	func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
		if features.has("dedicated_server"):
			if not (path.begins_with("res://scripts/server/") or path.begins_with("res://scripts/shared/") or path.begins_with("res://scenes/server/") or path == "res://scenes/server.tscn"):
				skip()
		elif path.begins_with("res://scripts/server/") or path.begins_with("res://scenes/server/") or path == "res://scenes/server.tscn":
			skip()

var exporter: ServerExport
func _enter_tree() -> void:
	exporter = ServerExport.new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
