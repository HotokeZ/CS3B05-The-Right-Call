extends Control

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var back_button: Button = $CanvasLayer/Root/Margin/Layout/Footer/BackButton
@onready var manual_text: RichTextLabel = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/ScrollContainer/ManualText

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_manual_text()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _build_manual_text() -> void:
	var lines = [
		"[center][b]DISPATCHER MANUAL[/b][/center]",
		"",
		"[b]Quick Unit Matching[/b]",
		"- [color=#e74c3c]Fire Truck[/color]: active fire, smoke, burning structures, AND technical operations like extrication of trapped victims or building collapse.",
		"- [color=#3498db]Ambulance[/color]: transport patients safely to hospital for medical emergencies, injuries, breathing problems, fainting, and heavy bleeding.",
		"- [color=#2980b9]Police Unit[/color]: violence, threats, criminal activity.",
		"",
		"[b]Core Principles[/b]",
		"1. [b]Life Safety First[/b]: Always instruct callers to prioritize their physical safety over property.",
		"2. [b]Do Not Play Hero[/b]: Tell callers to stay away from criminals and dangerous hazards. Never attempt to extinguish huge fires or arrest armed individuals.",
		"3. [b]Dispatch Accurately[/b]: Sending the wrong unit severely delays response times.",
		"4. [b]Wait for Arrival[/b]: You must keep the caller calm and stay on the line until the emergency responders arrive on the scene.",
		"",
		"[b]First Aid Reminders[/b]",
		"- Direct pressure stops severe bleeding. Don't remove bandages, add to them.",
		"- Never put water on a grease fire. Smother it instead.",
		"- Do not move patients with potential neck or spine injuries."
	]
	manual_text.text = "\n".join(lines)
