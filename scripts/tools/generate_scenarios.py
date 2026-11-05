import os
import json
import time
import requests

# ==========================================
# CONFIGURATION
# ==========================================
# Paste your Gemini API key here or set GEMINI_API_KEY environment variable:
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

# Target counts
TARGET_FIRE = 50
TARGET_POLICE = 50
TARGET_MEDICAL = 50

# Safely resolve file paths relative to this script's directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FILE_EN = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/curated_scenarios_ph_v2_en.json"))
FILE_TL = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/curated_scenarios_ph_v2_tl.json"))
FILE_TAGLISH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/curated_scenarios_ph_v2_taglish.json"))

# ==========================================

def get_best_model():
    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={GEMINI_API_KEY}"
    try:
        resp = requests.get(url).json()
        models = [m['name'] for m in resp.get('models', []) if 'generateContent' in m.get('supportedGenerationMethods', [])]
        for pref in ["models/gemini-2.5-flash", "models/gemini-2.0-flash", "models/gemini-1.5-flash"]:
            if pref in models: return pref
        return models[0] if models else "models/gemini-2.5-flash"
    except:
        return "models/gemini-2.5-flash"

ACTIVE_MODEL = None

def load_data(filepath):
    if not os.path.exists(filepath): return {"scenarios": []}
    with open(filepath, "r", encoding="utf-8") as f: return json.load(f)

def save_data(filepath, data):
    with open(filepath, "w", encoding="utf-8") as f: json.dump(data, f, indent=2)

def generate_batch(category, current_titles, batch_size=2):
    global ACTIVE_MODEL
    if not ACTIVE_MODEL:
        ACTIVE_MODEL = get_best_model()
        print(f"Auto-selected model: {ACTIVE_MODEL}")

    print(f"\nGenerating {batch_size} {category} scenarios using {ACTIVE_MODEL} (EN, TL, Taglish)...")
    
    agency_map = {"fire": "BFP", "criminal": "PNP", "medical": "MDRRMO"}
    agency = agency_map.get(category, "Emergency Services")
    vehicle = "fire_truck" if category == "fire" else "police" if category == "criminal" else "ambulance"
    
    prompt = f"""
    You are an expert 911 dispatch scenario generator.
    Generate {batch_size} highly realistic, completely unique emergency scenarios for the category: {category}.
    
    CRITICAL RULES:
    1. NEVER repeat these existing concepts: {json.dumps(list(current_titles))}
    2. The caller is already talking to 911. Never tell the caller to "call 911".
    3. Use the agency '{agency}' and vehicle '{vehicle}'.
    4. For EACH scenario, provide the text content in THREE languages: English, Deep Tagalog (tl), and Conversational Taglish (taglish).
    5. The keywords (safe_keywords, unsafe_keywords) MUST BE A SUPER-SET containing the keywords from ALL 3 languages combined into one large array!
    6. EXACTLY 1 mid-call transcript interaction must have an "options" array of 6 choices and an "nlp_evaluation" object.
    7. The root "options" array must contain EXACTLY 6 choices for the final dispatch action.
    8. Mix 1-2 "safe" options and 4-5 "unsafe" options per array. Every option must have a unique explanation.
    
    Output a strictly formatted JSON object exactly like this:
    {{
      "scenarios": [
        {{
          "id": "gen_{category}_001", "category": "{category}", "type": "{category}",
          "title": "Brief unique title", "severity": "high", "recommended_vehicle": "{vehicle}",
          
          "transcript_en": [ {{ "speaker": "Caller", "text": "English text" }}, {{ "speaker": "911", "options": [ {{ "text": "English opt", "label": "safe", "explanation": "English exp" }} ], "nlp_evaluation": {{ "safe_keywords": ["eng_kw", "tag_kw", "taglish_kw"], "unsafe_keywords": ["..."] }} }} ],
          "transcript_tl": [ {{ "speaker": "Caller", "text": "Tagalog text" }}, {{ "speaker": "911", "options": [ {{ "text": "Tagalog opt", "label": "safe", "explanation": "Tagalog exp" }} ], "nlp_evaluation": {{ "safe_keywords": ["eng_kw", "tag_kw", "taglish_kw"], "unsafe_keywords": ["..."] }} }} ],
          "transcript_taglish": [ {{ "speaker": "Caller", "text": "Taglish text" }}, {{ "speaker": "911", "options": [ {{ "text": "Taglish opt", "label": "safe", "explanation": "Taglish exp" }} ], "nlp_evaluation": {{ "safe_keywords": ["eng_kw", "tag_kw", "taglish_kw"], "unsafe_keywords": ["..."] }} }} ],
          
          "options_en": [ {{ "text": "Eng opt", "label": "safe", "hint": "Eng hint", "explanation": "Eng exp" }} ],
          "options_tl": [ {{ "text": "Tagalog opt", "label": "safe", "hint": "Tagalog hint", "explanation": "Tagalog exp" }} ],
          "options_taglish": [ {{ "text": "Taglish opt", "label": "safe", "hint": "Taglish hint", "explanation": "Taglish exp" }} ],
          
          "safe_keywords": ["eng_kw", "tag_kw", "taglish_kw"],
          "unsafe_keywords": ["eng_kw", "tag_kw", "taglish_kw"]
        }}
      ]
    }}
    Note: Both the transcript 'options' arrays and the root 'options' arrays MUST contain exactly 6 choices.
    """
    
    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/{ACTIVE_MODEL}:generateContent?key={GEMINI_API_KEY}"
        resp = requests.post(url, json={"contents": [{"parts": [{"text": prompt}]}], "generationConfig": {"responseMimeType": "application/json"}})
        resp_data = resp.json()
        
        if "error" in resp_data:
            print(f"API Error: {resp_data['error']['message']}")
            return []
            
        result = json.loads(resp_data["candidates"][0]["content"]["parts"][0]["text"])
        return result.get("scenarios", [])
    except Exception as e:
        print(f"Error generating batch: {e}")
        return []

