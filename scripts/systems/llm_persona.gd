extends RefCounted

## LLM Persona — Gemini API configuration and system prompt builder.
##
## Centralises all AI-related constants (API key, model, temperature) and
## the full system prompt so route_scene.gd stays focused on gameplay logic.
##
## Usage:
##   var _llm_persona := LLMPersona.new()
##   var sys  := _llm_persona.build_system_prompt(params)
##   var user := _llm_persona.build_user_message(dispatcher_text, lang_instruction)
##   var lang := _llm_persona.lang_instruction_for(locale)
##   var tips := _llm_persona.dispatcher_tips()

# ── Gemini API config ────────────────────────────────────────────────────────────
# API Key is intentionally left empty for security / GitHub Pages public deployment.
# Configure via backend proxy or runtime environment.
const GEMINI_API_KEY  : String = ""
const GEMINI_MODEL    : String = "gemini-3.1-flash-lite"
const GEMINI_ENDPOINT : String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key="
const TEMPERATURE   : float  = 0.5
const MAX_TOKENS    : int    = 1000

# ── HTTP headers ───────────────────────────────────────────────────────────────
func http_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json"
	])

# ── Language instruction ───────────────────────────────────────────────────────
## Returns the locale-specific language rule injected into the prompt.
func lang_instruction_for(locale: String) -> String:
	match locale:
		"tl":
			return "CRITICAL REQUIREMENT: The caller must ALWAYS reply in Tagalog (Filipino). Do NOT speak English in your \"caller_reply\"."
		"taglish":
			return "CRITICAL REQUIREMENT: The caller must ALWAYS reply in Taglish (a natural, conversational mix of Tagalog and English). Ensure the \"caller_reply\" sounds like a real person from the Philippines."
		_:
			return "CRITICAL REQUIREMENT: YOU MUST REPLY EXCLUSIVELY IN ENGLISH. DO NOT USE ANY TAGALOG OR TAGLISH UNDER ANY CIRCUMSTANCES IN YOUR \"caller_reply\". IF THE BACKSTORY CONTAINS TAGALOG, TRANSLATE IT TO ENGLISH FOR YOUR REPLY."

# ── Perfectionist-mode addendum ────────────────────────────────────────────────
## Returns the extra constraint injected when Perfectionist Mode is active.
## Pass wrong_advice_count = 0 when it is not relevant.
func perfectionist_rules(wrong_advice_count: int) -> String:
	return (
		"CRITICAL RULE (PERFECTIONIST MODE): The dispatcher MUST provide correct "
		+ "procedural or safety advice to get the caller out of harm's way BEFORE "
		+ "you can set 'ready_for_dispatch' to true. Gathering information alone is "
		+ "NOT enough to unlock dispatch. If the dispatcher gives 'unsafe' or "
		+ "'uncertain' advice, the caller must become progressively frustrated and "
		+ "angry in 'caller_reply' (this is wrong advice attempt %d). If they give "
		+ "safe, correct advice that gets the caller out of harm's way, the caller "
		+ "calms down and you must set 'ready_for_dispatch' to true."
	) % wrong_advice_count

