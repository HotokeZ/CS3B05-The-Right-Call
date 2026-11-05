class_name SafeScapeScenarioSkillMapper
extends RefCounted

## Scenario Skill Mapper for SafeScape 2.0
## Conservative, deterministic classification of scenarios to competency skills.
## Ambiguous fire scenarios map to General_Fire_Safety rather than guessing a formal BKT skill.

const SKILL_ELECTRICAL   := "Electrical_Hazard_Recognition"
const SKILL_CHEMICAL     := "Chemical_Hazard_Recognition"
const SKILL_EVACUATION   := "Evacuation_Protocol"
const SKILL_GENERAL_FIRE := "General_Fire_Safety"
const SKILL_MEDICAL      := "Medical_Response"
const SKILL_POLICE       := "Police_Dispatch"

static func determine_skill(scenario: Dictionary) -> String:
	if scenario.is_empty():
		return SKILL_GENERAL_FIRE

	# 1. Explicit skill override if defined in scenario metadata
	if scenario.has("skill") and String(scenario["skill"]).strip_edges() != "":
		return String(scenario["skill"]).strip_edges()
	if scenario.has("competency") and String(scenario["competency"]).strip_edges() != "":
		return String(scenario["competency"]).strip_edges()

	# 2. Category / type check
	var category = String(scenario.get("category", scenario.get("type", ""))).to_lower()
	var id_str = String(scenario.get("id", "")).to_lower()
	var title = String(scenario.get("title", "")).to_lower()

	# Medical Category
	if category == "medical" or "med_" in id_str or "medical" in id_str:
		return SKILL_MEDICAL

	# Police / Criminal Category
	if category == "police" or category == "criminal" or "crim_" in id_str or "police" in id_str:
		return SKILL_POLICE

	# Combine title and ID for conservative keyword analysis
	var text_to_check = (title + " " + id_str).to_lower()

	# 3. Conservative, explicit competency matching
	# Electrical Hazard Recognition
	if _contains_any(text_to_check, ["overloaded outlet", "exposed electrical", "exposed wire", "short circuit", "faulty wiring", "sparking socket", "electrical connection", "electrical fire", "power strip fire"]):
		return SKILL_ELECTRICAL

	# Chemical Hazard Recognition
	if _contains_any(text_to_check, ["lpg leak", "gas leak", "chemical spill", "toxic fumes", "flammable solvent", "fuel spill", "cylinder leak", "chemical hazard"]):
		return SKILL_CHEMICAL

	# Evacuation Protocol
	if _contains_any(text_to_check, ["trapped occupant", "blocked exit", "evacuation procedure", "escape route", "stairwell evacuation", "occupant extraction", "evacuation protocol"]):
		return SKILL_EVACUATION

	# 4. Conservative Fallback for General / Ambiguous Fire Scenarios
	# (e.g. Kitchen Grease Fire, Trash Can Fire, cooking fires)
	return SKILL_GENERAL_FIRE

static func _contains_any(source_text: String, keywords: Array) -> bool:
	for kw in keywords:
		if source_text.contains(kw):
			return true
	return false
