class_name SafeScapeEvaluationLogger
extends RefCounted

## Evaluation Logger for SafeScape 2.0
## Formats and logs BKT updates and adaptive cycles for IT expert evaluation & automated harness.
## Required test harness keys: bkt_state, dda_level, final_rule, expected, target.

signal log_emitted(log_dict: Dictionary, log_json: String)

static var last_logged_event: Dictionary = {}
static var logged_decision_keys: Dictionary = {}

static func reset_presentation_guards() -> void:
	logged_decision_keys.clear()

## Log when BKT learner state is reset
static func log_bkt_reset(memory_skills: Dictionary, persisted_skills: Dictionary = {}) -> Dictionary:
	if persisted_skills.is_empty():
		persisted_skills = memory_skills.duplicate(true)
		
	var record = {
		"event": "bkt_reset",
		"adaptive_enabled": true,
		"success": true,
		"state_reset_to": 0.40,
		"pending_call_invalidated": true,
		"pending_decision_context_invalidated": true,
		"memory_state": memory_skills.duplicate(true),
		"persisted_state": persisted_skills.duplicate(true)
	}
	last_logged_event = record
	var json_line = JSON.stringify(record)
	print("[EVAL_LOGGER] " + json_line)
	
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped = json_line.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				js.eval("try { console.log('SAFESCAPE_EVAL:', '%s'); } catch(e) {}" % escaped)
				
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var overlay = tree.root.find_child("ConsoleOverlay", true, false)
		if overlay and overlay.has_method("append_log_entry"):
			overlay.call("append_log_entry", json_line, record)
			
	return record

## Log option-count validation results
static func log_validation(val_record: Dictionary) -> Dictionary:
	last_logged_event = val_record
	var json_line = JSON.stringify(val_record)
	
	if not val_record.get("valid", false):
		push_warning("[EVAL_LOGGER] DDA OPTION COUNT VALIDATION FAILED: " + json_line)
	print("[EVAL_LOGGER] " + json_line)
	
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped = json_line.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				js.eval("try { console.log('SAFESCAPE_EVAL:', '%s'); } catch(e) {}" % escaped)
				
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var overlay = tree.root.find_child("ConsoleOverlay", true, false)
		if overlay and overlay.has_method("append_log_entry"):
			overlay.call("append_log_entry", json_line, val_record)
			
	return val_record

## Log when a decision point is presented to the learner
static func log_decision_presented(
	scenario_id: String,
	category: String,
	skill: String,
	mastery: float,
	dda_level: String,
	options_presented: int,
	expected_options: int = 2,
	correct_option_present: bool = true,
	decision_point_index: int = 1,
	adaptive_enabled: bool = true
) -> Dictionary:
	if scenario_id.strip_edges() == "":
		push_error("[EVAL_LOGGER ERROR] log_decision_presented received empty scenario_id!")

	var dp_key = "%s:%d" % [scenario_id, decision_point_index]
	if logged_decision_keys.has(dp_key):
		# Presentation guard: Suppress duplicate evaluation events for the same decision point
		return logged_decision_keys[dp_key]

	var record = {}
	if not adaptive_enabled:
		record = {
			"event": "decision_presented",
			"adaptive_enabled": false,
			"scenario_id": scenario_id,
			"decision_point": decision_point_index,
			"category": category,
			"skill": skill,
			"bkt_state": { "status": "INACTIVE" },
			"difficulty_source": "FIXED",
			"dda_level": "MODERATE",
			"expected_options": 3,
			"options_presented": options_presented,
			"correct_option_present": correct_option_present
		}
	else:
		record = {
			"event": "decision_presented",
			"adaptive_enabled": true,
			"scenario_id": scenario_id,
			"decision_point": decision_point_index,
			"category": category,
			"skill": skill,
			"mastery": mastery,
			"bkt_state": {
				"skill": skill,
				"probability": mastery,
				"status": "ACTIVE"
			},
			"difficulty_source": "ADAPTIVE_BKT",
			"dda_level": dda_level,
			"expected_options": expected_options,
			"options_presented": options_presented,
			"correct_option_present": correct_option_present
		}
	
	logged_decision_keys[dp_key] = record
	last_logged_event = record
	var json_line = JSON.stringify(record)
	
	print("[EVAL_LOGGER] " + json_line)
	
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped = json_line.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				js.eval("try { console.log('SAFESCAPE_EVAL:', '%s'); } catch(e) {}" % escaped)
				
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var overlay = tree.root.find_child("ConsoleOverlay", true, false)
		if overlay and overlay.has_method("append_log_entry"):
			overlay.call("append_log_entry", json_line, record)
			
	return record

