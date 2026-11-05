extends RefCounted

## Emergency Scenario Generator — NLP-backed edition.
##
## This version tries to call the Python NLP backend (via ``OS.execute()``)
## for scenario generation, hint retrieval, and response evaluation.
## If the backend is unavailable it falls back to the built-in templates.

var _rng := RandomNumberGenerator.new()

# ── Fallback locations (used when backend is unavailable) ───────────
const BACKEND_SCENARIO_BANK_FILENAME := "scenarios_bank_test.json"

# ── Fallback locations (used when backend is unavailable) ───────────
const FIRE_LOCATIONS := [
	"P. Burgos Street, Brgy. Poblacion I",
	"Rizal Avenue, Brgy. Poblacion III",
	"Luna Extension, Brgy. Sto. Angel Norte",
	"Regidor Street, Brgy. Poblacion II"
]

const MEDICAL_LOCATIONS := [
	"Old Market Road, Brgy. Poblacion IV",
	"Barangay Hall Frontage, Brgy. Pagsawitan",
	"Bus Terminal Loading Bay, Brgy. Bubukal",
	"Sports Court Entrance, Brgy. Gatid"
]

const CRIME_LOCATIONS := [
	"Municipal Hall Annex, Brgy. Poblacion I",
	"Public Market Parking Area, Brgy. Poblacion IV",
	"School Perimeter Gate, Brgy. Bagumbayan",
	"Town Plaza Alley, Brgy. Poblacion III"
]

# Temporary A/B test switch: use the new dataset while validating conversation quality.
const LOCAL_SCENARIO_BANK_PATH := "res://backend/scenarios_bank_test.json"
const CURATED_SCENARIO_BANK_PATH := "res://data/gameplay/curated_instruction_scenarios.json"
const RECENT_TEMPLATE_MEMORY := 42
const RECENT_SIGNATURE_MEMORY := 64
const RECENT_SAFE_STRATEGY_MEMORY := 18
const USE_CURATED_SCENARIOS_FOR_TESTING := true

# ── New Scenario Bank (primary source for easy_multiple_choice) ──────
const SCENARIO_BANK_PATH_EN := "res://data/gameplay/new_scenario_bank_basic_en.json"
const SCENARIO_BANK_PATH_TL := "res://data/gameplay/new_scenario_bank_basic_tl.json"
const SCENARIO_BANK_PATH_TAGLISH := "res://data/gameplay/new_scenario_bank_basic_tl_en.json"

var _scenario_bank_loaded_locale: String = ""
var _scenario_bank_templates: Array = []
var _scenario_bank_by_category: Dictionary = {
	"fire": [],
	"medical": [],
	"criminal": []
}

var _curated_loaded_locale: String = ""

var _bank_templates: Array = []
var _bank_locations: Array = []
var _bank_by_category: Dictionary = {
	"fire": [],
	"medical": [],
	"criminal": []
}
var _curated_templates: Array = []
var _curated_by_category: Dictionary = {
	"fire": [],
	"medical": [],
	"criminal": []
}
var _recent_template_ids: Array[String] = []
var _recent_scenario_signatures: Array[String] = []
var _recent_safe_strategy_signatures: Array[String] = []

var _scenario_decks: Dictionary = {}
var _last_played_template_ids: Dictionary = {}
var _last_played_category: String = ""

func _init() -> void:
	_rng.randomize()
	_load_scenario_bank("en")        # New Scenario Bank — highest priority
	_load_curated_scenario_bank("en") # Curated legacy bank — fallback
	_load_local_scenario_bank()       # v2 generated bank — final fallback

# 🛑🛑 Public API 🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑

func get_scenario_by_id(id: String, locale: String = "en", day_number: int = 1) -> Dictionary:
	_load_scenario_bank(locale)
	_load_curated_scenario_bank(locale)
	var target_template: Dictionary = {}
	for template in _scenario_bank_templates:
		if template.get("id", "") == id:
			target_template = template
			break
	if target_template.is_empty():
		for template in _curated_templates:
			if template.get("id", "") == id:
				target_template = template
				break
	if target_template.is_empty():
		for template in _bank_templates:
			if template.get("id", "") == id:
				target_template = template
				break
				
	if not target_template.is_empty():
		var generated = _build_scenario_from_template(target_template, "easy_multiple_choice", locale, day_number)
		if not generated.is_empty():
			generated = _normalize_scenario_for_education(generated)
			generated = _apply_day_option_count(generated, day_number)
			return generated
	return {}

