extends Control

@onready var color_rect = $ColorRect

var _preloaded_scene: PackedScene = null

func _ready() -> void:
	color_rect.color = Color(0, 0, 0, 1)
	# Start preloading the main menu in the background immediately
	_preloaded_scene = load("res://scenes/ui/main_menu.tscn")
	var tween = create_tween()
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 0), 1.5)
	tween.tween_interval(2.0)
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 1), 1.5)
	tween.tween_callback(_on_fade_out_finished)

func _on_fade_out_finished() -> void:
	if _preloaded_scene:
		get_tree().change_scene_to_packed(_preloaded_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")