extends Node

const MODES_PATH := "res://data/gameplay/difficulty_modes.json"
const TUTORIAL_PATH := "res://data/gameplay/tutorial_steps.json"
const SAVE_PATH := "user://player_progress.json"
# Temporary QA/testing override. Set to false before release.
const TEMP_FORCE_PROFESSIONAL_MODE := true

# All mode IDs that carry per-mode progress (day counter, results, shift slot).
const _MODE_IDS := ["easy_multiple_choice", "professional_nlp_dispatch"]

var modes_config: Dictionary = {}
var tutorial_config: Dictionary = {}
var progress: Dictionary = {
	"completed_tutorial": false,
	"passed_pre_assessment": false,
	"first_live_call_done": false,
	"selected_mode": "easy_multiple_choice",
	"professional_difficulty": "easy",
	"certifications": [],
	"completed_modules": [],
	"locale": "en",
	"perfectionist_mode": true,
	"bkt_mastery": {
		"Electrical_Hazard_Recognition": 0.40,
		"Chemical_Hazard_Recognition": 0.40,
		"Evacuation_Protocol": 0.40
	}
}

var bkt_manager: RefCounted = null
var performance_manager: Node = null

func _ready() -> void:
	_instantiate_performance_manager()
	if performance_manager:
		performance_manager.record_loading_start("application_startup")
	bkt_manager = load("res://scripts/bkt_dda/bkt_dda_manager.gd").new()
	_load_configs()
	_load_progress()
	_instantiate_console_overlay()
	call_deferred("_finish_startup_loading")

func _instantiate_performance_manager() -> void:
	if get_node_or_null("PerformanceManager") == null:
		var perf_script = load("res://scripts/performance/performance_manager.gd")
		if perf_script:
			performance_manager = perf_script.new()
			performance_manager.name = "PerformanceManager"
			add_child(performance_manager)

func _finish_startup_loading() -> void:
	if performance_manager:
		performance_manager.record_loading_end("application_startup", true)

func _instantiate_console_overlay() -> void:
	if get_node_or_null("ConsoleOverlay") == null:
		var scene = load("res://scenes/ui/console_overlay.tscn")
		if scene:
			var overlay = scene.instantiate()
			overlay.name = "ConsoleOverlay"
			add_child(overlay)

func _load_configs() -> void:
	modes_config    = _load_json(MODES_PATH)
	tutorial_config = _load_json(TUTORIAL_PATH)

func _load_progress() -> void:
	var loaded = _load_json(SAVE_PATH)
	if typeof(loaded) == TYPE_DICTIONARY and not loaded.is_empty():
		progress.merge(loaded, true)
	_ensure_progress_shape()

func _ensure_progress_shape() -> void:
	# ── Scalar keys with defaults ─────────────────────────────────────────────
	_default_if_missing("completed_tutorial",   false)
	_default_if_missing("passed_pre_assessment", false)
	_default_if_missing("first_live_call_done", false)
	_default_if_missing("selected_mode",        "easy_multiple_choice")
	_default_if_missing("professional_difficulty", "easy")
	_default_if_missing("locale",               "en")
	_default_if_missing("perfectionist_mode",   true)
	_default_if_missing("player_id",            "")
	_default_if_missing("persistent_total_score", 0)

	# ── Array-typed keys ─────────────────────────────────────────────────────
	if not progress.has("certifications") or typeof(progress["certifications"]) != TYPE_ARRAY:
		progress["certifications"] = []
	if not progress.has("completed_modules") or typeof(progress["completed_modules"]) != TYPE_ARRAY:
		progress["completed_modules"] = []

	if not progress.has("bkt_mastery") or typeof(progress["bkt_mastery"]) != TYPE_DICTIONARY:
		progress["bkt_mastery"] = {
			"Electrical_Hazard_Recognition": 0.40,
			"Chemical_Hazard_Recognition": 0.40,
			"Evacuation_Protocol": 0.40,
			"General_Fire_Safety": 0.40,
			"Medical_Response": 0.40,
			"Police_Dispatch": 0.40
		}

	# ── Per-mode namespaced keys — migrate legacy flat keys once ─────────────
	for mode_id in _MODE_IDS:
		_migrate_mode_keys(mode_id)

