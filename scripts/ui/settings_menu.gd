extends ColorRect

signal closed

@onready var close_btn: Button = $Panel/Margin/VBox/HeaderBox/CloseBtn
@onready var master_slider: HSlider = $Panel/Margin/VBox/Scroll/VBox/VolumeBox/MasterSlider
@onready var bgm_slider: HSlider = $Panel/Margin/VBox/Scroll/VBox/VolumeBox/BgmSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/Scroll/VBox/VolumeBox/SfxSlider
@onready var lang_option: OptionButton = $Panel/Margin/VBox/Scroll/VBox/LangBox/LangOption
@onready var legacy_map_toggle: CheckButton = $Panel/Margin/VBox/Scroll/VBox/MapBox/LegacyMapToggle
@onready var perfectionist_toggle: CheckButton = $Panel/Margin/VBox/Scroll/VBox/MapBox/PerfectionistToggle

@onready var restart_shift_btn: Button = $Panel/Margin/VBox/Scroll/VBox/DataBox/RestartShiftBtn
@onready var reset_all_btn: Button = $Panel/Margin/VBox/Scroll/VBox/DataBox/ResetAllBtn
@onready var view_eval_btn: Button = $Panel/Margin/VBox/Scroll/VBox/DataBox/ViewEvaluationBtn

@onready var save_exit_btn: Button = $Panel/Margin/VBox/FooterBox/SaveExitBtn
@onready var exit_game_btn: Button = $Panel/Margin/VBox/FooterBox/ExitGameBtn

@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

var _state: Node = null
var _am: Node = null  # Cached AudioManager reference
var _is_in_shift: bool = false
var _confirm_action: String = ""
var _is_closing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.7) # Dim background
	
	_state = get_node_or_null("/root/GameState")
	_am    = get_node_or_null("/root/AudioManager")
	_is_in_shift = get_tree().current_scene.name == "RouteScene"
	
	save_exit_btn.visible = _is_in_shift
	view_eval_btn.visible = _is_in_shift

	# ── Click SFX: wire to every button ───────────────────────────────────
	var am = _am
	var _click = func(): if am: am.play_click()
	close_btn.pressed.connect(_click)
	exit_game_btn.pressed.connect(_click)
	save_exit_btn.pressed.connect(_click)
	restart_shift_btn.pressed.connect(_click)
	reset_all_btn.pressed.connect(_click)
	view_eval_btn.pressed.connect(_click)

	close_btn.pressed.connect(_on_close)
	exit_game_btn.pressed.connect(_on_exit_game)
	save_exit_btn.pressed.connect(_on_save_exit)
	
	restart_shift_btn.pressed.connect(func(): _prompt_reset_modal("soft"))
	reset_all_btn.pressed.connect(func(): _prompt_reset_modal("hard"))
	view_eval_btn.pressed.connect(_on_view_evaluation)
	
	confirm_dialog.confirmed.connect(_on_confirm_action)
	
	# Load current language
	lang_option.add_item("Taglish (Mix of Tagalog & English - Default)", 0)
	lang_option.add_item("English Only", 1)
	lang_option.add_item("Tagalog Only", 2)
	
	if _state and _state.has_method("get_locale"):
		var loc = String(_state.call("get_locale"))
		if loc == "en": lang_option.selected = 1
		elif loc == "tl": lang_option.selected = 2
		else: lang_option.selected = 0
		
	lang_option.item_selected.connect(_on_lang_selected)
	
	if _state and _state.has_method("get_use_legacy_map"):
		legacy_map_toggle.button_pressed = bool(_state.call("get_use_legacy_map"))
	legacy_map_toggle.toggled.connect(_on_legacy_map_toggled)
	
	if _state and _state.has_method("is_mode_unlocked"):
		perfectionist_toggle.visible = _state.call("is_mode_unlocked", "professional_nlp_dispatch")
	else:
		perfectionist_toggle.visible = false
		
	if _state and _state.has_method("get_perfectionist_mode"):
		perfectionist_toggle.button_pressed = bool(_state.call("get_perfectionist_mode"))
	perfectionist_toggle.toggled.connect(_on_perfectionist_toggled)
	
	# Apply mobile UI scaling
	var vp = get_viewport_rect().size
	var is_portrait = vp.y > vp.x
	var scale_factor = min(vp.x / 1280.0, vp.y / 720.0)
	
	var panel = get_node_or_null("Panel")
	if is_portrait and panel:
		var max_scale_x = (vp.x - 64.0) / panel.size.x
		var max_scale_y = (vp.y - 120.0) / panel.size.y
		scale_factor = min(max_scale_x, max_scale_y)
		
	if scale_factor > 1.0 or is_portrait:
		if panel:
			panel.scale = Vector2(scale_factor, scale_factor)
			panel.pivot_offset = panel.size / 2.0

	# ── Volume sliders ────────────────────────────────────────────────────
	# Helper: saves all three volumes to GameState whenever any slider moves
	var _save_volumes = func():
		if _state and _state.has_method("set_audio_volumes"):
			var master_val = master_slider.value
			var bgm_val    = bgm_slider.value
			var siren_val  = sfx_slider.value
			_state.call("set_audio_volumes", master_val, bgm_val, siren_val)

	# Load initial values from GameState so UI matches what was saved
	if _state and _state.has_method("get_audio_volumes"):
		var saved: Dictionary = _state.call("get_audio_volumes")
		master_slider.value = float(saved.get("master", 1.0))
		bgm_slider.value    = float(saved.get("bgm",    0.7))
		sfx_slider.value    = float(saved.get("siren",  0.7))
	else:
		# Fallback: read live values from AudioServer / AudioManager
		var master_idx = AudioServer.get_bus_index("Master")
		if master_idx >= 0:
			master_slider.value = clamp(db_to_linear(AudioServer.get_bus_volume_db(master_idx)), 0.0, 1.0)
		if am and am._bgm_player:
			bgm_slider.value = clamp(db_to_linear(am._bgm_player.volume_db + 6.0), 0.0, 1.0)
		if am:
			sfx_slider.value = clamp(db_to_linear(am._siren_volume_db + 3.0), 0.0, 1.0)

	# Master — controls Godot Master bus
	master_slider.value_changed.connect(func(v):
		_on_volume_changed("Master", v)
		_save_volumes.call())

	# BGM — controls BGM player volume directly
	bgm_slider.value_changed.connect(func(v):
		if am and am._bgm_player:
			am._bgm_player.volume_db = linear_to_db(max(v, 0.001)) - 6.0
		_save_volumes.call())

	# Siren slider — controls SIREN volume only (not UI clicks)
	var sfx_label = get_node_or_null("Panel/Margin/VBox/Scroll/VBox/VolumeBox/SfxLabel")
	if sfx_label:
		sfx_label.text = "Siren Volume"
	sfx_slider.value_changed.connect(func(v):
		if am and am.has_method("set_siren_volume_db"):
			am.set_siren_volume_db(linear_to_db(max(v, 0.001)) - 3.0)
		_save_volumes.call())


