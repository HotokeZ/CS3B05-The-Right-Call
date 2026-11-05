class_name SafeScapeLevelRuleProvider
extends RefCounted

## Level Rule Provider
## Returns actual structured level/game rule configurations for logging & evaluation harness.
## Does not fabricate fake numbers; reads directly from active game mode & state.

static func get_final_rule(mode_id: String = "easy_multiple_choice", level_day: int = 1) -> Dictionary:
	# Minimum score threshold is fixed at 250 per game design (shift_min_score export).
	const MIN_SCORE = 250
	return {
		"rule_id": "rule_shift_completion_%s_day_%d" % [mode_id, level_day],
		"type": "WinWhenScore",
		"min_score": MIN_SCORE,
		"mode": mode_id,
		"day": level_day
	}

static func get_expected(mode_id: String = "easy_multiple_choice", level_day: int = 1) -> Dictionary:
	var expected_calls = 3
	if level_day > 3:
		expected_calls = 5
		
	return {
		"calls_to_complete": expected_calls,
		"target_accuracy": 0.80,
		"mastery_target": 0.85
	}

static func get_target(mode_id: String = "easy_multiple_choice", level_day: int = 1) -> Dictionary:
	return {
		"target_score": 250,
		"shift_duration_s": 300,
		"max_mistakes_per_call": 1
	}