func generate_scenario(mode_id: String = "easy_multiple_choice", locale: String = "en", day_number: int = 1) -> Dictionary:
	_load_scenario_bank(locale)
	_load_curated_scenario_bank(locale)
	print("[Generator] Loaded basic templates count: ", _scenario_bank_templates.size())
	
	# NEW SCENARIO BANK — highest priority for easy_multiple_choice
	if mode_id == "easy_multiple_choice":
		var sb_category = _pick_category_for_day(day_number)
		var sb_template = _pick_from_scenario_bank(sb_category)
		print("[Generator] Picked basic template from bank: ", sb_template.get("id", "None"), " (category: ", sb_category, ")")
		if not sb_template.is_empty():
			var sb_generated = _build_scenario_from_template(sb_template, mode_id, locale, day_number)
			if not sb_generated.is_empty():
				# NOTE: skip _apply_day_option_count for new bank — the display count
				# is already controlled by difficulty in _show_player_choices.
				_last_played_category = sb_generated.get("type", "")
				var sb_id = String(sb_template.get("id", ""))
				if sb_id != "":
					_recent_template_ids.append(sb_id)
					if _recent_template_ids.size() > RECENT_TEMPLATE_MEMORY:
						_recent_template_ids.pop_front()
				return sb_generated

	# CURATED LEGACY BANK — second priority for easy_multiple_choice
	if mode_id == "easy_multiple_choice" and USE_CURATED_SCENARIOS_FOR_TESTING:
		var curated_template = _pick_curated_template_without_repeat(_pick_category_for_day(day_number))
		if not curated_template.is_empty():
			var curated_generated = _build_scenario_from_template(curated_template, mode_id, locale, day_number)
			if not curated_generated.is_empty():
				curated_generated = _normalize_scenario_for_education(curated_generated)
				curated_generated = _apply_day_option_count(curated_generated, day_number)
				_remember_recent_scenario(_scenario_signature(curated_generated))
				_remember_safe_strategy(_safe_strategy_signature_from_template(curated_template))
				var curated_id = String(curated_template.get("id", ""))
				if curated_id != "":
					_recent_template_ids.append(curated_id)
					if _recent_template_ids.size() > RECENT_TEMPLATE_MEMORY:
						_recent_template_ids.pop_front()
				_last_played_category = curated_generated.get("type", "")
				return curated_generated

	# Primary method using local scenario bank (since NLP backend was removed for HTML5)
	var category = _pick_category_for_day(day_number)
	var bank_template = _pick_template_without_repeat(category)
	if not bank_template.is_empty():
		var bank_generated = _build_scenario_from_template(bank_template, mode_id, locale, day_number)
		if not bank_generated.is_empty():
			bank_generated = _normalize_scenario_for_education(bank_generated)
			_last_played_category = bank_generated.get("type", "")
			return _apply_day_option_count(bank_generated, day_number)

	# Final fallback to small built-in templates.
	var severity = _pick_severity_for_day(day_number)

	match category:
		"fire":
			return _apply_day_option_count(_normalize_scenario_for_education(_generate_fire_scenario(mode_id, severity)), day_number)
		"medical":
			return _apply_day_option_count(_normalize_scenario_for_education(_generate_medical_scenario(mode_id, severity)), day_number)
		_:
			return _apply_day_option_count(_normalize_scenario_for_education(_generate_criminal_scenario(mode_id, severity)), day_number)


func evaluate_typed_response(scenario: Dictionary, answer_text: String, _locale: String = "en") -> Dictionary:
	# Use standard keyword matching since NLP backend is deprecated for HTML5 deployment
	var text := answer_text.to_lower()
	var safe_hits = 0
	var unsafe_hits = 0

	for word in scenario.get("safe_keywords", []):
		if text.find(String(word).to_lower()) >= 0:
			safe_hits += 1

	for word in scenario.get("unsafe_keywords", []):
		if text.find(String(word).to_lower()) >= 0:
			unsafe_hits += 1

	if text.find("911") >= 0 or text.find("hotline") >= 0:
		safe_hits += 1

	var score = safe_hits - unsafe_hits
	if score >= 2:
		return {
			"label": "safe",
			"score": score,
			"feedback": "Good dispatch response. You prioritized safety and proper emergency procedure."
		}
	if score < 0:
		return {
			"label": "unsafe",
			"score": score,
			"feedback": "Risky response detected. Re-check the manual and prioritize caller safety first."
		}

	return {
		"label": "uncertain",
		"score": score,
		"feedback": "Partially correct. Clarify safety steps and dispatch instructions for a stronger answer."
	}


func get_hints(scenario: Dictionary, _locale: String = "en") -> Dictionary:
	"""Get hints directly from the scenario options dictionary instead of backend."""
	var result := {}
	var options: Array = scenario.get("options", [])
	for i in range(options.size()):
		var opt = options[i]
		if typeof(opt) == TYPE_DICTIONARY and opt.has("hint"):
			result[str(i)] = opt.get("hint")
	return result

func evaluate_choice(scenario: Dictionary, choice_index: int, _locale: String = "en") -> Dictionary:
	"""Evaluate a multiple-choice selection natively without backend."""
	var options: Array = scenario.get("options", [])
	if choice_index < 0 or choice_index >= options.size():
		return {"label": "unknown", "explanation": "Invalid option."}
	var opt: Dictionary = options[choice_index]
	return {
		"label": opt.get("label", "unknown"),
		"explanation": opt.get("explanation", opt.get("feedback", ""))
	}


# ── Internal helpers (unchanged fallback logic) ─────────────────────


# ── Shared JSON bank loader ───────────────────────────────────────────────────
# Returns the raw parsed Dictionary from a scenario JSON file, or {} on failure.
func _read_scenario_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# ── New Scenario Bank loader ────────────────────────────────────────────────
func _load_scenario_bank(locale: String = "en") -> void:
	if _scenario_bank_loaded_locale == locale and not _scenario_bank_templates.is_empty():
		return
	_scenario_bank_templates.clear()
	_scenario_bank_by_category = {"fire": [], "medical": [], "criminal": []}

	var path_map: Dictionary = {
		"en": SCENARIO_BANK_PATH_EN,
		"tl": SCENARIO_BANK_PATH_TL,
		"taglish": SCENARIO_BANK_PATH_TAGLISH
	}
	var path: String = path_map.get(locale, SCENARIO_BANK_PATH_EN)
	var parsed = _read_scenario_json(path)
	if parsed.is_empty() and locale != "en":
		parsed = _read_scenario_json(SCENARIO_BANK_PATH_EN)
	if parsed.is_empty():
		return

	_scenario_bank_loaded_locale = locale
	var templates = parsed.get("scenarios", [])
	if typeof(templates) != TYPE_ARRAY:
		return
	for raw in templates:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = raw
		var category = String(template.get("category", template.get("type", "fire")))
		if category == "police":
			category = "criminal"
		if not _scenario_bank_by_category.has(category):
			_scenario_bank_by_category[category] = []
		_scenario_bank_templates.append(template)
		var bucket: Array = _scenario_bank_by_category[category]
		bucket.append(template)

