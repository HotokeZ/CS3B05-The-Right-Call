class_name BKTDDAManager
extends RefCounted

## BKT & DDA Adaptive Manager (SafeScape 2.0)
## Closed-loop skill-based Bayesian Knowledge Tracing & Dynamic Difficulty Adjustment.
## Follows Chapter 3 of manuscript & evaluation specifications.

# ── Build Configuration Switch ───────────────────────────────────────────────
# Set ADAPTIVE_MODE = true for Experimental / Adaptive build
# Set ADAPTIVE_MODE = false for Comparison / Non-Adaptive build (fixed Moderate difficulty)
const ADAPTIVE_MODE: bool = true

# Debug console enabled flag for evaluation builds
const DEBUG_CONSOLE_ENABLED: bool = true

# ── BKT Initial & Heuristic Parameters ──────────────────────────────────────
const P_L0: float = 0.40  # Initial Prior Knowledge
const P_T: float  = 0.15  # Learn Rate
const P_G: float  = 0.20  # Guess Rate
const P_S: float  = 0.10  # Slip Rate

# ── Primary Competencies ───────────────────────────────────────────────────
const SKILL_ELECTRICAL: String = "Electrical_Hazard_Recognition"
const SKILL_CHEMICAL: String   = "Chemical_Hazard_Recognition"
const SKILL_EVACUATION: String = "Evacuation_Protocol"
const SKILL_GENERAL_FIRE: String = "General_Fire_Safety"
const SKILL_MEDICAL: String    = "Medical_Response"
const SKILL_POLICE: String     = "Police_Dispatch"

# Standard per-skill mastery dictionary
var _skill_masteries: Dictionary = {
	SKILL_ELECTRICAL: P_L0,
	SKILL_CHEMICAL: P_L0,
	SKILL_EVACUATION: P_L0,
	SKILL_GENERAL_FIRE: P_L0,
	SKILL_MEDICAL: P_L0,
	SKILL_POLICE: P_L0
}

func _init() -> void:
	load_persisted_state()

## Maps arbitrary category, scenario dict, or skill strings to standard competency skill
func normalize_skill_name(raw_skill: Variant) -> String:
	if typeof(raw_skill) == TYPE_DICTIONARY:
		return SafeScapeScenarioSkillMapper.determine_skill(raw_skill)
	var s = String(raw_skill).strip_edges()
	if s.is_empty():
		return SKILL_GENERAL_FIRE
	var lower = s.to_lower()
	if s == SKILL_ELECTRICAL or s == SKILL_CHEMICAL or s == SKILL_EVACUATION or s == SKILL_GENERAL_FIRE or s == SKILL_MEDICAL or s == SKILL_POLICE:
		return s
	if "electric" in lower:
		return SKILL_ELECTRICAL
	elif "chem" in lower:
		return SKILL_CHEMICAL
	elif "evac" in lower:
		return SKILL_EVACUATION
	elif "med" in lower:
		return SKILL_MEDICAL
	elif "crim" in lower or "police" in lower:
		return SKILL_POLICE
	elif "fire" in lower:
		return SKILL_GENERAL_FIRE
	return s

## Retrieve current mastery probability for a given skill
func get_mastery(raw_skill: Variant) -> float:
	var skill = normalize_skill_name(raw_skill)
	if not _skill_masteries.has(skill):
		_skill_masteries[skill] = P_L0
	return float(_skill_masteries[skill])

## Determine deterministic scenario difficulty based ONLY on current skill's BKT mastery.
## Mastery < 0.50 -> EASY
## 0.50 <= Mastery < 0.85 -> MODERATE
## Mastery >= 0.85 -> HARD
func determine_difficulty(raw_skill: Variant, override_mastery: float = -1.0) -> String:
	if not ADAPTIVE_MODE:
		return "MODERATE"
		
	var mastery = override_mastery if override_mastery >= 0.0 else get_mastery(raw_skill)
	if mastery < 0.50:
		return "EASY"
	elif mastery < 0.85:
		return "MODERATE"
	else:
		return "HARD"