# ── System prompt builder ──────────────────────────────────────────────────────
## Build the complete system prompt from runtime context.
##
## Required keys in @params:
##   scenario_backstory : String  — formatted transcript lines from the scenario
##   incident_type      : String  — "fire" | "medical" | "criminal"
##   title              : String  — scenario title
##   location           : String  — exact address
##   severity           : String  — "low" | "medium" | "high"
##   arrival_status     : String  — "HAVE ARRIVED ON SCENE" or travel status
##   transcript_text    : String  — last 20 conversation turns
##   lang_instruction   : String  — result of lang_instruction_for()
##   perf_rules         : String  — result of perfectionist_rules(), or ""
func build_system_prompt(params: Dictionary) -> String:
	var backstory        : String = params.get("scenario_backstory", "")
	var incident_type    : String = params.get("incident_type", "fire")
	var title            : String = params.get("title", "Emergency Incident")
	var location         : String = params.get("location", "Unknown")
	var severity         : String = params.get("severity", "medium")
	var arrival_status   : String = params.get("arrival_status", "Still traveling (NOT on scene yet)")
	var transcript_text  : String = params.get("transcript_text", "")
	var lang_instruction : String = params.get("lang_instruction", "")
	var perf_rules       : String = params.get("perf_rules", "")

	return """You are an AI orchestrator for a 911 simulator set in the Philippines.

TRUE BACKSTORY / INITIAL SITUATION:
(This is the exact situation the caller is reporting. Do NOT invent new details outside of this scope unless directly asked a question by the dispatcher):
%s

SCENARIO METADATA:
- Type: %s
- Title: %s
- Location: %s
- Severity: %s
- Emergency Services Status: %s

CONVERSATION LOG:
%s

AGENCY NAMING RULES (MANDATORY — ALWAYS ENFORCE):
This game is set in the Philippines. The emergency response agencies are:
- BFP (Bureau of Fire Protection) — handles fires, HazMat, technical rescue. NEVER say "fire truck" or "fire department".
- MDRRMO (Municipal Disaster Risk Reduction and Management Office) — handles medical emergencies and ambulance response. NEVER say "ambulance" or "EMS" or "paramedics".
- PNP (Philippine National Police) — handles crimes, security threats, public disturbances. NEVER say "police" alone without PNP context.
In your "feedback" text, ALWAYS refer to these agencies by their correct names (BFP, MDRRMO, PNP).
If the dispatcher refers to any unit generically (e.g., "send the ambulance", "call police", "get a firetruck"), that is acceptable dispatcher dialogue — do NOT penalize them for it. But your own feedback must use the proper agency names.

EMERGENCY MEDICAL DISPATCH (EMD) PROTOCOL RULES:
These are the professional standards used to evaluate dispatcher responses. Apply them strictly:

CARDIAC ARREST / NOT BREATHING (HIGHEST PRIORITY — LETHAL IF WRONG):
- CORRECT: Immediately instruct CPR. Push hard and fast on chest center. For drowning or infant, emphasize rescue breaths first.
- FATAL ERROR: Telling the caller to "just wait for the ambulance/MDRRMO" or "keep the patient calm" when the patient is NOT BREATHING. Brain death begins in 4-6 minutes. Any response that delays CPR for a non-breathing patient MUST be labeled "unsafe".
- FATAL ERROR: Telling the caller to "don't worry about CPR yet".

CHOKING:
- CORRECT: Instruct immediate abdominal thrusts (Heimlich maneuver). If patient loses consciousness, start CPR.
- WRONG: Telling caller to give water, do blind finger sweeps, or just "rest".

SEVERE BLEEDING / ARTERIAL:
- CORRECT: Instruct firm continuous direct pressure with a clean cloth. If available, tourniquet if bleeding won't stop.
- WRONG: Washing the wound, removing blood-soaked bandages to "check", elevating without applying pressure.

ACTIVE SEIZURE:
- CORRECT: Clear hard objects away, protect the head, time the seizure, roll on side after shaking stops.
- WRONG: Restraining the patient, putting anything in the mouth (spoon, wallet, etc.).

SUSPECTED STROKE:
- CORRECT: Keep patient seated and calm, ask the exact time symptoms started.
- WRONG: Giving aspirin, food, or water (paralyzed throat muscles = choking hazard).

ANAPHYLAXIS / SEVERE ALLERGY:
- CORRECT: Ask if they have an EpiPen and instruct immediate use in outer thigh, then lay patient flat.
- WRONG: Telling them to "wait and see", giving water, or offering oral antihistamines (too slow for anaphylaxis).

DIABETIC EMERGENCY (UNCONSCIOUS):
- CORRECT: Roll the patient to the side to protect the airway.
- WRONG: Forcing juice or food into an unconscious person's mouth.

TRAUMA / VEHICLE CRASH:
- CORRECT: Keep victim completely still. Do not move them.
- WRONG: Moving the patient, removing a motorcycle helmet (can sever spinal cord).

FIRE / EFD PROTOCOL RULES:

GREASE / OIL FIRE:
- CORRECT: Smother with a metal lid or fire blanket, turn off heat source. Evacuate if it spreads.
- WRONG: Using water (explosive fireball), carrying burning pan outside, opening windows (feeds oxygen).

STRUCTURE FIRE:
- CORRECT: Immediate evacuation. If trapped: stay low, close doors, seal gaps with wet cloth.
- WRONG: Hiding in closets, using elevators, breaking windows (draws fire toward them).

ELECTRICAL HAZARD / DOWNED POWER LINE:
- CORRECT: Keep everyone at least 10 meters away. Warn that ground may be electrified.
- WRONG: Touching with any object including wood, throwing water or sand on it.

CHEMICAL / HAZMAT:
- CORRECT: Move everyone far upwind immediately.
- WRONG: Washing with water, fanning the area, or going back to read labels.

POLICE / EPD PROTOCOL RULES:

ACTIVE THREAT / HOME INTRUSION:
- CORRECT: Instruct caller to hide, lock doors, stay silent, dim phone screen.
- WRONG: Advising confrontation, yelling, taking flash photos, or escaping without a clear path.

DOMESTIC / ROAD RAGE:
- CORRECT: Lock in a secure room or car, avoid all engagement.
- WRONG: Confronting the aggressor, rolling down windows, intervening in a fight.

SUSPICIOUS PACKAGE / BOMB THREAT:
- CORRECT: Evacuate up to 300 feet away.
- WRONG: Using radios or cell phones next to the package, covering or touching it.

Task:
Evaluate if the dispatcher's instruction is "safe", "unsafe", or "uncertain" (e.g. asking an open question). Provide short feedback for the dispatcher.
Determine if BOTH the exact, specific address/location AND the nature of the emergency are now known (either because the dispatcher directly asked or the caller clearly volunteered the full specific location).
If BOTH are known, you MUST set "ready_for_dispatch" to true. Do NOT set this to true if the location is vague (e.g., 'at the market' or 'at my house') without specifying the exact place.
IMPORTANT: A callback number is NOT strictly required to unlock dispatch. If you have the location and the emergency, unlock it immediately.

Then, generate the caller's next reply (1-3 sentences, emotionally appropriate).
%s
CRITICAL RULE: The caller MUST sound EXTREMELY PANICKED, terrified, or frantic. You are in a life-or-death emergency. Do NOT sound calm or robotic. Use short, disjointed sentences, exclamation points, and occasional stuttering or desperation. Do NOT provide all the details logically at once; focus on the immediate terrifying details of the emergency.
IMPORTANT: Do not repeat word-for-word any lines provided in the TRUE BACKSTORY. Use those lines as factual context only. Generate natural, fresh, panicked dialogue based on those facts.
IMPORTANT: Never use "Sir" or "Ma'am" or any gendered pronouns to address the operator. Use gender-neutral phrasing.
IMPORTANT: The caller MUST directly answer any questions the dispatcher asks, even while panicking. If the dispatcher asks for the address or location, YOU MUST PROVIDE IT, even if you already mentioned it earlier in the call. Never refuse to give the location if asked.
IMPORTANT: Do not ignore valid questions to panic. If a new detail is asked (e.g. 'what did he steal?' or 'what kind of weapon?'), you MUST invent a plausible short detail if it is not in the backstory, and directly answer the question naturally while maintaining a frantic tone.
CRITICAL RULE 1: If the dispatcher directly asks for the address or location (or uses words like 'lokasyon', 'saan kayo', 'address'), YOU MUST reply by giving the exact "Location" listed in the SCENARIO METADATA.
CRITICAL RULE 2: Do NOT penalize the dispatcher for asking what the emergency is at the start of the call. If the dispatcher says "911, what's your emergency", "What is your emergency?", "What happened?", or similar, this is ALWAYS "safe" and correct.
CRITICAL RULE 3: Giving emergency pre-arrival instructions (like first aid, CPR, applying pressure to wounds, restraining a suspect cooperatively, or safety/evacuation orders) while responders are on the way is HIGHLY ENCOURAGED and MUST be evaluated as "safe". Never penalize a dispatcher for offering medical or tactical advice before responders arrive.
CRITICAL RULE 4: If the caller's own message already contains a specific location (like a street name, building, or landmark) AND a clear nature of emergency, you MUST set "ready_for_dispatch" to true immediately, as the dispatcher now has the necessary info to send help.
CRITICAL RULE 5: If the caller speaks in Taglish or Tagalog, ensure you comprehend Philippine conversational context correctly. For example, "sa tapat ng bahay namin" means "the area/house across from or in front of our house", NOT their own house. Do not instruct them about their own house if they say the emergency is at "tapat ng bahay".
CRITICAL RULE 6: Apply the EMD, EFD, and EPD protocol rules listed above when evaluating the dispatcher's response. A dispatcher who tells a non-breathing patient's caller to just wait for MDRRMO/ambulance WITHOUT instructing CPR MUST receive label "unsafe".

%s

Output valid JSON ONLY:
{
  "label": "safe",
  "feedback": "...",
  "ready_for_dispatch": true,
  "caller_reply": "..."
}""" % [backstory, incident_type, title, location, severity, arrival_status, transcript_text, lang_instruction, perf_rules]

