@tool
extends EditorExportPlugin
func _get_name() -> String: return "NativeMatchExport"
func _export_begin(features: PackedStringArray,_debug: bool,_path: String,_flags: int) -> void:
	if not "windows" in features or not "x86_64" in features: return
	var library := "res://native/bin/match.windows.x86_64.dll"
	if not FileAccess.file_exists(library): return
	add_shared_object(library,PackedStringArray(["windows","x86_64"]),"native/bin")
	add_file("res://native/match.cfg",FileAccess.get_file_as_bytes("res://native/match.cfg"),false)
	for notice in ["GODOT_CPP_LICENSE.md","LIBCXX_LICENSE.txt","MINGW_COPYING.txt"]:
		add_file("res://licenses/"+notice,FileAccess.get_file_as_bytes("res://native/"+notice),false)