func _on_close() -> void:
	if _is_closing:
		return
	_is_closing = true
	var route_scene = get_tree().current_scene
	if route_scene and route_scene.name == "RouteScene":
		if route_scene.has_method("_hide_coach_pointer"):
			route_scene.call("_hide_coach_pointer")
		if route_scene.has_method("_hide_tutorial_focus"):
			route_scene.call("_hide_tutorial_focus")
	closed.emit()
	queue_free()

func _on_exit_game() -> void:
	get_tree().quit()

func _on_save_exit() -> void:
	# Trigger mid-session save if in RouteScene
	var scene = get_tree().current_scene
	if scene and scene.has_method("serialize_session"):
		scene.call("serialize_session")
	get_tree().paused = false
	if _am:
		_am.stop_all_sfx()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_view_evaluation() -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_show_shift_review"):
		scene.call("_show_shift_review", "Current Shift Evaluation", "Reviewing your performance so far.", "")
	_on_close()

var _checkbox_container: VBoxContainer = null
var _easy_checkbox: CheckBox = null
var _cert_checkbox: CheckBox = null

func _prompt_reset_modal(reset_type: String) -> void:
	_confirm_action = reset_type
	if not _state: return
	
	# Clear previous custom UI in dialog if any
	if _checkbox_container:
		_checkbox_container.queue_free()
		_checkbox_container = null
	
	_checkbox_container = VBoxContainer.new()
	var lbl = Label.new()
	if reset_type == "soft":
		lbl.text = "Soft Reset: Cancel your current active shift and try again.\n(Your overall day progression is kept safe.)\n\nWhich mode do you want to reset?"
	else:
		lbl.text = "Hard Reset: Erase all shift history and return to Day 1.\n(E-Learning progress is PERMANENT and will NOT be erased.)\n\nWhich mode do you want to reset?"
	_checkbox_container.add_child(lbl)
	
	var is_professional_unlocked = false
	if _state.has_method("is_mode_unlocked"):
		is_professional_unlocked = _state.call("is_mode_unlocked", "professional_nlp_dispatch")
	
	if is_professional_unlocked:
		_easy_checkbox = CheckBox.new()
		_easy_checkbox.text = "Normal / Easy Mode"
		_easy_checkbox.button_pressed = true
		_checkbox_container.add_child(_easy_checkbox)
		
		_cert_checkbox = CheckBox.new()
		_cert_checkbox.text = "Professional Dispatcher Mode"
		_cert_checkbox.button_pressed = true
		_checkbox_container.add_child(_cert_checkbox)
	else:
		_easy_checkbox = CheckBox.new()
		_easy_checkbox.text = "Normal / Easy Mode"
		_easy_checkbox.button_pressed = true
		_easy_checkbox.disabled = true # Only one option anyway
		_checkbox_container.add_child(_easy_checkbox)
		
	confirm_dialog.add_child(_checkbox_container)
	confirm_dialog.dialog_text = ""
	confirm_dialog.popup_centered()