func _pick_from_scenario_bank(category: String) -> Dictionary:
	var pool: Array = _scenario_bank_by_category.get(category, [])
	if pool.is_empty():
		pool = _scenario_bank_templates
	if pool.is_empty():
		return {}
		
	# Filter out the tutorial grease fire scenarios
	var filtered_pool: Array = []
	for template in pool:
		var tid = String(template.get("id", ""))
		if tid != "new_sb_fire_basic_001" and tid != "new_sb_fire_basic_001_tl" and tid != "new_sb_fire_basic_001_tl_en":
			filtered_pool.append(template)
	if filtered_pool.is_empty():
		filtered_pool = pool
		
	var deck_key = "sb_" + category
	return _get_next_from_deck(deck_key, filtered_pool)

func _load_local_scenario_bank() -> void:

	var parsed = _read_scenario_json(LOCAL_SCENARIO_BANK_PATH)
	if parsed.is_empty():
		return
	_bank_locations = parsed.get("locations_ph", [])
	var templates = parsed.get("scenarios", [])
	if typeof(templates) != TYPE_ARRAY:
		return
	for raw in templates:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = raw
		var category = String(template.get("category", template.get("type", "fire")))
		if category == "police":
			category = "criminal"
		if category == "natural_disaster":
			category = "fire"
		if not _bank_by_category.has(category):
			continue
		_bank_templates.append(template)
		var bucket: Array = _bank_by_category.get(category, [])
		bucket.append(template)
		_bank_by_category[category] = bucket

func _load_curated_scenario_bank(locale: String = "en") -> void:
	if _curated_loaded_locale == locale and not _curated_templates.is_empty():
		return
		
	_curated_templates.clear()
	_curated_by_category.clear()
	
	var path = "res://data/gameplay/curated_scenarios_ph_v2_" + locale + ".json"
	var parsed = _read_scenario_json(path)
	if parsed.is_empty():
		path = "res://data/gameplay/curated_scenarios_ph_v2_en.json"
		parsed = _read_scenario_json(path)
	if parsed.is_empty():
		return
		
	_curated_loaded_locale = locale
	var templates = parsed.get("scenarios", [])
	if typeof(templates) != TYPE_ARRAY:
		return
	for raw in templates:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = raw
		var category = String(template.get("category", template.get("type", "fire")))
		if not _curated_by_category.has(category):
			_curated_by_category[category] = []
		_curated_templates.append(template)
		var bucket: Array = _curated_by_category[category]
		bucket.append(template)

func _pick_category_for_day(day_number: int = 1) -> String:
	var day = max(1, day_number)
	var fire_cutoff = max(28, 42 - ((day - 1) * 2))
	var medical_cutoff = min(82, fire_cutoff + 31)
	
	for attempt in range(10):
		var roll = _rng.randi_range(0, 99)
		var chosen = ""
		if roll < fire_cutoff:
			chosen = "fire"
		elif roll < medical_cutoff:
			chosen = "medical"
		else:
			chosen = "criminal"
			
		if chosen == _last_played_category and attempt < 9:
			continue
		return chosen
		
	var fallback_options = ["fire", "medical", "criminal"]
	fallback_options.erase(_last_played_category)
	if fallback_options.size() > 0:
		return fallback_options[_rng.randi_range(0, fallback_options.size() - 1)]
	return "medical"

func _pick_severity_for_day(day_number: int = 1) -> String:
	var day = max(1, day_number)
	var low_weight = max(10, 40 - ((day - 1) * 4))
	var medium_weight = min(65, 38 + ((day - 1) * 2))
	var roll = _rng.randi_range(0, 99)
	if roll < low_weight:
		return "low"
	if roll < low_weight + medium_weight:
		return "medium"
	return "high"

func _severity_rank(severity: String) -> int:
	match severity:
		"low":
			return 0
		"extreme":
			return 3
		"high":
			return 2
		_:
			return 1

func _max_severity(a: String, b: String) -> String:
	return a if _severity_rank(a) >= _severity_rank(b) else b

func _scenario_signature(scenario: Dictionary) -> String:
	var kind = String(scenario.get("type", "unknown")).to_lower()
	var template_id = String(scenario.get("template_id", "")).to_lower()
	var title = String(scenario.get("title", "")).to_lower().strip_edges()
	var incident_key = template_id if template_id != "" else "%s|%s" % [kind, title]
	return "%s|%s" % [kind, incident_key]

func _remember_recent_scenario(signature: String) -> void:
	if signature == "":
		return
	_recent_scenario_signatures.append(signature)
	if _recent_scenario_signatures.size() > RECENT_SIGNATURE_MEMORY:
		_recent_scenario_signatures.pop_front()

