import os
import json

# Safely resolve file paths relative to this script's directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_FILE = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/raw_scenarios.json"))
FILE_EN = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/curated_scenarios_ph_v2_en.json"))
FILE_TL = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/curated_scenarios_ph_v2_tl.json"))
FILE_TAGLISH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../data/gameplay/curated_scenarios_ph_v2_taglish.json"))

def load_data(filepath):
    if not os.path.exists(filepath): return {"scenarios": []}
    with open(filepath, "r", encoding="utf-8") as f: return json.load(f)

def save_data(filepath, data):
    with open(filepath, "w", encoding="utf-8") as f: json.dump(data, f, indent=2)

def extract_language_scenario(raw_scenario, lang_suffix):
    return {
        "id": raw_scenario["id"], 
        "category": raw_scenario["category"], 
        "type": raw_scenario["type"],
        "title": raw_scenario["title"], 
        "severity": raw_scenario["severity"], 
        "recommended_vehicle": raw_scenario["recommended_vehicle"],
        "transcript": raw_scenario.get(f"transcript_{lang_suffix}", []),
        "options": raw_scenario.get(f"options_{lang_suffix}", []),
        "safe_keywords": raw_scenario.get("safe_keywords", []),
        "unsafe_keywords": raw_scenario.get("unsafe_keywords", [])
    }

def main():
    if not os.path.exists(RAW_FILE):
        print(f"ERROR: Could not find '{RAW_FILE}'. Please create this file and paste your Gemini output into it.")
        return

    print("Loading raw scenarios...")
    try:
        with open(RAW_FILE, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
    except Exception as e:
        print(f"Error parsing raw JSON. Make sure you copied the entire block correctly: {e}")
        return

    en_data = load_data(FILE_EN)
    tl_data = load_data(FILE_TL)
    taglish_data = load_data(FILE_TAGLISH)

    count = 0
    for s in raw_data.get("scenarios", []):
        # Prevent duplicates by checking ID
        if not any(existing.get("id") == s["id"] for existing in en_data["scenarios"]):
            en_data["scenarios"].append(extract_language_scenario(s, "en"))
            tl_data["scenarios"].append(extract_language_scenario(s, "tl"))
            taglish_data["scenarios"].append(extract_language_scenario(s, "taglish"))
            count += 1

    save_data(FILE_EN, en_data)
    save_data(FILE_TL, tl_data)
    save_data(FILE_TAGLISH, taglish_data)
    
    print(f"Successfully processed and saved {count} new localized scenarios to your game files!")

if __name__ == "__main__":
    main()