func _on_confirm_action() -> void:
	if not _state: return
	
	var _reset_easy = _easy_checkbox and _easy_checkbox.button_pressed
	var _reset_cert = _cert_checkbox and _cert_checkbox.button_pressed
	
	if _confirm_action == "soft":
		# Clear only the in-progress shift data for each checked mode
		if _reset_easy and _state.has_method("clear_shift_progress_for_mode"):
			_state.call("clear_shift_progress_for_mode", "easy_multiple_choice")
		if _reset_cert and _state.has_method("clear_shift_progress_for_mode"):
			_state.call("clear_shift_progress_for_mode", "professional_nlp_dispatch")
	elif _confirm_action == "hard":
		# Full reset back to Day 1 for each checked mode
		if _reset_easy and _state.has_method("reset_easy_progress"):
			_state.call("reset_easy_progress")
		if _reset_cert and _state.has_method("reset_professional_progress"):
			_state.call("reset_professional_progress")
		
	if _is_in_shift:
		if _am:
			_am.stop_all_sfx()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	else:
		var menu = get_tree().current_scene
		if menu and menu.has_method("_refresh_ui"):
			menu.call("_refresh_ui")
				
	_on_close()

func _on_lang_selected(index: int) -> void:
	if not _state or not _state.has_method("set_locale"): return
	if index == 0: _state.call("set_locale", "taglish")
	elif index == 1: _state.call("set_locale", "en")
	elif index == 2: _state.call("set_locale", "tl")
	
	var menu = get_tree().current_scene
	if not _is_in_shift and menu and menu.has_method("_refresh_ui"):
		menu.call("_refresh_ui")

func _on_volume_changed(bus_name: String, linear_val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var db = linear_to_db(linear_val)
		if linear_val <= 0.01:
			db = -80.0
		AudioServer.set_bus_volume_db(idx, db)

func _on_legacy_map_toggled(button_pressed: bool) -> void:
	if _state and _state.has_method("set_use_legacy_map"):
		_state.call("set_use_legacy_map", button_pressed)

func _on_perfectionist_toggled(button_pressed: bool) -> void:
	if _state and _state.has_method("set_perfectionist_mode"):
		_state.call("set_perfectionist_mode", button_pressed)

## Called during the interactive tutorial to walk the player through language settings.
## Spotlights the language dropdown, waits for it to be opened (item_selected), then closes the menu.
func run_tutorial() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var lang_box = get_node_or_null("Panel/Margin/VBox/Scroll/VBox/LangBox")
	var target: Control = lang_option if lang_option else lang_box
	if target == null:
		_on_close()
		return
	
	var route_scene = get_tree().current_scene
	var has_tut = route_scene and route_scene.name == "RouteScene" and route_scene.has_method("_show_tutorial_focus")
	
	if has_tut:
		await get_tree().process_frame
		if _is_closing or not is_inside_tree(): return
		route_scene.call("_show_tutorial_focus", target)
		route_scene.call("_point_coach_at", target, "Click the Language dropdown to change language.")
	
	# Wait for the dropdown to be opened
	var popup = lang_option.get_popup()
	await popup.about_to_popup
	if _is_closing or not is_inside_tree(): return
	
	if has_tut:
		# Hide the blocking dim layer so the popup menu can actually be clicked!
		route_scene.call("_hide_tutorial_focus")
		route_scene.call("_point_coach_at", target, "Select a language from the list.")
		
	# Wait until the popup menu is closed (either an item is selected or user clicks away)
	await popup.popup_hide
	if _is_closing or not is_inside_tree(): return
	
	if has_tut:
		# Small delay to ensure the dropdown is visually closed (ignore_pause=true so timer ticks while paused)
		await get_tree().create_timer(0.2, true, false, true).timeout
		if _is_closing or not is_inside_tree(): return
		route_scene.call("_show_tutorial_focus", close_btn)
		route_scene.call("_point_coach_at", close_btn, "Click the 'X' to close the settings menu.")