func _safe_strategy_signature_from_template(template: Dictionary) -> String:
	var options: Array = template.get("options", [])
	for raw_opt in options:
		if typeof(raw_opt) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = raw_opt
		if String(opt.get("label", "")).to_lower() == "safe":
			return _normalize_option_text(String(opt.get("text", "")))
	return String(template.get("id", "unknown_safe_strategy"))

func _remember_safe_strategy(signature: String) -> void:
	if signature == "":
		return
	_recent_safe_strategy_signatures.append(signature)
	if _recent_safe_strategy_signatures.size() > RECENT_SAFE_STRATEGY_MEMORY:
		_recent_safe_strategy_signatures.pop_front()

# Normalize an option text to a compact, lowercase token for signature matching.
func _normalize_option_text(raw: String) -> String:
	var text = raw.to_lower().strip_edges()
	for ch in [",", ".", ";", ":", "!", "?", "\"", "'", "-", "(", ")", "[", "]"]:
		text = text.replace(ch, " ")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")
	return text

func _get_template_id(template: Dictionary) -> String:
	return String(template.get("id", ""))

func _build_shuffled_deck(pool: Array, last_played_id: String) -> Array:
	var deck: Array = []
	for template in pool:
		deck.append(template)
		deck.append(template)
	
	if deck.is_empty():
		return deck
		
	var max_attempts = 100
	var valid_deck = false
	for attempt in range(max_attempts):
		deck.shuffle()
		valid_deck = true
		
		# In Godot, pop_back() gets the last element, so deck.back() is drawn first.
		if last_played_id != "" and deck.size() > 0 and _get_template_id(deck.back()) == last_played_id:
			valid_deck = false
			continue
			
		for i in range(1, deck.size()):
			if _get_template_id(deck[i]) == _get_template_id(deck[i-1]):
				valid_deck = false
				break
				
		if valid_deck:
			break
			
	if not valid_deck and deck.size() > 2:
		# Fallback: forcefully separate adjacent duplicates
		for i in range(1, deck.size()):
			if _get_template_id(deck[i]) == _get_template_id(deck[i-1]):
				for j in range(deck.size()):
					if i != j and i-1 != j:
						var j_id = _get_template_id(deck[j])
						var safe_left = true
						var safe_right = true
						if i > 0 and _get_template_id(deck[i-1]) == j_id: safe_left = false
						if i < deck.size()-1 and _get_template_id(deck[i+1]) == j_id: safe_right = false
						
						var i_id = _get_template_id(deck[i])
						var j_safe_left = true
						var j_safe_right = true
						if j > 0 and _get_template_id(deck[j-1]) == i_id: j_safe_left = false
						if j < deck.size()-1 and _get_template_id(deck[j+1]) == i_id: j_safe_right = false
						
						if safe_left and safe_right and j_safe_left and j_safe_right:
							var temp = deck[i]
							deck[i] = deck[j]
							deck[j] = temp
							break
							
	return deck

func _get_next_from_deck(deck_key: String, pool: Array) -> Dictionary:
	if not _scenario_decks.has(deck_key) or _scenario_decks[deck_key].is_empty():
		var last_played = _last_played_template_ids.get(deck_key, "")
		_scenario_decks[deck_key] = _build_shuffled_deck(pool, last_played)
		
	if _scenario_decks[deck_key].is_empty():
		return {}
		
	var template = _scenario_decks[deck_key].pop_back()
	_last_played_template_ids[deck_key] = _get_template_id(template)
	return template

func _pick_curated_template_without_repeat(category: String) -> Dictionary:
	var pool: Array = _curated_by_category.get(category, [])
	if pool.is_empty():
		pool = _curated_templates
	if pool.is_empty():
		return {}

	var deck_key = "curated_" + category
	return _get_next_from_deck(deck_key, pool)

func _pick_template_without_repeat(category: String) -> Dictionary:
	var pool: Array = _bank_by_category.get(category, [])
	if pool.is_empty():
		pool = _bank_templates
	if pool.is_empty():
		return {}

	# Filter out the tutorial grease fire scenarios
	var filtered_pool: Array = []
	for template in pool:
		var tid = String(template.get("id", ""))
		if tid != "new_sb_fire_basic_001" and tid != "new_sb_fire_basic_001_tl" and tid != "new_sb_fire_basic_001_tl_en":
			filtered_pool.append(template)
	if filtered_pool.is_empty():
		filtered_pool = pool

	var deck_key = "bank_" + category
	var picked: Dictionary = _get_next_from_deck(deck_key, filtered_pool)
	var picked_id = String(picked.get("id", ""))
	if picked_id != "":
		_recent_template_ids.append(picked_id)
		if _recent_template_ids.size() > RECENT_TEMPLATE_MEMORY:
			_recent_template_ids.pop_front()
	_remember_recent_scenario(_scenario_signature({
		"type": String(picked.get("category", picked.get("type", "unknown"))),
		"template_id": picked_id,
		"title": String(picked.get("title", ""))
	}))
	return picked

func _pick_bank_location(template: Dictionary) -> String:
	var location = String(template.get("location", "")).strip_edges()
	if location != "":
		return location
	if not _bank_locations.is_empty():
		return String(_bank_locations[_rng.randi_range(0, _bank_locations.size() - 1)])
	return "Santa Cruz center"

