extends Node

## CloudSaveManager
## Handles cloud profile synchronization and progress saving for SafeScape 2.0 / The Right Call.
## Communicates with the web host page via JavaScriptBridge and HTTPRequest.

signal progress_loaded(data: Dictionary)
signal progress_saved(payload: Dictionary)

var user_id: String = ""
var player_name: String = ""
var high_score: int = 0
var total_calls: int = 0
var successful_calls: int = 0
var failed_calls: int = 0
var completed_scenarios: Array = []

func _ready() -> void:
	if OS.has_feature("web"):
		_init_web_profile()
	else:
		_init_desktop_fallback()

func _init_web_profile() -> void:
	# 1. Parse player details from URL query params
	var uid_eval = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('user_id') || ''")
	var name_eval = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('player_name') || ''")

	user_id = str(uid_eval) if uid_eval != null else ""
	player_name = str(name_eval) if name_eval != null else ""

	print("[CloudSaveManager] Web Profile Initialized -> User ID: '", user_id, "' | Name: '", player_name, "'")

	# Sync initial profile to GameState if available
	_sync_to_game_state()

	# 2. Fetch progress from Cloud API
	load_cloud_progress()

var game_state_override: Node = null

func _get_game_state() -> Node:
	if game_state_override != null and is_instance_valid(game_state_override):
		return game_state_override
	if is_inside_tree():
		var node = get_node_or_null("/root/GameState")
		if node != null:
			return node
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root:
		var node = main_loop.root.get_node_or_null("GameState")
		if node != null:
			return node
	if get_parent() != null and get_parent().has_node("GameState"):
		return get_parent().get_node("GameState")
	return null

func _init_desktop_fallback() -> void:
	# Local testing / editor mode fallback
	var state = _get_game_state()
	if state and state.has_method("get_persistent_score"):
		user_id = "editor_dev"
		player_name = "Cadet Dispatcher"
		high_score = int(state.call("get_persistent_score"))
	print("[CloudSaveManager] Desktop / Local mode running (web features disabled).")

func load_cloud_progress() -> void:
	if not OS.has_feature("web") or user_id == "" or user_id == "guest":
		return

	var http_request = HTTPRequest.new()
	http_request.name = "CloudLoadHTTPRequest"
	add_child(http_request)

	http_request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		http_request.queue_free()
		print("[CloudSaveManager] Load response code: ", code)
		if code == 200:
			var json_text = body.get_string_from_utf8()
			var parsed = JSON.parse_string(json_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var data: Dictionary = parsed
				high_score = int(data.get("high_score", high_score))
				total_calls = int(data.get("total_calls_handled", total_calls))
				successful_calls = int(data.get("successful_calls", successful_calls))
				failed_calls = int(data.get("failed_calls", failed_calls))
				var scenarios = data.get("completed_scenarios", [])
				if typeof(scenarios) == TYPE_ARRAY:
					for sc in scenarios:
						if not completed_scenarios.has(sc):
							completed_scenarios.append(sc)

				print("[CloudSaveManager] Cloud data loaded successfully: HighScore=", high_score, " Calls=", total_calls)
				_sync_to_game_state()
				progress_loaded.emit(data)
			else:
				push_warning("[CloudSaveManager] Failed to parse JSON dictionary from cloud response.")
		else:
			push_warning("[CloudSaveManager] Cloud load returned non-200 status code: %d" % code)
	)

	var origin = JavaScriptBridge.eval("window.location.origin")
	var url = str(origin) + "/api/games/right-call/load?user_id=" + user_id
	print("[CloudSaveManager] Requesting cloud load URL: ", url)
	var err = http_request.request(url)
	if err != OK:
		push_warning("[CloudSaveManager] Failed to dispatch HTTPRequest: %d" % err)
		http_request.queue_free()

## Call this when a call is dispatched, score changes, or game ends:
func save_progress(current_score: int, calls_handled: int = 1, successful: int = 1, failed: int = 0, scenario_id: String = "", is_won: bool = false) -> void:
	if scenario_id != "" and not completed_scenarios.has(scenario_id):
		completed_scenarios.append(scenario_id)

	# Update internal cumulative metrics
	if calls_handled > total_calls:
		total_calls = calls_handled
	else:
		total_calls += calls_handled

	if successful > successful_calls:
		successful_calls = successful
	else:
		successful_calls += successful

	if failed > failed_calls:
		failed_calls = failed
	else:
		failed_calls += failed

	if current_score > high_score:
		high_score = current_score

	# Update GameState if available
	var state = _get_game_state()
	if state and state.has_method("set_persistent_score"):
		state.call("set_persistent_score", max(current_score, high_score))

	var payload = {
		"user_id": int(user_id) if user_id.is_valid_int() else 0,
		"score": current_score,
		"calls_handled": total_calls,
		"successful_calls": successful_calls,
		"failed_calls": failed_calls,
		"completed_scenarios": completed_scenarios,
		"is_won": is_won
	}

	if not OS.has_feature("web"):
		print("[CloudSaveManager] (Desktop Mode) save_progress called: ", payload)
		progress_saved.emit(payload)
		return

	# PostMessage to Web wrapper (handles cookies and session auth automatically!)
	var js_code = """
		if (window.parent) {
			window.parent.postMessage({
				type: 'RIGHT_CALL_SAVE',
				payload: %s
			}, '*');
		}
	""" % JSON.stringify(payload)

	JavaScriptBridge.eval(js_code)
	print("[CloudSaveManager] Dispatched RIGHT_CALL_SAVE postMessage: ", payload)
	progress_saved.emit(payload)

func _sync_to_game_state() -> void:
	var state = _get_game_state()
	if state == null:
		return

	if user_id != "" and state.progress.has("player_id"):
		state.progress["player_id"] = user_id

	if player_name != "":
		state.progress["player_name"] = player_name

	if high_score > 0 and state.has_method("get_persistent_score"):
		var curr = int(state.call("get_persistent_score"))
		if high_score > curr and state.has_method("set_persistent_score"):
			state.call("set_persistent_score", high_score)