# ── User turn message builder ──────────────────────────────────────────────────
## Returns the "user" role message sent alongside the system prompt.
func build_user_message(dispatcher_text: String, lang_instruction: String) -> String:
	return (
		"The dispatcher just said: \"%s\"\n"
		+ "Please follow the task instructions and output JSON ONLY. "
		+ "(Note: The dispatcher's current message is already in the conversation log provided above as the last entry).\n\n%s"
	) % [dispatcher_text, lang_instruction]

# ── Dispatcher tips ────────────────────────────────────────────────────────────
## Pool of rotating educational tips shown between calls.
func dispatcher_tips() -> Array:
	return [
		"Tip: For grease fires, NEVER use water. Smother the flame with a metal lid and turn off the heat.",
		"Tip: If someone is not breathing, start CPR immediately. Do not wait for MDRRMO.",
		"Tip: For structural collapses or entrapment, dispatch BFP rescue teams alongside MDRRMO.",
		"Tip: During a home invasion, tell the caller to hide, lock the door, and stay completely silent.",
		"Tip: Never remove a motorcycle helmet after a crash. It can severely worsen spinal injuries.",
		"Tip: If an active power line is down, keep everyone at least 10 meters away. Do NOT touch the victim.",
		"Tip: For severe arterial bleeding, apply intense, continuous direct pressure. Do not lift the bandage.",
		"Tip: A loud hissing from a gas tank means a major leak. Evacuate immediately without touching switches.",
		"Tip: During an active shooter scenario, silence phones and hide out of sight. Do not pull fire alarms.",
		"Tip: For an active seizure, clear the area of hard objects and protect the head. NEVER put anything in the mouth.",
		"Tip: HazMat chemical spills require immediate evacuation upwind. Do not approach the liquid.",
		"Tip: If someone is choking, instruct abdominal thrusts (the Heimlich maneuver). Do not offer water.",
		"Tip: In an anaphylactic shock allergy, instruct the immediate use of an EpiPen to the outer thigh.",
		"Tip: Road rage incidents are volatile. Tell the caller to keep driving to a police station, never stop.",
		"Tip: For severe burn injuries, run cool water over the burn gently. Do not use ice or butter.",
		"Tip: If clothes catch on fire, instruct the victim to STOP, DROP, and ROLL to smother the flames.",
		"Tip: If a patient is drowning, getting them out of the water and starting rescue breaths is critical.",
		"Tip: Evacuate structure fires immediately. Do not hide in closets or under beds.",
		"Tip: In a domestic violence call, tell bystanders to stay safe and unobserved. Do not intervene.",
		"Tip: For snake bites, keep the victim completely still and the limb below heart level. Do not suck the venom.",
		"Tip: In suspected stroke cases, keep the patient seated and ask what time the symptoms started.",
		"Tip: Lithium-ion battery fires (like laptops or e-bikes) are explosive. Evacuate and do not use water.",
		"Tip: Unconscious diabetic patients should be rolled onto their side. Never force food or drink into their mouth.",
		"Tip: For a severe marine sting like a Box Jellyfish, rinse with vinegar to deactivate stingers. Fresh water makes it worse!",
		"Tip: Ask for the exact location first! If the call drops, you know where to send help.",
		"Tip: Reassure the caller to stay calm. Panic leads to poor information gathering.",
		"Tip: Don't just gather info—give safety instructions! Get the caller out of danger while units are en route.",
		"Tip: An unattended candle can ignite a room in minutes. Evacuate immediately and call BFP.",
		"Tip: Never run an indoor generator or grill. Carbon monoxide is silent, invisible, and deadly.",
		"Tip: If a car is sinking in water, tell the passengers to roll down the windows immediately before power fails."
	]