func _build_scenario_from_template(template: Dictionary, mode_id: String, locale: String, day_number: int) -> Dictionary:
	if template.is_empty():
		return {}

	var category = String(template.get("category", template.get("type", "fire")))
	if category == "natural_disaster":
		category = "fire"
	var location = _pick_bank_location(template)
	var base_severity = String(template.get("severity", "medium"))
	var severity = _max_severity(base_severity, _pick_severity_for_day(day_number))

	var transcript: Array = []
	var transcript_key = "transcript_" + locale
	if locale == "taglish":
		transcript_key = "transcript_tl_en"
		
	var transcript_src: Array = template.get(transcript_key, [])
	if transcript_src.is_empty():
		transcript_src = template.get("transcript_en", [])
	if transcript_src.is_empty():
		transcript_src = template.get("transcript", [])
		
	for raw_line in transcript_src:
		if typeof(raw_line) == TYPE_DICTIONARY:
			var line = raw_line
			# Options-based 911 turns (new Scenario Bank format) — preserve as-is
			if line.has("options"):
				var raw_opts: Array = line.get("options", [])
				var resolved_opts: Array = []
				for raw_opt in raw_opts:
					if typeof(raw_opt) == TYPE_DICTIONARY:
						resolved_opts.append(raw_opt)
				transcript.append({
					"speaker": String(line.get("speaker", "911")),
					"options": resolved_opts
				})
			else:
				var line_text = String(line.get("text", "")).replace("{location}", location)
				transcript.append({
					"speaker": String(line.get("speaker", "Caller")),
					"text": line_text
				})
		elif typeof(raw_line) == TYPE_STRING:
			var line_str: String = String(raw_line).replace("{location}", location)
			var speaker := "Caller"
			var text_part := line_str
			var sep_idx = line_str.find(":")
			if sep_idx > 0:
				speaker = line_str.substr(0, sep_idx).strip_edges()
				text_part = line_str.substr(sep_idx + 1).strip_edges()
			transcript.append({
				"speaker": speaker,
				"text": text_part
			})

	var options: Array = []
	if mode_id != "professional_nlp_dispatch":
		var shuffled_options: Array = template.get("options", []).duplicate(true)
		shuffled_options.shuffle()
		for raw_opt in shuffled_options:
			if typeof(raw_opt) != TYPE_DICTIONARY:
				continue
			var opt: Dictionary = raw_opt
			options.append({
				"text": String(opt.get("text", "Follow dispatcher instructions and stay safe.")),
				"label": String(opt.get("label", "uncertain")),
				"hint": String(opt.get("hint", "Think about what keeps everyone safest.")),
				"explanation": String(opt.get("explanation", opt.get("feedback", ""))),
				"feedback": String(opt.get("feedback", opt.get("explanation", ""))),
				"dda_role": String(opt.get("dda_role", ""))
			})

		# New test banks may omit explicit options and provide metadata fields instead.
		if options.is_empty():
			options = _build_options_from_metadata(template, category)

	var recommended_map = {
		"fire": "fire_truck",
		"medical": "ambulance",
		"criminal": "police"
	}
	var raw_recommended = String(template.get("recommended_vehicle", recommended_map.get(category, "ambulance"))).to_lower()
	var normalized_recommended = raw_recommended
	if raw_recommended == "police_mobile":
		normalized_recommended = "police"
	elif raw_recommended == "firetruck":
		normalized_recommended = "fire_truck"
	elif raw_recommended == "ems":
		normalized_recommended = "ambulance"

	return {
		"id": "%s_%d" % [String(template.get("id", "fallback")), _rng.randi()],
		"template_id": String(template.get("id", "fallback")),
		"mode": mode_id,
		"type": category,
		"severity": severity,
		"title": String(template.get("title", "Emergency Incident")),
		"location": location,
		"recommended_vehicle": normalized_recommended,
		"transcript": transcript,
		"options": options,
		"safe_keywords": template.get("safe_keywords", []),
		"unsafe_keywords": template.get("unsafe_keywords", []),
		"locale": locale
	}

func _build_options_from_metadata(template: Dictionary, category: String) -> Array:
	var built: Array = []
	var acceptable: Array = template.get("acceptable_phrasings", [])
	var misses: Array = template.get("critical_misses", [])

	for phr_any in acceptable:
		if typeof(phr_any) != TYPE_STRING:
			continue
		var phr = String(phr_any).strip_edges()
		if phr == "":
			continue
		built.append({
			"text": phr,
			"label": "safe",
			"hint": "Choose the response that protects life safety and keeps the caller secure.",
			"explanation": "This aligns with safe dispatch protocol for the incident.",
			"feedback": "Good call: this response supports safe and professional handling."
		})

	for miss_any in misses:
		if typeof(miss_any) != TYPE_STRING:
			continue
		var miss = String(miss_any).strip_edges()
		if miss == "":
			continue
		built.append({
			"text": "Avoid this: %s" % miss,
			"label": "unsafe",
			"hint": "Avoid options that escalate risk or violate emergency protocol.",
			"explanation": "This action is explicitly flagged as a critical miss.",
			"feedback": "Unsafe: this response can increase danger or delay proper aid."
		})

	if built.is_empty():
		# Last-resort defaults to guarantee selectable choices in easy mode.
		built.append({
			"text": "Confirm exact location and keep the caller in a safe place.",
			"label": "safe",
			"hint": "Start with location and immediate safety.",
			"explanation": "Location and safety confirmation are essential first steps.",
			"feedback": "Good protocol start."
		})
		built.append(_build_generic_distractor(category, 0))

	return built