## Closed-Loop BKT Update & DDA Selection
func update_skill(raw_skill: Variant, is_correct: bool, mode_id: String = "easy_multiple_choice", day_number: int = 1, telemetry: Dictionary = {}) -> Dictionary:
	var skill = normalize_skill_name(raw_skill)
	var mastery_before = get_mastery(skill)
	var diff_before = determine_difficulty(skill, mastery_before)

	# Safe fallback for telemetry scenario_id if omitted
	if not telemetry.has("scenario_id") or String(telemetry.get("scenario_id", "")).strip_edges() == "":
		telemetry["scenario_id"] = "sc_%s" % skill.to_lower()

	# In non-adaptive mode (comparison condition), difficulty is fixed and BKT state remains inactive
	if not ADAPTIVE_MODE:
		var non_adaptive_log = SafeScapeEvaluationLogger.log_bkt_and_dda_cycle(
			skill,
			is_correct,
			mastery_before,
			0.48,
			mastery_before,
			P_T,
			P_G,
			P_S,
			diff_before,
			diff_before,
			false,
			mode_id,
			day_number,
			telemetry
		)
		return non_adaptive_log
	
	# Likelihoods based on observation
	var p_obs_given_l = (1.0 - P_S) if is_correct else P_S
	var p_obs_given_not_l = P_G if is_correct else (1.0 - P_G)
	
	# P(Correct) expected probability before observation
	var p_correct = (mastery_before * (1.0 - P_S)) + ((1.0 - mastery_before) * P_G)
	
	# Bayes' Rule posterior
	var denominator = (mastery_before * p_obs_given_l) + ((1.0 - mastery_before) * p_obs_given_not_l)
	var p_l_given_obs = 0.5
	if denominator > 0.0:
		p_l_given_obs = (mastery_before * p_obs_given_l) / denominator
		
	# Transition given learning rate
	var mastery_after = p_l_given_obs + (1.0 - p_l_given_obs) * P_T
	mastery_after = clamp(mastery_after, 0.0, 1.0)
	
	# Update internal skill mastery independently for competency
	_skill_masteries[skill] = mastery_after
	
	var diff_after = determine_difficulty(skill, mastery_after)
	
	# Persist state if in adaptive mode
	if ADAPTIVE_MODE:
		save_persisted_state()
		
	# Log evaluation cycle
	var log_record = SafeScapeEvaluationLogger.log_bkt_and_dda_cycle(
		skill,
		is_correct,
		mastery_before,
		p_correct,
		mastery_after,
		P_T,
		P_G,
		P_S,
		diff_before,
		diff_after,
		ADAPTIVE_MODE,
		mode_id,
		day_number,
		telemetry
	)
	
	return log_record

## Load mastery state from localStorage via safe wrapper
func load_persisted_state() -> void:
	var loaded = SafeScapeLocalStorage.load_bkt_state()
	if typeof(loaded) == TYPE_DICTIONARY and not loaded.is_empty():
		for k in loaded.keys():
			var val = float(loaded[k])
			val = clamp(val, 0.0, 1.0)
			_skill_masteries[k] = val
			
	# Ensure default competencies exist
	if not _skill_masteries.has(SKILL_ELECTRICAL): _skill_masteries[SKILL_ELECTRICAL] = P_L0
	if not _skill_masteries.has(SKILL_CHEMICAL): _skill_masteries[SKILL_CHEMICAL] = P_L0
	if not _skill_masteries.has(SKILL_EVACUATION): _skill_masteries[SKILL_EVACUATION] = P_L0
	if not _skill_masteries.has(SKILL_GENERAL_FIRE): _skill_masteries[SKILL_GENERAL_FIRE] = P_L0
	if not _skill_masteries.has(SKILL_MEDICAL): _skill_masteries[SKILL_MEDICAL] = P_L0
	if not _skill_masteries.has(SKILL_POLICE): _skill_masteries[SKILL_POLICE] = P_L0

## Save mastery state to localStorage
func save_persisted_state() -> void:
	SafeScapeLocalStorage.save_bkt_state(_skill_masteries)

## Reset BKT state for evaluation test sessions
func reset_bkt_state() -> Dictionary:
	_skill_masteries = {
		SKILL_ELECTRICAL: P_L0,
		SKILL_CHEMICAL: P_L0,
		SKILL_EVACUATION: P_L0,
		SKILL_GENERAL_FIRE: P_L0,
		SKILL_MEDICAL: P_L0,
		SKILL_POLICE: P_L0
	}
	SafeScapeLocalStorage.reset_bkt_state()
	save_persisted_state()
	var loaded_back = SafeScapeLocalStorage.load_bkt_state()
	SafeScapeEvaluationLogger.log_bkt_reset(_skill_masteries, loaded_back)
	return _skill_masteries.duplicate(true)

