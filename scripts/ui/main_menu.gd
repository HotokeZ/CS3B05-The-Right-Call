extends Control

const ROUTE_SCENE_NEW := "res://scenes/maps/route_scene_temp.tscn"
const ROUTE_SCENE_LEGACY := "res://scenes/maps/route_scene.tscn"

func _get_route_scene() -> String:
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("get_use_legacy_map"):
		if state.call("get_use_legacy_map"):
			return ROUTE_SCENE_LEGACY
	return ROUTE_SCENE_NEW
const TUTORIAL_SCENE := "res://scenes/ui/tutorial_scene.tscn"
const PRE_ASSESS_SCENE := "res://scenes/ui/pre_assessment.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"

@onready var title_label: Label = $CanvasLayer/Margin/Layout/TitleBox/TitleLabel
@onready var subtitle_label: Label = $CanvasLayer/Margin/Layout/TitleBox/SubtitleLabel
@onready var tutorial_button: Button = $CanvasLayer/Margin/Layout/LeftPanel/Actions/TutorialButton
@onready var pre_assess_button: Button = $CanvasLayer/Margin/Layout/LeftPanel/Actions/PreAssessButton
@onready var easy_button: Button = $CanvasLayer/Margin/Layout/LeftPanel/Actions/EasyButton
@onready var professional_button: Button = $CanvasLayer/Margin/Layout/LeftPanel/Actions/ProfessionalButton
@onready var left_panel: Control = $CanvasLayer/Margin/Layout/LeftPanel
@onready var right_panel: Control = $CanvasLayer/Margin/Layout/RightPanel
@onready var settings_button: Button = $CanvasLayer/Margin/Layout/LeftPanel/Actions/SettingsButton
@onready var info_title: Label = $CanvasLayer/Margin/Layout/RightPanel/InfoCard/Margin/VBox/InfoTitle
@onready var info_desc: Label = $CanvasLayer/Margin/Layout/RightPanel/InfoCard/Margin/VBox/InfoDescription
@onready var certification_label: Label = $CanvasLayer/Margin/Layout/RightPanel/InfoCard/Margin/VBox/CertificationLabel
@onready var status_label: Label = $CanvasLayer/Margin/Layout/RightPanel/InfoCard/Margin/VBox/StatusLabel

var _difficulty_popup: ConfirmationDialog
var _save_popup: ConfirmationDialog
var _settings_popup: Node = null
var _pending_mode_id: String = ""