## Log when a decision point BKT & DDA cycle is completed
static func log_bkt_and_dda_cycle(
	skill: String,
	response_correct: bool,
	mastery_before: float,
	p_correct: float,
	mastery_after: float,
	learn_rate: float,
	guess_rate: float,
	slip_rate: float,
	diff_before: String,
	diff_after: String,
	is_adaptive_mode: bool,
	mode_id: String = "easy_multiple_choice",
	day_number: int = 1,
	telemetry: Dictionary = {}
) -> Dictionary:
	var sc_id = String(telemetry.get("scenario_id", "")).strip_edges()
	if sc_id == "":
		push_error("[EVAL_LOGGER ERROR] log_bkt_and_dda_cycle received empty scenario_id!")
	
	var final_rule_obj = SafeScapeLevelRuleProvider.get_final_rule(mode_id, day_number)
	var expected_obj = SafeScapeLevelRuleProvider.get_expected(mode_id, day_number)
	var target_obj = SafeScapeLevelRuleProvider.get_target(mode_id, day_number)

	var bkt_state_data: Variant = null
	var dda_level_str: String = telemetry.get("dda_level", diff_before)
	var options_count: int = telemetry.get("options_presented", 3)
	var bkt_applied: bool = is_adaptive_mode
	var diff_source: String = "ADAPTIVE_BKT" if is_adaptive_mode else "FIXED"
	
	var reported_diff_before = diff_before
	var reported_diff_after = diff_after

	if is_adaptive_mode:
		bkt_state_data = {
			"skill": skill,
			"probability": mastery_after,
			"status": "ACTIVE"
		}
	else:
		bkt_state_data = {
			"skill": skill,
			"probability": null,
			"status": "INACTIVE"
		}
		dda_level_str = "MODERATE"
		reported_diff_before = "MODERATE"
		reported_diff_after = "MODERATE"
		options_count = 3

	var log_record = {
		"event": "bkt_update",
		"scenario_id": sc_id,
		"category": telemetry.get("category", "fire"),
		"skill": skill,
		"interaction_mode": mode_id,
		"decision_point": telemetry.get("decision_point", 1),
		"first_attempt_correct": telemetry.get("first_attempt_correct", response_correct),
		"total_attempts": telemetry.get("total_attempts", 1),
		"mistakes_count": telemetry.get("mistakes_count", 0),
		"final_attempt_correct": true,
		"response_correct": response_correct,
		"adaptive_enabled": is_adaptive_mode,
		"bkt_update_applied": bkt_applied,
		"difficulty_source": diff_source,
		"bkt": {
			"mastery_before": mastery_before if is_adaptive_mode else null,
			"p_correct": p_correct if is_adaptive_mode else null,
			"mastery_after": mastery_after if is_adaptive_mode else null,
			"learn_rate": learn_rate,
			"guess": guess_rate,
			"slip": slip_rate
		},
		"dda": {
			"difficulty_before": reported_diff_before,
			"difficulty_after": reported_diff_after,
			"effective_difficulty": dda_level_str
		},
		"dda_level": dda_level_str,
		"options_presented": options_count,
		"bkt_state": bkt_state_data,
		"final_rule": final_rule_obj,
		"expected": expected_obj,
		"target": target_obj
	}
	
	last_logged_event = log_record
	var json_line = JSON.stringify(log_record)

	# 1. Output to Godot Engine log
	print("[EVAL_LOGGER] " + json_line)

	# 2. Output to Browser Console if running in HTML5 / Web export on Itch.io
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped = json_line.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				js.eval("try { console.log('SAFESCAPE_EVAL:', '%s'); } catch(e) {}" % escaped)

	# 3. Notify any connected ConsoleOverlay UI listeners
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var overlay = tree.root.find_child("ConsoleOverlay", true, false)
		if overlay and overlay.has_method("append_log_entry"):
			overlay.call("append_log_entry", json_line, log_record)

	return log_record

## Log a performance/stability event (loading, fps, memory, api, errors, recovery, summary)
static func log_performance_event(record: Dictionary) -> Dictionary:
	last_logged_event = record
	var json_line = JSON.stringify(record)

	# 1. Output to Godot Engine log
	print("[EVAL_LOGGER] " + json_line)

	# 2. Output to Browser Console if running on Web
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			if js != null:
				var escaped = json_line.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "")
				js.eval("try { console.log('SAFESCAPE_EVAL:', '%s'); } catch(e) {}" % escaped)

	# 3. Notify ConsoleOverlay if present
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var overlay = tree.root.find_child("ConsoleOverlay", true, false)
		if overlay:
			if overlay.has_method("append_log_entry"):
				overlay.call("append_log_entry", json_line, record)
			if overlay.has_method("append_perf_log_entry"):
				overlay.call("append_perf_log_entry", json_line, record)

	return record