func _normalize_scenario_for_education(scenario: Dictionary) -> Dictionary:
	if scenario.is_empty():
		return scenario

	var normalized: Dictionary = scenario.duplicate(true)
	var incident_type = String(normalized.get("type", "")).to_lower()
	if incident_type == "fire":
		_normalize_fire_inside_perspective(normalized)
		_normalize_fire_response_consistency(normalized)
	elif incident_type == "criminal":
		_normalize_criminal_cover_dialogue(normalized)

	var options: Array = normalized.get("options", [])
	for i in range(options.size()):
		if typeof(options[i]) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = options[i]
		if String(opt.get("hint", "")).strip_edges() == "":
			opt["hint"] = "Think about what keeps everyone safest while responders travel to the scene."
		options[i] = opt
	normalized["options"] = options
	return normalized

func _target_option_count_for_day(day_number: int) -> int:
	var day = max(1, day_number)
	if day <= 3:
		return 2
	if day <= 7:
		return 3
	if day <= 10:
		return 4
	return 5

func _build_generic_distractor(incident_type: String, variant_index: int) -> Dictionary:
	var key = String(incident_type).to_lower()
	var fire_texts = [
		"Rush back inside right now to save kitchen items before responders arrive.",
		"Open all doors and windows immediately to feed the smoke out faster.",
		"Have neighbors carry flammable items near the fire outside."
	]
	var medical_texts = [
		"Tell the patient to stand quickly and walk it off while waiting.",
		"Give any available pain medicine before assessing allergies.",
		"Leave the patient alone and continue normal activity nearby."
	]
	var criminal_texts = [
		"Approach the suspect directly and demand they surrender.",
		"Ask nearby bystanders to chase and detain suspects.",
		"Delay reporting details until the situation calms down on its own."
	]

	var option_text = "Take actions that are not verified by safety protocol."
	match key:
		"fire":
			option_text = fire_texts[variant_index % fire_texts.size()]
		"medical":
			option_text = medical_texts[variant_index % medical_texts.size()]
		"criminal":
			option_text = criminal_texts[variant_index % criminal_texts.size()]

	return {
		"text": option_text,
		"label": "unsafe",
		"hint": "Choose the action that protects life and avoids extra risk while professionals travel.",
		"explanation": "This action introduces preventable danger. Dispatch guidance should reduce risk and keep everyone safe.",
		"feedback": "Unsafe guidance: choose the option that preserves safety while responders are en route."
	}

func _apply_day_option_count(scenario: Dictionary, day_number: int) -> Dictionary:
	if scenario.is_empty():
		return scenario

	var adjusted: Dictionary = scenario.duplicate(true)
	var options: Array = adjusted.get("options", [])
	if options.is_empty():
		return adjusted

	var desired = _target_option_count_for_day(day_number)
	var safe_options: Array = []
	var other_options: Array = []
	for raw_opt in options:
		if typeof(raw_opt) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = raw_opt
		if String(opt.get("label", "")).to_lower() == "safe":
			safe_options.append(opt)
		else:
			other_options.append(opt)

	var picked: Array = []
	if not safe_options.is_empty():
		safe_options.shuffle()
		picked.append(safe_options[0])
	else:
		other_options.shuffle()
		if not other_options.is_empty():
			picked.append(other_options.pop_front())

	other_options.shuffle()
	for opt in other_options:
		if picked.size() >= desired:
			break
		picked.append(opt)

	while picked.size() < desired:
		picked.append(_build_generic_distractor(String(adjusted.get("type", "fire")), picked.size()))

	if picked.size() > desired:
		picked.resize(desired)
	picked.shuffle()
	adjusted["options"] = picked
	return adjusted

func _normalize_fire_inside_perspective(scenario: Dictionary) -> void:
	var title = String(scenario.get("title", ""))
	var transcript: Array = scenario.get("transcript", [])
	if transcript.is_empty():
		return

	var needs_inside_view = title.to_lower().find("window") >= 0
	if not needs_inside_view:
		for line in transcript:
			if typeof(line) != TYPE_DICTIONARY:
				continue
			var text = String((line as Dictionary).get("text", "")).to_lower()
			if text.find("smoke pouring out") >= 0 or text.find("apartment window") >= 0:
				needs_inside_view = true
				break

	if not needs_inside_view:
		return

	var location = String(scenario.get("location", "your location"))
	scenario["title"] = "Possible Apartment Fire (Caller Inside)"

	var revised: Array = [
		{"speaker": "911", "text": "911, can you confirm your location?"},
		{"speaker": "Caller", "text": "Help! I think our apartment is burning at %s!" % location},
		{"speaker": "911", "text": "Why do you think it is burning?"},
		{"speaker": "Caller", "text": "There is a strong burning smell and smoke is coming into my room."},
		{"speaker": "911", "text": "Leave the unit immediately if it is safe, close doors behind you, and stay on the line."},
		{"speaker": "Caller", "text": "Okay, we are moving out now. Please send help fast."}
	]
	scenario["transcript"] = revised