func _ready() -> void:
	# Add map background
	var tex_rect = TextureRect.new()
	tex_rect.texture = load("res://assets/maps/map_high.png")
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.modulate = Color(0.4, 0.4, 0.4, 1.0)
	
	var pm_script = load("res://scripts/vehicles/multi_patrol_manager.gd")
	if pm_script:
		var pm = Node2D.new()
		pm.set_script(pm_script)
		tex_rect.add_child(pm)
	
	get_node("CanvasLayer").add_child(tex_rect)
	get_node("CanvasLayer").move_child(tex_rect, 0)

	title_label.text = "The Right Call"
	subtitle_label.text = "Emergency Dispatch Academy"

	# ── Audio ──────────────────────────────────────────────────────────────
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_bgm()

	# Wire click SFX to every button
	var _play_click = func(): if am: am.play_click()
	tutorial_button.pressed.connect(_play_click)
	pre_assess_button.pressed.connect(_play_click)
	easy_button.pressed.connect(_play_click)
	professional_button.pressed.connect(_play_click)
	settings_button.pressed.connect(_play_click)

	tutorial_button.pressed.connect(_on_tutorial_pressed)
	pre_assess_button.pressed.connect(_on_pre_assess_pressed)
	easy_button.pressed.connect(_on_easy_pressed)
	professional_button.pressed.connect(_on_professional_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	var cs_mgr = get_node_or_null("/root/CloudSaveManager")
	if cs_mgr and cs_mgr.has_signal("progress_loaded"):
		cs_mgr.progress_loaded.connect(func(_data): _refresh_state_ui())

	tutorial_button.mouse_entered.connect(func(): _show_info("Play Tutorial", "Learn the basics of taking emergency calls and dispatching the correct units."))
	pre_assess_button.mouse_entered.connect(func(): _show_info("BFP Assessments", "Take the fire safety quiz hub to unlock gameplay progress."))
	easy_button.mouse_entered.connect(func(): _show_info("Play Normal Mode", "Practice dispatch decisions with the standard gameplay mode."))
	professional_button.mouse_entered.connect(func(): _show_info("Professional Dispatcher", "Continue the advanced dispatch mode once your certification is ready."))
	settings_button.mouse_entered.connect(func(): _show_info("Settings & Data", "Adjust audio, language, and save data from one overlay."))

	_difficulty_popup = ConfirmationDialog.new()
	_difficulty_popup.title = "Select Difficulty"
	var diff_box = VBoxContainer.new()
	diff_box.name = "DiffVBox"
	var diff_msg = Label.new()
	diff_msg.text = "Select your dispatch difficulty. Harder modes have more distractors and take longer to resolve."
	diff_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_msg.custom_minimum_size = Vector2(400, 0)
	diff_box.add_child(diff_msg)
	var easy_diff_btn = Button.new()
	easy_diff_btn.text = "Easy"
	easy_diff_btn.pressed.connect(_on_difficulty_easy)
	diff_box.add_child(easy_diff_btn)
	var medium_diff_btn = Button.new()
	medium_diff_btn.text = "Medium"
	medium_diff_btn.pressed.connect(func(): _on_difficulty_custom_action("medium"))
	diff_box.add_child(medium_diff_btn)
	var hard_diff_btn = Button.new()
	hard_diff_btn.text = "Hard"
	hard_diff_btn.pressed.connect(func(): _on_difficulty_custom_action("hard"))
	diff_box.add_child(hard_diff_btn)
	var cancel_diff_btn = Button.new()
	cancel_diff_btn.text = "Cancel Menu"
	cancel_diff_btn.pressed.connect(_difficulty_popup.hide)
	diff_box.add_child(cancel_diff_btn)
	_difficulty_popup.add_child(diff_box)
	_difficulty_popup.get_ok_button().hide()
	_difficulty_popup.get_cancel_button().hide()
	add_child(_difficulty_popup)

	_save_popup = ConfirmationDialog.new()
	_save_popup.title = "Progress Found"
	var save_box = VBoxContainer.new()
	var save_msg = Label.new()
	save_msg.text = "You have a saved shift or day progress. What would you like to do?"
	save_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_msg.custom_minimum_size = Vector2(400, 0)
	save_box.add_child(save_msg)
	var continue_btn = Button.new()
	continue_btn.text = "Continue Shift"
	continue_btn.pressed.connect(_on_continue_shift)
	save_box.add_child(continue_btn)
	var restart_shift_btn = Button.new()
	restart_shift_btn.text = "Restart Shift (Clear current shift progress)"
	restart_shift_btn.pressed.connect(_on_restart_shift)
	save_box.add_child(restart_shift_btn)
	var restart_all_btn = Button.new()
	restart_all_btn.text = "Restart to Day 1 (Clear ALL progress)"
	restart_all_btn.pressed.connect(_on_restart_all)
	save_box.add_child(restart_all_btn)
	var cancel_save_btn = Button.new()
	cancel_save_btn.text = "Cancel Menu"
	cancel_save_btn.pressed.connect(_save_popup.hide)
	save_box.add_child(cancel_save_btn)
	_save_popup.add_child(save_box)
	_save_popup.get_ok_button().hide()
	_save_popup.get_cancel_button().hide()
	add_child(_save_popup)

	_show_info("Welcome!", "Hover over a menu option to see more details.")
	_refresh_ui()
	_update_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	if not left_panel or not right_panel:
		return
	var vp_size = get_viewport_rect().size
	var is_portrait = vp_size.y > vp_size.x
	
	var info_card = right_panel.get_node("InfoCard")
	var actions = left_panel.get_node("Actions")

	if is_portrait:
		# Mobile / Portrait layout
		# Move InfoCard directly into Actions VBoxContainer to share same spacing as buttons
		if info_card and actions and info_card.get_parent() != actions:
			info_card.get_parent().remove_child(info_card)
			actions.add_child(info_card)
			actions.move_child(info_card, 0)
			
		right_panel.visible = false
		
		# Buttons centered with Description box sitting on top
		left_panel.anchor_left = 0.05
		left_panel.anchor_top = 0.05
		left_panel.anchor_right = 0.95
		left_panel.anchor_bottom = 0.95
		left_panel.add_theme_constant_override("margin_left", 0)
		
		# Massively increase font sizes for mobile (200% increase = ~3x size)
		title_label.add_theme_font_size_override("font_size", 120)
		subtitle_label.add_theme_font_size_override("font_size", 60)
		tutorial_button.add_theme_font_size_override("font_size", 66)
		pre_assess_button.add_theme_font_size_override("font_size", 66)
		easy_button.add_theme_font_size_override("font_size", 66)
		professional_button.add_theme_font_size_override("font_size", 66)
		settings_button.add_theme_font_size_override("font_size", 66)
		info_desc.add_theme_font_size_override("font_size", 50)
		info_title.add_theme_font_size_override("font_size", 60)
		certification_label.add_theme_font_size_override("font_size", 50)
		status_label.add_theme_font_size_override("font_size", 50)
		
		tutorial_button.custom_minimum_size = Vector2(0, 64)
		pre_assess_button.custom_minimum_size = Vector2(0, 64)
		easy_button.custom_minimum_size = Vector2(0, 64)
		professional_button.custom_minimum_size = Vector2(0, 64)
		settings_button.custom_minimum_size = Vector2(0, 64)
		
	else:
		# Desktop / Landscape layout
		if info_card and actions and info_card.get_parent() == actions:
			actions.remove_child(info_card)
			right_panel.add_child(info_card)
			
		right_panel.visible = true
		
		right_panel.anchor_left = 0.5
		right_panel.anchor_top = 0.15
		right_panel.anchor_right = 1.0
		right_panel.anchor_bottom = 1.0
		
		left_panel.anchor_left = 0.0
		left_panel.anchor_top = 0.15
		left_panel.anchor_right = 0.5
		left_panel.anchor_bottom = 1.0
		left_panel.add_theme_constant_override("margin_left", 64)
		
		_reset_button_font_sizes()

func _state() -> Node:
	return get_node_or_null("/root/GameState")

# Clears all per-button font-size overrides applied in portrait mode.
func _reset_button_font_sizes() -> void:
	for lbl in [title_label, subtitle_label, info_title, info_desc,
	            certification_label, status_label]:
		if lbl:
			lbl.remove_theme_font_size_override("font_size")
	for btn in [tutorial_button, pre_assess_button, easy_button,
	            professional_button, settings_button]:
		if btn:
			btn.remove_theme_font_size_override("font_size")
			btn.custom_minimum_size = Vector2(0, 0)

func _show_info(title: String, desc: String) -> void:
	if info_title:
		info_title.text = title
	if info_desc:
		info_desc.text = desc

func _on_settings_pressed() -> void:
	if _settings_popup and is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
	var scene = load(SETTINGS_SCENE)
	if scene == null:
		status_label.text = "Settings UI unavailable."
		return
	_settings_popup = scene.instantiate()
	if _settings_popup.has_signal("closed"):
		_settings_popup.closed.connect(_on_settings_closed)
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		canvas.add_child(_settings_popup)
	else:
		add_child(_settings_popup)

func _on_settings_closed() -> void:
	if _settings_popup and is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
	_settings_popup = null

func _refresh_state_ui() -> void:
	_refresh_ui()

func _refresh_ui() -> void:
	var state = _state()
	if state == null:
		status_label.text = "Game state system unavailable."
		for btn in [tutorial_button, pre_assess_button, easy_button, professional_button]:
			btn.disabled = true
		return

	var completed_tutorial: bool  = bool(state.call("has_completed_tutorial"))
	var passed_pre_assessment: bool = bool(state.call("has_passed_pre_assessment"))
	var mode: Dictionary          = state.call("get_selected_mode")
	var day_number := 1
	if state.has_method("get_current_day"):
		day_number = int(state.call("get_current_day"))

	for btn in [tutorial_button, pre_assess_button, easy_button]:
		btn.disabled = false

	pre_assess_button.text = "BFP E-Learning & Assessments"
	tutorial_button.text   = "Play Tutorial"
	easy_button.text       = "Play Normal Mode"

	var s_text = ""
	var cs_mgr = get_node_or_null("/root/CloudSaveManager")
	if cs_mgr:
		var pname = String(cs_mgr.get("player_name"))
		var puid = String(cs_mgr.get("user_id"))
		if pname != "" or puid != "":
			var display_tag = pname if pname != "" else ("User #" + puid)
			s_text += "Agent: %s\n" % display_tag
		var c_high = int(cs_mgr.get("high_score"))
		if c_high > 0:
			s_text += "Cloud High Score: %d pts\n" % c_high

	if not passed_pre_assessment:
		s_text += "Welcome! Please pass the pre-assessment first before live dispatch training."
		professional_button.disabled = true
	elif not completed_tutorial:
		s_text += "Pre-assessment passed. Start the tutorial next before entering live emergency calls on normal mode."
	else:
		s_text += "Tutorial completed. Normal mode is ready, and professional mode is unlocked."

	s_text += "\nCurrent shift day: Day %d" % day_number

	if state.has_method("get_latest_shift_result"):
		var latest: Dictionary = state.call("get_latest_shift_result")
		if not latest.is_empty():
			s_text += "\nLast saved day score: Day %d | %d pts" % [
				int(latest.get("day", 1)), int(latest.get("score", 0))]

	var professional_mode: Dictionary = state.call("get_mode", "professional_nlp_dispatch")
	professional_button.text = String(professional_mode.get("title", "Professional Dispatcher"))
	var force_professional_for_test := (
		state.has_method("is_professional_mode_temporarily_forced")
		and bool(state.call("is_professional_mode_temporarily_forced"))
	)
	var professional_unlocked: bool = (
		bool(state.call("is_mode_unlocked", "professional_nlp_dispatch"))
		and (force_professional_for_test or passed_pre_assessment)
	)
	professional_button.disabled = not professional_unlocked

	if force_professional_for_test:
		certification_label.text = "Certification status: temporary test override enabled"
	elif professional_unlocked:
		certification_label.text = "Certification status: unlocked"
	else:
		certification_label.text = "Certification required: BFP Sta. Cruz Dispatch Certification"

	if not mode.is_empty():
		s_text += "\nCurrent selected mode: %s" % String(mode.get("title", "Normal"))

	status_label.text = s_text

func _on_tutorial_pressed() -> void:
	var state = _state()
	if state and state.has_method("set_force_tutorial"):
		state.call("set_force_tutorial", true)
	get_tree().change_scene_to_file(TUTORIAL_SCENE)

func _on_pre_assess_pressed() -> void:
	get_tree().change_scene_to_file(PRE_ASSESS_SCENE)

func _on_easy_pressed() -> void:
	var state = _state()
	if state == null:
		status_label.text = "Game state system unavailable."
		return
	_pending_mode_id = "easy_multiple_choice"
	
	var saved_shift: Dictionary = {}
	if state.has_method("get_saved_shift_for_mode"):
		saved_shift = state.call("get_saved_shift_for_mode", "easy_multiple_choice")
		
	if not saved_shift.is_empty():
		_save_popup.popup_centered()
	else:
		_on_difficulty_custom_action("easy")

func _on_professional_pressed() -> void:
	var state = _state()
	if state == null:
		status_label.text = "Game state system unavailable."
		return
	if not bool(state.call("is_mode_unlocked", "professional_nlp_dispatch")):
		status_label.text = String(state.call("get_mode_lock_reason", "professional_nlp_dispatch"))
		return
		
	_pending_mode_id = "professional_nlp_dispatch"
	
	var saved_shift: Dictionary = {}
	if state.has_method("get_saved_shift_for_mode"):
		saved_shift = state.call("get_saved_shift_for_mode", "professional_nlp_dispatch")
	else:
		state.call("select_mode", "professional_nlp_dispatch")
		saved_shift = state.call("get_saved_shift")
	if not saved_shift.is_empty():
		_save_popup.popup_centered()
	else:
		_difficulty_popup.popup_centered()

func _on_continue_shift() -> void:
	_save_popup.hide()
	var state = _state()
	if state and _pending_mode_id != "":
		state.call("select_mode", _pending_mode_id)
	get_tree().change_scene_to_file(_get_route_scene())

func _on_restart_shift() -> void:
	_save_popup.hide()
	var state = _state()
	if state:
		if state.has_method("clear_saved_shift_for_mode") and _pending_mode_id != "":
			state.call("clear_saved_shift_for_mode", _pending_mode_id)
			state.call("select_mode", _pending_mode_id)
		else:
			state.call("select_mode", "professional_nlp_dispatch")
			state.call("clear_shift_progress")
	if _pending_mode_id == "easy_multiple_choice":
		_on_difficulty_custom_action("easy")
	else:
		_difficulty_popup.popup_centered()

func _on_restart_all() -> void:
	_save_popup.hide()
	var state = _state()
	if state:
		if state.has_method("clear_all_saves"):
			state.call("clear_all_saves")
			if _pending_mode_id != "":
				state.call("select_mode", _pending_mode_id)
		else:
			state.call("clear_shift_progress")
	if _pending_mode_id == "easy_multiple_choice":
		_on_difficulty_custom_action("easy")
	else:
		_difficulty_popup.popup_centered()

func _on_difficulty_custom_action(action: StringName) -> void:
	var state = _state()
	var action_str = String(action)
	if state:
		if action_str == "medium":
			state.call("set_professional_difficulty", "medium")
		elif action_str == "hard":
			state.call("set_professional_difficulty", "hard")
		elif action_str == "easy":
			state.call("set_professional_difficulty", "easy")
	_difficulty_popup.hide()
	if state and _pending_mode_id != "":
		state.call("select_mode", _pending_mode_id)
	get_tree().change_scene_to_file(_get_route_scene())

func _on_difficulty_easy() -> void:
	_on_difficulty_custom_action("easy")