def extract_language_scenario(raw_scenario, lang_suffix):
    # Builds a clean standard scenario object for a specific language
    clean = {
        "id": raw_scenario["id"], "category": raw_scenario["category"], "type": raw_scenario["type"],
        "title": raw_scenario["title"], "severity": raw_scenario["severity"], "recommended_vehicle": raw_scenario["recommended_vehicle"],
        "transcript": raw_scenario.get(f"transcript_{lang_suffix}", []),
        "options": raw_scenario.get(f"options_{lang_suffix}", []),
        "safe_keywords": raw_scenario.get("safe_keywords", []),
        "unsafe_keywords": raw_scenario.get("unsafe_keywords", [])
    }
    return clean

def main():
    en_data = load_data(FILE_EN)
    tl_data = load_data(FILE_TL)
    taglish_data = load_data(FILE_TAGLISH)
    
    while True:
        counts = {"fire": 0, "criminal": 0, "medical": 0}
        current_titles = set()
        
        for s in en_data.get("scenarios", []):
            counts[s.get("category", "")] += 1
            current_titles.add(s.get("title", ""))
            
        total_target = TARGET_FIRE + TARGET_POLICE + TARGET_MEDICAL
        print(f"\n--- Progress --- | Fire: {counts['fire']}/{TARGET_FIRE} | Police: {counts['criminal']}/{TARGET_POLICE} | Medical: {counts['medical']}/{TARGET_MEDICAL} | Total: {sum(counts.values())}/{total_target}")
        if sum(counts.values()) >= total_target:
            print(f"All targets reached! {total_target} scenarios generated.")
            break
            
        target_category = "fire" if counts["fire"] < TARGET_FIRE else "criminal" if counts["criminal"] < TARGET_POLICE else "medical"
        
        raw_batch = generate_batch(target_category, current_titles, batch_size=2) # Reduced to 2 to handle 3 languages per prompt safely
        if raw_batch:
            for s in raw_batch:
                en_data["scenarios"].append(extract_language_scenario(s, "en"))
                tl_data["scenarios"].append(extract_language_scenario(s, "tl"))
                taglish_data["scenarios"].append(extract_language_scenario(s, "taglish"))
            save_data(FILE_EN, en_data)
            save_data(FILE_TL, tl_data)
            save_data(FILE_TAGLISH, taglish_data)
            print("Saved localized scenarios to disk.")
        
        print("Sleeping for 10 seconds...")
        time.sleep(10)

if __name__ == "__main__":
    main()
