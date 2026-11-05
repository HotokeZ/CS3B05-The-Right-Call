import os
import sys

files_to_check = [
    "scripts/persistence/local_storage.gd",
    "scripts/rules/level_rule_provider.gd",
    "scripts/evaluation/evaluation_logger.gd",
    "scripts/bkt_dda/bkt_dda_manager.gd",
    "scripts/bkt_dda/scenario_skill_mapper.gd",
    "scripts/ui/console_overlay.gd",
    "scripts/systems/game_state.gd",
    "scripts/maps/route_scene.gd",
    "scripts/systems/emergency_scenario_generator.gd",
    "test/test_bkt_dda.gd"
]

print("Auditing GDScript files for syntax and dictionary structure...")
all_ok = True

for fpath in files_to_check:
    full_path = os.path.abspath(fpath)
    if not os.path.exists(full_path):
        print(f"MISSING: {fpath}")
        all_ok = False
        continue
    with open(full_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    curly = 0
    in_str = False
    str_char = ''
    syntax_error = False
    
    for i, line in enumerate(lines, 1):
        clean = line.split("#")[0]
        for idx, ch in enumerate(clean):
            if in_str:
                if ch == str_char and (idx == 0 or clean[idx-1] != '\\'):
                    in_str = False
            else:
                if ch == '"' or ch == "'":
                    in_str = True
                    str_char = ch
                elif ch == '{':
                    curly += 1
                elif ch == '}':
                    curly -= 1
                    if curly < 0:
                        print(f"SYNTAX ERROR in {fpath} line {i}: Extra closing brace '}}'!")
                        syntax_error = True
                        all_ok = False
                        break
        if syntax_error:
            break

    if curly != 0:
        print(f"SYNTAX ERROR in {fpath}: Unclosed dictionary brace '{{' (curly={curly})")
        all_ok = False
    elif not syntax_error:
        print(f"OK ({len(lines)} lines): {fpath}")

if all_ok:
    print("\nAll GDScript files verified successfully with zero dictionary syntax errors!")
else:
    sys.exit(1)