# ── Internal: set a key to its default value only if absent ──────────────────
func _default_if_missing(key: String, default_value: Variant) -> void:
	if not progress.has(key):
		progress[key] = default_value

# ── Internal: migrate/initialize per-mode progress keys for one mode ─────────
func _migrate_mode_keys(mode_id: String) -> void:
	var day_key   = "current_day_"     + mode_id
	var res_key   = "daily_results_"   + mode_id
	var shift_key = "saved_shift_"     + mode_id
	var is_normal = (mode_id == "easy_multiple_choice")

	# Day counter
	if not progress.has(day_key):
		progress[day_key] = (
			progress["current_day"] if (is_normal and progress.has("current_day"))
			else 1
		)

	# Daily results array
	if not progress.has(res_key) or typeof(progress[res_key]) != TYPE_ARRAY:
		if is_normal and progress.has("daily_results") and typeof(progress["daily_results"]) == TYPE_ARRAY:
			progress[res_key] = progress["daily_results"].duplicate()
		else:
			progress[res_key] = []

	# In-progress shift dictionary
	if not progress.has(shift_key) or typeof(progress[shift_key]) != TYPE_DICTIONARY:
		if is_normal and progress.has("saved_shift") and typeof(progress["saved_shift"]) == TYPE_DICTIONARY:
			progress[shift_key] = progress["saved_shift"].duplicate()
		else:
			progress[shift_key] = {}

	# Persistent cumulative score across days
	var score_key = "persistent_total_score_" + mode_id
	if not progress.has(score_key):
		progress[score_key] = (
			int(progress["persistent_total_score"]) if progress.has("persistent_total_score")
			else 0
		)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		if performance_manager:
			performance_manager.record_persistence_op(false, "Failed to open '%s' for reading" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		if performance_manager:
			performance_manager.record_persistence_op(true)
		return parsed
	if performance_manager:
		performance_manager.record_persistence_op(false, "Failed to parse JSON from '%s'" % path)
	return {}

func save_progress() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		if performance_manager:
			performance_manager.record_persistence_op(false, "Failed to open '%s' for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(progress, "\t"))
	if performance_manager:
		performance_manager.record_persistence_op(true)

# ── Internal: returns the active mode id (never empty) ───────────────────────
func _active_mode_id() -> String:
	return String(progress.get("selected_mode", "easy_multiple_choice"))

func get_current_day() -> int:
	return max(1, int(progress.get("current_day_" + _active_mode_id(), 1)))

func get_day_difficulty_scale() -> float:
	return clamp(1.0 + float(get_current_day() - 1) * 0.06, 1.0, 1.75)

func record_shift_result(score: int, calls_completed: int) -> Dictionary:
	var mode_id      = _active_mode_id()
	var completed_day = get_current_day()
	var res_key      = "daily_results_" + mode_id
	var day_key      = "current_day_"   + mode_id
	var results: Array = progress.get(res_key, [])
	results.append({
		"day": completed_day,
		"score": max(0, score),
		"calls_completed": max(0, calls_completed),
		"completed_at_unix": int(Time.get_unix_time_from_system())
	})
	progress[res_key] = results
	progress[day_key] = completed_day + 1
	save_progress()
	return {
		"completed_day":    completed_day,
		"next_day":         get_current_day(),
		"difficulty_scale": get_day_difficulty_scale()
	}

func get_latest_shift_result() -> Dictionary:
	var results: Array = progress.get("daily_results_" + _active_mode_id(), [])
	if results.is_empty():
		return {}
	var latest = results[results.size() - 1]
	return latest if typeof(latest) == TYPE_DICTIONARY else {}

func get_modes() -> Array:
	return modes_config.get("modes", [])

func get_mode(mode_id: String) -> Dictionary:
	for mode in get_modes():
		if mode.get("id", "") == mode_id:
			return mode
	return {}

func is_mode_unlocked(mode_id: String) -> bool:
	var mode = get_mode(mode_id)
	if mode.is_empty():
		return false
	if mode_id == "professional_nlp_dispatch" and TEMP_FORCE_PROFESSIONAL_MODE:
		return true
	if mode.get("unlocked_by_default", false):
		return true
	var cert_id = String(mode.get("required_certification", ""))
	return cert_id == "" or has_certification(cert_id)

func is_professional_mode_temporarily_forced() -> bool:
	return TEMP_FORCE_PROFESSIONAL_MODE

func get_mode_lock_reason(mode_id: String) -> String:
	var mode = get_mode(mode_id)
	if mode.is_empty():
		return "Mode not found."
	if is_mode_unlocked(mode_id):
		return ""
	var cert_id = String(mode.get("required_certification", ""))
	if cert_id == "":
		return "This mode is currently unavailable."
	return "Complete the required certification in the e-learning app first: %s" % cert_id

func select_mode(mode_id: String) -> bool:
	if not is_mode_unlocked(mode_id):
		return false
	progress["selected_mode"] = mode_id
	save_progress()
	return true

func get_selected_mode() -> Dictionary:
	return get_mode(String(progress.get("selected_mode", "easy_multiple_choice")))

func set_professional_difficulty(diff: String) -> void:
	if diff in ["easy", "medium", "hard"]:
		progress["professional_difficulty"] = diff
		save_progress()

func get_professional_difficulty() -> String:
	return String(progress.get("professional_difficulty", "easy"))

func complete_tutorial() -> void:
	progress["completed_tutorial"] = true
	save_progress()

func has_completed_tutorial() -> bool:
	return bool(progress.get("completed_tutorial", false))

func pass_pre_assessment() -> void:
	progress["passed_pre_assessment"] = true
	save_progress()

func has_passed_pre_assessment() -> bool:
	return bool(progress.get("passed_pre_assessment", false))

func set_first_live_call_done() -> void:
	progress["first_live_call_done"] = true
	save_progress()

func reset_first_live_call_done() -> void:
	progress["first_live_call_done"] = false
	save_progress()

func get_first_live_call_done() -> bool:
	return bool(progress.get("first_live_call_done", false))

var _force_tutorial: bool = false
func set_force_tutorial(val: bool) -> void:
	_force_tutorial = val

func get_force_tutorial() -> bool:
	return _force_tutorial

func get_tutorial_steps() -> Array:
	return tutorial_config.get("steps", [])

func get_tutorial_title() -> String:
	return String(tutorial_config.get("title", "Tutorial"))

func get_tutorial_subtitle() -> String:
	return String(tutorial_config.get("subtitle", ""))

func translate(text: String) -> String:
	return text

func get_completed_modules_count() -> int:
	return (progress.get("completed_modules", []) as Array).size()

func is_module_completed(module_num: int) -> bool:
	return module_num in (progress.get("completed_modules", []) as Array)

func complete_module(module_num: int) -> void:
	var modules: Array = progress.get("completed_modules", [])
	if module_num in modules:
		return
	modules.append(module_num)
	progress["completed_modules"] = modules
	save_progress()

func grant_certification(cert_id: String) -> void:
	var certs: Array = progress.get("certifications", [])
	if cert_id in certs:
		return
	certs.append(cert_id)
	progress["certifications"] = certs
	save_progress()

func has_certification(cert_id: String) -> bool:
	return cert_id in (progress.get("certifications", []) as Array)

func reset_progress() -> void:
	progress = {
		"completed_tutorial": false,
		"passed_pre_assessment": false,
		"first_live_call_done": false,
		"selected_mode": "easy_multiple_choice",
		"professional_difficulty": "easy",
		"certifications": [],
		"completed_modules": [],
		"locale": "en",
		"perfectionist_mode": true,
		"current_day_easy_multiple_choice": 1,
		"current_day_professional_nlp_dispatch": 1,
		"daily_results_easy_multiple_choice": [],
		"daily_results_professional_nlp_dispatch": [],
		"saved_shift_easy_multiple_choice": {},
		"saved_shift_professional_nlp_dispatch": {},
		"persistent_total_score": 0,
		"persistent_total_score_easy_multiple_choice": 0,
		"persistent_total_score_professional_nlp_dispatch": 0,
		"bkt_mastery": {
			"Electrical_Hazard_Recognition": 0.40,
			"Chemical_Hazard_Recognition": 0.40,
			"Evacuation_Protocol": 0.40,
			"General_Fire_Safety": 0.40,
			"Medical_Response": 0.40,
			"Police_Dispatch": 0.40
		}
	}
	reset_bkt_state()
	save_progress()

func set_use_legacy_map(val: bool) -> void:
	progress["legacy_map"] = val
	save_progress()

func get_use_legacy_map() -> bool:
	return bool(progress.get("legacy_map", false))

func set_locale(locale: String) -> void:
	if locale in ["en", "tl", "taglish"]:
		progress["locale"] = locale
		save_progress()

func get_locale() -> String:
	return String(progress.get("locale", "en"))

func set_perfectionist_mode(val: bool) -> void:
	progress["perfectionist_mode"] = val
	save_progress()

func get_perfectionist_mode() -> bool:
	return bool(progress.get("perfectionist_mode", true))

# ── Saved-shift accessors ─────────────────────────────────────────────────────
func get_saved_shift() -> Dictionary:
	return _get_shift_dict("saved_shift_" + _active_mode_id())

func get_saved_shift_for_mode(mode_id: String) -> Dictionary:
	return _get_shift_dict("saved_shift_" + mode_id)

func save_shift_progress(shift_data: Dictionary) -> void:
	progress["saved_shift_" + _active_mode_id()] = shift_data
	save_progress()

func clear_shift_progress() -> void:
	progress["saved_shift_" + _active_mode_id()] = {}
	save_progress()

func clear_shift_progress_for_mode(mode_id: String) -> void:
	progress["saved_shift_" + mode_id] = {}
	save_progress()

# ── Internal: safe dictionary fetch for shift slots ──────────────────────────
func _get_shift_dict(key: String) -> Dictionary:
	var shift = progress.get(key)
	return shift if typeof(shift) == TYPE_DICTIONARY else {}

# Resets Professional mode data back to Day 1 and resets BKT mastery to 0.40.
func reset_professional_progress() -> void:
	progress["saved_shift_professional_nlp_dispatch"]    = {}
	progress["current_day_professional_nlp_dispatch"]    = 1
	progress["daily_results_professional_nlp_dispatch"]  = []
	progress["persistent_total_score_professional_nlp_dispatch"] = 0
	progress["professional_difficulty"]                  = "easy"
	if _active_mode_id() == "professional_nlp_dispatch":
		progress["persistent_total_score"] = 0
	reset_bkt_state()
	save_progress()

# Resets Normal / Easy mode data back to Day 1 and resets BKT mastery to 0.40.
func reset_easy_progress() -> void:
	progress["saved_shift_easy_multiple_choice"]   = {}
	progress["current_day_easy_multiple_choice"]   = 1
	progress["daily_results_easy_multiple_choice"] = []
	progress["persistent_total_score_easy_multiple_choice"] = 0
	if _active_mode_id() == "easy_multiple_choice":
		progress["persistent_total_score"] = 0
	reset_bkt_state()
	save_progress()

# ── Persistent cumulative score accessors ────────────────────────────────────
func get_persistent_score() -> int:
	var mode_key = "persistent_total_score_" + _active_mode_id()
	if progress.has(mode_key):
		return max(0, int(progress[mode_key]))
	return max(0, int(progress.get("persistent_total_score", 0)))

func set_persistent_score(val: int) -> void:
	var s = max(0, val)
	progress["persistent_total_score_" + _active_mode_id()] = s
	progress["persistent_total_score"] = s
	save_progress()

func add_to_persistent_score(pts: int) -> int:
	var updated = max(0, get_persistent_score() + pts)
	set_persistent_score(updated)
	return updated

func clear_all_saves() -> void:
	for mode_id in _MODE_IDS:
		progress["saved_shift_" + mode_id] = {}
		progress["persistent_total_score_" + mode_id] = 0
	progress["persistent_total_score"] = 0
	save_progress()

func clear_saved_shift_for_mode(mode_id: String) -> void:
	clear_shift_progress_for_mode(mode_id)


func get_total_historical_calls() -> int:
	var total = 0
	for mode_id in _MODE_IDS:
		for res in (progress.get("daily_results_" + mode_id, []) as Array):
			if typeof(res) == TYPE_DICTIONARY:
				total += int(res.get("calls_completed", 0))
	return total

# ── Audio volume persistence ──────────────────────────────────────────────────
func set_audio_volumes(master: float, bgm: float, siren: float) -> void:
	progress["audio_master"] = master
	progress["audio_bgm"]    = bgm
	progress["audio_siren"]  = siren
	save_progress()

func get_audio_volumes() -> Dictionary:
	return {
		"master": float(progress.get("audio_master", 1.0)),
		"bgm":    float(progress.get("audio_bgm",    0.7)),
		"siren":  float(progress.get("audio_siren",  0.7)),
	}

# ── Bayesian Knowledge Tracing (BKT) and DDA ───────────────────────────
# BKT parameters (P_L0, P_T, P_G, P_S) are canonical in bkt_dda/bkt_dda_manager.gd.
# Do not duplicate them here to avoid divergence.

const ANALYTICS_BKT_PATH = "user://safescape_bkt_analytics.csv"
const ANALYTICS_SHIFT_PATH = "user://safescape_shift_summaries.csv"

# ── Google Forms Web Logging configuration ──────────────────────────────
const BKT_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSdYMC-MZMSmTGHap28KIwrYEp_PcIGTMwFnCXNZJm0lEPgYVw/formResponse"
const BKT_ENTRY_CATEGORY = "entry.877937151"
const BKT_ENTRY_IS_CORRECT = "entry.323129846"
const BKT_ENTRY_OLD_P = "entry.411497459"
const BKT_ENTRY_NEW_P = "entry.641927599"
const BKT_ENTRY_DAY = "entry.736085720"
const BKT_ENTRY_MODE = "entry.1386010153"
const BKT_ENTRY_SOURCE = "entry.1590700101"
const BKT_ENTRY_PLAYER_ID = "entry.XXXXXX_BKT" # TODO: Replace with real Google Form entry ID

const SHIFT_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSflsJuzN90s9-Kc93bo2E55Oezzh8n-XtXWfRD28GSW5gWQbg/formResponse"
const SHIFT_ENTRY_MODE = "entry.348479592"
const SHIFT_ENTRY_DAY = "entry.2055702061"
const SHIFT_ENTRY_SCORE = "entry.858702930"
const SHIFT_ENTRY_CALLS = "entry.751058503"
const SHIFT_ENTRY_FIRE = "entry.866540435"
const SHIFT_ENTRY_MED = "entry.631381422"
const SHIFT_ENTRY_CRIM = "entry.405757596"
const SHIFT_ENTRY_PLAYER_ID = "entry.XXXXXX_SHIFT" # TODO: Replace with real Google Form entry ID

func get_bkt_mastery(category: Variant) -> float:
	if bkt_manager != null and bkt_manager.has_method("get_mastery"):
		return bkt_manager.call("get_mastery", category)
	var mastery = progress.get("bkt_mastery", {})
	if typeof(category) == TYPE_STRING:
		return float(mastery.get(category, 0.40))
	return 0.40

func determine_dda_difficulty(category: Variant) -> String:
	if bkt_manager != null and bkt_manager.has_method("determine_difficulty"):
		return bkt_manager.call("determine_difficulty", category)
	return "MODERATE"

func reset_bkt_state() -> void:
	if bkt_manager != null and bkt_manager.has_method("reset_bkt_state"):
		bkt_manager.call("reset_bkt_state")
	progress["bkt_mastery"] = {
		"Electrical_Hazard_Recognition": 0.40,
		"Chemical_Hazard_Recognition": 0.40,
		"Evacuation_Protocol": 0.40,
		"General_Fire_Safety": 0.40,
		"Medical_Response": 0.40,
		"Police_Dispatch": 0.40
	}
	save_progress()
	
	# Notify active scene (e.g. RouteScene) to invalidate pre-generated call state
	if is_inside_tree():
		var tree = get_tree()
		if tree and tree.current_scene:
			if tree.current_scene.has_method("invalidate_call_state_after_reset"):
				tree.current_scene.call("invalidate_call_state_after_reset")

func init_bkt_prior(category: Variant, score_ratio: float) -> void:
	if not progress.has("bkt_mastery") or typeof(progress["bkt_mastery"]) != TYPE_DICTIONARY:
		progress["bkt_mastery"] = {"Electrical_Hazard_Recognition": 0.40, "Chemical_Hazard_Recognition": 0.40, "Evacuation_Protocol": 0.40}
	
	var cat_str = String(category)
	var prior = clamp(score_ratio, 0.15, 0.90)
	var old_prior = float(progress["bkt_mastery"].get(cat_str, 0.40))
	progress["bkt_mastery"][cat_str] = prior
	save_progress()
	
	log_bkt_analytics_event(cat_str, true, old_prior, prior, "pre_assessment")
	print("BKT Prior initialized for category: ", cat_str, " to ", prior)

func update_bkt_mastery(category: Variant, is_correct: bool = true, telemetry: Dictionary = {}) -> float:
	var mode_id = String(progress.get("selected_mode", "easy_multiple_choice"))
	var day_num = get_current_day()
	
	if bkt_manager != null and bkt_manager.has_method("update_skill"):
		var record = bkt_manager.call("update_skill", category, is_correct, mode_id, day_num, telemetry)
		if typeof(record) == TYPE_DICTIONARY and record.has("bkt_state"):
			var bkt_st = record["bkt_state"]
			if typeof(bkt_st) == TYPE_DICTIONARY and bkt_st.has("probability") and bkt_st["probability"] != null:
				return float(bkt_st["probability"])
				
	return get_bkt_mastery(category)

func log_bkt_analytics_event(category: String, is_correct: bool, old_p: float, new_p: float, source: String) -> void:
	var mode = progress.get("selected_mode", "easy_multiple_choice")
	var day = progress.get("current_day_" + mode, 1)
	var player_id = progress.get("player_id", "")

	# Local file logging (works on desktop builds)
	var file_exists = FileAccess.file_exists(ANALYTICS_BKT_PATH)
	var file = FileAccess.open(ANALYTICS_BKT_PATH, FileAccess.WRITE_READ if file_exists else FileAccess.WRITE)
	if file != null:
		if not file_exists or file.get_length() == 0:
			file.store_line("Timestamp,PlayerID,Category,IsCorrect,OldMastery,NewMastery,CurrentDay,SelectedMode,Source")
		else:
			file.seek_end()
		var timestamp = Time.get_datetime_string_from_system()
		var line = "%s,%s,%s,%s,%.4f,%.4f,%d,%s,%s" % [
			timestamp,
			player_id,
			category,
			"1" if is_correct else "0",
			old_p,
			new_p,
			day,
			mode,
			source
		]
		file.store_line(line)
		file.close()

	# Web logging (works on both WebGL HTML5 and desktop builds)
	var web_data = {
		BKT_ENTRY_CATEGORY: category,
		BKT_ENTRY_IS_CORRECT: "1" if is_correct else "0",
		BKT_ENTRY_OLD_P: "%.4f" % old_p,
		BKT_ENTRY_NEW_P: "%.4f" % new_p,
		BKT_ENTRY_DAY: str(day),
		BKT_ENTRY_MODE: mode,
		BKT_ENTRY_SOURCE: source,
		BKT_ENTRY_PLAYER_ID: player_id
	}
	_send_form_data(BKT_FORM_URL, web_data)

func log_shift_summary(score: int, calls_completed: int) -> void:
	var mode = progress.get("selected_mode", "easy_multiple_choice")
	var day = progress.get("current_day_" + mode, 1) - 1
	var player_id = progress.get("player_id", "")
	var mastery = progress.get("bkt_mastery", {})
	# Use canonical skill names matching BKTDDAManager constants.
	var f_p = float(mastery.get("General_Fire_Safety", 0.5))
	var m_p = float(mastery.get("Medical_Response", 0.5))
	var c_p = float(mastery.get("Police_Dispatch", 0.5))

	# Local file logging (works on desktop builds)
	var file_exists = FileAccess.file_exists(ANALYTICS_SHIFT_PATH)
	var file = FileAccess.open(ANALYTICS_SHIFT_PATH, FileAccess.WRITE_READ if file_exists else FileAccess.WRITE)
	if file != null:
		if not file_exists or file.get_length() == 0:
			file.store_line("Timestamp,PlayerID,Mode,DayNumber,ShiftScore,CallsCompleted,FinalFireMastery,FinalMedicalMastery,FinalCriminalMastery")
		else:
			file.seek_end()
		var timestamp = Time.get_datetime_string_from_system()
		var line = "%s,%s,%s,%d,%d,%d,%.4f,%.4f,%.4f" % [
			timestamp,
			player_id,
			mode,
			day,
			score,
			calls_completed,
			f_p,
			m_p,
			c_p
		]
		file.store_line(line)
		file.close()

	# Web logging (works on both WebGL HTML5 and desktop builds)
	var web_data = {
		SHIFT_ENTRY_MODE: mode,
		SHIFT_ENTRY_DAY: str(day),
		SHIFT_ENTRY_SCORE: str(score),
		SHIFT_ENTRY_CALLS: str(calls_completed),
		SHIFT_ENTRY_FIRE: "%.4f" % f_p,
		SHIFT_ENTRY_MED: "%.4f" % m_p,
		SHIFT_ENTRY_CRIM: "%.4f" % c_p,
		SHIFT_ENTRY_PLAYER_ID: player_id
	}
	_send_form_data(SHIFT_FORM_URL, web_data)

func _send_form_data(url: String, data: Dictionary) -> void:
	if url == "" or url.contains("1FAIpQLS..."):
		# Skip if Google Form is not set up/configured by the user
		return
	
	var req_id = "form_%d" % (Time.get_ticks_msec() % 100000)
	if performance_manager:
		performance_manager.record_api_request_start(req_id, "google_forms_sync")
	
	var http = HTTPRequest.new()
	add_child(http)
	
	# Clean up the node when the request is done
	http.request_completed.connect(func(result, response_code, _headers, _body):
		if performance_manager:
			var success = (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
			performance_manager.record_api_request_end(req_id, success, response_code)
		http.queue_free()
	)
	
	# Encode the parameters as urlencoded payload
	var query_parts = []
	for key in data.keys():
		var val = String(data[key]).uri_encode()
		query_parts.append(key + "=" + val)
	var query_string = "&".join(query_parts)
	
	var headers = PackedStringArray([
		"Content-Type: application/x-www-form-urlencoded"
	])
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, query_string)
	if err != OK:
		if performance_manager:
			performance_manager.record_api_request_end(req_id, false, 0, "HTTPRequest failed to dispatch: %d" % err)
		print("Failed to dispatch web logging request: ", err)
		http.queue_free()
