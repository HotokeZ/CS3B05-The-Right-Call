class_name SafeScapeLocalStorage
extends RefCounted

## Cross-Platform LocalStorage & File Persistence Wrapper for SafeScape 2.0
## Evaluates platform features at runtime:
## - HTML5 / Web / Itch.io: uses browser localStorage
## - Godot Editor / Desktop / Local testing: uses user://SafeScapeBKTState.json
## Provides unified API: save_state(), load_state(), reset_state()

const STORAGE_KEY := "SafeScapeBKTState"
const FILE_PATH := "user://SafeScapeBKTState.json"

static func save_state(state: Dictionary) -> bool:
	return save_bkt_state(state)

static func load_state() -> Dictionary:
	return load_bkt_state()

static func reset_state() -> bool:
	return reset_bkt_state()

static func save_bkt_state(state: Dictionary) -> bool:
	var json_string = JSON.stringify(state)
	
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped_json = json_string.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				var code = "try { localStorage.setItem('%s', '%s'); true; } catch(e) { false; }" % [STORAGE_KEY, escaped_json]
				var result = js.eval(code)
				return bool(result) if result != null else false
				
	# Desktop / Godot Editor / Local testing path
	return _save_to_user_file(json_string)

static func load_bkt_state() -> Dictionary:
	var json_str := ""
	
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var code = "try { localStorage.getItem('%s') || ''; } catch(e) { ''; }" % STORAGE_KEY
				var result = js.eval(code)
				if result != null and typeof(result) == TYPE_STRING:
					json_str = result
					
	if json_str.is_empty():
		json_str = _load_from_user_file()
		
	if json_str.is_empty():
		return {}
		
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

static func reset_bkt_state() -> bool:
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var code = "try { localStorage.removeItem('%s'); true; } catch(e) { false; }" % STORAGE_KEY
				js.eval(code)
				
	return _delete_user_file()

static func _save_to_user_file(json_string: String) -> bool:
	var file = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		return true
	return false

static func _load_from_user_file() -> String:
	if FileAccess.file_exists(FILE_PATH):
		var file = FileAccess.open(FILE_PATH, FileAccess.READ)
		if file != null:
			return file.get_as_text()
	return ""

static func _delete_user_file() -> bool:
	var removed = true
	if FileAccess.file_exists(FILE_PATH):
		removed = (DirAccess.remove_absolute(FILE_PATH) == OK)
	if FileAccess.file_exists("user://safescape_bkt_state.json"):
		DirAccess.remove_absolute("user://safescape_bkt_state.json")
	return removed