func _normalize_fire_response_consistency(scenario: Dictionary) -> void:
	var transcript: Array = scenario.get("transcript", [])
	if transcript.is_empty():
		return

	var text_blob = String(scenario.get("title", "")).to_lower()
	for line in transcript:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		text_blob += " " + String((line as Dictionary).get("text", "")).to_lower()

	var caller_already_outside = text_blob.find("some people are out") >= 0 or text_blob.find("already outside") >= 0 or text_blob.find("we are outside") >= 0 or text_blob.find("evacuated") >= 0
	var severe_fire = text_blob.find("getting bigger") >= 0 or text_blob.find("spreading") >= 0 or text_blob.find("thick black smoke") >= 0 or text_blob.find("massive") >= 0 or text_blob.find("strong burning smell") >= 0

	var options: Array = scenario.get("options", [])
	for i in range(options.size()):
		if typeof(options[i]) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = options[i]
		var opt_text = String(opt.get("text", "")).to_lower()

		if caller_already_outside and opt_text.find("evacuate") >= 0:
			opt["text"] = "Keep everyone outside, move farther from smoke, and wait for firefighters."
			opt["explanation"] = "Since occupants are already out, keep everyone at a safe distance and let firefighters handle suppression."
			opt["feedback"] = "Correct: keep everyone outside and away from smoke."
			opt["label"] = "safe"

		if severe_fire and (opt_text.find("smother") >= 0 or opt_text.find("turn off heat") >= 0 or opt_text.find("metal lid") >= 0):
			opt["text"] = "Evacuate immediately, close doors behind you if safe, and wait for firefighters outside."
			opt["explanation"] = "If fire is already spreading, evacuation is safer than trying to suppress it directly."
			opt["feedback"] = "Correct: prioritize evacuation and professional response."
			opt["label"] = "safe"

		options[i] = opt

	var safe_keywords: Array = scenario.get("safe_keywords", [])
	for kw in ["evacuate", "outside", "safe distance", "wait for firefighters"]:
		if not safe_keywords.has(kw):
			safe_keywords.append(kw)
	scenario["safe_keywords"] = safe_keywords
	scenario["options"] = options

func _normalize_criminal_cover_dialogue(scenario: Dictionary) -> void:
	var transcript: Array = scenario.get("transcript", [])
	if transcript.is_empty():
		return

	var has_cover_statement := false
	var has_confront_question := false
	var do_not_confront_idx := -1

	for i in range(transcript.size()):
		if typeof(transcript[i]) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = transcript[i]
		var speaker = String(line.get("speaker", "")).to_lower()
		var text_lower = String(line.get("text", "")).to_lower()
		if speaker == "caller":
			if text_lower.find("taking cover") >= 0 or text_lower.find("behind cover") >= 0 or text_lower.find("stay hidden") >= 0 or text_lower.find("hiding") >= 0:
				has_cover_statement = true
			if text_lower.find("confront") >= 0 or text_lower.find("stop them") >= 0:
				has_confront_question = true
		elif speaker == "911":
			if text_lower.find("do not confront") >= 0 or text_lower.find("don't confront") >= 0:
				do_not_confront_idx = i

	if has_cover_statement and do_not_confront_idx >= 0 and typeof(transcript[do_not_confront_idx]) == TYPE_DICTIONARY:
		var updated_line: Dictionary = transcript[do_not_confront_idx]
		updated_line["text"] = "Good, it is important that you stay hidden. Do not confront the suspect."
		transcript[do_not_confront_idx] = updated_line

	if has_cover_statement and not has_confront_question:
		var insert_at = do_not_confront_idx + 1
		if insert_at <= 0 or insert_at > transcript.size():
			insert_at = transcript.size()
		transcript.insert(insert_at, {"speaker": "Caller", "text": "Should we try to confront them if they run?"})
		transcript.insert(insert_at + 1, {"speaker": "911", "text": "No. Do not confront them. Stay hidden, protect everyone nearby, and keep giving me updates from a safe place."})

	scenario["transcript"] = transcript

func _generate_fire_scenario(mode_id: String, severity: String) -> Dictionary:
	var location = FIRE_LOCATIONS[_rng.randi_range(0, FIRE_LOCATIONS.size() - 1)]
	var transcript = [
		{"speaker": "911", "text": "911, what is the address of your emergency?"},
		{"speaker": "Caller", "text": "%s! We have flames from a pan in the kitchen!" % location},
		{"speaker": "911", "text": "Is everyone clear from the hot stove area?"},
		{"speaker": "Caller", "text": "Yes, but the fire is still visible and we are scared."},
		{"speaker": "911", "text": "Do not use water. I am dispatching a fire unit while I guide you."},
		{"speaker": "Caller", "text": "Okay, tell me what to do next."}
	]

	var options = [
		{
			"text": "Throw water on the pan quickly.",
			"label": "unsafe",
			"hint": "Think about what happens when water meets very hot oil — it can actually make the fire MUCH bigger! 💦🔥",
			"explanation": "Water causes hot grease to splatter everywhere and the fire explodes outward. Never use water on burning oil!",
			"feedback": "Unsafe: water spreads grease fires."
		},
		{
			"text": "Keep people back, call 911, and smother with a lid if safe.",
			"label": "safe",
			"hint": "Fire needs air to keep burning. What happens if you block the air from reaching the flames? 🕯️✅",
			"explanation": "Covering the pan with a lid cuts off the oxygen supply. Without air, the fire goes out. Great job! 🎉",
			"feedback": "Correct: protect people and smother safely."
		},
		{
			"text": "Move the burning pan to the sink.",
			"label": "unsafe",
			"hint": "Moving something that is on fire is very risky — you could get burned or spread the fire! 🌬️⚠️",
			"explanation": "Carrying a burning pan is extremely dangerous. Hot oil can splash causing severe burns.",
			"feedback": "Unsafe: carrying a burning pan can spread fire."
		}
	]

	return {
		"id": "fire_%d" % _rng.randi(),
		"template_id": "grease_fire",
		"mode": mode_id,
		"type": "fire",
		"severity": severity,
		"title": "Kitchen Fire Report",
		"location": location,
		"recommended_vehicle": "fire_truck",
		"transcript": transcript,
		"options": options,
		"safe_keywords": ["evacuate", "lid", "smother", "call 911", "extinguisher"],
		"unsafe_keywords": ["water", "move pan", "pick up pan"]
	}

func _generate_medical_scenario(mode_id: String, severity: String) -> Dictionary:
	var location = MEDICAL_LOCATIONS[_rng.randi_range(0, MEDICAL_LOCATIONS.size() - 1)]
	var symptom = ["heavy bleeding", "difficulty breathing", "unconscious after collapse"][_rng.randi_range(0, 2)]
	var transcript = [
		{"speaker": "911", "text": "911, what is your emergency location?"},
		{"speaker": "Caller", "text": "At %s. Someone has %s!" % [location, symptom]},
		{"speaker": "911", "text": "Stay calm and keep the patient safe. Is the patient breathing?"},
		{"speaker": "Caller", "text": "Yes, but weak. We need help fast."},
		{"speaker": "911", "text": "Medical team is being dispatched now. Keep the area clear."}
	]

	var options = [
		{
			"text": "Move the patient immediately without support.",
			"label": "unsafe",
			"hint": "Moving someone who is hurt could make hidden injuries much worse! 🤕⚠️",
			"explanation": "Unnecessary movement during trauma can worsen injuries. Keep the patient stable.",
			"feedback": "Unsafe: avoid unnecessary movement during trauma."
		},
		{
			"text": "Call 911, monitor breathing, and keep patient stable.",
			"label": "safe",
			"hint": "Keeping the patient stable while waiting for help is exactly what doctors recommend! 🏥✅",
			"explanation": "Monitoring breathing and keeping the patient stable is textbook first aid! 🎉",
			"feedback": "Correct: monitor and stabilize while waiting for EMS."
		},
		{
			"text": "Give random medicine from nearby stores.",
			"label": "unsafe",
			"hint": "Giving unknown medicine to someone could make things worse or cause an allergic reaction! 💊❌",
			"explanation": "Never give unknown medication. Only trained medical professionals should administer drugs.",
			"feedback": "Unsafe: do not administer unknown medication."
		}
	]

	return {
		"id": "medical_%d" % _rng.randi(),
		"template_id": "heavy_bleeding",
		"mode": mode_id,
		"type": "medical",
		"severity": severity,
		"title": "Medical Emergency",
		"location": location,
		"recommended_vehicle": "ambulance",
		"transcript": transcript,
		"options": options,
		"safe_keywords": ["ambulance", "breathing", "stable", "call 911", "first aid"],
		"unsafe_keywords": ["leave", "ignore", "random medicine"]
	}

func _generate_criminal_scenario(mode_id: String, severity: String) -> Dictionary:
	var location = CRIME_LOCATIONS[_rng.randi_range(0, CRIME_LOCATIONS.size() - 1)]
	var incident = ["armed threat", "active break-in", "violent disturbance"][_rng.randi_range(0, 2)]
	var transcript = [
		{"speaker": "911", "text": "911, what is your location?"},
		{"speaker": "Caller", "text": "%s. We have an %s happening now!" % [location, incident]},
		{"speaker": "911", "text": "Good, it is important that you stay hidden. Do not confront suspects."},
		{"speaker": "Caller", "text": "Understood. We are staying behind cover."},
		{"speaker": "911", "text": "Police response is on the way. Keep this line open."}
	]

	var options = [
		{
			"text": "Tell bystanders to confront the suspect.",
			"label": "unsafe",
			"hint": "Confronting someone who is dangerous puts everyone at extreme risk! 🛡️⚠️",
			"explanation": "Never confront an armed or dangerous person. This could escalate to serious injury.",
			"feedback": "Unsafe: avoid civilian confrontation."
		},
		{
			"text": "Keep everyone sheltered and dispatch police support.",
			"label": "safe",
			"hint": "Keeping yourself and others safe while calling for trained help is the smartest move! 🦸✅",
			"explanation": "Staying sheltered and dispatching police is exactly the right call! 🎉",
			"feedback": "Correct: prioritize shelter and law enforcement response."
		},
		{
			"text": "Ignore it and wait for updates.",
			"label": "unsafe",
			"hint": "If nobody reports what's happening, no help will come for anyone in danger! 📞⚠️",
			"explanation": "Not reporting a crime means others could be hurt. Always call for help.",
			"feedback": "Unsafe: immediate reporting and response are required."
		}
	]

	return {
		"id": "crime_%d" % _rng.randi(),
		"template_id": "robbery_in_progress",
		"mode": mode_id,
		"type": "criminal",
		"severity": severity,
		"title": "Public Safety Incident",
		"location": location,
		"recommended_vehicle": "police",
		"transcript": transcript,
		"options": options,
		"safe_keywords": ["police", "shelter", "safe distance", "call 911"],
		"unsafe_keywords": ["confront", "fight", "ignore"]
	}


# LLM generation moved to Gemini API client in route_scene.gd
