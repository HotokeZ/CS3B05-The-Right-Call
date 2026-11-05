extends Node2D

@export var map_texture_path: String = "res://assets/maps/map_high.png"
@export var route_json_res_path: String = "res://data/routes/citywide_patrol_route.json"
@export var station_json_res_path: String = "res://data/gameplay/service_stations.json"
@export var building_json_res_path: String = ""
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export var dispatch_initial_delay_s: float = 2.0
@export var dispatch_between_calls_min_s: float = 5.0
@export var dispatch_between_calls_max_s: float = 10.0
@export var transcript_tick_s: float = 0.9
@export var shift_duration_s: int = 300
@export var shift_min_score: int = 250
@export var max_waiting_calls: int = 3
@export var responder_speed_multiplier: float = 2.2
@export var responder_follow_smoothing: float = 10.0
@export var use_safe_road_overlay: bool = true
@export var road_inner_width_px: float = 8.0
@export var road_outline_width_px: float = 12.0
@export var road_inner_color: Color = Color8(243, 246, 252)
@export var road_outline_color: Color = Color8(126, 144, 168)

# Runtime map state
var _map_sprite: Sprite2D
var _world_node: Node2D
var _img_w: int = 0
var _img_h: int = 0
var _current_scale: float = 1.0
var _min_scale: float = 1.0
var _max_scale: float = 4.0
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO
var _user_zoomed: bool = false
var _call_active: bool = false  # When true, map input is frozen
var _follow_dispatched_vehicle: bool = false
var _follow_vehicle_pos_valid: bool = false
var _follow_vehicle_world_pos: Vector2 = Vector2.ZERO
var _station_layer: Node2D = null
var _station_markers: Array = []
var _road_overlay_layer: Node2D = null

# Existing HUD nodes from scene
var _mode_label: Label
var _hint_label: Label
var _home_button: Button
var _hud_content: VBoxContainer

# Rotating tips
var _tips_list: Array = []
var _tip_index: int = 0
var _tip_timer: Timer = null

# Dispatch UI state
var _dim_overlay: ColorRect
var _dispatch_panel: PanelContainer
var _close_button: Button
var _tab_container: HBoxContainer
var _panel_header_label: Label
var _incident_summary_label: Label
var _incoming_label: Label
var _chat_box: VBoxContainer
var _caller_portrait: TextureRect
var _operator_portrait: TextureRect
var _current_call_mistakes: int = 0
var _caller_images: Array = []
var _response_prompt_label: Label
var _choices_box: VBoxContainer
var _hint_button: Button
var _hint_display_label: RichTextLabel
var _typed_row: HBoxContainer
var _typed_input: LineEdit
var _typed_submit_button: Button
var _response_feedback_label: Label
var _assignment_label: Label
var _timeline_label: Label
var _keyboard_toggle_button: TextureButton
var _manual_panel: PanelContainer
var _manual_text: RichTextLabel
var _vehicle_buttons: Dictionary = {}
var _vehicle_grid: GridContainer
var _dispatch_phase_unlocked: bool = false

# Dispatch gameplay state
var _route_points_px: Array = []
var _buildings_px: Array = []
var _pending_call: Dictionary = {}
var _active_call: Dictionary = {}
var _active_call_marker: Node2D = null
var _active_call_world_position: Vector2 = Vector2.ZERO
var _transcript_index: int = 0
var _awaiting_dispatch: bool = false
var _has_dispatched_vehicle: bool = false
var _services_arrived: bool = false
var _pending_resolution_s: float = 0.0
var _response_quality: String = "uncertain"
var _selected_mode_id: String = "easy_multiple_choice"
var _selected_locale: String = "en"
var _current_day: int = 1
var _day_difficulty_scale: float = 1.0
var _queued_calls: Array = []
var _conversation_log: Array = []  # Running log of {speaker, text} for LLM context
var _call_sequence: int = 0

# Interactive transcript state
var _is_interactive_tutorial: bool = false
var _tutorial_panel: PanelContainer = null
var _tutorial_label: Label = null
var _tutorial_proceed_lbl: Label = null
var _caller_lines: Array = []  # Filtered: only Caller/System lines
var _caller_line_index: int = 0  # Which caller line we're on
var _interactive_phase: int = 0  # 0=waiting, 1+=response round N
var _player_responded_this_round: bool = false
var _intake_stage: int = -1
var _location_revealed: bool = false
var _complaint_revealed: bool = false

# Decision point BKT retry tracking (Option B: One Decision Point = One BKT Observation)
var _dp_attempts: int = 0
var _dp_mistakes: int = 0
var _dp_first_attempt_correct: bool = false
var _current_dp_context: Dictionary = {}
var _awaiting_dispatcher_prompt: bool = false
var _expected_dispatcher_prompt_text: String = ""
var _active_mid_transcript_options: Array = []
var _active_rendered_options: Array = []
var _active_mid_rendered_options: Array = []
var _bypassed_intake: bool = false
var _num_interactive_choices_answered: int = 0
var _professional_scored_tags: Dictionary = {}
var _coach_pointer_label: Label = null
var _coach_pointer_tween: Tween = null
var _tutorial_focus_layer: Control = null
var _tutorial_focus_blocks: Array = []
var _tutorial_focus_target: Variant = null
var _tutorial_focus_tween: Tween = null

# Scoring
var _call_score: int = 0
var _total_score: int = 0
var _shift_score: int = 0
var _calls_completed: int = 0
var _wrong_advice_count: int = 0

var _call_start_time: float = 0.0
var _score_label: Label
var _shift_label: Label
var _score_container: VBoxContainer
var _feedback_dialog: AcceptDialog
var _feedback_popup_context: String = ""
var _kid_message_dialog: AcceptDialog
var _hud_panel: PanelContainer
var _toggle_hud_button: Button
var _minimized_call_button: Button
var _next_day_button: Button
var _offscreen_indicator: Area2D
var _offscreen_indicator_arrow: Polygon2D
var _shift_remaining_s: int = 0
var _shift_time_complete_announced: bool = false
var _shift_ready_announced: bool = false
var _pending_day_restart: bool = false
var _post_shift_action: String = ""
var _shift_review_dialog: AcceptDialog
var _shift_review_list: VBoxContainer
var _shift_review_other_button: Button
var _shift_review_proceed_button: Button
var _other_options_dialog: AcceptDialog
var _other_options_list: VBoxContainer
var _shift_call_reviews: Array = []
var _current_call_review: Dictionary = {}

# Timers
var _transcript_timer: Timer
var _next_call_timer: Timer
var _arrival_timer: Timer
var _resolution_timer: Timer
var _shift_timer: Timer

# Helpers
var _dispatch_rng := RandomNumberGenerator.new()
var _scenario_generator: RefCounted
var _patrol_manager: Node = null

# Gemini API Integration for HTML5 LLM
var _llm_http: HTTPRequest = null
var _llm_persona: RefCounted = null   # LLMPersona — prompt builder & API config
var _is_waiting_for_llm: bool = false
var _intake_location_asked: bool = false
var _intake_emergency_asked: bool = false

var _virtual_keyboard: Node = null

func _ready() -> void:
	_llm_http = HTTPRequest.new()
	_llm_http.accept_gzip = false
	add_child(_llm_http)
	_llm_persona = load("res://scripts/systems/llm_persona.gd").new()
	# Instantiate the virtual keyboard as a CanvasLayer overlay
	_virtual_keyboard = load("res://scripts/ui/virtual_keyboard.gd").new()
	add_child(_virtual_keyboard)
	_virtual_keyboard.text_changed.connect(func(new_text):
		if _typed_input:
			_typed_input.text = new_text
			_typed_input.caret_column = new_text.length()
	)
	_virtual_keyboard.hide_requested.connect(func():
		if _virtual_keyboard:
			_virtual_keyboard.visible = false
			if _dispatch_panel:
				_dispatch_panel.offset_bottom = 0
	)
	_virtual_keyboard.submit_pressed.connect(_on_typed_submit_pressed)



	# ── Audio ─────────────────────────────────────────────────────────────
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_bgm()

	var state = get_node_or_null("/root/GameState")
	if state:
		var _init_mode_id: String = "easy_multiple_choice"
		if state.has_method("get_selected_mode"):
			var _init_mode: Dictionary = state.call("get_selected_mode")
			_init_mode_id = String(_init_mode.get("id", "easy_multiple_choice"))
		var _is_normal_mode: bool = (_init_mode_id == "easy_multiple_choice")
		if not state.call("get_first_live_call_done") and _is_normal_mode:
			_is_interactive_tutorial = true
		if state.has_method("get_force_tutorial") and state.call("get_force_tutorial") and _is_normal_mode:
			_is_interactive_tutorial = true
			
		if state.has_method("get_locale"):
			_selected_locale = String(state.call("get_locale"))
		if state.has_method("get_current_day"):
			_current_day = max(1, int(state.call("get_current_day")))
		if state.has_method("get_day_difficulty_scale"):
			_day_difficulty_scale = max(1.0, float(state.call("get_day_difficulty_scale")))
		# Load persistent cumulative score
		if state.has_method("get_persistent_score"):
			_total_score = int(state.call("get_persistent_score"))
		else:
			_total_score = 0

		if state.has_method("get_saved_shift"):
			var saved = state.call("get_saved_shift")
			# ONLY restore shift progress if we are NOT running the tutorial refresher
			if not saved.is_empty() and not _is_interactive_tutorial:
				if saved.has("total_score"):
					_total_score = int(saved.get("total_score", _total_score))
				if saved.has("shift_score"):
					_shift_score = int(saved.get("shift_score", 0))
				elif saved.has("total_score"):
					_shift_score = int(saved.get("total_score", 0))
				_calls_completed = int(saved.get("calls_completed", 0))
				_shift_call_reviews = saved.get("shift_call_reviews", [])
				_shift_remaining_s = int(saved.get("shift_remaining_s", _shift_remaining_s))
		if state.has_method("get_total_historical_calls"):
			_call_sequence = _calls_completed


	if _shift_remaining_s <= 0:
		_shift_remaining_s = max(1, shift_duration_s)

	_dispatch_rng.randomize()
	_map_sprite = $Map
	_world_node = $World

	_init_map_dimensions()
	_fit_map_to_viewport()
	_configure_world_route_source()

	get_viewport().connect("size_changed", Callable(self, "_on_viewport_resized"))
	_add_vehicle_manager()

	_load_caller_images()
	_setup_hud()

func _load_caller_images() -> void:
	var path = "res://assets/Portraits/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".import", "").replace(".remap", "")
				if clean_name.ends_with(".png") and "Berong" not in clean_name:
					var full_path = path + clean_name
					if not _caller_images.has(full_path):
						_caller_images.append(full_path)
			file_name = dir.get_next()
	_setup_scenario_generator()
	_load_route_points_for_calls()
	_setup_dispatch_ui()
	_apply_kid_friendly_ui()
	_setup_dispatch_timers()
	if _is_interactive_tutorial:
		_create_tutorial_ui()
	_schedule_next_call(dispatch_initial_delay_s)

func _create_tutorial_ui() -> void:
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.custom_minimum_size = Vector2(300, 64)
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_tutorial_panel.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.5, 0.7, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.8, 0.2, 1.0)
	_tutorial_panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12.0
	hbox.offset_top = 8.0
	hbox.offset_right = -12.0
	hbox.offset_bottom = -8.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 16)
	_tutorial_panel.add_child(hbox)
	
	var icon = Label.new()
	icon.text = "COACH:"
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	hbox.add_child(icon)
	
	_tutorial_label = Label.new()
	_tutorial_label.text = "Waiting for your first emergency call..."
	_tutorial_label.add_theme_font_size_override("font_size", 20)
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_tutorial_label)
	
	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(80, 36)
	skip_btn.focus_mode = Control.FOCUS_NONE
	var skip_btn_style = StyleBoxFlat.new()
	skip_btn_style.bg_color = Color(0.8, 0.25, 0.25, 1.0)
	skip_btn_style.corner_radius_top_left = 6
	skip_btn_style.corner_radius_top_right = 6
	skip_btn_style.corner_radius_bottom_left = 6
	skip_btn_style.corner_radius_bottom_right = 6
	skip_btn.add_theme_stylebox_override("normal", skip_btn_style)
	
	var skip_btn_hover = StyleBoxFlat.new()
	skip_btn_hover.bg_color = Color(0.9, 0.35, 0.35, 1.0)
	skip_btn_hover.corner_radius_top_left = 6
	skip_btn_hover.corner_radius_top_right = 6
	skip_btn_hover.corner_radius_bottom_left = 6
	skip_btn_hover.corner_radius_bottom_right = 6
	skip_btn.add_theme_stylebox_override("hover", skip_btn_hover)
	
	skip_btn.pressed.connect(_on_skip_tutorial_pressed)
	hbox.add_child(skip_btn)
	
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		canvas.add_child(_tutorial_panel)
		canvas.move_child(_tutorial_panel, -1)
	else:
		add_child(_tutorial_panel)
		
	_tutorial_proceed_lbl = Label.new()
	_tutorial_proceed_lbl.text = "Click to proceed"
	_tutorial_proceed_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tutorial_proceed_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tutorial_proceed_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tutorial_proceed_lbl.offset_right = -20
	_tutorial_proceed_lbl.offset_bottom = -20
	_tutorial_proceed_lbl.add_theme_font_size_override("font_size", 24)
	_tutorial_proceed_lbl.add_theme_color_override("font_color", Color(1, 1, 0.5, 0.9))
	_tutorial_proceed_lbl.add_theme_constant_override("outline_size", 4)
	_tutorial_proceed_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_tutorial_proceed_lbl.visible = false
	if canvas:
		canvas.add_child(_tutorial_proceed_lbl)
	else:
		add_child(_tutorial_proceed_lbl)
		
	_layout_tutorial_panel()

func _layout_tutorial_panel() -> void:
	if _tutorial_panel == null:
		return
	var vp_size = get_viewport().get_visible_rect().size
	var panel_width = clamp(vp_size.x - 24.0, 300.0, 860.0)
	_tutorial_panel.anchor_left = 0.5
	_tutorial_panel.anchor_right = 0.5
	_tutorial_panel.anchor_top = 0.0
	_tutorial_panel.anchor_bottom = 0.0
	_tutorial_panel.offset_left = -panel_width * 0.5
	_tutorial_panel.offset_right = panel_width * 0.5
	_tutorial_panel.offset_top = 10.0
	_tutorial_panel.offset_bottom = 78.0

func _set_intake_state(location_known: bool, complaint_known: bool) -> void:
	_location_revealed = location_known
	_complaint_revealed = complaint_known
	if _incident_summary_label:
		if _complaint_revealed:
			_incident_summary_label.text = "Complaint: %s" % String(_active_call.get("title", "Emergency"))
		else:
			_incident_summary_label.text = "Complaint: Ask the caller first"
	if _incoming_label:
		var location_text = "Unknown"
		if _location_revealed:
			location_text = String(_active_call.get("location", "Unknown"))
		_incoming_label.text = "Location: %s\nSeverity: %s" % [
			location_text,
			String(_active_call.get("severity", "medium")).capitalize()
		]

func _ensure_coach_pointer() -> void:
	if _coach_pointer_label != null:
		return
	var canvas = get_node_or_null("TutorialTopLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "TutorialTopLayer"
		canvas.layer = 128
		add_child(canvas)
	_coach_pointer_label = Label.new()
	_coach_pointer_label.name = "CoachPointer"
	_coach_pointer_label.visible = false
	_coach_pointer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_pointer_label.add_theme_font_size_override("font_size", 20)
	_coach_pointer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	_coach_pointer_label.add_theme_constant_override("outline_size", 5)
	_coach_pointer_label.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.35, 0.95))
	_coach_pointer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(_coach_pointer_label)

func _ensure_tutorial_focus_layer() -> void:
	if _tutorial_focus_layer != null:
		return
	var canvas = get_node_or_null("TutorialTopLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "TutorialTopLayer"
		canvas.layer = 128
		add_child(canvas)
	_tutorial_focus_layer = Control.new()
	_tutorial_focus_layer.name = "TutorialFocusLayer"
	_tutorial_focus_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_focus_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_focus_layer.visible = false
	canvas.add_child(_tutorial_focus_layer)
	canvas.move_child(_tutorial_focus_layer, -1)

	_tutorial_focus_blocks.clear()
	for _i in range(4):
		var block = ColorRect.new()
		block.color = Color(0.0, 0.0, 0.08, 0.52)
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		block.visible = false
		_tutorial_focus_layer.add_child(block)
		_tutorial_focus_blocks.append(block)

func _update_tutorial_focus_layout() -> void:
	if _tutorial_focus_layer == null or _tutorial_focus_target == null:
		return
	if typeof(_tutorial_focus_target) == TYPE_OBJECT:
		if _tutorial_focus_target is Control:
			if not _tutorial_focus_target.is_visible_in_tree():
				_hide_coach_pointer()
				return
		elif _tutorial_focus_target is Window:
			if not _tutorial_focus_target.visible:
				_hide_coach_pointer()
				return

	var top_parent: Viewport = get_viewport()
	if typeof(_tutorial_focus_target) == TYPE_OBJECT and _tutorial_focus_target is Node and _tutorial_focus_target.is_inside_tree():
		top_parent = _tutorial_focus_target.get_viewport()
		
	var vp = top_parent.get_visible_rect().size
	var rect: Rect2
	if _tutorial_focus_target is Control:
		rect = _tutorial_focus_target.get_global_rect()
		rect = rect.grow(8.0)
	elif _tutorial_focus_target is Window:
		rect = Rect2(Vector2.ZERO, _tutorial_focus_target.size).grow(8.0)
	else:
		return
		
	var left = clamp(rect.position.x, 0.0, vp.x)
	var top = clamp(rect.position.y, 0.0, vp.y)
	var right = clamp(rect.position.x + rect.size.x, 0.0, vp.x)
	var bottom = clamp(rect.position.y + rect.size.y, 0.0, vp.y)

	var top_block: ColorRect = _tutorial_focus_blocks[0]
	top_block.position = Vector2(0.0, 0.0)
	top_block.size = Vector2(vp.x, top)
	top_block.visible = true

	var bottom_block: ColorRect = _tutorial_focus_blocks[1]
	bottom_block.position = Vector2(0.0, bottom)
	bottom_block.size = Vector2(vp.x, max(0.0, vp.y - bottom))
	bottom_block.visible = true

	var left_block: ColorRect = _tutorial_focus_blocks[2]
	left_block.position = Vector2(0.0, top)
	left_block.size = Vector2(left, max(0.0, bottom - top))
	left_block.visible = true

	var right_block: ColorRect = _tutorial_focus_blocks[3]
	right_block.position = Vector2(right, top)
	right_block.size = Vector2(max(0.0, vp.x - right), max(0.0, bottom - top))
	right_block.visible = true

func _show_tutorial_focus(target: Variant) -> void:
	if not _is_interactive_tutorial:
		return
	if target == null:
		_hide_tutorial_focus()
		return
	_ensure_tutorial_focus_layer()
	if _tutorial_focus_layer == null:
		return
		
	var top_parent: Node = self
	if typeof(target) == TYPE_OBJECT and target is Node and target.is_inside_tree():
		top_parent = target.get_viewport()
	var canvas = top_parent.get_node_or_null("TutorialTopLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "TutorialTopLayer"
		canvas.layer = 128
		top_parent.add_child(canvas)
		
	if _tutorial_focus_layer.get_parent() != canvas:
		if _tutorial_focus_layer.get_parent():
			_tutorial_focus_layer.get_parent().remove_child(_tutorial_focus_layer)
		canvas.add_child(_tutorial_focus_layer)
		canvas.move_child(_tutorial_focus_layer, -1)
		
	_tutorial_focus_target = target
	_tutorial_focus_layer.visible = true
	_update_tutorial_focus_layout()
	if _tutorial_focus_tween:
		_tutorial_focus_tween.kill()
		_tutorial_focus_tween = null
	_tutorial_focus_tween = create_tween()
	for block in _tutorial_focus_blocks:
		if block is ColorRect:
			var cr: ColorRect = block
			cr.color = Color(0.0, 0.0, 0.08, 0.0)
			_tutorial_focus_tween.parallel().tween_property(cr, "color:a", 0.52, 0.2)

func _hide_tutorial_focus() -> void:
	_tutorial_focus_target = null
	if _tutorial_focus_tween:
		_tutorial_focus_tween.kill()
		_tutorial_focus_tween = null
	if _tutorial_focus_layer:
		_tutorial_focus_layer.visible = false
	for block in _tutorial_focus_blocks:
		if block is ColorRect:
			(block as ColorRect).visible = false

func _hide_coach_pointer() -> void:
	if _coach_pointer_tween:
		_coach_pointer_tween.kill()
		_coach_pointer_tween = null
	if _coach_pointer_label:
		_coach_pointer_label.visible = false
	if _tutorial_proceed_lbl:
		_tutorial_proceed_lbl.visible = false
	_hide_tutorial_focus()

func _point_coach_at(target: Control, prompt: String) -> void:
	if not _is_interactive_tutorial:
		return
	if target == null or not target.is_visible_in_tree():
		_hide_coach_pointer()
		return
	_ensure_coach_pointer()
	if _coach_pointer_label == null:
		return
	if _coach_pointer_tween:
		_coach_pointer_tween.kill()
		_coach_pointer_tween = null
		
	var top_parent: Node = self
	if target.is_inside_tree():
		top_parent = target.get_viewport()
	var canvas = top_parent.get_node_or_null("TutorialTopLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "TutorialTopLayer"
		canvas.layer = 128
		top_parent.add_child(canvas)
		
	if _coach_pointer_label.get_parent() != canvas:
		if _coach_pointer_label.get_parent():
			_coach_pointer_label.get_parent().remove_child(_coach_pointer_label)
		canvas.add_child(_coach_pointer_label)
		
	if _tutorial_proceed_lbl:
		_tutorial_proceed_lbl.visible = true

	_coach_pointer_label.text = "%s" % prompt
	_coach_pointer_label.custom_minimum_size = Vector2(400, 30)
	_coach_pointer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var target_rect = target.get_global_rect()
		
	var vp = top_parent.get_visible_rect().size
	var label_height = _coach_pointer_label.get_minimum_size().y
	var base_y = target_rect.position.y - label_height - 10.0
	if prompt == "Dispatch":
		# Pin directly above the target button instead of floating upward.
		base_y = target_rect.position.y - label_height - 8.0
	elif prompt == "Answer Call":
		base_y = target_rect.position.y + target_rect.size.y + 10.0
		
	if base_y < 10:
		base_y = target_rect.position.y + target_rect.size.y + 10.0
		
	var base_x = target_rect.position.x + (target_rect.size.x / 2.0) - 200
	if base_x < 10:
		base_x = 10
	elif base_x + 400 > vp.x - 10:
		base_x = vp.x - 410
		
	var base_pos = Vector2(base_x, base_y)
	_coach_pointer_label.global_position = base_pos
	_coach_pointer_label.visible = true
	_show_tutorial_focus(target)
	if _coach_pointer_label.get_parent():
		_coach_pointer_label.get_parent().move_child(_coach_pointer_label, -1)
	_coach_pointer_tween = create_tween()
	_coach_pointer_tween.set_loops()
	_coach_pointer_tween.tween_property(_coach_pointer_label, "global_position:y", base_pos.y - 8.0, 0.45)
	_coach_pointer_tween.tween_property(_coach_pointer_label, "global_position:y", base_pos.y, 0.45)

func _start_intake_prompt() -> void:
	_intake_stage = 0
	_clear_choice_buttons()
	if _selected_mode_id != "easy_multiple_choice":
		if _typed_row:
			_typed_row.visible = true
		if _typed_input:
			_typed_input.placeholder_text = "Ask for exact location and callback number..."
			_typed_input.grab_focus()
		if _response_prompt_label:
			_response_prompt_label.text = "Intake step 1/2: Ask for location first (and callback number)."
		return

	# Check if this scenario has built-in interactive transcript options
	var has_interactive = false
	if not _active_call.is_empty():
		for turn in _active_call.get("transcript", []):
			if typeof(turn) == TYPE_DICTIONARY and turn.has("options"):
				has_interactive = true
				break
				
	if has_interactive:
		_intake_stage = -1
		_bypassed_intake = true
		if _typed_row:
			_typed_row.visible = false
		_begin_call_transcript_after_intake(false)
		return

	if _typed_row:
		_typed_row.visible = false
		
	var t_ask_location = "What is your exact location?"
	var t_prompt = "Intake step 1/2: Ask for exact location."
	if _selected_locale == "tl":
		t_ask_location = "Saan po ang eksaktong lokasyon ninyo?"
		t_prompt = "Intake step 1/2: Itanong ang eksaktong lokasyon."
	elif _selected_locale == "taglish":
		t_ask_location = "What is your exact location po?"
		t_prompt = "Intake step 1/2: Ask for exact location po."
		
	if _response_prompt_label:
		_response_prompt_label.text = t_prompt
	if _choices_box:
		var location_btn = Button.new()
		location_btn.text = t_ask_location
		location_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_choice_button(location_btn, _ui_scale_factor())
		location_btn.pressed.connect(Callable(self , "_on_intake_question_pressed").bind(0))
		_choices_box.add_child(location_btn)
		_animate_choice_button_attention(location_btn)
		if _is_interactive_tutorial:
			if _tutorial_label:
				_tutorial_label.text = "First step: ask where the caller is."
			_point_coach_at(location_btn, "Ask location")

func _on_wrong_intake_pressed(explanation: String = "") -> void:
	if _feedback_dialog:
		_feedback_popup_context = ""
		_apply_dialog_color_and_juice(false, true)
		var msg = "Unsafe dialogue choice."
		if explanation != "":
			msg += "\n\nWhy:\n" + explanation
		else:
			msg += "\n\nAlways ask for critical information directly or provide safe guidance."
		_feedback_dialog.dialog_text = msg
		_feedback_dialog.popup_centered(Vector2i(600, 200))
		_apply_dialog_juice(false, true)


func _on_intake_question_pressed(step: int) -> void:
	if _active_call.is_empty():
		return
	_clear_choice_buttons()
	
	var t_ask_location = "What is your exact location?"
	var t_location_reply = "We are at %s."
	var t_ask_complaint = "Tell me what happened."
	var t_prompt_complaint = "Intake step 2/2: Ask what happened."
	var t_correct_loc = "Correct Choice.\n\nYour Action: What is your exact location?\n\nWhy:\nEstablishing the location immediately ensures we know where to send help even if the call drops."
	var t_correct_comp = "Correct Choice.\n\nYour Action: Tell me what happened.\n\nWhy:\nGathering the nature of the emergency is the crucial second step to dispatch the appropriate response units."
	
	if _selected_locale == "tl":
		t_ask_location = "Saan po ang eksaktong lokasyon ninyo?"
		t_location_reply = "Nasa %s po kami."
		t_ask_complaint = "Sabihin po ninyo kung ano ang nangyari."
		t_prompt_complaint = "Intake step 2/2: Itanong kung ano ang nangyari."
		t_correct_loc = "Tamang Desisyon.\n\nIyong Aksyon: Saan po ang eksaktong lokasyon ninyo?\n\nDahil:\nAng pagtukoy sa lokasyon agad-agad ay sumisiguro na alam natin kung saan ipadadala ang tulong kahit maputol ang tawag."
		t_correct_comp = "Tamang Desisyon.\n\nIyong Aksyon: Sabihin po ninyo kung ano ang nangyari.\n\nDahil:\nAng pag-alam sa uri ng emergency ang mahalagang ikalawang hakbang upang maipadala ang tamang mga yunit."
	elif _selected_locale == "taglish":
		t_ask_location = "What is your exact location po?"
		t_location_reply = "We are at %s po."
		t_ask_complaint = "Can you tell me what happened po?"
		t_prompt_complaint = "Intake step 2/2: Ask what happened po."
		t_correct_loc = "Correct Choice.\n\nYour Action: What is your exact location po?\n\nWhy:\nEstablishing the location immediately ensures we know where to send help even if the call drops."
		t_correct_comp = "Correct Choice.\n\nYour Action: Can you tell me what happened po?\n\nWhy:\nGathering the nature of the emergency is the crucial second step to dispatch the appropriate response units."

	if step == 0:
		_append_transcript_line("Dispatcher", t_ask_location)
		_append_transcript_line("Caller", t_location_reply % String(_active_call.get("location", "Unknown location")))
		_set_intake_state(true, false)
		_intake_stage = 1
		
		if _feedback_dialog:
			_feedback_popup_context = ""
			_apply_dialog_color_and_juice(true, false)
			_feedback_dialog.dialog_text = t_correct_loc
			_feedback_dialog.popup_centered(Vector2i(600, 200))
			_apply_dialog_juice(true, false)

		if _response_prompt_label:
			_response_prompt_label.text = t_prompt_complaint
		if _choices_box:
			var diff = "easy"
			var game_state = get_node_or_null("/root/GameState")
			if game_state and game_state.has_method("get_professional_difficulty"):
				diff = String(game_state.call("get_professional_difficulty"))
			var num_distractors = 1
			if diff == "medium":
				num_distractors = 2
			elif diff == "hard":
				num_distractors = 3
				
			var _intake_step2_distractors = [
				{"text": "Does anyone at that location have medical insurance?", "feedback": "Emergency dispatch is based on need, not insurance or ability to pay."},
				{"text": "I'll send emergency response units right away, please hold.", "feedback": "You cannot dispatch units until you know WHAT the emergency is. Different emergencies require different units."},
				{"text": "Can I get your full name and phone number for the record?", "feedback": "Bureaucratic details should not delay finding out the nature of the emergency."},
				{"text": "Are you the owner of the property at that location?", "feedback": "Property ownership is irrelevant to dispatching life-saving emergency services."},
				{"text": "Please stay calm and wait outside for responders to arrive.", "feedback": "Dangerous advice. If there is an active shooter or violent threat outside, you just put the caller in danger."},
				{"text": "Can you take a picture of the scene and send it to us?", "feedback": "Never ask a caller to put themselves in danger to gather evidence or media."},
				{"text": "Okay, units are dispatched. You can hang up now.", "feedback": "Never hang up before establishing the nature of the emergency and providing safety instructions."},
				{"text": "Are you willing to file a formal report about this?", "feedback": "You haven't established what is happening yet; assuming it requires a report delays immediate response."},
				{"text": "Is the weather clear where you are right now?", "feedback": "Irrelevant small talk delays dispatching the correct units."},
				{"text": "Have you tried asking a neighbor for help first?", "feedback": "Dismissive and dangerous. They called 911 for professional help."}
			]
			if _selected_locale == "tl":
				_intake_step2_distractors = [
					{"text": "Mayroon bang medical insurance ang sinuman sa lokasyong iyan?", "feedback": "Ang emergency dispatch ay base sa pangangailangan, hindi sa insurance o kakayahang magbayad."},
					{"text": "Magpapadala ako agad ng mga yunit ng emergency, maghintay lang po.", "feedback": "Hindi ka makakapagpadala ng yunit hangga't hindi mo alam kung ano ang emergency. Ang magkakaibang emergency ay nangangailangan ng magkakaibang yunit."},
					{"text": "Maaari ko bang makuha ang iyong buong pangalan at numero para sa rekord?", "feedback": "Ang mga burukratikong detalye ay hindi dapat magpaantala sa pag-alam sa uri ng emergency."},
					{"text": "Kayo po ba ang may-ari ng ari-arian sa lokasyong iyan?", "feedback": "Ang pagmamay-ari ng ari-arian ay walang kinalaman sa pagpapadala ng mga yunit ng emergency."}
				]
			elif _selected_locale == "taglish":
				_intake_step2_distractors = [
					{"text": "May medical insurance ba ang mga tao diyan po?", "feedback": "Emergency dispatch is based on need, not insurance or ability to pay."},
					{"text": "I'll send emergency response units right away, please hold po.", "feedback": "You cannot dispatch units until you know WHAT the emergency is."},
					{"text": "Can I get your full name and phone number for the record po?", "feedback": "Bureaucratic details should not delay finding out the nature of the emergency."}
				]
				
			_intake_step2_distractors.shuffle()
			var bad_texts: Array = _intake_step2_distractors

			var complaint_btn = Button.new()
			complaint_btn.text = t_ask_complaint
			complaint_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_style_choice_button(complaint_btn, _ui_scale_factor())
			complaint_btn.pressed.connect(Callable(self, "_on_intake_question_pressed").bind(1))
			
			var btns = [complaint_btn]
			for i in range(min(num_distractors, bad_texts.size())):
				var bad_btn = Button.new()
				bad_btn.text = bad_texts[i]["text"]
				bad_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_style_choice_button(bad_btn, _ui_scale_factor())
				bad_btn.pressed.connect(Callable(self, "_on_wrong_intake_pressed").bind(bad_texts[i]["feedback"]))
				btns.append(bad_btn)
				
			btns.shuffle()
			_layout_choice_buttons(btns)
			if _is_interactive_tutorial:
				if _feedback_dialog and _feedback_dialog.visible:
					var ok_btn = _feedback_dialog.get_ok_button()
					if ok_btn:
						_show_tutorial_focus(ok_btn)
						_point_coach_at(ok_btn, "Action Feedback shows how your choice affects the situation. Click OK to continue.")
					await _feedback_dialog.confirmed
				if _chat_box and _chat_box.get_parent():
					_scroll_dialog_to_top()
					_point_coach_at(_chat_box.get_parent(), "Read reply")
				await get_tree().create_timer(2.5).timeout
				if is_instance_valid(complaint_btn):
					if _tutorial_label:
						_tutorial_label.text = "Great. Next ask what is happening."
					_scroll_dialog_to_bottom()
					await get_tree().process_frame
					await get_tree().process_frame
					if is_instance_valid(_choices_box):
						_show_tutorial_focus(_choices_box)
					_point_coach_at(complaint_btn, "Ask complaint")
		return

	_append_transcript_line("Dispatcher", t_ask_complaint)
	
	var first_caller_line = String(_active_call.get("title", "There is an emergency and we need help."))
	if not _active_call.is_empty():
		var transcript: Array = _active_call.get("transcript", [])
		for line in transcript:
			if typeof(line) == TYPE_DICTIONARY and String(line.get("speaker", "Caller")).to_lower() == "caller":
				var txt = String(line.get("text", ""))
				if txt != "":
					first_caller_line = txt
					break

	_append_transcript_line("Caller", first_caller_line)
	_set_intake_state(true, true)
	_intake_stage = -1
	
	if _feedback_dialog:
		_feedback_popup_context = ""
		_apply_dialog_color_and_juice(true, false)
		_feedback_dialog.dialog_text = t_correct_comp
		_feedback_dialog.popup_centered(Vector2i(600, 200))
		_apply_dialog_juice(true, false)
		
	if _is_interactive_tutorial:
		if _feedback_dialog and _feedback_dialog.visible:
			var ok_btn = _feedback_dialog.get_ok_button()
			if ok_btn:
				_show_tutorial_focus(ok_btn)
				_point_coach_at(ok_btn, "Action Feedback explains your choice. Click OK to continue.")
			await _feedback_dialog.confirmed
		if _chat_box and _chat_box.get_parent():
			_scroll_dialog_to_top()
			_point_coach_at(_chat_box.get_parent(), "Read reply")
		await get_tree().create_timer(2.5).timeout
		if _tutorial_label:
			_tutorial_label.text = "Nice intake. Now make a safe response choice."
			
	_begin_call_transcript_after_intake(true)

func _begin_call_transcript_after_intake(skip_first_caller_line: bool = false) -> void:
	_caller_lines.clear()
	
	if _selected_mode_id != "easy_multiple_choice":
		_show_player_choices()
		return
		
	var transcript: Array = _active_call.get("transcript", [])
	for raw_line in transcript:
		if typeof(raw_line) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = raw_line
		var speaker = String(line.get("speaker", "Caller")).strip_edges()
		var text = String(line.get("text", "")).strip_edges()
		
		# NEW — pass options entries through as special "choice" turns:
		if line.has("options"):
			_caller_lines.append({
				"speaker": speaker,
				"options": line.get("options", [])
			})
			continue
			
		if text == "":
			continue
		if _is_redundant_911_intake_prompt(speaker, text):
			continue
		_caller_lines.append({"speaker": speaker, "text": text})
	_caller_line_index = 0
	if skip_first_caller_line:
		for i in range(_caller_lines.size()):
			if String(_caller_lines[i].get("speaker", "")) == "Caller":
				_caller_line_index = i + 1
				break
	
	if _caller_lines.is_empty() or _caller_line_index >= _caller_lines.size():
		_show_player_choices()
	else:
		_play_next_caller_line()

func _is_redundant_911_intake_prompt(speaker: String, text: String) -> bool:
	if speaker.to_lower() != "911":
		return false
	var msg = text.to_lower()
	if _text_has_any(msg, [
		"exact location",
		"your location",
		"where are you",
		"state your location",
		"address",
		"located"
	]):
		return true
	if _text_has_any(msg, [
		"what happened",
		"what is your emergency",
		"what's your emergency",
		"nature of your emergency",
		"what are you reporting",
		"describe the emergency",
		"what is the situation",
		"anong emergency"
	]):
		return true
	return false

func _record_response_review(chosen_text: String, label: String, explanation: String, options: Array) -> void:
	if _current_call_review.is_empty():
		return
	var safe_options: Array[String] = []
	var other_options: Array = []
	var all_options: Array = []
	var skipped_selected := false
	for raw_opt in options:
		if typeof(raw_opt) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = raw_opt
		var opt_text = String(opt.get("text", ""))
		var opt_label = String(opt.get("label", "")).to_lower()
		var opt_explanation = String(opt.get("explanation", opt.get("feedback", ""))).strip_edges()
		var opt_payload = {
			"text": opt_text,
			"label": opt_label,
			"impact": _impact_summary_for_label(opt_label),
			"explanation": opt_explanation
		}
		all_options.append(opt_payload)
		if opt_label == "safe":
			safe_options.append(opt_text)
		if not skipped_selected and opt_text == chosen_text:
			skipped_selected = true
			continue
		other_options.append(opt_payload)
	var correct = String(label).to_lower() == "safe"
	_current_call_review["checks_total"] = int(_current_call_review.get("checks_total", 0)) + 1
	if correct:
		_current_call_review["checks_correct"] = int(_current_call_review.get("checks_correct", 0)) + 1
	var new_resp = {
		"chosen_text": chosen_text,
		"label": label,
		"correct": correct,
		"safe_options": safe_options,
		"all_options": all_options,
		"other_options": other_options,
		"explanation": explanation
	}
	
	if not _current_call_review.has("responses"):
		_current_call_review["responses"] = []
	var arr: Array = _current_call_review["responses"]
	arr.append(new_resp)
	
	# Also set "response" to the last one for backward compatibility with other scripts
	_current_call_review["response"] = new_resp

func _impact_summary_for_label(label: String) -> String:
	match String(label).to_lower():
		"safe":
			return "Likely better outcome: this option generally improves safety and response quality."
		"unsafe":
			return "Likely worse outcome: this option can increase danger or delay effective help."
		_:
			return "Mixed outcome: this option may help partially but is not the strongest choice."

func _record_vehicle_review(selected_vehicle: String, recommended_str: String, correct: bool, explanation: String) -> void:
	if _current_call_review.is_empty():
		return
	_current_call_review["checks_total"] = int(_current_call_review.get("checks_total", 0)) + 1
	if correct:
		_current_call_review["checks_correct"] = int(_current_call_review.get("checks_correct", 0)) + 1
		
	var new_disp = {
		"selected": _vehicle_name(selected_vehicle),
		"recommended": recommended_str,
		"correct": correct,
		"explanation": explanation
	}
	
	if not _current_call_review.has("dispatches"):
		_current_call_review["dispatches"] = []
	var arr: Array = _current_call_review["dispatches"]
	arr.append(new_disp)
	
	# Keep single key for backward compatibility
	_current_call_review["dispatch"] = new_disp

func _build_shift_review_detail(review: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Location: %s" % String(review.get("location", "Unknown")))
	var protocol_hits: Array = review.get("protocol_hits", [])
	if not protocol_hits.is_empty():
		lines.append("Professional protocol checkpoints:")
		for hit in protocol_hits:
			lines.append("- %s" % String(hit))
		lines.append("")
	var responses: Array = review.get("responses", [])
	if responses.size() == 0 and not review.get("response", {}).is_empty():
		responses = [review.get("response", {})]
		
	if not responses.is_empty():
		var idx = 1
		for response in responses:
			var safe_opts_arr: Array = response.get("safe_options", [])
			var safe_opts = ""
			if not safe_opts_arr.is_empty():
				var safe_bits: Array[String] = []
				for entry in safe_opts_arr:
					safe_bits.append(String(entry))
				safe_opts = " | ".join(PackedStringArray(safe_bits))
			lines.append("Response #%d chosen: %s" % [idx, String(response.get("chosen_text", ""))])
			lines.append("Response #%d result: %s" % [idx, "Correct" if bool(response.get("correct", false)) else "Needs improvement"])
			if safe_opts != "" and idx == 1:
				lines.append("Best safe option(s): %s" % safe_opts)
			var response_explanation = String(response.get("explanation", "")).strip_edges()
			if response_explanation != "":
				lines.append("Why: %s" % response_explanation)
			lines.append("")
			idx += 1
	var dispatches: Array = review.get("dispatches", [])
	if dispatches.is_empty():
		var d = review.get("dispatch", {})
		if not d.is_empty():
			dispatches = [d]
			
	for dispatch in dispatches:
		lines.append("Dispatch sent: %s" % String(dispatch.get("selected", "")))
		lines.append("Recommended unit(s): %s" % String(dispatch.get("recommended", "")))
		lines.append("Dispatch result: %s" % ("Correct" if bool(dispatch.get("correct", false)) else "Not ideal"))
		var dispatch_explanation = String(dispatch.get("explanation", "")).strip_edges()
		if dispatch_explanation != "":
			lines.append("Why: %s" % dispatch_explanation)
		lines.append("")
	return "\n".join(lines)

func _detail_target_height(detail: RichTextLabel) -> float:
	if detail == null:
		return 80.0
	var h = float(detail.get_content_height()) + 10.0
	if h <= 12.0:
		h = 56.0 + float(detail.text.length()) * 0.2
	return clamp(h, 56.0, 420.0)

func _animate_accordion_clip(clip: Control, detail: RichTextLabel, target_height: float, open: bool) -> void:
	if clip == null or detail == null:
		return
	if clip.has_meta("accordion_tween"):
		var running = clip.get_meta("accordion_tween")
		if running is Tween:
			(running as Tween).kill()

	var tw = create_tween()
	clip.set_meta("accordion_tween", tw)
	var current_size = clip.custom_minimum_size
	var goal_h = target_height if open else 0.0
	tw.tween_property(clip, "custom_minimum_size", Vector2(current_size.x, goal_h), 0.2)
	tw.parallel().tween_property(detail, "modulate:a", 1.0 if open else 0.0, 0.16)

func _toggle_accordion_animated(clips: Array, details: Array, toggles: Array, heights: Array, target_index: int, show_text: String, hide_text: String) -> void:
	if target_index < 0 or target_index >= clips.size():
		return
	if target_index >= details.size() or target_index >= heights.size():
		return

	var should_open = true
	if clips[target_index] is Control:
		should_open = (clips[target_index] as Control).custom_minimum_size.y <= 1.0

	for i in range(clips.size()):
		if not (clips[i] is Control) or i >= details.size() or i >= heights.size() or not (details[i] is RichTextLabel):
			continue
		var open = should_open and i == target_index
		var dynamic_height = _detail_target_height(details[i]) if open else float(heights[i])
		_animate_accordion_clip(clips[i], details[i], dynamic_height, open)
		if i < toggles.size() and toggles[i] is Button:
			(toggles[i] as Button).text = hide_text if open else show_text

func _populate_shift_review_list() -> void:
	if _shift_review_list == null:
		return
	for child in _shift_review_list.get_children():
		child.queue_free()

	# Inject the dialog text directly into the scrollable list as a wrapped Label to prevent boundary overlaps
	if _shift_review_dialog != null and _shift_review_dialog.dialog_text != "":
		var popup_msg = _shift_review_dialog.dialog_text
		_shift_review_dialog.dialog_text = ""
		var sum_lbl = Label.new()
		sum_lbl.text = popup_msg
		sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sum_lbl.custom_minimum_size = Vector2(800, 0)
		sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sum_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sum_lbl.add_theme_font_size_override("font_size", 16)
		sum_lbl.add_theme_color_override("font_color", Color8(34, 46, 62))
		_shift_review_list.add_child(sum_lbl)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		_shift_review_list.add_child(spacer)

	if _shift_call_reviews.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No completed calls were recorded this shift."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 17)
		empty_label.add_theme_color_override("font_color", Color8(34, 46, 62))
		_shift_review_list.add_child(empty_label)
		return

	var detail_clips: Array = []
	var detail_nodes: Array = []
	var detail_heights: Array = []
	var toggle_nodes: Array = []

	for review in _shift_call_reviews:
		if typeof(review) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = review
		var card = PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color8(255, 238, 208)
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_left = 10
		card_style.corner_radius_bottom_right = 10
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color8(255, 160, 86)
		card.add_theme_stylebox_override("panel", card_style)
		_shift_review_list.add_child(card)

		var card_margin = MarginContainer.new()
		card_margin.mouse_filter = Control.MOUSE_FILTER_PASS
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_top", 10)
		card_margin.add_theme_constant_override("margin_right", 12)
		card_margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(card_margin)

		var box = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_theme_constant_override("separation", 8)
		card_margin.add_child(box)

		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(row)

		var complaint = Label.new()
		complaint.mouse_filter = Control.MOUSE_FILTER_PASS
		complaint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		complaint.text = "Call %d: %s" % [int(item.get("call_number", 0)), String(item.get("title", "Emergency"))]
		complaint.add_theme_font_size_override("font_size", 17)
		complaint.add_theme_color_override("font_color", Color8(26, 36, 52))
		row.add_child(complaint)

		var checks_total = int(item.get("checks_total", 0))
		var checks_correct = int(item.get("checks_correct", 0))
		var score = int(item.get("score", 0))
		var summary = Label.new()
		summary.mouse_filter = Control.MOUSE_FILTER_PASS
		summary.text = "Score %d | %d/%d" % [score, checks_correct, checks_total]
		summary.add_theme_font_size_override("font_size", 16)
		summary.add_theme_color_override("font_color", Color8(52, 82, 109))
		row.add_child(summary)

		var toggle = Button.new()
		toggle.text = "Show details"
		toggle.custom_minimum_size = Vector2(128, 32)
		_style_choice_button(toggle, 0.88)
		row.add_child(toggle)

		var detail_clip = ScrollContainer.new()
		detail_clip.mouse_filter = Control.MOUSE_FILTER_PASS
		detail_clip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		detail_clip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		detail_clip.custom_minimum_size = Vector2(0, 0)
		detail_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(detail_clip)

		var detail = RichTextLabel.new()
		detail.mouse_filter = Control.MOUSE_FILTER_PASS
		detail.bbcode_enabled = false
		detail.fit_content = true
		detail.scroll_active = false
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.text = _build_shift_review_detail(item)
		detail.add_theme_font_size_override("normal_font_size", 15)
		detail.add_theme_color_override("default_color", Color8(34, 46, 62))
		detail.modulate.a = 0.0
		detail_clip.add_child(detail)

		var card_index = detail_nodes.size()
		detail_clips.append(detail_clip)
		detail_nodes.append(detail)
		detail_heights.append(_detail_target_height(detail))
		toggle_nodes.append(toggle)

		toggle.pressed.connect(func():
			_toggle_accordion_animated(detail_clips, detail_nodes, toggle_nodes, detail_heights, card_index, "Show details", "Hide details")
		)

func _show_shift_review(title: String, summary: String, post_action: String = "", is_tutorial_demo: bool = false) -> void:
	if _shift_review_dialog == null:
		_show_kid_message(title, summary)
		return
	_post_shift_action = post_action
	_shift_review_dialog.title = title
	_shift_review_dialog.dialog_text = summary
	_populate_shift_review_list()
	
	if _shift_review_other_button:
		_shift_review_other_button.disabled = is_tutorial_demo
	if _shift_review_proceed_button:
		_shift_review_proceed_button.disabled = is_tutorial_demo
	
	if not is_tutorial_demo:
		var state = get_node_or_null("/root/GameState")
		if state and state.has_method("clear_shift_progress"):
			state.call("clear_shift_progress")

		# Cloud save hook for game beat / boss scenario completion
		var is_victory = (_shift_score >= shift_min_score and (_current_day >= 5 or title == "Shift Completed" or title == "Day Complete"))
		var cs_mgr = get_node_or_null("/root/CloudSaveManager")
		if cs_mgr and cs_mgr.has_method("save_progress") and is_victory:
			cs_mgr.save_progress(
				_total_score,
				0,
				0,
				0,
				"call_boss_scenario" if _current_day >= 5 else ("day_%d_complete" % _current_day),
				_current_day >= 5
			)
		
	_shift_review_dialog.popup_centered(Vector2i(860, 520))

func _collect_unselected_options(item: Dictionary) -> Array:
	var responses: Array = item.get("responses", [])
	if responses.size() == 0 and not item.get("response", {}).is_empty():
		responses = [item.get("response", {})]
		
	var others: Array = []
	if responses.size() > 0:
		var response = responses[0] # Use the options from the first response mapping
		var chosen_text = String(response.get("chosen_text", "")).strip_edges()
		others = response.get("other_options", []).duplicate(true)
		if others.is_empty():
			var all_opts: Array = response.get("all_options", [])
			for raw_all in all_opts:
				if typeof(raw_all) != TYPE_DICTIONARY:
					continue
				var all_opt: Dictionary = raw_all
				if String(all_opt.get("text", "")).strip_edges() == chosen_text:
					continue
				others.append(all_opt)
	return others

func _build_other_options_card_detail(item: Dictionary, others: Array) -> String:
	var lines: Array[String] = []
	var response: Dictionary = item.get("response", {})
	var chosen_text = String(response.get("chosen_text", "")).strip_edges()
	if chosen_text != "":
		lines.append("You chose: %s" % chosen_text)
		lines.append("")
	var option_number = 1
	for raw_opt in others:
		if typeof(raw_opt) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = raw_opt
		lines.append("Alternative %d: %s" % [option_number, String(opt.get("text", ""))])
		var expl = String(opt.get("explanation", "")).strip_edges()
		if expl != "":
			lines.append("If chosen: %s" % expl)
		lines.append("")
		option_number += 1
	return "\n".join(PackedStringArray(lines))

func _populate_other_options_tiles() -> void:
	if _other_options_list == null:
		return
	for child in _other_options_list.get_children():
		child.queue_free()

	if _shift_call_reviews.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No call reviews are available yet."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 17)
		empty_label.add_theme_color_override("font_color", Color8(34, 46, 62))
		_other_options_list.add_child(empty_label)
		return

	var added_count = 0
	var detail_clips: Array = []
	var detail_nodes: Array = []
	var detail_heights: Array = []
	var toggle_nodes: Array = []
	for review in _shift_call_reviews:
		if typeof(review) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = review
		var others = _collect_unselected_options(item)
		if others.is_empty():
			continue
		added_count += 1

		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color8(255, 238, 208)
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_left = 10
		card_style.corner_radius_bottom_right = 10
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color8(255, 160, 86)
		card.add_theme_stylebox_override("panel", card_style)
		_other_options_list.add_child(card)

		var card_margin = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_top", 10)
		card_margin.add_theme_constant_override("margin_right", 12)
		card_margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(card_margin)

		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card_margin.add_child(box)

		var row = HBoxContainer.new()
		box.add_child(row)

		var title = Label.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text = "Call %d: %s" % [int(item.get("call_number", 0)), String(item.get("title", "Emergency"))]
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", Color8(26, 36, 52))
		row.add_child(title)

		var toggle = Button.new()
		toggle.text = "Show alternatives"
		toggle.custom_minimum_size = Vector2(190, 34)
		_style_choice_button(toggle, 0.86)
		row.add_child(toggle)

		var detail_clip = VBoxContainer.new()
		detail_clip.clip_contents = true
		detail_clip.custom_minimum_size = Vector2(0, 0)
		detail_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(detail_clip)

		var detail = RichTextLabel.new()
		detail.bbcode_enabled = false
		detail.fit_content = true
		detail.scroll_active = false
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.text = _build_other_options_card_detail(item, others)
		detail.add_theme_font_size_override("normal_font_size", 15)
		detail.add_theme_color_override("default_color", Color8(34, 46, 62))
		detail.modulate.a = 0.0
		detail_clip.add_child(detail)

		var card_index = detail_nodes.size()
		detail_clips.append(detail_clip)
		detail_nodes.append(detail)
		detail_heights.append(_detail_target_height(detail))
		toggle_nodes.append(toggle)

		toggle.pressed.connect(func():
			_toggle_accordion_animated(detail_clips, detail_nodes, toggle_nodes, detail_heights, card_index, "Show alternatives", "Hide alternatives")
		)

	if added_count == 0:
		var none_label = Label.new()
		none_label.text = "No alternative answers were captured for this shift yet."
		none_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none_label.add_theme_font_size_override("font_size", 17)
		none_label.add_theme_color_override("font_color", Color8(34, 46, 62))
		_other_options_list.add_child(none_label)

func _on_shift_review_custom_action(action: String) -> void:
	if action == "proceed_next_day":
		_shift_review_dialog.hide()
		get_tree().reload_current_scene()
		return
	if action != "review_other_options":
		return
	if _other_options_dialog == null or _other_options_list == null:
		return
	_other_options_dialog.dialog_text = ""
	_populate_other_options_tiles()
	_other_options_dialog.popup_centered(Vector2i(860, 620))

func _on_shift_review_dialog_confirmed() -> void:
	var action = _post_shift_action
	_post_shift_action = ""
	var tree = get_tree()
	if tree == null:
		return
	if action == "restart_day":
		_pending_day_restart = false
		tree.reload_current_scene()
	elif action == "return_menu":
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("stop_all_sfx"):
			am.stop_all_sfx()
		tree.change_scene_to_file(main_menu_scene_path)
	elif action == "reload_scene":
		tree.reload_current_scene()

func _open_shift_review_for_manual_end(post_action: String, title: String, summary: String) -> void:
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("record_shift_result"):
		state.call("record_shift_result", _shift_score, _calls_completed)
		if state.has_method("log_shift_summary"):
			state.call("log_shift_summary", _shift_score, _calls_completed)
	# Mark the first live call as done whenever a real shift completes so the
	# tutorial never re-appears on Normal mode after a genuine session.
	if state and state.has_method("get_first_live_call_done") and not state.call("get_first_live_call_done"):
		if state.has_method("set_first_live_call_done"):
			state.call("set_first_live_call_done")
	_show_shift_review(title, summary, post_action)

func _init_map_dimensions() -> void:
	var img_w = 0
	var img_h = 0

	if ResourceLoader.exists(map_texture_path):
		var tex: Texture2D = load(map_texture_path)
		if tex:
			_map_sprite.texture = tex
			_map_sprite.centered = false
			var sz = tex.get_size()
			img_w = int(sz.x)
			img_h = int(sz.y)

	if img_w == 0 or img_h == 0:
		img_w = int(_world_node.image_width)
		img_h = int(_world_node.image_height)

	_img_w = img_w
	_img_h = img_h

# Two-finger zoom state
var _touch_points: Dictionary = {}

func _fit_map_to_viewport() -> void:
	if _img_w <= 0 or _img_h <= 0:
		return
	var vp_size = get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	var fit_scale = max(vp_size.x / float(_img_w), vp_size.y / float(_img_h))
	_current_scale = fit_scale
	_min_scale = fit_scale
	_max_scale = fit_scale * 4.0

	var scaled_w = _img_w * fit_scale
	var scaled_h = _img_h * fit_scale
	var offset = Vector2((vp_size.x - scaled_w) * 0.5, (vp_size.y - scaled_h) * 0.5)

	_map_sprite.scale = Vector2(fit_scale, fit_scale)
	_world_node.scale = Vector2(fit_scale, fit_scale)
	_map_sprite.position = offset
	_world_node.position = offset

func _configure_world_route_source() -> void:
	_world_node.route_file_path = route_json_res_path
	_world_node.image_width = _img_w
	_world_node.image_height = _img_h

func _add_vehicle_manager() -> void:
	if not ResourceLoader.exists("res://scripts/vehicles/multi_patrol_manager.gd"):
		return
	var mgr_script = load("res://scripts/vehicles/multi_patrol_manager.gd")
	if mgr_script == null:
		return
	var mgr = mgr_script.new()
	mgr.route_file_path = route_json_res_path
	mgr.bounds_file_path = "res://assets/maps/map.bounds.json"
	mgr.station_file_path = station_json_res_path
	mgr.image_width = _img_w
	mgr.image_height = _img_h
	_world_node.add_child(mgr)
	_patrol_manager = mgr
	if _patrol_manager.has_signal("response_arrived"):
		_patrol_manager.connect("response_arrived", Callable(self, "_on_response_arrived"))
	if _patrol_manager.has_signal("response_position_updated"):
		_patrol_manager.connect("response_position_updated", Callable(self, "_on_response_position_updated"))
	_setup_service_station_markers()

func _on_viewport_resized() -> void:
	if _user_zoomed:
		return
	_fit_map_to_viewport()
	_apply_kid_friendly_ui()
	_layout_tutorial_panel()
	_update_tutorial_focus_layout()

func _station_label_short(vtype: String) -> String:
	match vtype:
		"fire_truck":
			return "BFP"
		"ambulance":
			return "MDRRMO"
		_:
			return "PNP"

func _add_rect_poly(parent: Node2D, center: Vector2, size: Vector2, color: Color, z_index: int = 0) -> void:
	var half = size * 0.5
	var poly = Polygon2D.new()
	poly.z_index = z_index
	poly.color = color
	poly.polygon = PackedVector2Array([
		Vector2(center.x - half.x, center.y - half.y),
		Vector2(center.x + half.x, center.y - half.y),
		Vector2(center.x + half.x, center.y + half.y),
		Vector2(center.x - half.x, center.y + half.y)
	])
	parent.add_child(poly)

func _build_station_building_badge(parent: Node2D, vtype: String) -> void:
	var pin = Polygon2D.new()
	pin.polygon = PackedVector2Array([Vector2(-40, -80), Vector2(40, -80), Vector2(0, 0)])
	pin.color = Color(1.0, 0.9, 0.1, 1.0)
	pin.z_index = 10
	var outline = Line2D.new()
	outline.points = PackedVector2Array([Vector2(-40, -80), Vector2(40, -80), Vector2(0, 0), Vector2(-40, -80)])
	outline.width = 4.0
	outline.default_color = Color(0, 0, 0, 1)
	outline.z_index = 11
	parent.add_child(pin)
	parent.add_child(outline)

func _setup_service_station_markers() -> void:
	if _world_node == null:
		return
	if _station_layer and is_instance_valid(_station_layer):
		_station_layer.queue_free()
	_station_markers.clear()

	_station_layer = Node2D.new()
	_station_layer.name = "ServiceStations"
	_world_node.add_child(_station_layer)

	var station_data: Array = []
	if _patrol_manager and _patrol_manager.has_method("get_service_station_markers"):
		station_data = _patrol_manager.call("get_service_station_markers")

	for st_any in station_data:
		if typeof(st_any) != TYPE_DICTIONARY:
			continue
		var st: Dictionary = st_any
		var pos_any = st.get("position", Vector2.ZERO)
		if not (pos_any is Vector2):
			continue
		var pos: Vector2 = pos_any
		var station_node = Node2D.new()
		station_node.position = pos
		station_node.z_index = 2
		_station_layer.add_child(station_node)

		_build_station_building_badge(station_node, String(st.get("type", "police")))

		var tag = Label.new()
		tag.text = String(st.get("name", "Station"))
		tag.position = Vector2(-184, -20)
		tag.size = Vector2(368, 36)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 20)
		tag.add_theme_color_override("font_color", Color8(34, 48, 66))
		tag.add_theme_constant_override("outline_size", 2)
		tag.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
		station_node.add_child(tag)
		_station_markers.append(station_node)
		
	if not "map_high" in map_texture_path:
		_station_layer.visible = false

func _ui_scale_factor() -> float:
	var width = get_viewport().get_visible_rect().size.x
	if width <= 480.0:
		return 1.75
	if width <= 768.0:
		return 1.45
	if width <= 1024.0:
		return 1.2
	return 1.0

func _style_dispatch_button(btn: Button, base: Color, hover: Color, scale: float) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, round(50.0 * scale))
	btn.add_theme_font_size_override("font_size", int(round(17.0 * scale)))

	var normal = StyleBoxFlat.new()
	normal.bg_color = base
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(1.0, 1.0, 1.0, 0.75)

	var hov = normal.duplicate()
	hov.bg_color = hover

	var dis = normal.duplicate()
	dis.bg_color = Color(0.78, 0.78, 0.8, 0.75)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", Color8(44, 54, 72))

func _style_choice_button(btn: Button, scale: float = 1.0) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, round(58.0 * scale))
	btn.add_theme_font_size_override("font_size", int(round(20.0 * scale)))
	btn.add_theme_color_override("font_color", Color8(32, 42, 58))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color8(255, 225, 158)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color8(247, 159, 49)

	var hover = normal.duplicate()
	hover.bg_color = Color8(255, 236, 182)

	var pressed = normal.duplicate()
	pressed.bg_color = Color8(252, 211, 122)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _set_choice_button_pulse(value: float, btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var pulse = clamp(value, 0.0, 1.0)
	for name in ["normal", "hover", "pressed"]:
		var sb = btn.get_theme_stylebox(name)
		if sb is StyleBoxFlat:
			var flat: StyleBoxFlat = sb
			flat.shadow_size = int(round(2.0 + pulse * 7.0))
			flat.shadow_offset = Vector2.ZERO
			flat.shadow_color = Color(1.0, 0.78, 0.34, 0.22 + pulse * 0.42)

func _animate_choice_button_attention(btn: Button, index: int = 0) -> void:
	if btn == null:
		return
	var delay = min(float(index) * 0.04, 0.2)
	btn.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_set_choice_button_pulse(0.0, btn)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(delay)
	tween.tween_property(btn, "modulate:a", 1.0, 0.25)
	
	var timer = Timer.new()
	timer.wait_time = 3.0
	btn.add_child(timer)
	var pulses = [0]
	
	var pulse_func = func():
		if not is_instance_valid(btn): return
		if pulses[0] >= 3:
			if is_instance_valid(timer): timer.stop()
			return
		pulses[0] += 1
		var p_tween = btn.create_tween()
		p_tween.set_trans(Tween.TRANS_SINE)
		p_tween.set_ease(Tween.EASE_IN_OUT)
		p_tween.tween_method(_set_choice_button_pulse.bind(btn), 0.0, 1.0, 0.22)
		p_tween.tween_method(_set_choice_button_pulse.bind(btn), 1.0, 0.0, 0.22)
	
	timer.timeout.connect(pulse_func)
	timer.start()
	tween.tween_callback(pulse_func)

func _restart_choice_button_pulse(btn: Button, index: int) -> void:
	pass

func _show_kid_message(title: String, message: String) -> void:
	if _kid_message_dialog == null:
		return
	_kid_message_dialog.title = title
	_kid_message_dialog.dialog_text = ""
	
	var scroll = _kid_message_dialog.get_node_or_null("CustomScroll")
	var lbl = null
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "CustomScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, 180)
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_right", 16)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(m)
		lbl = Label.new()
		lbl.name = "CustomLabel"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color8(22, 62, 105))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.add_child(lbl)
		_kid_message_dialog.add_child(scroll)
	else:
		lbl = scroll.get_child(0).get_node("CustomLabel")
		
	lbl.text = message
	var vp_size = get_viewport().get_visible_rect().size
	var popup_w = int(clamp(vp_size.x * 0.86, 420.0, 760.0))
	var popup_h = int(clamp(vp_size.y * 0.42, 220.0, 360.0))
	_kid_message_dialog.popup_centered(Vector2i(popup_w, popup_h))

func _format_shift_time(total_seconds: int) -> String:
	var clamped_seconds = max(0, total_seconds)
	var minutes = clamped_seconds / 60
	var seconds = clamped_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _max_calls_per_shift() -> int:
	return 10

func _remaining_shift_call_slots() -> int:
	var in_flight_calls = _queued_calls.size()
	if not _active_call.is_empty() or _call_active:
		in_flight_calls += 1
	elif not _pending_call.is_empty():
		in_flight_calls += 1
	var used_calls = _calls_completed + in_flight_calls
	return max(0, _max_calls_per_shift() - used_calls)

func _is_shift_window_open() -> bool:
	return _shift_remaining_s <= 0 or _calls_completed >= _max_calls_per_shift()

func _can_end_shift() -> bool:
	return _is_shift_window_open() and _shift_score >= shift_min_score

func _shift_end_block_reason() -> String:
	var reasons: Array[String] = []
	if not _is_shift_window_open():
		reasons.append("Shift unlock: wait %s or complete %d/%d calls" % [_format_shift_time(_shift_remaining_s), _calls_completed, _max_calls_per_shift()])
	if _shift_score < shift_min_score:
		reasons.append("Score: %d/%d (need %d more points)" % [_shift_score, shift_min_score, shift_min_score - _shift_score])
	if _calls_completed >= _max_calls_per_shift() and _shift_score < shift_min_score:
		reasons.append("Daily call limit reached. Day restart required.")
	return "\n".join(reasons)

func _update_shift_ui() -> void:
	var calls_text = "Calls: %d/%d" % [_calls_completed, _max_calls_per_shift()]
	if _shift_label:
		if _can_end_shift():
			_shift_label.text = "Shift: READY | %s" % calls_text
			_shift_label.add_theme_color_override("font_color", Color8(45, 121, 84))
		elif _shift_score >= shift_min_score:
			_shift_label.text = "Shift: Score Ready | %s" % calls_text
			_shift_label.add_theme_color_override("font_color", Color8(44, 54, 72))
		else:
			_shift_label.text = "Shift: Need %d pts | %s" % [shift_min_score - _shift_score, calls_text]
			_shift_label.add_theme_color_override("font_color", Color8(167, 74, 42))

	if _next_day_button:
		_next_day_button.visible = _can_end_shift()
		_next_day_button.text = "Proceed to Day %d" % (_current_day + 1)

	if _home_button:
		_home_button.tooltip_text = "Pause"

func _apply_kid_friendly_ui() -> void:
	var scale = _ui_scale_factor()
	var vp = get_viewport_rect().size
	var is_portrait = vp.y > vp.x
	var is_mobile = scale > 1.0 or is_portrait
	var hud_panel: PanelContainer = get_node_or_null("CanvasLayer/HUDPanel")

	var canvas = get_node_or_null("CanvasLayer")
	if is_portrait and canvas and not canvas.has_node("NotchPad"):
		var notch_pad = ColorRect.new()
		notch_pad.name = "NotchPad"
		notch_pad.color = Color.BLACK
		notch_pad.set_anchors_preset(Control.PRESET_TOP_WIDE)
		notch_pad.custom_minimum_size = Vector2(0, 100)
		canvas.add_child(notch_pad)
		canvas.move_child(notch_pad, 0)

	if _mode_label:
		_mode_label.add_theme_font_size_override("font_size", int(round(22.0 * scale)))
		_mode_label.add_theme_color_override("font_color", Color8(22, 62, 105))
		_mode_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_mode_label.clip_text = true
	if _hint_label:
		_hint_label.add_theme_font_size_override("font_size", int(round(16.0 * scale)))
		_hint_label.add_theme_color_override("font_color", Color8(30, 84, 55))
		_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_label.custom_minimum_size = Vector2(0, 0)
		_hint_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_hint_label.max_lines_visible = 3

	if _score_label:
		var size = 32.0 if is_portrait else 24.0
		_score_label.add_theme_font_size_override("font_size", int(round(size * scale)))
		_score_label.add_theme_constant_override("outline_size", 0)
		_score_label.add_theme_color_override("font_color", Color8(22, 32, 44))
	if _shift_label:
		var size = 22.0 if is_portrait else 18.0
		_shift_label.add_theme_font_size_override("font_size", int(round(size * scale)))
		_shift_label.add_theme_constant_override("outline_size", 0)
		_shift_label.add_theme_color_override("font_color", Color8(52, 82, 109))

	if _dispatch_panel:
		if is_portrait:
			_dispatch_panel.anchor_left = 0.03
			_dispatch_panel.anchor_right = 0.97
			_dispatch_panel.anchor_top = 0.12
			_dispatch_panel.anchor_bottom = 0.96
			_dispatch_panel.offset_left = 0
			_dispatch_panel.offset_right = 0
			_dispatch_panel.offset_top = 0
			_dispatch_panel.offset_bottom = 0
		else:
			_dispatch_panel.anchor_left = 0.05
			_dispatch_panel.anchor_right = 0.95
			_dispatch_panel.anchor_top = 0.1
			_dispatch_panel.anchor_bottom = 0.9
			_dispatch_panel.offset_bottom = 0.0

		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color8(234, 247, 255)
		panel_style.corner_radius_top_left = 18
		panel_style.corner_radius_top_right = 18
		panel_style.corner_radius_bottom_left = 18
		panel_style.corner_radius_bottom_right = 18
		panel_style.border_width_left = 3
		panel_style.border_width_top = 3
		panel_style.border_width_right = 3
		panel_style.border_width_bottom = 3
		panel_style.border_color = Color8(89, 181, 255)
		_dispatch_panel.add_theme_stylebox_override("panel", panel_style)

	if _score_container:
		_score_container.offset_top = 160.0 * scale if is_portrait else 24.0
		var parent = _score_container.get_parent()
		if parent and parent.get_node_or_null("ScoreBG") == null:
			var bg = ColorRect.new()
			bg.name = "ScoreBG"
			bg.color = Color(1.0, 1.0, 1.0, 0.9)
			var bg_style = StyleBoxFlat.new()
			bg_style.bg_color = Color(1.0, 1.0, 1.0, 0.9)
			bg_style.corner_radius_top_left = 8
			bg_style.corner_radius_top_right = 8
			bg_style.corner_radius_bottom_left = 8
			bg_style.corner_radius_bottom_right = 8
			parent.add_child(bg)
			parent.move_child(bg, _score_container.get_index())
		
		var score_bg = parent.get_node_or_null("ScoreBG") if parent else null
		if score_bg:
			_score_container.reset_size()
			score_bg.position = _score_container.position - Vector2(12, 8)
			score_bg.size = _score_container.size + Vector2(24, 16)

	var text_scale = scale * (1.6 if is_portrait else 1.0)

	if _panel_header_label:
		_panel_header_label.add_theme_font_size_override("font_size", int(round(24.0 * text_scale)))
		_panel_header_label.add_theme_color_override("font_color", Color8(22, 62, 105))
	if _incident_summary_label:
		_incident_summary_label.add_theme_font_size_override("font_size", int(round(18.0 * text_scale)))
		_incident_summary_label.add_theme_color_override("font_color", Color8(44, 54, 72))
	if _incoming_label:
		_incoming_label.add_theme_font_size_override("font_size", int(round(13.0 * text_scale)))
		_incoming_label.add_theme_color_override("font_color", Color8(72, 82, 98))
	if _chat_box:
		for hbox in _chat_box.get_children():
			if hbox.get_child_count() > 0:
				for c in hbox.get_children():
					if c is PanelContainer:
						for pc in c.get_children():
							if pc is RichTextLabel:
								pc.add_theme_font_size_override("normal_font_size", int(round(16.0 * text_scale)))
	if _response_prompt_label:
		_response_prompt_label.add_theme_font_size_override("font_size", int(round(16.0 * text_scale)))
		_response_prompt_label.add_theme_color_override("font_color", Color8(22, 109, 168))
	if _timeline_label:
		_timeline_label.add_theme_font_size_override("font_size", int(round(15.0 * text_scale)))
		_timeline_label.add_theme_color_override("font_color", Color8(216, 124, 29))
	if _response_feedback_label:
		_response_feedback_label.add_theme_font_size_override("font_size", int(round(14.0 * text_scale)))
		_response_feedback_label.add_theme_color_override("font_color", Color8(45, 121, 84))
	if _assignment_label:
		_assignment_label.add_theme_font_size_override("font_size", int(round(14.0 * text_scale)))
		_assignment_label.add_theme_color_override("font_color", Color8(44, 54, 72))

	_style_dispatch_button(_typed_submit_button, Color8(104, 193, 255), Color8(129, 205, 255), text_scale)
	# Note: _keyboard_toggle_button is a floating TextureButton now.
	_style_dispatch_button(_hint_button, Color8(171, 221, 255), Color8(191, 231, 255), text_scale)

	if _close_button:
		_style_dispatch_button(_close_button, Color8(255, 140, 112), Color8(255, 161, 135), text_scale)
		_close_button.custom_minimum_size = Vector2(round(58.0 * text_scale), round(52.0 * text_scale))
		_close_button.add_theme_font_size_override("font_size", int(round(24.0 * text_scale)))

	if _toggle_hud_button:
		var btn_scale = scale * (2.0 if is_portrait else 1.0)
		_toggle_hud_button.position = Vector2(16, 116) if is_portrait else Vector2(16, 48)
		_toggle_hud_button.size = Vector2(64 * btn_scale, 64 * btn_scale)
		_toggle_hud_button.custom_minimum_size = Vector2(64 * btn_scale, 64 * btn_scale)
		_toggle_hud_button.add_theme_font_size_override("font_size", int(round(32 * btn_scale)))
		
		var style = _toggle_hud_button.get_theme_stylebox("normal")
		if style and style is StyleBoxFlat:
			style.corner_radius_top_left = int(round(32 * btn_scale))
			style.corner_radius_top_right = int(round(32 * btn_scale))
			style.corner_radius_bottom_left = int(round(32 * btn_scale))
			style.corner_radius_bottom_right = int(round(32 * btn_scale))
			
	if _keyboard_toggle_button:
		var btn_scale = scale * (1.5 if is_portrait else 1.0)
		_keyboard_toggle_button.size = Vector2(64 * btn_scale, 64 * btn_scale)
		_keyboard_toggle_button.custom_minimum_size = Vector2(64 * btn_scale, 64 * btn_scale)
		var vp_size = get_viewport().get_visible_rect().size
		_keyboard_toggle_button.position = Vector2(
			vp_size.x - (80 * btn_scale),
			vp_size.y - (80 * btn_scale)
		)
	if _hud_panel:
		var btn_scale = scale * (2.0 if is_portrait else 1.0)
		if is_portrait:
			_hud_panel.position = Vector2(16 + 64 * btn_scale + 8, 116)
			_hud_panel.custom_minimum_size = Vector2(vp.x - (16 + 64 * btn_scale + 32), 0)
			_hud_panel.size = Vector2(vp.x - (16 + 64 * btn_scale + 32), 160)
			_hud_panel.clip_contents = true
			if _mode_label:
				_mode_label.add_theme_font_size_override("font_size", int(round(28 * scale)))
			if _hint_label:
				_hint_label.add_theme_font_size_override("font_size", int(round(24 * scale)))
		else:
			_hud_panel.position = Vector2(16 + 64 * btn_scale + 8, 48)
			_hud_panel.custom_minimum_size = Vector2(vp.x / 3.0, 0)
			_hud_panel.size = Vector2(vp.x / 3.0, 160)
			_hud_panel.clip_contents = true
	
	var settings_btn: Button = get_node_or_null("CanvasLayer/SettingsButton")
	if settings_btn:
		var btn_scale = scale * (2.0 if is_portrait else 1.0)
		settings_btn.offset_top = 116.0 if is_portrait else 48.0
		settings_btn.offset_left = -78.0 * btn_scale
		settings_btn.offset_bottom = settings_btn.offset_top + (68.0 * btn_scale)
		settings_btn.custom_minimum_size = Vector2(68 * btn_scale, 68 * btn_scale)
		settings_btn.expand_icon = true
		settings_btn.add_theme_font_size_override("font_size", int(round(32 * btn_scale)))

	if is_mobile and _score_container:
		_score_container.offset_top = 120.0 if is_portrait else 72.0

	if _typed_input:
		_typed_input.custom_minimum_size = Vector2(0, round(42.0 * scale))
		_typed_input.add_theme_font_size_override("font_size", int(round(15.0 * scale)))
		_typed_input.add_theme_color_override("font_color", Color8(18, 30, 46))
		_typed_input.add_theme_color_override("font_placeholder_color", Color8(84, 106, 132))
		var kid_input_style = StyleBoxFlat.new()
		kid_input_style.bg_color = Color8(252, 254, 255)
		kid_input_style.corner_radius_top_left = 10
		kid_input_style.corner_radius_top_right = 10
		kid_input_style.corner_radius_bottom_left = 10
		kid_input_style.corner_radius_bottom_right = 10
		kid_input_style.border_width_left = 2
		kid_input_style.border_width_top = 2
		kid_input_style.border_width_right = 2
		kid_input_style.border_width_bottom = 2
		kid_input_style.border_color = Color8(101, 168, 227)
		_typed_input.add_theme_stylebox_override("normal", kid_input_style)
		var kid_input_focus = kid_input_style.duplicate()
		kid_input_focus.border_color = Color8(53, 130, 202)
		_typed_input.add_theme_stylebox_override("focus", kid_input_focus)

	if _minimized_call_button:
		_minimized_call_button.custom_minimum_size = Vector2(0, round(42.0 * scale))
		_minimized_call_button.add_theme_font_size_override("font_size", int(round(14.0 * scale)))
	if _next_day_button:
		_next_day_button.custom_minimum_size = Vector2(0, round(44.0 * scale))
		_next_day_button.add_theme_font_size_override("font_size", int(round(15.0 * scale)))

	for key in _vehicle_buttons.keys():
		var btn: Button = _vehicle_buttons[key]
		if btn:
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(0, round(94.0 * scale))
			btn.add_theme_font_size_override("font_size", int(round(17.0 * scale)))
			if key == "fire_truck":
				_style_dispatch_button(btn, Color8(255, 153, 143), Color8(255, 173, 165), scale)
			elif key == "ambulance":
				_style_dispatch_button(btn, Color8(141, 228, 159), Color8(163, 236, 178), scale)
			elif key == "police":
				_style_dispatch_button(btn, Color8(133, 184, 255), Color8(154, 198, 255), scale)
			else:
				_style_dispatch_button(btn, Color8(255, 214, 128), Color8(255, 223, 153), scale)

func _input(event) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode == KEY_F8:
			_activate_test_shift_cheat()
			return
		
		# TEMPORARY CHEATS FOR PERFECTIONIST MODE (TODO: REMOVE LATER)
		if key_event.pressed and not key_event.echo and key_event.ctrl_pressed:
			if key_event.keycode == KEY_K:
				_wrong_advice_count = 0
				print("CHEAT: Forced safe advice. Enabling dispatch.")
				_dispatch_phase_unlocked = true
				_set_vehicle_buttons_enabled(true)
				if _vehicle_grid:
					_vehicle_grid.visible = true
				if _assignment_label:
					_assignment_label.text = "Dispatch unlocked via Cheat!"
				_score_and_show_feedback("safe", "CHEAT: Safe Action", "Bypassed via Ctrl+K cheat.")
				return
			if key_event.keycode == KEY_EQUAL: # Ctrl +
				_wrong_advice_count += 1
				print("CHEAT: Increased anger/frustration to ", _wrong_advice_count)
				return
			if key_event.keycode == KEY_MINUS: # Ctrl -
				_wrong_advice_count = max(0, _wrong_advice_count - 1)
				print("CHEAT: Decreased anger/frustration to ", _wrong_advice_count)
				return

	# ── Freeze map input while a call is active ──
	if _call_active:
		return

	var hovered = get_viewport().gui_get_hovered_control()
	if hovered != null:
		if event is InputEventMouseButton:
			var mouse_release := event as InputEventMouseButton
			if mouse_release.button_index == MOUSE_BUTTON_LEFT and not mouse_release.pressed:
				_dragging = false
		elif event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if not touch.pressed:
				_touch_points.erase(touch.index)
				if _touch_points.is_empty():
					_dragging = false
		return

	# Mouse Input
	if event is InputEventMouseButton:
		var mouse_btn := event as InputEventMouseButton
		if mouse_btn.pressed:
			if mouse_btn.button_index == MOUSE_BUTTON_LEFT:
				_dragging = true
				_drag_last = mouse_btn.position
			elif mouse_btn.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(mouse_btn.position, 1.1)
			elif mouse_btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(mouse_btn.position, 1.0 / 1.1)
		else:
			if mouse_btn.button_index == MOUSE_BUTTON_LEFT:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging and _touch_points.is_empty():
		var motion := event as InputEventMouseMotion
		var delta = motion.position - _drag_last
		_drag_last = motion.position
		_world_node.position += delta
		_map_sprite.position += delta
		_clamp_map_position()

	# Touch Input
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
			if _touch_points.size() == 1:
				_dragging = true
				_drag_last = touch.position
		else:
			_touch_points.erase(touch.index)
			if _touch_points.is_empty():
				_dragging = false

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touch_points.has(drag.index):
			_touch_points[drag.index] = drag.position

		if _touch_points.size() == 1 and _dragging:
			var delta = drag.position - _drag_last
			_drag_last = drag.position
			_world_node.position += delta
			_map_sprite.position += delta
			_clamp_map_position()
			
		elif _touch_points.size() == 2:
			var pts = _touch_points.values()
			var p1: Vector2 = pts[0]
			var p2: Vector2 = pts[1]
			
			var current_dist = p1.distance_to(p2)
			
			var old_p1 = p1
			var old_p2 = p2
			if drag.index == _touch_points.keys()[0]:
				old_p1 = p1 - drag.relative
			else:
				old_p2 = p2 - drag.relative
				
			var old_dist = old_p1.distance_to(old_p2)
			
			if old_dist > 5.0 and current_dist > 5.0:
				var center = (p1 + p2) * 0.5
				var zoom_factor = current_dist / old_dist
				_zoom_at(center, zoom_factor)

func _activate_test_shift_cheat() -> void:
	_shift_score = max(_shift_score, shift_min_score)
	_total_score = max(_total_score, _shift_score)
	_shift_remaining_s = 0
	_shift_time_complete_announced = true
	_shift_ready_announced = true
	if _shift_timer:
		_shift_timer.stop()
	if _score_label:
		_score_label.text = "Score: %d" % _total_score
	_update_shift_ui()
	if _hint_label:
		pass
	_show_kid_message("Testing Cheat Enabled", "Shift completion is unlocked for quick testing.\nUse Ctrl+Shift+F8 in route scene to re-apply anytime.")

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var new_scale = clamp(_current_scale * factor, _min_scale, _max_scale)
	var actual_factor = 1.0
	if _current_scale != 0.0:
		actual_factor = new_scale / _current_scale

	var delta_world = (1.0 - actual_factor) * (screen_pos - _world_node.position)
	var delta_map = (1.0 - actual_factor) * (screen_pos - _map_sprite.position)
	_world_node.position += delta_world
	_map_sprite.position += delta_map
	_current_scale = new_scale
	_world_node.scale = Vector2(_current_scale, _current_scale)
	_map_sprite.scale = Vector2(_current_scale, _current_scale)
	_user_zoomed = true
	_clamp_map_position()

func _clamped_map_offset(offset: Vector2) -> Vector2:
	var vp_size = get_viewport().get_visible_rect().size
	var scaled_w = float(_img_w) * _current_scale
	var scaled_h = float(_img_h) * _current_scale
	var out = offset

	var max_x = 0.0
	var min_x = vp_size.x - scaled_w
	var max_y = 0.0
	var min_y = vp_size.y - scaled_h

	if scaled_w <= vp_size.x:
		out.x = (vp_size.x - scaled_w) * 0.5
	else:
		out.x = clamp(out.x, min_x, max_x)

	if scaled_h <= vp_size.y:
		out.y = (vp_size.y - scaled_h) * 0.5
	else:
		out.y = clamp(out.y, min_y, max_y)

	return out

func _clamp_map_position() -> void:
	var clamped = _clamped_map_offset(_map_sprite.position)
	_map_sprite.position = clamped
	_world_node.position = clamped

func _on_toggle_hud_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_click()
	if _hud_panel == null:
		return
	var showing = not _hud_panel.visible
	_hud_panel.visible = showing
	if showing and _toggle_hud_button:
		# Position panel: top-left corner touches bottom-right of info button
		var btn_pos = _toggle_hud_button.position
		var btn_size = _toggle_hud_button.size
		_hud_panel.position = Vector2(btn_pos.x, btn_pos.y + btn_size.y + 4)
		# Reset tip timer on open
		if _tip_timer:
			_tip_timer.stop()
			_tip_timer.start()

func _setup_tip_timer() -> void:
	if _tip_timer != null:
		return
	_tip_timer = Timer.new()
	_tip_timer.name = "TipTimer"
	_tip_timer.one_shot = false
	_tip_timer.wait_time = 4.0
	add_child(_tip_timer)
	_tip_timer.timeout.connect(_advance_tip)
	_tip_timer.start()

func _advance_tip() -> void:
	if _tips_list.is_empty() or _hint_label == null:
		return
	_tip_index = (_tip_index + 1) % _tips_list.size()
	var tip = _tips_list[_tip_index]
	_hint_label.text = tip
	# Adjust wait time based on tip length: ~0.06s per char, clamp 3-6s
	if _tip_timer:
		_tip_timer.wait_time = clamp(tip.length() * 0.06, 3.0, 6.0)

func _on_tip_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_tip()
		if _tip_timer:
			_tip_timer.stop()
			_tip_timer.start()


func _setup_hud() -> void:
	var scale = _ui_scale_factor()
	var vp = get_viewport_rect().size
	var is_portrait = vp.y > vp.x

	_mode_label = get_node_or_null("CanvasLayer/HUDPanel/HUDMargin/HUDContent/ModeLabel")
	_hint_label = get_node_or_null("CanvasLayer/HUDPanel/HUDMargin/HUDContent/HintLabel")
	_hud_content = get_node_or_null("CanvasLayer/HUDPanel/HUDMargin/HUDContent")
	_hud_panel = get_node_or_null("CanvasLayer/HUDPanel")
	if _hud_panel and _mode_label:
		_mode_label.add_theme_font_size_override("font_size", 18)
		_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mode_label.custom_minimum_size = Vector2(120, 0)
		_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mode_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _hud_panel and _hint_label:
		_hint_label.add_theme_font_size_override("font_size", 18)
		_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_label.custom_minimum_size = Vector2(0, 0)
	if _hud_panel:
		# Compact info panel — shrink to content only
		_hud_panel.custom_minimum_size = Vector2(260, 0)
		_hud_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_hud_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_hud_panel.clip_contents = false
		_hud_panel.position = Vector2(16, 88)  # below the info button (pos 16,16 size 64)
		_hud_panel.visible = false
		# Force inner containers to shrink
		var hud_margin = get_node_or_null("CanvasLayer/HUDPanel/HUDMargin")
		if hud_margin:
			hud_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if _hud_content:
			_hud_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if _mode_label:
			_mode_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_mode_label.custom_minimum_size = Vector2(0, 0)
		# Cap the hint label to 3 lines max — this is the key height limiter
		if _hint_label:
			_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_hint_label.custom_minimum_size = Vector2(0, 0)
			_hint_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_hint_label.max_lines_visible = 3


		
		_tips_list = [
			"Welcome to the Live Dispatch Floor!",
			"Always pick the safest option to instruct the caller.",
			"When ready, dispatch the right unit:",
			"- BFP: for fires, chemical spills, and technical rescues.",
			"- MDRRMO: transport patients safely to hospital for medical emergencies, injuries, breathing problems, AND technical operations like extrication of trapped victims or building collapse.",
			"- PNP: violence, threats, criminal activity."
		]
		_tip_index = randi() % _tips_list.size()
		if _hint_label:
			_hint_label.text = _tips_list[_tip_index]
			_hint_label.mouse_filter = Control.MOUSE_FILTER_STOP
			if not _hint_label.gui_input.is_connected(_on_tip_clicked):
				_hint_label.gui_input.connect(_on_tip_clicked)
		_setup_tip_timer()
		
		if _toggle_hud_button == null:
			_toggle_hud_button = Button.new()
			_toggle_hud_button.name = "ToggleHUDButton"
			_toggle_hud_button.text = "i"
			_toggle_hud_button.add_theme_font_size_override("font_size", 32)
			
			var t_style = StyleBoxFlat.new()
			t_style.bg_color = Color(0.2, 0.25, 0.35, 0.95)
			t_style.corner_radius_top_left = 32
			t_style.corner_radius_top_right = 32
			t_style.corner_radius_bottom_left = 32
			t_style.corner_radius_bottom_right = 32
			t_style.border_width_left = 3
			t_style.border_width_right = 3
			t_style.border_width_top = 3
			t_style.border_width_bottom = 3
			t_style.border_color = Color.WHITE
			_toggle_hud_button.add_theme_stylebox_override("normal", t_style)
			
			var h_style = t_style.duplicate()
			h_style.bg_color = Color(0.3, 0.35, 0.45, 0.95)
			_toggle_hud_button.add_theme_stylebox_override("hover", h_style)
			_toggle_hud_button.add_theme_stylebox_override("pressed", h_style)
			
			_toggle_hud_button.position = Vector2(16, 16)
			_toggle_hud_button.size = Vector2(64, 64)
			_toggle_hud_button.pressed.connect(_on_toggle_hud_pressed)
			
			var toggle_canvas = get_node_or_null("CanvasLayer")
			if toggle_canvas:
				toggle_canvas.add_child(_toggle_hud_button)
	_home_button = get_node_or_null("CanvasLayer/HUDPanel/HUDMargin/HUDContent/HomeButton")
	if _home_button == null:
		_home_button = get_node_or_null("CanvasLayer/SettingsButton")
	if _home_button:
		# Add a nice little hover style override to the settings button
		var normal = StyleBoxFlat.new()
		normal.bg_color = Color(0.2, 0.25, 0.35, 0.9)
		normal.corner_radius_top_left = 6
		normal.corner_radius_top_right = 6
		normal.corner_radius_bottom_left = 6
		normal.corner_radius_bottom_right = 6
		_home_button.add_theme_stylebox_override("normal", normal)

		var hover = StyleBoxFlat.new()
		hover.bg_color = Color(0.3, 0.35, 0.45, 0.9)
		hover.corner_radius_top_left = 6
		hover.corner_radius_top_right = 6
		hover.corner_radius_bottom_left = 6
		hover.corner_radius_bottom_right = 6
		_home_button.add_theme_stylebox_override("hover", hover)
		_home_button.pressed.connect(_on_home_pressed)

	var canvas = get_node_or_null("CanvasLayer")
	if canvas and _minimized_call_button == null:
		_minimized_call_button = Button.new()
		_minimized_call_button.name = "ReturnToCallButton"
		_minimized_call_button.text = "Return to Call"
		_minimized_call_button.visible = false
		
		var btn_h = 68.0 * scale * (1.5 if is_portrait else 1.0)
		_minimized_call_button.custom_minimum_size = Vector2(0, btn_h)
		_minimized_call_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_minimized_call_button.offset_left = 32.0 * scale
		_minimized_call_button.offset_right = -32.0 * scale
		_minimized_call_button.offset_bottom = -64.0 * scale if not is_portrait else -140.0 * scale
		_minimized_call_button.offset_top = _minimized_call_button.offset_bottom - btn_h
		
		var min_style = StyleBoxFlat.new()
		min_style.bg_color = Color(0.8, 0.2, 0.25, 0.95)
		min_style.corner_radius_top_left = 12
		min_style.corner_radius_top_right = 12
		min_style.corner_radius_bottom_left = 12
		min_style.corner_radius_bottom_right = 12
		min_style.border_width_left = 3
		min_style.border_width_top = 3
		min_style.border_width_right = 3
		min_style.border_width_bottom = 3
		min_style.border_color = Color.WHITE
		_minimized_call_button.add_theme_stylebox_override("normal", min_style)
		_minimized_call_button.add_theme_stylebox_override("hover", min_style)
		_minimized_call_button.add_theme_color_override("font_color", Color.WHITE)
		_minimized_call_button.add_theme_font_size_override("font_size", int(round(28.0 * scale * (1.5 if is_portrait else 1.0))))
		_minimized_call_button.pressed.connect(_on_minimized_call_pressed)
		
		canvas.add_child(_minimized_call_button)
		# Move it to front
		canvas.move_child(_minimized_call_button, -1)
	if _hud_content and _next_day_button == null:
		_next_day_button = Button.new()
		_next_day_button.name = "ProceedNextDayButton"
		_next_day_button.text = "Proceed to Day %d" % (_current_day + 1)
		_next_day_button.visible = false
		_next_day_button.custom_minimum_size = Vector2(0, 36)
		_next_day_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var next_style = StyleBoxFlat.new()
		next_style.bg_color = Color(0.22, 0.62, 0.36, 0.95)
		next_style.corner_radius_top_left = 8
		next_style.corner_radius_top_right = 8
		next_style.corner_radius_bottom_left = 8
		next_style.corner_radius_bottom_right = 8
		next_style.border_width_left = 2
		next_style.border_width_top = 2
		next_style.border_width_right = 2
		next_style.border_width_bottom = 2
		next_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
		_next_day_button.add_theme_stylebox_override("normal", next_style)
		_next_day_button.add_theme_stylebox_override("hover", next_style)
		_next_day_button.add_theme_color_override("font_color", Color.WHITE)
		_next_day_button.pressed.connect(_on_proceed_next_day_pressed)
		if _home_button and _home_button.get_parent() == _hud_content:
			_hud_content.add_child(_next_day_button)
			_hud_content.move_child(_next_day_button, _home_button.get_index())
		else:
			_hud_content.add_child(_next_day_button)

	# Add score label (top-left area of HUD)
	canvas = get_node_or_null("CanvasLayer")
	if canvas:
		_score_container = VBoxContainer.new()
		_score_container.name = "ScoreContainer"
		_score_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_score_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_score_container.offset_top = 16.0
		_score_container.add_theme_constant_override("separation", 12)
		canvas.add_child(_score_container)
		
		_score_label = Label.new()
		_score_label.name = "ScoreLabel"
		_score_label.text = "Score: %d" % _total_score
		_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_score_label.add_theme_font_size_override("font_size", 26)
		_score_label.add_theme_constant_override("outline_size", 8)
		_score_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		_score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_score_container.add_child(_score_label)

		_shift_label = Label.new()
		_shift_label.name = "ShiftLabel"
		_shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shift_label.add_theme_font_size_override("font_size", 20)
		_shift_label.add_theme_constant_override("outline_size", 5)
		_shift_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.95))
		_score_container.add_child(_shift_label)
		_update_shift_ui()

		_feedback_dialog = AcceptDialog.new()
		_feedback_dialog.name = "FeedbackDialog"
		_feedback_dialog.title = "Action Feedback"
		_feedback_dialog.exclusive = true
		_feedback_dialog.dialog_autowrap = true
		var feedback_style = StyleBoxFlat.new()
		feedback_style.bg_color = Color8(255, 244, 229)
		feedback_style.corner_radius_top_left = 14
		feedback_style.corner_radius_top_right = 14
		feedback_style.corner_radius_bottom_left = 14
		feedback_style.corner_radius_bottom_right = 14
		feedback_style.border_width_left = 3
		feedback_style.border_width_top = 3
		feedback_style.border_width_right = 3
		feedback_style.border_width_bottom = 3
		feedback_style.border_color = Color8(255, 160, 86)
		_feedback_dialog.add_theme_stylebox_override("panel", feedback_style)
		_feedback_dialog.add_theme_stylebox_override("embedded_border", feedback_style)
		_feedback_dialog.add_theme_color_override("title_color", Color8(44, 54, 72))
		var dialog_label = _feedback_dialog.get_label()
		scale = _ui_scale_factor()
		if dialog_label:
			dialog_label.custom_minimum_size = Vector2(360, 0)
			dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dialog_label.add_theme_font_size_override("font_size", int(round(19 * scale)))
			dialog_label.add_theme_color_override("font_color", Color8(44, 54, 72))
		var feedback_ok = _feedback_dialog.get_ok_button()
		if feedback_ok:
			feedback_ok.add_theme_font_size_override("font_size", int(round(24 * scale)))
			feedback_ok.custom_minimum_size = Vector2(0, round(60 * scale))
			feedback_ok.add_theme_color_override("font_color", Color8(44, 54, 72))
			var feedback_ok_style = StyleBoxFlat.new()
			feedback_ok_style.bg_color = Color8(255, 205, 104)
			feedback_ok_style.corner_radius_top_left = 10
			feedback_ok_style.corner_radius_top_right = 10
			feedback_ok_style.corner_radius_bottom_left = 10
			feedback_ok_style.corner_radius_bottom_right = 10
			feedback_ok_style.border_width_left = 2
			feedback_ok_style.border_width_top = 2
			feedback_ok_style.border_width_right = 2
			feedback_ok_style.border_width_bottom = 2
			feedback_ok_style.border_color = Color(1.0, 1.0, 1.0, 0.85)
			feedback_ok.add_theme_stylebox_override("normal", feedback_ok_style)
			feedback_ok.add_theme_stylebox_override("hover", feedback_ok_style)
			feedback_ok.add_theme_stylebox_override("pressed", feedback_ok_style)
		_feedback_dialog.confirmed.connect(_on_feedback_popup_closed)
		canvas.add_child(_feedback_dialog)

		_kid_message_dialog = AcceptDialog.new()
		_kid_message_dialog.name = "KidMessageDialog"
		_kid_message_dialog.title = "Great Job!"
		_kid_message_dialog.exclusive = false
		_kid_message_dialog.dialog_autowrap = true
		var kid_style = StyleBoxFlat.new()
		kid_style.bg_color = Color8(255, 244, 229)
		kid_style.corner_radius_top_left = 14
		kid_style.corner_radius_top_right = 14
		kid_style.corner_radius_bottom_left = 14
		kid_style.corner_radius_bottom_right = 14
		kid_style.border_width_left = 3
		kid_style.border_width_top = 3
		kid_style.border_width_right = 3
		kid_style.border_width_bottom = 3
		kid_style.border_color = Color8(255, 160, 86)
		_kid_message_dialog.add_theme_stylebox_override("panel", kid_style)
		_kid_message_dialog.add_theme_stylebox_override("embedded_border", kid_style)
		_kid_message_dialog.add_theme_color_override("title_color", Color8(44, 54, 72))
		var msg_label = _kid_message_dialog.get_label()
		if msg_label:
			msg_label.custom_minimum_size = Vector2(360, 0)
			msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			msg_label.add_theme_font_size_override("font_size", int(round(18 * scale)))
			msg_label.add_theme_color_override("font_color", Color8(44, 54, 72))
		var kid_ok = _kid_message_dialog.get_ok_button()
		if kid_ok:
			kid_ok.add_theme_font_size_override("font_size", int(round(24 * scale)))
			kid_ok.custom_minimum_size = Vector2(0, round(60 * scale))
			kid_ok.add_theme_color_override("font_color", Color8(44, 54, 72))
			var ok_style = StyleBoxFlat.new()
			ok_style.bg_color = Color8(255, 205, 104)
			ok_style.corner_radius_top_left = 10
			ok_style.corner_radius_top_right = 10
			ok_style.corner_radius_bottom_left = 10
			ok_style.corner_radius_bottom_right = 10
			ok_style.border_width_left = 2
			ok_style.border_width_top = 2
			ok_style.border_width_right = 2
			ok_style.border_width_bottom = 2
			ok_style.border_color = Color(1.0, 1.0, 1.0, 0.85)
			kid_ok.add_theme_stylebox_override("normal", ok_style)
			kid_ok.add_theme_stylebox_override("hover", ok_style)
			kid_ok.add_theme_stylebox_override("pressed", ok_style)
		_kid_message_dialog.confirmed.connect(_on_kid_message_dialog_confirmed)
		canvas.add_child(_kid_message_dialog)

		_shift_review_dialog = AcceptDialog.new()
		_shift_review_dialog.name = "ShiftReviewDialog"
		_shift_review_dialog.title = "Shift Review"
		_shift_review_dialog.dialog_autowrap = true
		_shift_review_dialog.exclusive = true
		_shift_review_dialog.borderless = true
		var review_style = StyleBoxFlat.new()
		review_style.bg_color = Color8(255, 244, 229)
		review_style.corner_radius_top_left = 14
		review_style.corner_radius_top_right = 14
		review_style.corner_radius_bottom_left = 14
		review_style.corner_radius_bottom_right = 14
		review_style.border_width_left = 3
		review_style.border_width_top = 3
		review_style.border_width_right = 3
		review_style.border_width_bottom = 3
		review_style.border_color = Color8(255, 160, 86)
		_shift_review_dialog.add_theme_stylebox_override("panel", review_style)
		_shift_review_dialog.add_theme_stylebox_override("embedded_border", review_style)
		_shift_review_dialog.add_theme_color_override("title_color", Color8(30, 38, 54))
		var review_label = _shift_review_dialog.get_label()
		if review_label:
			review_label.custom_minimum_size = Vector2(860, 56)
			review_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			review_label.add_theme_font_size_override("font_size", 19)
			review_label.add_theme_color_override("font_color", Color8(34, 46, 62))
		var review_ok = _shift_review_dialog.get_ok_button()
		if review_ok:
			review_ok.add_theme_font_size_override("font_size", 21)
			review_ok.add_theme_color_override("font_color", Color8(34, 46, 62))
			review_ok.custom_minimum_size = Vector2(250, 56)
			_style_choice_button(review_ok, 0.95)
		_shift_review_other_button = _shift_review_dialog.add_button("Review Other Options", false, "review_other_options")
		if _shift_review_other_button:
			_style_choice_button(_shift_review_other_button, 0.92)
			_shift_review_other_button.add_theme_font_size_override("font_size", 21)
			_shift_review_other_button.custom_minimum_size = Vector2(250, 56)
		# Proceed to Next Day button — only visible when shift can be ended
		_shift_review_proceed_button = _shift_review_dialog.add_button("Proceed to Next Day", true, "proceed_next_day")
		if _shift_review_proceed_button:
			_style_choice_button(_shift_review_proceed_button, 0.92)
			_shift_review_proceed_button.add_theme_font_size_override("font_size", 21)
			_shift_review_proceed_button.custom_minimum_size = Vector2(250, 56)
			
		var action_area = _shift_review_dialog.get_ok_button().get_parent()
		if action_area is BoxContainer:
			action_area.alignment = BoxContainer.ALIGNMENT_CENTER
			action_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var parent_margin = action_area.get_parent()
			if parent_margin and parent_margin is Control:
				parent_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			# Pull native engine spacers out of the tree entirely so they
			# don't interfere with index-based ordering.
			var to_remove: Array = []
			for c in action_area.get_children():
				if c != _shift_review_other_button \
						and c != _shift_review_dialog.get_ok_button() \
						and c != _shift_review_proceed_button:
					to_remove.append(c)
			for c in to_remove:
				action_area.remove_child(c)
				c.queue_free()

			# Build a clean [Review][sp1][OK][sp2][Proceed] sequence.
			var sp1 = Control.new()
			sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sp2 = Control.new()
			sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_area.add_child(sp1)
			action_area.add_child(sp2)

			# Set button size flags (no expansion — keep natural width).
			if _shift_review_other_button:
				_shift_review_other_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				_shift_review_other_button.custom_minimum_size = Vector2(250, 56)
			_shift_review_dialog.get_ok_button().size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_shift_review_dialog.get_ok_button().custom_minimum_size = Vector2(250, 56)
			if _shift_review_proceed_button:
				_shift_review_proceed_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				_shift_review_proceed_button.custom_minimum_size = Vector2(250, 56)

			# After add_child the order is:
			# 0=Review 1=OK 2=Proceed 3=sp1 4=sp2  (add_button prepended them)
			# Force exact sequence: 0=Review 1=sp1 2=OK 3=sp2 4=Proceed
			if _shift_review_other_button:
				action_area.move_child(_shift_review_other_button, 0)
			action_area.move_child(sp1, 1)
			action_area.move_child(_shift_review_dialog.get_ok_button(), 2)
			action_area.move_child(sp2, 3)
			if _shift_review_proceed_button:
				action_area.move_child(_shift_review_proceed_button, 4)
			
		var review_scroll = ScrollContainer.new()
		review_scroll.custom_minimum_size = Vector2(820, 360)
		review_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		review_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_shift_review_dialog.add_child(review_scroll)
		_shift_review_list = VBoxContainer.new()
		_shift_review_list.add_theme_constant_override("separation", 10)
		_shift_review_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		review_scroll.add_child(_shift_review_list)
		_shift_review_dialog.confirmed.connect(_on_shift_review_dialog_confirmed)
		_shift_review_dialog.custom_action.connect(_on_shift_review_custom_action)
		canvas.add_child(_shift_review_dialog)

		_other_options_dialog = AcceptDialog.new()
		_other_options_dialog.name = "OtherOptionsDialog"
		_other_options_dialog.title = "Other Options Review"
		_other_options_dialog.dialog_autowrap = true
		_other_options_dialog.exclusive = true
		_other_options_dialog.borderless = true
		_other_options_dialog.add_theme_stylebox_override("panel", review_style)
		_other_options_dialog.add_theme_stylebox_override("embedded_border", review_style)
		_other_options_dialog.add_theme_color_override("title_color", Color8(30, 38, 54))
		var other_lbl = _other_options_dialog.get_label()
		if other_lbl:
			other_lbl.custom_minimum_size = Vector2(640, 24)
			other_lbl.add_theme_font_size_override("font_size", 18)
			other_lbl.add_theme_color_override("font_color", Color8(34, 46, 62))
			other_lbl.text = ""
		var other_ok = _other_options_dialog.get_ok_button()
		if other_ok:
			_style_choice_button(other_ok, 0.92)
			other_ok.custom_minimum_size = Vector2(120, 38)
		var other_scroll = ScrollContainer.new()
		other_scroll.custom_minimum_size = Vector2(760, 420)
		other_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		other_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_other_options_dialog.add_child(other_scroll)
		_other_options_list = VBoxContainer.new()
		_other_options_list.add_theme_constant_override("separation", 10)
		_other_options_list.custom_minimum_size = Vector2(740, 420)
		_other_options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_other_options_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		other_scroll.add_child(_other_options_list)
		canvas.add_child(_other_options_dialog)

	var state = get_node_or_null("/root/GameState")
	if state == null:
		return
	var mode: Dictionary = state.call("get_selected_mode")
	_selected_mode_id = String(mode.get("id", "easy_multiple_choice"))
	if state.has_method("get_locale"):
		_selected_locale = String(state.call("get_locale"))
	if state.has_method("get_current_day"):
		_current_day = max(1, int(state.call("get_current_day")))
	if state.has_method("get_day_difficulty_scale"):
		_day_difficulty_scale = max(1.0, float(state.call("get_day_difficulty_scale")))

	if _mode_label:
		_mode_label.text = "Mode: %s | Day %d" % [String(mode.get("title", "Dispatch Mode")), _current_day]

var _pause_dialog: ConfirmationDialog

func _on_home_pressed() -> void:
	var settings_scn = load("res://scenes/ui/settings_menu.tscn")
	if settings_scn:
		var menu = settings_scn.instantiate()
		get_node("CanvasLayer").add_child(menu)
		menu.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		menu.closed.connect(func(): get_tree().paused = false)

func _force_early_end_shift() -> void:
	if _shift_timer:
		_shift_timer.stop()
	
	if _shift_score < shift_min_score:
		_pending_day_restart = false
		if _hint_label:
			pass
		_show_shift_review(
			"Shift Failed",
			"You completed %d calls and scored %d points. Minimum required score is %d. Day %d will restart after you close this review." % [_calls_completed, _shift_score, shift_min_score, _current_day],
			"restart_day"
		)
	else:
		if _hint_label:
			pass
		_open_shift_review_for_manual_end(
			"reload_scene",
			"Shift Evaluation",
			"Review Day %d performance, then continue to Day %d." % [_current_day, _current_day + 1]
		)

func _on_proceed_next_day_pressed() -> void:
	if not _can_end_shift():
		_show_kid_message("Shift In Progress", _shift_end_block_reason())
		return
	_open_shift_review_for_manual_end(
		"reload_scene",
		"Shift Evaluation",
		"Review Day %d performance, then continue to Day %d." % [_current_day, _current_day + 1]
	)

func _on_kid_message_dialog_confirmed() -> void:
	if not _pending_day_restart:
		return
	_pending_day_restart = false
	var tree = get_tree()
	if tree:
		tree.reload_current_scene()

func _setup_scenario_generator() -> void:
	if not ResourceLoader.exists("res://scripts/systems/emergency_scenario_generator.gd"):
		return
	var gen_script = load("res://scripts/systems/emergency_scenario_generator.gd")
	if gen_script:
		_scenario_generator = gen_script.new()

func _load_route_points_for_calls() -> void:
	_route_points_px.clear()
	_buildings_px.clear()

	if building_json_res_path != "" and FileAccess.file_exists(building_json_res_path):
		var bfile = FileAccess.open(building_json_res_path, FileAccess.READ)
		if bfile != null:
			var bparsed = JSON.parse_string(bfile.get_as_text())
			if typeof(bparsed) == TYPE_DICTIONARY and bparsed.has("buildings"):
				for b in bparsed.get("buildings"):
					if typeof(b) == TYPE_DICTIONARY and b.has("x") and b.has("y"):
						_buildings_px.append(Vector2(float(b.get("x")), float(b.get("y"))))

	if not FileAccess.file_exists(route_json_res_path):
		return
	var file = FileAccess.open(route_json_res_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	var points_root = parsed
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("points"):
		points_root = parsed.get("points")
	if typeof(points_root) != TYPE_ARRAY:
		return

	for p in points_root:
		var nx = 0.0
		var ny = 0.0
		if typeof(p) == TYPE_DICTIONARY:
			nx = float(p.get("x", 0.0))
			ny = float(p.get("y", 0.0))
		elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
			nx = float(p[0])
			ny = float(p[1])
		else:
			continue
		_route_points_px.append(Vector2(nx * float(_img_w), ny * float(_img_h)))

	_setup_safe_road_overlay()

func _setup_safe_road_overlay() -> void:
	if _world_node == null:
		return
	if _road_overlay_layer and is_instance_valid(_road_overlay_layer):
		_road_overlay_layer.queue_free()
		_road_overlay_layer = null
	if not use_safe_road_overlay:
		return
	if _route_points_px.size() < 2:
		return

	_road_overlay_layer = Node2D.new()
	_road_overlay_layer.name = "RoadOverlay"
	_road_overlay_layer.z_index = -2
	_world_node.add_child(_road_overlay_layer)
	_world_node.move_child(_road_overlay_layer, 0)

	var outline = Line2D.new()
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.antialiased = true
	outline.default_color = road_outline_color
	outline.width = max(road_outline_width_px, road_inner_width_px + 2.0)
	_road_overlay_layer.add_child(outline)

	var inner = Line2D.new()
	inner.joint_mode = Line2D.LINE_JOINT_ROUND
	inner.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner.antialiased = true
	inner.default_color = road_inner_color
	inner.width = max(2.0, road_inner_width_px)
	_road_overlay_layer.add_child(inner)

	for p in _route_points_px:
		outline.add_point(p)
		inner.add_point(p)

func _setup_dispatch_timers() -> void:
	_transcript_timer = Timer.new()
	_transcript_timer.wait_time = transcript_tick_s
	_transcript_timer.one_shot = false
	_transcript_timer.timeout.connect(_on_transcript_tick)
	add_child(_transcript_timer)

	_next_call_timer = Timer.new()
	_next_call_timer.one_shot = true
	_next_call_timer.timeout.connect(_on_next_call_timeout)
	add_child(_next_call_timer)

	_arrival_timer = Timer.new()
	_arrival_timer.one_shot = true
	_arrival_timer.timeout.connect(_on_arrival_timeout)
	add_child(_arrival_timer)

	_resolution_timer = Timer.new()
	_resolution_timer.one_shot = true
	_resolution_timer.timeout.connect(_on_resolution_timeout)
	add_child(_resolution_timer)

	_shift_timer = Timer.new()
	_shift_timer.wait_time = 1.0
	_shift_timer.one_shot = false
	_shift_timer.timeout.connect(_on_shift_tick)
	add_child(_shift_timer)
	_shift_timer.start()

func _on_shift_tick() -> void:
	if _shift_remaining_s <= 0:
		if _shift_timer:
			_shift_timer.stop()
		return

	_shift_remaining_s -= 1
	_update_shift_ui()

	if _shift_remaining_s == 0 and not _shift_time_complete_announced:
		_shift_time_complete_announced = true
		if _shift_score >= shift_min_score:
			if not _shift_ready_announced:
				_shift_ready_announced = true
				if _hint_label:
					pass
		elif _hint_label:
			pass

func _setup_dispatch_ui() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)

	# ── Full-screen dim overlay ──────────────────────────────────────
	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "DimOverlay"
	_dim_overlay.color = Color(0.0, 0.0, 0.05, 0.65)
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.visible = false
	canvas.add_child(_dim_overlay)

	# ── Main dispatch panel (centered, 911 Operator style) ─────────
	_dispatch_panel = PanelContainer.new()
	_dispatch_panel.name = "DispatchPanel"
	# Use anchor-based sizing so it always fits the viewport
	_dispatch_panel.anchor_left = 0.02
	_dispatch_panel.anchor_right = 0.98
	_dispatch_panel.anchor_top = 0.02
	_dispatch_panel.anchor_bottom = 0.95
	_dispatch_panel.offset_left = 0
	_dispatch_panel.offset_right = 0
	_dispatch_panel.offset_top = 0
	_dispatch_panel.offset_bottom = 0
	_dispatch_panel.offset_bottom = 0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.97)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.75, 0.15, 0.2, 1.0)
	_dispatch_panel.add_theme_stylebox_override("panel", panel_style)
	_dispatch_panel.visible = false
	canvas.add_child(_dispatch_panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	_dispatch_panel.add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(outer_vbox)

	# ── Close (X) button overlaid on top-right ─────────────────────
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.flat = true
	_close_button.custom_minimum_size = Vector2(52, 52)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.6, 0.1, 0.15, 1.0)
	close_style.corner_radius_top_right = 4
	_close_button.add_theme_stylebox_override("normal", close_style)
	var close_hover = StyleBoxFlat.new()
	close_hover.bg_color = Color(0.85, 0.2, 0.25, 1.0)
	close_hover.corner_radius_top_right = 4
	_close_button.add_theme_stylebox_override("hover", close_hover)
	_close_button.add_theme_color_override("font_color", Color.WHITE)
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.pressed.connect(_on_close_call_panel)
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 16)
	header_margin.add_theme_constant_override("margin_top", 12)
	header_margin.add_theme_constant_override("margin_right", 16)
	header_margin.add_theme_constant_override("margin_bottom", 0)
	outer_vbox.add_child(header_margin)
	outer_vbox.move_child(header_margin, 1)

	var header_row = HBoxContainer.new()
	header_margin.add_child(header_row)

	_panel_header_label = Label.new()
	_panel_header_label.text = "INCOMING CALL:"
	_panel_header_label.add_theme_font_size_override("font_size", 22)
	_panel_header_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	_panel_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_panel_header_label)

	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_row.add_child(_close_button)

	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_margin)

	var content = VBoxContainer.new()
	content.name = "DialogContent"
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content)

	# ── Location info ──────────────────────────────────────────────
	_incident_summary_label = Label.new()
	_incident_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_incident_summary_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 1.0))
	_incident_summary_label.add_theme_font_size_override("font_size", 16)
	_incident_summary_label.custom_minimum_size = Vector2(0, 34)
	content.add_child(_incident_summary_label)

	_incoming_label = Label.new()
	_incoming_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_incoming_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85, 1.0))
	_incoming_label.add_theme_font_size_override("font_size", 13)
	_incoming_label.custom_minimum_size = Vector2(0, 42)
	content.add_child(_incoming_label)

	# ── Transcript area (messenger layout) ─────────────────────────
	var transcript_hbox = HBoxContainer.new()
	transcript_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript_hbox.custom_minimum_size = Vector2(0, 240) # Guarantee ~3-message min height without overflowing
	transcript_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(transcript_hbox)

	var caller_vbox = VBoxContainer.new()
	caller_vbox.alignment = BoxContainer.ALIGNMENT_END
	caller_vbox.custom_minimum_size = Vector2(200, 0)
	transcript_hbox.add_child(caller_vbox)

	_caller_portrait = TextureRect.new()
	_caller_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_caller_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_caller_portrait.custom_minimum_size = Vector2(240, 240)
	_caller_portrait.flip_h = true
	caller_vbox.add_child(_caller_portrait)

	var transcript_panel = PanelContainer.new()
	transcript_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var transcript_style = StyleBoxFlat.new()
	transcript_style.bg_color = Color(0.04, 0.05, 0.1, 1.0)
	transcript_style.corner_radius_top_left = 6
	transcript_style.corner_radius_top_right = 6
	transcript_style.corner_radius_bottom_left = 6
	transcript_style.corner_radius_bottom_right = 6
	transcript_style.border_width_left = 1
	transcript_style.border_width_top = 1
	transcript_style.border_width_right = 1
	transcript_style.border_width_bottom = 1
	transcript_style.border_color = Color(0.2, 0.25, 0.35, 0.8)
	transcript_panel.add_theme_stylebox_override("panel", transcript_style)
	transcript_hbox.add_child(transcript_panel)

	var transcript_margin = MarginContainer.new()
	transcript_margin.add_theme_constant_override("margin_left", 8)
	transcript_margin.add_theme_constant_override("margin_top", 8)
	transcript_margin.add_theme_constant_override("margin_right", 8)
	transcript_margin.add_theme_constant_override("margin_bottom", 8)
	transcript_panel.add_child(transcript_margin)

	var transcript_inner_vbox = VBoxContainer.new()
	transcript_inner_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript_inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_inner_vbox.add_theme_constant_override("separation", 10)
	transcript_margin.add_child(transcript_inner_vbox)

	var chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	transcript_inner_vbox.add_child(chat_scroll)

	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_box.add_theme_constant_override("separation", 6)
	chat_scroll.add_child(_chat_box)
	
	var op_vbox = VBoxContainer.new()
	op_vbox.alignment = BoxContainer.ALIGNMENT_END
	op_vbox.custom_minimum_size = Vector2(200, 0)
	transcript_hbox.add_child(op_vbox)

	_operator_portrait = TextureRect.new()
	_operator_portrait.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_operator_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var op_tex = _load_icon("res://assets/Portraits/3 Emotion Berong. Serious, Calm, Confident.png")
	if op_tex:
		var op_atlas = AtlasTexture.new()
		op_atlas.atlas = op_tex
		var fw = op_tex.get_width() / 3
		var fh = op_tex.get_height()
		var base_region = Rect2(2 * fw, 0, fw, fh) # Confident
		op_atlas.region = _trim_region(op_tex, base_region)
		_operator_portrait.texture = op_atlas
		_operator_portrait.flip_h = true
		_operator_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_operator_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_operator_portrait.custom_minimum_size = Vector2(198, 198) # 10% taller than 180 baseline
	op_vbox.add_child(_operator_portrait)

	# ── Response prompt label ──────────────────────────────────────
	_response_prompt_label = Label.new()
	_response_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_response_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	_response_prompt_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_response_prompt_label)

	# ── Multiple choice box (Outside Transcript) ───
	_choices_box = VBoxContainer.new()
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_box.add_theme_constant_override("separation", 6)
	content.add_child(_choices_box)

	# ── Hint System ───────────────────────────────────────────────
	_hint_button = Button.new()
	_hint_button.text = "Need a Hint?"
	_hint_button.visible = false
	_hint_button.custom_minimum_size = Vector2(0, 40)
	var hint_btn_style = StyleBoxFlat.new()
	hint_btn_style.bg_color = Color(0.2, 0.4, 0.6, 1.0)
	hint_btn_style.corner_radius_top_left = 4
	hint_btn_style.corner_radius_top_right = 4
	hint_btn_style.corner_radius_bottom_left = 4
	hint_btn_style.corner_radius_bottom_right = 4
	_hint_button.add_theme_stylebox_override("normal", hint_btn_style)
	_hint_button.add_theme_color_override("font_color", Color.WHITE)
	_hint_button.pressed.connect(_on_hint_button_pressed)
	content.add_child(_hint_button)

	_hint_display_label = RichTextLabel.new()
	_hint_display_label.bbcode_enabled = true
	_hint_display_label.fit_content = true
	_hint_display_label.visible = false
	var hint_lbl_style = StyleBoxFlat.new()
	hint_lbl_style.bg_color = Color(0.1, 0.2, 0.3, 1.0)
	hint_lbl_style.content_margin_left = 8
	hint_lbl_style.content_margin_top = 8
	hint_lbl_style.content_margin_right = 8
	hint_lbl_style.content_margin_bottom = 8
	hint_lbl_style.corner_radius_top_left = 4
	hint_lbl_style.corner_radius_top_right = 4
	hint_lbl_style.corner_radius_bottom_left = 4
	hint_lbl_style.corner_radius_bottom_right = 4
	_hint_display_label.add_theme_stylebox_override("normal", hint_lbl_style)
	content.add_child(_hint_display_label)

	# ── Typed input row (hidden by default) ────────────────────────
	_typed_row = HBoxContainer.new()
	_typed_row.visible = false
	_typed_row.add_theme_constant_override("separation", 8)
	content.add_child(_typed_row)

	_typed_input = LineEdit.new()
	_typed_input.placeholder_text = "Type your dispatch guidance here..."
	_typed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_typed_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_typed_input.custom_minimum_size = Vector2(0, 44)
	var typed_style = StyleBoxFlat.new()
	typed_style.bg_color = Color8(250, 253, 255)
	typed_style.corner_radius_top_left = 4
	typed_style.corner_radius_top_right = 4
	typed_style.corner_radius_bottom_left = 4
	typed_style.corner_radius_bottom_right = 4
	typed_style.border_width_left = 1
	typed_style.border_width_top = 1
	typed_style.border_width_right = 1
	typed_style.border_width_bottom = 1
	typed_style.border_color = Color8(78, 141, 196)
	_typed_input.add_theme_stylebox_override("normal", typed_style)
	var typed_focus = typed_style.duplicate()
	typed_focus.bg_color = Color8(255, 255, 255)
	typed_focus.border_width_left = 2
	typed_focus.border_width_top = 2
	typed_focus.border_width_right = 2
	typed_focus.border_width_bottom = 2
	typed_focus.border_color = Color8(48, 128, 198)
	_typed_input.add_theme_stylebox_override("focus", typed_focus)
	_typed_input.add_theme_color_override("font_color", Color8(22, 33, 49))
	_typed_input.add_theme_color_override("font_placeholder_color", Color8(92, 112, 136))
	_typed_input.add_theme_color_override("caret_color", Color8(18, 103, 170))
	_typed_input.add_theme_color_override("selection_color", Color8(166, 218, 255, 190))
	if _typed_input.has_signal("text_submitted"):
		_typed_input.text_submitted.connect(_on_typed_text_submitted)
		
	# Disable native keyboard and rely purely on our in-game keyboard
	_typed_input.virtual_keyboard_enabled = false
	_typed_input.editable = true
	_typed_input.focus_mode = Control.FOCUS_NONE
	
	# Create an invisible button overlay to capture taps and open the keyboard
	var tap_overlay = Button.new()
	tap_overlay.flat = true
	tap_overlay.focus_mode = Control.FOCUS_NONE
	tap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap_overlay.pressed.connect(func():
		if _is_mobile_device():
			if _virtual_keyboard and not _virtual_keyboard.visible:
				_on_keyboard_toggle_pressed()
	)
	_typed_input.add_child(tap_overlay)
	
	_typed_row.add_child(_typed_input)


	_typed_submit_button = Button.new()
	_typed_submit_button.text = "Submit"
	_typed_submit_button.custom_minimum_size = Vector2(96, 44)
	_typed_submit_button.add_theme_font_size_override("font_size", int(round(20 * _ui_scale_factor())))
	var submit_btn_style = StyleBoxFlat.new()
	submit_btn_style.bg_color = Color(0.18, 0.45, 0.7, 1.0)
	submit_btn_style.corner_radius_top_left = 4
	submit_btn_style.corner_radius_top_right = 4
	submit_btn_style.corner_radius_bottom_left = 4
	submit_btn_style.corner_radius_bottom_right = 4
	_typed_submit_button.add_theme_stylebox_override("normal", submit_btn_style)
	_typed_submit_button.add_theme_color_override("font_color", Color.WHITE)
	_typed_submit_button.pressed.connect(_on_typed_submit_pressed)
	_typed_row.add_child(_typed_submit_button)

	# ── Feedback label ─────────────────────────────────────────────
	_response_feedback_label = Label.new()
	_response_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_response_feedback_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.78, 1.0))
	_response_feedback_label.add_theme_font_size_override("font_size", 13)
	content.add_child(_response_feedback_label)

	# ── Assignment label ───────────────────────────────────────────
	_assignment_label = Label.new()
	_assignment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assignment_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 1.0))
	_assignment_label.add_theme_font_size_override("font_size", 13)
	content.add_child(_assignment_label)

	# ── Vehicle dispatch grid ──────────────────────────────────────
	_vehicle_grid = GridContainer.new()
	_vehicle_grid.columns = 3
	_vehicle_grid.add_theme_constant_override("h_separation", 6)
	_vehicle_grid.add_theme_constant_override("v_separation", 6)
	_vehicle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_grid.custom_minimum_size = Vector2(0, 180) # Ensure it does not get squashed to 0 height
	_vehicle_grid.visible = false
	content.add_child(_vehicle_grid)

	_add_vehicle_button(_vehicle_grid, "fire_truck", "Dispatch BFP", "res://assets/The Right Call Sprites/firetrucksprite.png")
	_add_vehicle_button(_vehicle_grid, "ambulance", "Dispatch MDRRMO", "res://assets/The Right Call Sprites/ambulancesprite.png")
	_add_vehicle_button(_vehicle_grid, "police", "Dispatch PNP", "res://assets/The Right Call Sprites/policeeesprite.png")
	_set_vehicle_buttons_enabled(false)

	# ── Timeline label ─────────────────────────────────────────────
	_timeline_label = Label.new()
	_timeline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timeline_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4, 1.0))
	_timeline_label.add_theme_font_size_override("font_size", 13)
	content.add_child(_timeline_label)

	# ── Floating Keyboard Button ──
	_keyboard_toggle_button = TextureButton.new()
	_keyboard_toggle_button.focus_mode = Control.FOCUS_NONE
	var kb_tex = load("res://assets/ui/icons/keyboard.svg")
	if kb_tex:
		_keyboard_toggle_button.texture_normal = kb_tex
	_keyboard_toggle_button.ignore_texture_size = true
	_keyboard_toggle_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_keyboard_toggle_button.custom_minimum_size = Vector2(80, 80)
	_keyboard_toggle_button.modulate = Color(1, 1, 1, 0.9)
	
	# We want this floating on the bottom right of the canvas, not in the VBox content list
	# But because we need it to stay positioned regardless of VBox, we add it to canvas directly
	_keyboard_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Position will be set during resize, but initial values:
	var vp_size = get_viewport().get_visible_rect().size
	_keyboard_toggle_button.position = Vector2(
		vp_size.x - 80,
		vp_size.y - 80
	)
	_keyboard_toggle_button.pressed.connect(_on_keyboard_toggle_pressed)
	_keyboard_toggle_button.visible = false
	canvas.add_child(_keyboard_toggle_button)

	# ── Guidebook panel (unchanged position) ───────────────────────
	_setup_manual_panel(canvas)

	# ── Off-screen Indicator ─────────────────────────────────────────
	_offscreen_indicator = Area2D.new()
	_offscreen_indicator.name = "OffscreenIndicator"
	_offscreen_indicator.input_pickable = true
	_offscreen_indicator.visible = false
	canvas.add_child(_offscreen_indicator)

	var call_bg = Polygon2D.new()
	var call_bg_pts = PackedVector2Array()
	for i in range(24):
		var angle = (float(i) / 24.0) * TAU
		call_bg_pts.append(Vector2(cos(angle) * 32.0, sin(angle) * 32.0))
	call_bg.polygon = call_bg_pts
	call_bg.color = Color(0.9, 0.2, 0.24, 0.95)
	_offscreen_indicator.add_child(call_bg)

	var call_stem = Polygon2D.new()
	call_stem.polygon = PackedVector2Array([
		Vector2(-5.0, -20.0), Vector2(5.0, -20.0), Vector2(3.6, 4.0), Vector2(-3.6, 4.0)
	])
	call_stem.color = Color.WHITE
	_offscreen_indicator.add_child(call_stem)

	var call_dot = Polygon2D.new()
	var call_dot_pts = PackedVector2Array()
	for i in range(10):
		var angle = (float(i) / 10.0) * TAU
		call_dot_pts.append(Vector2(cos(angle) * 2.4, sin(angle) * 2.4 + 7.0))
	call_dot.polygon = call_dot_pts
	call_dot.color = Color.WHITE
	_offscreen_indicator.add_child(call_dot)

	_offscreen_indicator_arrow = Polygon2D.new()
	_offscreen_indicator_arrow.polygon = PackedVector2Array([
		Vector2(24.0, 0.0), Vector2(12.0, -5.0), Vector2(12.0, 5.0)
	])
	_offscreen_indicator_arrow.color = Color(0.95, 0.95, 1.0, 0.95)
	_offscreen_indicator.add_child(_offscreen_indicator_arrow)
	
	var indicator_collision = CollisionShape2D.new()
	var indicator_shape = CircleShape2D.new()
	indicator_shape.radius = 22.0
	indicator_collision.shape = indicator_shape
	_offscreen_indicator.add_child(indicator_collision)
	
	_offscreen_indicator.input_event.connect(_on_offscreen_indicator_clicked)

	_set_dispatch_panel_waiting_state("Stand by for incoming calls.")

func _on_minimized_call_pressed() -> void:
	_scroll_dialog_to_top()
	if _active_call.is_empty():
		if _minimized_call_button:
			_minimized_call_button.visible = false
		return
	if _minimized_call_button:
		_minimized_call_button.visible = false
	if _dispatch_panel:
		_dispatch_panel.visible = true
	if _dim_overlay:
		_dim_overlay.visible = true
	_call_active = true
	if _hint_label:
		pass


func _on_offscreen_indicator_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _active_call_marker != null and is_instance_valid(_active_call_marker):
			_pan_map_to_world_point(_active_call_marker.position)

func _pan_map_to_world_point(world_point: Vector2) -> void:
	if _world_node == null or _map_sprite == null:
		return
	var viewport_center = get_viewport().get_visible_rect().size * 0.5
	var target_offset = _clamped_map_offset(viewport_center - world_point * _current_scale)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_world_node, "position", target_offset, 0.42)
	tween.parallel().tween_property(_map_sprite, "position", target_offset, 0.42)

func _minimize_call_during_dispatch() -> void:
	if _dispatch_panel:
		_dispatch_panel.visible = false
	if _dim_overlay:
		_dim_overlay.visible = false
	if _minimized_call_button:
		_minimized_call_button.visible = true

func _restore_call_after_dispatch() -> void:
	if _minimized_call_button:
		_minimized_call_button.visible = false
	if _dispatch_panel:
		_dispatch_panel.visible = true
	if _dim_overlay:
		_dim_overlay.visible = true

func _setup_manual_panel(canvas: Node) -> void:
	_manual_panel = PanelContainer.new()
	_manual_panel.name = "ManualPanel"
	_manual_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_manual_panel.offset_left = -580.0
	_manual_panel.offset_top = 630.0
	_manual_panel.offset_right = -16.0
	_manual_panel.offset_bottom = 1000.0
	var manual_style = StyleBoxFlat.new()
	manual_style.bg_color = Color(0.08, 0.1, 0.18, 0.96)
	manual_style.corner_radius_top_left = 6
	manual_style.corner_radius_top_right = 6
	manual_style.corner_radius_bottom_left = 6
	manual_style.corner_radius_bottom_right = 6
	manual_style.border_width_left = 2
	manual_style.border_width_top = 2
	manual_style.border_width_right = 2
	manual_style.border_width_bottom = 2
	manual_style.border_color = Color(0.4, 0.5, 0.65, 0.8)
	_manual_panel.add_theme_stylebox_override("panel", manual_style)
	_manual_panel.visible = false
	canvas.add_child(_manual_panel)

	var manual_margin = MarginContainer.new()
	manual_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	manual_margin.add_theme_constant_override("margin_left", 14)
	manual_margin.add_theme_constant_override("margin_top", 14)
	manual_margin.add_theme_constant_override("margin_right", 14)
	manual_margin.add_theme_constant_override("margin_bottom", 14)
	_manual_panel.add_child(manual_margin)

	_manual_text = RichTextLabel.new()
	_manual_text.fit_content = false
	_manual_text.scroll_active = true
	_manual_text.bbcode_enabled = true
	_manual_text.text = _build_manual_text()
	_manual_text.add_theme_color_override("default_color", Color(0.85, 0.9, 0.95, 1.0))
	manual_margin.add_child(_manual_text)

func _add_vehicle_button(parent: Node, vehicle_id: String, label_text: String, icon_path: String) -> void:
	var btn = Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 176)
	btn.expand_icon = true
	btn.add_theme_font_size_override("font_size", 34)
	
	var icon_tex = _load_icon(icon_path)
	if icon_tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = icon_tex
		var frames_count = 4 # These spritesheets all have 4 frames
		var frame_w = icon_tex.get_width() / frames_count
		var frame_h = icon_tex.get_height()
		atlas.region = Rect2(0, 0, frame_w, frame_h)
		btn.icon = atlas
		
		# Animate the sprite frames
		var timer = Timer.new()
		timer.wait_time = 0.15
		timer.autostart = true
		btn.add_child(timer)
		var frame_idx = [0]
		timer.timeout.connect(func():
			if not is_instance_valid(atlas): return
			frame_idx[0] = (frame_idx[0] + 1) % frames_count
			atlas.region = Rect2(frame_idx[0] * frame_w, 0, frame_w, frame_h)
		)
		
	btn.tooltip_text = "Tap to dispatch this unit"
	btn.pressed.connect(Callable(self, "_on_vehicle_button_pressed").bind(vehicle_id))
	parent.add_child(btn)
	_vehicle_buttons[vehicle_id] = btn

func _load_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	if tex is Texture2D:
		return tex
	return null

func _build_manual_text() -> String:
	var lines = [
		"[b]Emergency Guidebook[/b]",
		"",
		"1. Respond to emergency callers quickly and accurately.",
		"2. Keep the caller calm and confirm exact location.",
		"3. Protect lives before property.",
		"4. Never advise dangerous actions (example: water on grease fire).",
		"5. Dispatch the best unit for incident type.",
		"",
		"[b]Call Flow[/b]",
		"- Wait for an emergency alert pin on the map.",
		"- Click the alert pin to open the conversation panel.",
		"- Answer the caller (multiple choice or typed NLP mode).",
		"- Dispatch the correct emergency vehicle.",
		"- End call only after services arrive.",
		"",
		"[b]Quick Unit Matching[/b]",
		"- BFP: active fire, smoke, burning structures.",
		"- MDRRMO: transport patients safely to hospital for medical emergencies, injuries, breathing problems, AND technical operations like extrication of trapped victims or building collapse.",
		"- PNP: violence, threats, criminal activity."
	]
	return "\n".join(lines)

func _on_manual_button_pressed() -> void:
	if _manual_panel:
		_manual_panel.visible = not _manual_panel.visible


func _schedule_next_call(delay_s: float) -> void:
	if _remaining_shift_call_slots() <= 0:
		if _active_call.is_empty() and not _call_active:
			_set_dispatch_panel_waiting_state("Daily call limit reached for this shift.")
		return
	if _next_call_timer:
		_next_call_timer.start(max(0.2, delay_s))
	if _active_call.is_empty() and not _call_active:
		_set_dispatch_panel_waiting_state("Stand by. New incident coming soon.")
	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "An emergency call is coming! Wait for it to appear."

func _set_dispatch_panel_waiting_state(message: String) -> void:
	if _panel_header_label:
		_panel_header_label.text = "INCOMING CALL"
	if _incident_summary_label:
		_incident_summary_label.text = ""
	if _incoming_label:
		_incoming_label.text = message
	if _dispatch_panel:
		_dispatch_panel.visible = false

func _on_next_call_timeout() -> void:
	if not _pending_call.is_empty():
		return
	if _active_call_marker and is_instance_valid(_active_call_marker):
		return
	if not _queued_calls.is_empty():
		return
	if _remaining_shift_call_slots() <= 0:
		if _hint_label:
			pass
		return
	if _route_points_px.is_empty():
		_set_dispatch_panel_waiting_state("Route data unavailable. Check route JSON.")
		_schedule_next_call(dispatch_between_calls_max_s)
		return
	var generated = _generate_call_scenario()
	if generated.is_empty():
		_schedule_next_call(dispatch_between_calls_max_s)
		return
	if not generated.has("marker_pos"):
		generated["marker_pos"] = _pick_random_road_position()

	# If a call is still being handled, queue the new emergency so it can be answered next.
	if not _active_call.is_empty() or _call_active:
		if _queued_calls.size() < max_waiting_calls and _remaining_shift_call_slots() > 0:
			_queued_calls.append(generated)
			if _response_feedback_label:
				_response_feedback_label.text = "New emergency reported. Waiting queue: %d" % _queued_calls.size()
			if _hint_label:
				pass
			_update_keyboard_toggle_button_state()
			if _has_dispatched_vehicle:
				_schedule_background_emergency_if_needed()
		return

	_pending_call = generated
	await get_tree().create_timer(randf_range(1.0, 5.0)).timeout
	_spawn_call_marker()

func _generate_call_scenario() -> Dictionary:
	if _is_interactive_tutorial:
		if _scenario_generator and _scenario_generator.has_method("get_scenario_by_id"):
			var tut_id = "new_sb_fire_basic_001"
			if _selected_locale == "tl":
				tut_id = "new_sb_fire_basic_001_tl"
			elif _selected_locale == "taglish":
				tut_id = "new_sb_fire_basic_001_tl_en"
			var tut_scenario = _scenario_generator.call("get_scenario_by_id", tut_id, _selected_locale)
			if typeof(tut_scenario) == TYPE_DICTIONARY and not tut_scenario.is_empty():
				var scenario_copy = tut_scenario.duplicate(true)
				scenario_copy["id"] = "tut_fire"
				return scenario_copy

	if _scenario_generator and _scenario_generator.has_method("generate_scenario"):
		var state = get_node_or_null("/root/GameState")
		if state and state.has_method("get_locale"):
			_selected_locale = String(state.call("get_locale"))
		print("[RouteScene] Calling generate_scenario with mode=", _selected_mode_id, " locale=", _selected_locale, " day=", _current_day)
		var generated = _scenario_generator.call("generate_scenario", _selected_mode_id, _selected_locale, _current_day)
		if typeof(generated) == TYPE_DICTIONARY:
			print("[RouteScene] Scenario generated: ID=", generated.get("template_id", generated.get("id")), " Title=", generated.get("title"), " Transcript size=", generated.get("transcript", []).size(), " Options size=", generated.get("options", []).size())
			return generated
		else:
			print("[RouteScene] Error: generate_scenario did not return a dictionary. Returned: ", typeof(generated))
	return {
		"type": "fire",
		"severity": "medium",
		"title": "Fallback Emergency",
		"location": "Santa Cruz center",
		"recommended_vehicle": "fire_truck",
		"transcript": [
			{"speaker": "911", "text": "911, what is your emergency?"},
			{"speaker": "Caller", "text": "There is smoke inside our building!"}
		],
		"options": [
			{"text": "Evacuate everyone and dispatch a fire truck.", "label": "safe", "feedback": "Good response."},
			{"text": "Ignore and wait.", "label": "unsafe", "feedback": "Unsafe response."}
		]
	}

func _spawn_call_marker() -> void:
	if _pending_call.is_empty():
		return
	if _active_call_marker and is_instance_valid(_active_call_marker):
		_active_call_marker.queue_free()

	var marker = Node2D.new()
	marker.name = "EmergencyCallMarker"
	var marker_pos = _pending_call.get("marker_pos", _pick_random_road_position())
	if marker_pos is Vector2:
		marker.position = marker_pos
	else:
		marker.position = _pick_random_road_position()

	var area = Area2D.new()
	area.input_pickable = true
	var shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 56.0
	shape.shape = circle_shape
	area.add_child(shape)
	area.input_event.connect(Callable(self, "_on_call_marker_input_event").bind(marker))
	marker.add_child(area)

	# Red circle background
	var bg_circle = Polygon2D.new()
	var circle_pts = PackedVector2Array()
	for i in range(32):
		var angle = (float(i) / 32.0) * TAU
		circle_pts.append(Vector2(cos(angle) * 44.0, sin(angle) * 44.0))
	bg_circle.polygon = circle_pts
	bg_circle.color = Color(0.85, 0.15, 0.2, 1.0)
	marker.add_child(bg_circle)

	# White "!" exclamation mark — stem (tall rectangle)
	var stem = Polygon2D.new()
	stem.polygon = PackedVector2Array([
		Vector2(-6, -28), Vector2(6, -28), Vector2(4, 6), Vector2(-4, 6)
	])
	stem.color = Color.WHITE
	marker.add_child(stem)

	# White "!" exclamation mark — dot (small circle)
	var dot = Polygon2D.new()
	var dot_pts = PackedVector2Array()
	for i in range(12):
		var angle = (float(i) / 12.0) * TAU
		dot_pts.append(Vector2(cos(angle) * 6.0, sin(angle) * 6.0 + 18.0))
	dot.polygon = dot_pts
	dot.color = Color.WHITE
	marker.add_child(dot)

	_world_node.add_child(marker)
	_active_call_marker = marker
	
	var vp = get_viewport_rect().size
	var is_portrait = vp.y > vp.x
	var base_scale = 7.0 if is_portrait else 4.5
	marker.scale = Vector2(base_scale, base_scale)

	var tw = marker.create_tween()
	tw.set_loops()
	tw.tween_property(marker, "scale", Vector2(base_scale * 1.15, base_scale * 1.15), 0.45)
	tw.tween_property(marker, "scale", Vector2(base_scale, base_scale), 0.45)

	if _hint_label:
		pass
	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "Click the red '!' alert icon on the map to open the call."
		
	# Start phone ring sound
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ring"):
		am.play_ring()

func _on_call_marker_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, marker: Node2D) -> void:
	if event is InputEventMouseButton:
		var mouse = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_dragging = false
			_open_call_from_marker(marker)

func _process(_delta: float) -> void:
	_update_dispatched_vehicle_follow(_delta)
	if is_instance_valid(_tutorial_focus_target):
		_update_tutorial_focus_layout()
	elif _tutorial_focus_target != null:
		_tutorial_focus_target = null
	if _active_call_marker != null and is_instance_valid(_active_call_marker) and _offscreen_indicator != null:
		var vp_rect = get_viewport_rect()
		
		# Getting global position on screen by taking canvas transform into account
		var canvas_transform = get_canvas_transform()
		var marker_screen_pos = canvas_transform * _active_call_marker.global_position
		
		# Define a safe margin (how close to edge before it's "offscreen")
		var margin = 32.0
		var padded_rect = vp_rect.grow(-margin)
		
		if not padded_rect.has_point(marker_screen_pos) and not _call_active:
			_offscreen_indicator.visible = true
			
			# Clamp indicator position to screen edges
			var ind_pos = marker_screen_pos
			ind_pos.x = clamp(ind_pos.x, margin, vp_rect.size.x - margin)
			ind_pos.y = clamp(ind_pos.y, margin, vp_rect.size.y - margin)
			_offscreen_indicator.position = ind_pos
			
			# Keep bubble upright; rotate only compass arrow toward call location.
			_offscreen_indicator.rotation = 0.0
			if _offscreen_indicator_arrow:
				_offscreen_indicator_arrow.rotation = ind_pos.angle_to_point(marker_screen_pos)
			
			# Pulse animation for the call indicator
			_offscreen_indicator.scale = Vector2.ONE * (2.0 + sin(Time.get_ticks_msec() / 220.0) * 0.24)
		else:
			_offscreen_indicator.visible = false
	elif _offscreen_indicator != null:
		_offscreen_indicator.visible = false

func _update_dispatched_vehicle_follow(delta: float) -> void:
	if not _follow_dispatched_vehicle or not _follow_vehicle_pos_valid:
		return
	if _world_node == null or _map_sprite == null:
		return
	var viewport_center = get_viewport().get_visible_rect().size * 0.5
	
	var target_zoom = clamp(_min_scale * 2.5, _min_scale, _max_scale)
	_current_scale = lerp(_current_scale, target_zoom, delta * 2.0)
	_world_node.scale = Vector2(_current_scale, _current_scale)
	_map_sprite.scale = Vector2(_current_scale, _current_scale)
	
	var target_offset = _clamped_map_offset(viewport_center - _follow_vehicle_world_pos * _current_scale)
	var blend = clamp(delta * max(1.0, responder_follow_smoothing), 0.0, 1.0)
	_world_node.position = _world_node.position.lerp(target_offset, blend)
	_map_sprite.position = _map_sprite.position.lerp(target_offset, blend)

func _on_response_position_updated(_vehicle_id: String, world_position: Vector2) -> void:
	_follow_vehicle_world_pos = world_position
	_follow_vehicle_pos_valid = true

## Invalidates pre-generated and active call state when BKT Reset is triggered
func invalidate_call_state_after_reset() -> void:
	print("[RouteScene] BKT Reset received. Invalidating pre-generated & active call state...")
	_pending_call.clear()
	_queued_calls.clear()
	_current_dp_context.clear()
	_active_rendered_options.clear()
	_active_mid_rendered_options.clear()
	_active_mid_transcript_options.clear()
	_clear_choice_buttons()
	
	if _active_call_marker and is_instance_valid(_active_call_marker):
		_active_call_marker.queue_free()
		_active_call_marker = null
		
	if _call_active or not _active_call.is_empty():
		_active_call.clear()
		_call_active = false
		if _dispatch_panel:
			_dispatch_panel.visible = false
		if _dim_overlay:
			_dim_overlay.visible = false
			
	_schedule_next_call(0.5)

func _open_call_from_marker(marker: Node2D) -> void:
	if marker != _active_call_marker:
		return
	if _pending_call.is_empty():
		return

	_active_call_world_position = marker.position
	_pan_map_to_world_point(marker.position)
	if _active_call_marker and is_instance_valid(_active_call_marker):
		_active_call_marker.queue_free()
	_active_call_marker = null

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_ring"):
		am.stop_ring()

	_active_call = _pending_call.duplicate(true)
	_pending_call.clear()
	_call_sequence += 1
	_transcript_index = 0
	_conversation_log.clear()
	_active_rendered_options.clear()
	_active_mid_rendered_options.clear()
	_active_mid_transcript_options.clear()
	SafeScapeEvaluationLogger.reset_presentation_guards()
	_dp_attempts = 0
	_dp_mistakes = 0
	_dp_first_attempt_correct = false
	_current_dp_context.clear()
	_intake_location_asked = false
	_intake_emergency_asked = false
	_awaiting_dispatch = false
	_services_arrived = false
	_response_quality = "uncertain"
	_dispatch_phase_unlocked = false
	_has_dispatched_vehicle = false
	_is_waiting_for_llm = false
	_awaiting_dispatcher_prompt = false
	_call_active = true
	if _minimized_call_button:
		_minimized_call_button.visible = false

	if _dim_overlay:
		_dim_overlay.visible = true
	if _dispatch_panel:
		_dispatch_panel.visible = true
	if _panel_header_label:
		_panel_header_label.text = "CALL #%d" % _call_sequence
	_set_intake_state(false, false)
	_intake_stage = 0

	if _hint_label:
		pass
	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "Click 'Answer Call' to connect to the citizen."

	if _chat_box:
		for child in _chat_box.get_children():
			child.queue_free()
	
	_current_call_mistakes = 0
	if _operator_portrait and _operator_portrait.texture is AtlasTexture:
		var fw = _operator_portrait.texture.atlas.get_width() / 3
		var fh = _operator_portrait.texture.atlas.get_height()
		_operator_portrait.texture.region = Rect2(2 * fw, 0, fw, fh) # Confident

	if _caller_portrait and _caller_images.size() > 0:
		var chosen_img_path = _caller_images[randi() % _caller_images.size()]
		var caller_tex = _load_icon(chosen_img_path)
		if caller_tex:
			var img = caller_tex.get_image()
			if img:
				var used = img.get_used_rect()
				var atlas = AtlasTexture.new()
				atlas.atlas = caller_tex
				atlas.region = used
				_caller_portrait.texture = atlas
			else:
				_caller_portrait.texture = caller_tex
			
			if "Kid" in chosen_img_path:
				_caller_portrait.custom_minimum_size = Vector2(144, 144) # 20% smaller than 180
			elif "Teen" in chosen_img_path:
				_caller_portrait.custom_minimum_size = Vector2(162, 162) # 10% smaller than 180
			else:
				_caller_portrait.custom_minimum_size = Vector2(180, 180) # Baseline
	_append_transcript_line("System", "Call connected. Recording live transcript...")

	_clear_choice_buttons()
	if _typed_row:
		_typed_row.visible = false
	if _typed_input:
		_typed_input.text = ""
	if _response_feedback_label:
		_response_feedback_label.text = ""
	if _response_prompt_label:
		_response_prompt_label.text = "Press Answer Call to begin transcription."
	if _assignment_label:
		_assignment_label.text = ""
	if _timeline_label:
		_timeline_label.text = ""
	_set_vehicle_buttons_enabled(false)
	if _vehicle_grid:
		_vehicle_grid.visible = false

	_on_answer_call_pressed()
	if _keyboard_toggle_button:
		if _selected_mode_id == "easy_multiple_choice":
			_keyboard_toggle_button.visible = false
		else:
			_keyboard_toggle_button.visible = true
			_keyboard_toggle_button.disabled = false

func _on_answer_call_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_click()
		if am.has_method("stop_ring"):
			am.stop_ring()
	if _active_call.is_empty():
		return

	# Add the complete transcript for the interactive steps
	_caller_lines.clear()
	_caller_line_index = 0
	_interactive_phase = 0
	_player_responded_this_round = false
	_intake_stage = 0
	_bypassed_intake = false
	_num_interactive_choices_answered = 0
	_professional_scored_tags.clear()
	_call_score = 0
	_wrong_advice_count = 0
	_call_start_time = Time.get_ticks_msec() / 1000.0
	_current_call_review = {
		"call_number": _call_sequence,
		"title": String(_active_call.get("title", "Emergency")),
		"type": String(_active_call.get("type", "unknown")),
		"location": String(_active_call.get("location", "Unknown")),
		"checks_total": 0,
		"checks_correct": 0,
		"score": 0,
		"protocol_hits": [],
		"response": {},
		"dispatch": {}
	}

	_has_dispatched_vehicle = false
	_dispatch_phase_unlocked = false
	_set_vehicle_buttons_enabled(false)
	if _vehicle_grid:
		_vehicle_grid.visible = false
	if _assignment_label:
		_assignment_label.text = "Finish the caller conversation first. Dispatch buttons unlock after response review."

	if _response_prompt_label:
		_response_prompt_label.text = "Begin intake by asking location first."

	_start_intake_prompt()

	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "Start with intake. Ask where they are and what happened."

func _play_next_caller_line() -> void:
	if _caller_line_index < _caller_lines.size():
		var line: Dictionary = _caller_lines[_caller_line_index]
		var speaker = String(line.get("speaker", "Caller"))
		
		# Options-based 911 turn = mid-call multiple choice
		if line.has("options") and (speaker.to_lower() == "911" or speaker.to_lower() == "dispatcher"):
			_caller_line_index += 1
			if _caller_line_index >= _caller_lines.size():
				_show_player_choices()
			else:
				_active_mid_transcript_options = line.get("options", [])
				_show_mid_transcript_choices()
			return
			
		var text = String(line.get("text", ""))
		
		if speaker == "911":
			_show_dispatcher_prompt(text)
		else:
			_append_transcript_line(speaker, text)
			_caller_line_index += 1
			
			if _bypassed_intake:
				var updated = false
				if not _complaint_revealed:
					_complaint_revealed = true
					updated = true
				if _num_interactive_choices_answered == 1 and not _location_revealed:
					_location_revealed = true
					updated = true
				if updated:
					_set_intake_state(_location_revealed, _complaint_revealed)
					
			if _transcript_timer:
				_transcript_timer.start()
	else:
		_show_player_choices()

## Centralized single authority for constructing valid, deduplicated, source-only option lists.
func build_final_options(source_options: Array, dda_level: String) -> Array:
	if source_options.is_empty():
		return []

	# Step 1: Separate safe (correct) and unsafe (distractor) options strictly based on label == "safe"
	var safe_options: Array = []
	var unsafe_options: Array = []
	
	for opt_any in source_options:
		if typeof(opt_any) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = opt_any
		if String(opt.get("label", "unsafe")).to_lower() == "safe":
			safe_options.append(opt)
		else:
			unsafe_options.append(opt)

	# Guarantee exactly one correct option
	var correct_opt: Dictionary = {}
	if not safe_options.is_empty():
		correct_opt = safe_options[0]
	elif not unsafe_options.is_empty():
		push_error("[OPTION BUILDER ERROR] No safe option in source! Forcing first option as correct.")
		correct_opt = unsafe_options[0]
		unsafe_options.erase(correct_opt)
	else:
		return []

	var correct_text_key = _clean_option_text_for_normal_mode(String(correct_opt.get("text", ""))).strip_edges().to_lower()
	var seen_texts: Array = [correct_text_key]

	# Step 2: Determine target option count from DDA level
	var target_count = 2
	if dda_level == "MODERATE":
		target_count = 3
	elif dda_level == "HARD":
		target_count = 4

	var max_distractors = target_count - 1

	# Step 3: Categorize distractors by dda_role, enforcing text uniqueness
	var obvious_pool: Array = []
	var plausible_pool: Array = []
	var close_pool: Array = []
	var other_pool: Array = []

	for opt in unsafe_options:
		var raw_t = String(opt.get("text", ""))
		var clean_t = _clean_option_text_for_normal_mode(raw_t).strip_edges().to_lower()
		if clean_t == "" or seen_texts.has(clean_t):
			SafeScapeEvaluationLogger.log_validation({
				"event": "duplicate_option_detected",
				"scenario_id": String(_active_call.get("id", _active_call.get("template_id", ""))),
				"option_text": raw_t
			})
			continue

		var role = String(opt.get("dda_role", ""))
		if role == "obvious_distractor":
			obvious_pool.append(opt)
		elif role == "plausible_distractor":
			plausible_pool.append(opt)
		elif role == "close_distractor":
			close_pool.append(opt)
		else:
			other_pool.append(opt)

	obvious_pool.shuffle()
	plausible_pool.shuffle()
	close_pool.shuffle()
	other_pool.shuffle()

	# Step 4: Pick unique distractors according to DDA tier priority
	var chosen_distractors: Array = []
	var priority_order: Array = []
	if dda_level == "EASY":
		priority_order = [obvious_pool, plausible_pool, close_pool, other_pool]
	elif dda_level == "MODERATE":
		priority_order = [plausible_pool, obvious_pool, close_pool, other_pool]
	else:
		priority_order = [close_pool, plausible_pool, obvious_pool, other_pool]

	for pool in priority_order:
		for opt in pool:
			if chosen_distractors.size() >= max_distractors:
				break
			var norm_t = _clean_option_text_for_normal_mode(String(opt.get("text", ""))).strip_edges().to_lower()
			if not seen_texts.has(norm_t):
				seen_texts.append(norm_t)
				chosen_distractors.append(opt)

	# Step 5: Fallback - if chosen_distractors is still less than max_distractors, fill from remaining unused unsafe options
	if chosen_distractors.size() < max_distractors:
		for opt in unsafe_options:
			var norm_t = _clean_option_text_for_normal_mode(String(opt.get("text", ""))).strip_edges().to_lower()
			if not seen_texts.has(norm_t):
				seen_texts.append(norm_t)
				chosen_distractors.append(opt)
				if chosen_distractors.size() >= max_distractors:
					break

	# Construct final option array: exactly 1 correct option + chosen unique distractors
	var final_list: Array = [correct_opt]
	final_list.append_array(chosen_distractors)
	
	# Clamp to maximum 4
	if final_list.size() > 4:
		final_list.resize(4)

	final_list.shuffle()
	return final_list


func _show_mid_transcript_choices() -> void:
	_dp_attempts = 0
	_dp_mistakes = 0
	_dp_first_attempt_correct = false
	_scroll_dialog_to_bottom()
	_clear_choice_buttons()
	if _typed_row:
		_typed_row.visible = false
	
	if _response_prompt_label:
		_response_prompt_label.text = "Select your next response to the caller:"
	
	if _choices_box and _active_mid_transcript_options.size() > 0:
		var sc_id = String(_active_call.get("template_id", _active_call.get("id", "")))
		if sc_id == "": sc_id = "scenario_%d" % _call_sequence
		var sc_cat = String(_active_call.get("type", _active_call.get("category", "fire")))
		var sc_skill = SafeScapeScenarioSkillMapper.determine_skill(_active_call)
		var game_st = get_node_or_null("/root/GameState")
		var mastery_before = 0.40
		var dda_before = "EASY"
		if game_st:
			if game_st.has_method("get_bkt_mastery"):
				mastery_before = game_st.call("get_bkt_mastery", sc_skill)
			if game_st.has_method("determine_dda_difficulty"):
				dda_before = game_st.call("determine_dda_difficulty", sc_skill)

		var source_opts = _active_mid_transcript_options
		var final_opts = build_final_options(source_opts, dda_before)
		_active_mid_rendered_options = final_opts

		var seen_texts: Array = []
		var safe_btn: Button = null
		var btns_to_layout: Array = []
		var correct_count = 0

		for i in range(final_opts.size()):
			var opt: Dictionary = final_opts[i]
			var raw_text = String(opt.get("text", ""))
			var display_text = _clean_option_text_for_normal_mode(raw_text)
			if display_text == "": display_text = raw_text
			
			var is_safe = (String(opt.get("label", "")).to_lower() == "safe")
			if is_safe:
				correct_count += 1

			var t_key = display_text.strip_edges().to_lower()
			if not seen_texts.has(t_key):
				seen_texts.append(t_key)

			var btn = Button.new()
			btn.text = display_text
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.set_meta("option_idx", i)
			_style_choice_button(btn, _ui_scale_factor())
			btn.pressed.connect(Callable(self, "_on_mid_transcript_choice_pressed").bind(i))
			btns_to_layout.append(btn)
			
			if _is_interactive_tutorial and is_safe:
				safe_btn = btn

		var rendered_count = btns_to_layout.size()
		var target_count = 2
		if dda_before == "MODERATE": target_count = 3
		elif dda_before == "HARD": target_count = 4

		_current_dp_context = {
			"scenario_id": sc_id,
			"category": sc_cat,
			"skill": sc_skill,
			"mastery_before": mastery_before,
			"dda_level": dda_before,
			"options_presented": rendered_count
		}

		var is_valid = (rendered_count <= 4 and rendered_count > 0 and correct_count == 1 and seen_texts.size() == rendered_count)
		var dp_index = _num_interactive_choices_answered + 1
		var is_adaptive = true
		if game_st and game_st.bkt_manager:
			is_adaptive = bool(game_st.bkt_manager.ADAPTIVE_MODE)

		SafeScapeEvaluationLogger.log_decision_presented(sc_id, sc_cat, sc_skill, mastery_before, dda_before, rendered_count, target_count, (correct_count == 1), dp_index, is_adaptive)

		SafeScapeEvaluationLogger.log_validation({
			"event": "option_validation",
			"scenario_id": sc_id,
			"dda_level": dda_before,
			"target_options": target_count,
			"source_options": source_opts.size(),
			"source_unique_options": source_opts.size(),
			"final_options": rendered_count,
			"final_unique_options": seen_texts.size(),
			"correct_options": correct_count,
			"correct_option_present": (correct_count == 1),
			"options_are_source_only": true,
			"valid": is_valid
		})
		
		SafeScapeEvaluationLogger.log_validation({
			"event": "dda_option_validation",
			"dda_level": dda_before,
			"expected_options": target_count,
			"actual_options": rendered_count,
			"valid": is_valid
		})

		_layout_choice_buttons(btns_to_layout)
		
		if _is_interactive_tutorial:
			_scroll_dialog_to_bottom()
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().create_timer(0.06).timeout
			if is_instance_valid(_choices_box):
				_show_tutorial_focus(_choices_box)
			if is_instance_valid(safe_btn):
				_point_coach_at(safe_btn, "Click safest response")

func _on_mid_transcript_choice_pressed(idx: int) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_click()
	if idx < 0 or idx >= _active_mid_rendered_options.size():
		return
	var opt: Dictionary = _active_mid_rendered_options[idx]
	var is_safe = String(opt.get("label", "")).to_lower() == "safe"
	var raw_text = String(opt.get("text", ""))
	
	var explanation = String(opt.get("explanation", opt.get("feedback", "This is the safest immediate action." if is_safe else "This response is unsafe or inappropriate.")))
	_record_response_review(raw_text, String(opt.get("label", "unsafe")), explanation, _active_mid_transcript_options)
	
	_dp_attempts += 1
	if _dp_attempts == 1:
		_dp_first_attempt_correct = is_safe

	if not is_safe:
		_dp_mistakes += 1
		_current_call_mistakes += 1
		# Wrong choice mid-call
		if _feedback_dialog:
			_feedback_popup_context = ""
			_apply_dialog_color_and_juice(false, true)
			_feedback_dialog.dialog_text = "Unsafe dialogue choice.\n\nYour Action: %s\n\nWhy:\n%s" % [raw_text, explanation]
			_feedback_dialog.popup_centered(Vector2i(600, 200))
			_apply_dialog_juice(false, true)
			if _is_interactive_tutorial:
				await get_tree().process_frame
				if is_instance_valid(_feedback_dialog) and _feedback_dialog.visible:
					var ok_btn = _feedback_dialog.get_ok_button()
					if ok_btn:
						_show_tutorial_focus(ok_btn)
						_point_coach_at(ok_btn, "Click OK to try again.")
		# DO NOT update BKT on retries - wait until decision point is completed!
		return
	
	# Decision point resolved with correct choice (is_safe == true)!
	var dp_skill = String(_current_dp_context.get("skill", SafeScapeScenarioSkillMapper.determine_skill(_active_call)))
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("update_bkt_mastery"):
		var telemetry = {
			"decision_point": _num_interactive_choices_answered + 1,
			"first_attempt_correct": _dp_first_attempt_correct,
			"total_attempts": _dp_attempts,
			"mistakes_count": _dp_mistakes,
			"final_attempt_correct": true,
			"options_presented": _current_dp_context.get("options_presented", 3),
			"dda_level": _current_dp_context.get("dda_level", "EASY"),
			"scenario_id": _current_dp_context.get("scenario_id", "scenario_001"),
			"category": _current_dp_context.get("category", "fire"),
			"recommended_vehicle": String(_active_call.get("recommended_vehicle", ""))
		}
		state.call("update_bkt_mastery", dp_skill, _dp_first_attempt_correct, telemetry)

	# Correct choice mid-call
	_clear_choice_buttons()
	_num_interactive_choices_answered += 1
	var display_text = _clean_option_text_for_normal_mode(raw_text)
	_append_transcript_line("Dispatcher", display_text)
	
	if _feedback_dialog:
		_feedback_popup_context = ""
		_apply_dialog_color_and_juice(true, false)
		_feedback_dialog.dialog_text = "Correct Choice.\n\nYour Action: %s\n\nWhy:\n%s" % [raw_text, explanation]
		_feedback_dialog.popup_centered(Vector2i(600, 200))
		_apply_dialog_juice(true, false)
		if _is_interactive_tutorial:
			await get_tree().process_frame
			if is_instance_valid(_feedback_dialog) and _feedback_dialog.visible:
				var ok_btn = _feedback_dialog.get_ok_button()
				if ok_btn:
					_show_tutorial_focus(ok_btn)
					_point_coach_at(ok_btn, "Click OK to continue.")
		await _feedback_dialog.confirmed
	
	# Continue the caller transcript
	if _transcript_timer:
		_transcript_timer.start()
	else:
		_play_next_caller_line()

func _show_dispatcher_prompt(text: String) -> void:
	_clear_choice_buttons()
	if _selected_mode_id != "easy_multiple_choice":
		_awaiting_dispatcher_prompt = true
		_expected_dispatcher_prompt_text = text
		if _typed_row:
			_typed_row.visible = true
		if _typed_input:
			_typed_input.placeholder_text = "Type what you want to ask the caller..."
			_safe_focus_input()
		if _response_prompt_label:
			_response_prompt_label.text = "Type your next question to the caller."
		return

	if _typed_row:
		_typed_row.visible = false
	if _response_prompt_label:
		_response_prompt_label.text = "Ask the caller:"
	
	if _choices_box:
		var diff = "easy"
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("get_professional_difficulty"):
			diff = String(game_state.call("get_professional_difficulty"))
		var num_distractors = 1
		if diff == "medium":
			num_distractors = 2
		elif diff == "hard":
			num_distractors = 3
			
		var bad_texts = _get_scenario_bad_texts([
			"There's nothing we can do right now.",
			"Try to confront them yourself.",
			"Please hold, we are very busy.",
			"Just wait there until the problem goes away.",
			"Are you sure you need emergency services?",
			"Hang up and try calling the non-emergency line."
		])

		var btn = Button.new()
		btn.text = text
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_choice_button(btn, _ui_scale_factor())
		btn.pressed.connect(Callable(self, "_on_dispatcher_prompt_pressed").bind(text))
		
		var btns = [btn]
		for i in range(num_distractors):
			var bad_btn = Button.new()
			bad_btn.text = bad_texts[i]
			bad_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_style_choice_button(bad_btn, _ui_scale_factor())
			bad_btn.pressed.connect(Callable(self, "_on_wrong_intake_pressed"))
			btns.append(bad_btn)
			
		btns.shuffle()
		_layout_choice_buttons(btns)
		if _is_interactive_tutorial:
			_point_coach_at(btn, "Ask caller")

func _on_dispatcher_prompt_pressed(text: String) -> void:
	_clear_choice_buttons()
	_append_transcript_line("Dispatcher", text)
	if _response_prompt_label:
		_response_prompt_label.text = "Caller is responding..."
	if _is_interactive_tutorial:
		if _chat_box and _chat_box.get_parent():
			_scroll_dialog_to_top()
			_point_coach_at(_chat_box.get_parent(), "Read reply")
	_caller_line_index += 1
	if _transcript_timer:
		_transcript_timer.start()

func _on_transcript_tick() -> void:
	# In the new interactive flow, the timer is used as a delay between
	# caller lines when continuing after player responds
	if _transcript_timer:
		_transcript_timer.stop()
	_play_next_caller_line()

func _scroll_dialog_to_bottom() -> void:
	for delay in [0.05, 0.15]:
		get_tree().create_timer(delay).timeout.connect(func():
			if _dispatch_panel:
				var scroll: ScrollContainer = _dispatch_panel.find_child("DialogScroll", true, false)
				if scroll and is_instance_valid(scroll):
					var vbar = scroll.get_v_scroll_bar()
					if vbar and is_instance_valid(vbar):
						scroll.scroll_vertical = int(vbar.max_value)
			if is_instance_valid(_chat_box) and is_instance_valid(_chat_box.get_parent()):
				var scroll = _chat_box.get_parent()
				if scroll is ScrollContainer and is_instance_valid(scroll):
					var vbar = scroll.get_v_scroll_bar()
					if vbar and is_instance_valid(vbar):
						scroll.scroll_vertical = int(vbar.max_value)
		)

func _scroll_dialog_to_top() -> void:
	if _dispatch_panel:
		var scroll: ScrollContainer = _dispatch_panel.find_child("DialogScroll", true, false)
		if scroll:
			get_tree().create_timer(0.05).timeout.connect(func(): scroll.scroll_vertical = 0)

func _show_player_choices() -> void:
	_dp_attempts = 0
	_dp_mistakes = 0
	_dp_first_attempt_correct = false
	_scroll_dialog_to_bottom()
	_clear_choice_buttons()
	if _typed_row:
		_typed_row.visible = false

	if _selected_mode_id == "easy_multiple_choice":
		if _response_prompt_label:
			_response_prompt_label.text = "Select the best response:"
		if _choices_box:
			var source_opts: Array = _get_scenario_options()
			
			# Extract scenario metadata at decision start
			var sc_id = String(_active_call.get("template_id", _active_call.get("id", "")))
			if sc_id == "":
				push_error("[RouteScene ERROR] _active_call has empty scenario ID! Defaulting to call_sequence.")
				sc_id = "scenario_%d" % _call_sequence

			var sc_cat = String(_active_call.get("type", _active_call.get("category", "fire")))
			var sc_skill = SafeScapeScenarioSkillMapper.determine_skill(_active_call)
			var game_st = get_node_or_null("/root/GameState")
			var mastery_before = 0.40
			var dda_before = "EASY"
			if game_st:
				if game_st.has_method("get_bkt_mastery"):
					mastery_before = game_st.call("get_bkt_mastery", sc_skill)
				if game_st.has_method("determine_dda_difficulty"):
					dda_before = game_st.call("determine_dda_difficulty", sc_skill)
			
			var final_opts = build_final_options(source_opts, dda_before)
			_active_rendered_options = final_opts

			var seen_texts: Array = []
			var safe_btn: Button = null
			var btns_to_layout: Array = []
			var correct_count = 0

			for i in range(final_opts.size()):
				var opt: Dictionary = final_opts[i]
				var raw_text = String(opt.get("text", ""))
				var display_text = _clean_option_text_for_normal_mode(raw_text)
				if display_text == "": display_text = raw_text
				
				var is_safe = (String(opt.get("label", "")).to_lower() == "safe")
				if is_safe:
					correct_count += 1

				var t_key = display_text.strip_edges().to_lower()
				if not seen_texts.has(t_key):
					seen_texts.append(t_key)

				var btn = Button.new()
				btn.text = display_text
				btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				btn.set_meta("option_idx", i)
				_style_choice_button(btn, _ui_scale_factor())
				btn.pressed.connect(Callable(self, "_on_choice_option_pressed").bind(i))
				btns_to_layout.append(btn)
				
				if _is_interactive_tutorial and is_safe:
					safe_btn = btn

			var rendered_count = btns_to_layout.size()
			var target_count = 2
			if dda_before == "MODERATE": target_count = 3
			elif dda_before == "HARD": target_count = 4

			_current_dp_context = {
				"scenario_id": sc_id,
				"category": sc_cat,
				"skill": sc_skill,
				"mastery_before": mastery_before,
				"dda_level": dda_before,
				"options_presented": rendered_count
			}
			
			var is_valid = (rendered_count <= 4 and rendered_count > 0 and correct_count == 1 and seen_texts.size() == rendered_count)
			var dp_index = _num_interactive_choices_answered + 1
			var is_adaptive = true
			if game_st and game_st.bkt_manager:
				is_adaptive = bool(game_st.bkt_manager.ADAPTIVE_MODE)

			SafeScapeEvaluationLogger.log_decision_presented(sc_id, sc_cat, sc_skill, mastery_before, dda_before, rendered_count, target_count, (correct_count == 1), dp_index, is_adaptive)
			
			SafeScapeEvaluationLogger.log_validation({
				"event": "option_validation",
				"scenario_id": sc_id,
				"dda_level": dda_before,
				"target_options": target_count,
				"source_options": source_opts.size(),
				"source_unique_options": source_opts.size(),
				"final_options": rendered_count,
				"final_unique_options": seen_texts.size(),
				"correct_options": correct_count,
				"correct_option_present": (correct_count == 1),
				"options_are_source_only": true,
				"valid": is_valid
			})

			SafeScapeEvaluationLogger.log_validation({
				"event": "dda_option_validation",
				"dda_level": dda_before,
				"expected_options": target_count,
				"actual_options": rendered_count,
				"valid": is_valid
			})
					
			_layout_choice_buttons(btns_to_layout)
			_scroll_dialog_to_bottom()
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().create_timer(0.06).timeout
			
			if _is_interactive_tutorial and _tutorial_label:
				var is_fire = String(_active_call.get("id", "")) == "tut_fire"
				if is_fire:
					_tutorial_label.text = "Click the safest response. Never instruct them to use water on this fire!"
				else:
					_tutorial_label.text = "Click the safest response."
				if is_instance_valid(_choices_box):
					_show_tutorial_focus(_choices_box)
				if is_instance_valid(safe_btn):
					_point_coach_at(safe_btn, "Click safest response")
	else:
		if _response_prompt_label:
			_response_prompt_label.text = "Type your response to the caller:"
		if _typed_row:
			_typed_row.visible = true
			
		_scroll_dialog_to_bottom()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.06).timeout
		
		if _is_interactive_tutorial and _tutorial_label:
			var is_fire = String(_active_call.get("id", "")) == "tut_fire"
			if is_fire:
				_tutorial_label.text = "Type the safest response. Never instruct them to use water on this fire!"
			else:
				_tutorial_label.text = "Type the safest response."
		if _is_interactive_tutorial and _typed_submit_button:
			_point_coach_at(_typed_submit_button, "Submit")

func _start_dispatch_phase() -> void:
	_clear_choice_buttons()
	if _typed_row:
		_typed_row.visible = false
	if not _has_dispatched_vehicle:
		_dispatch_phase_unlocked = true
		if _vehicle_grid:
			_vehicle_grid.visible = true
		_set_vehicle_buttons_enabled(true)
		if _response_prompt_label:
			_response_prompt_label.text = "Now dispatch the best emergency vehicle."
		if _assignment_label:
			_assignment_label.text = "Dispatch is unlocked: tap one emergency unit now."
	else:
		if _response_prompt_label:
			_response_prompt_label.text = "Keep caller calm while units travel to the scene."

	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "Excellent. Now click the Fire Truck below to dispatch help!"
		var coached_vehicle = _vehicle_buttons.get("fire_truck", null)
		if coached_vehicle == null:
			coached_vehicle = _vehicle_buttons.get(String(_active_call.get("recommended_vehicle", "")), null)
		if coached_vehicle is Control:
			_scroll_dialog_to_bottom()
			# Defer by one frame so the vehicle grid layout is fully resolved
			# before reading get_global_rect() inside _point_coach_at.
			var _cv = coached_vehicle
			get_tree().process_frame.connect(func():
				_point_coach_at(_cv, "Dispatch")
			, CONNECT_ONE_SHOT)
	_update_keyboard_toggle_button_state()

func _on_choice_option_pressed(option_idx: int) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_click()
	_scroll_dialog_to_top()
	if _active_call.is_empty() or _player_responded_this_round:
		return
	if option_idx < 0 or option_idx >= _active_rendered_options.size():
		return

	var selected: Dictionary = _active_rendered_options[option_idx]
	var label = String(selected.get("label", "uncertain"))
	var explanation = String(selected.get("explanation", ""))
	if explanation.is_empty():
		explanation = String(selected.get("feedback", ""))

	_dp_attempts += 1
	if _dp_attempts == 1:
		_dp_first_attempt_correct = (label == "safe")

	if label != "safe":
		_dp_mistakes += 1
		_current_call_mistakes += 1
		_feedback_popup_context = "tutorial_retry"
		_apply_dialog_color_and_juice(false, true)
		_feedback_dialog.dialog_text = "Incorrect Choice.\n\n%s\n\nPlease try again." % explanation
		_feedback_dialog.popup_centered()
		_apply_dialog_juice(false, true)
		if _is_interactive_tutorial:
			await get_tree().process_frame
			if is_instance_valid(_feedback_dialog) and _feedback_dialog.visible:
				var ok_btn = _feedback_dialog.get_ok_button()
				if ok_btn:
					_show_tutorial_focus(ok_btn)
					_point_coach_at(ok_btn, "Click OK to try again.")
		# DO NOT update BKT on retries - wait until decision point is completed!
		return

	# Decision point resolved with correct choice (label == "safe")!
	# Perform single BKT update for this decision point using decision-start context and first-attempt correctness as observation
	var dp_skill = String(_current_dp_context.get("skill", SafeScapeScenarioSkillMapper.determine_skill(_active_call)))
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("update_bkt_mastery"):
		var telemetry = {
			"decision_point": _num_interactive_choices_answered + 1,
			"first_attempt_correct": _dp_first_attempt_correct,
			"total_attempts": _dp_attempts,
			"mistakes_count": _dp_mistakes,
			"final_attempt_correct": true,
			"options_presented": _current_dp_context.get("options_presented", 3),
			"dda_level": _current_dp_context.get("dda_level", "EASY"),
			"scenario_id": _current_dp_context.get("scenario_id", "scenario_001"),
			"category": _current_dp_context.get("category", "fire"),
			"recommended_vehicle": String(_active_call.get("recommended_vehicle", ""))
		}
		state.call("update_bkt_mastery", dp_skill, _dp_first_attempt_correct, telemetry)

	_player_responded_this_round = true
	var chosen_text = String(selected.get("text", ""))
	_append_transcript_line("Dispatcher", chosen_text)
	
	if _is_interactive_tutorial:
		if _chat_box and _chat_box.get_parent():
			_point_coach_at(_chat_box.get_parent(), "Review response")
		await get_tree().create_timer(3.0).timeout
		
	_record_response_review(chosen_text, label, explanation, _active_rendered_options)
	_score_and_show_feedback(label, chosen_text, explanation)

func _on_typed_submit_pressed() -> void:
	if _active_call.is_empty():
		return
	var user_text = _typed_input.text.strip_edges() if _typed_input else ""
	if user_text == "":
		if _response_feedback_label:
			_response_feedback_label.text = "Please type a response first."
		return

	# (Silent tracking now happens via the LLM response below)
	if _has_dispatched_vehicle and _selected_mode_id != "easy_multiple_choice":
		_handle_post_dispatch_chat(user_text)
		return

	if _awaiting_dispatcher_prompt:
		_awaiting_dispatcher_prompt = false
		_score_professional_turn(user_text)
		_append_transcript_line("Dispatcher", user_text)
		if _typed_input:
			_typed_input.text = ""
		if _response_prompt_label:
			_response_prompt_label.text = "Caller is responding..."
		_caller_line_index += 1
		if _transcript_timer:
			_transcript_timer.start()
		return

	if _is_waiting_for_llm:
		return

	_score_professional_turn(user_text)
	_append_transcript_line("Dispatcher", user_text)
	if _typed_input:
		_typed_input.text = ""
	
	_is_waiting_for_llm = true
	if _typed_input:
		_typed_input.editable = false
	var result: Dictionary = {}
	if _llm_http != null:
		var raw_llm = await _call_llm_evaluate_and_reply(user_text)
		if not raw_llm.is_empty():
			result = raw_llm
	
	if _typed_input:
		_typed_input.editable = true
		_safe_focus_input()

	if result.is_empty():
		# Fallback keyword logic
		if _scenario_generator and _scenario_generator.has_method("evaluate_typed_response"):
			result = _scenario_generator.call("evaluate_typed_response", _active_call, user_text)
		else:
			result = {"label": "uncertain", "feedback": "Response received.", "hint": ""}
		
	var label = String(result.get("label", "uncertain"))
	var feedback = String(result.get("feedback", ""))
	var hint = String(result.get("hint", ""))
	
	# Update BKT mastery on evaluated choice using decision context
	var dp_skill = String(_current_dp_context.get("skill", SafeScapeScenarioSkillMapper.determine_skill(_active_call)))
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("update_bkt_mastery"):
		var sc_id = String(_current_dp_context.get("scenario_id", _active_call.get("template_id", _active_call.get("id", "scenario_%d" % _call_sequence))))
		var telemetry = {
			"decision_point": _num_interactive_choices_answered + 1,
			"first_attempt_correct": (label == "safe"),
			"total_attempts": 1,
			"mistakes_count": 0 if label == "safe" else 1,
			"final_attempt_correct": (label == "safe"),
			"options_presented": _current_dp_context.get("options_presented", 1),
			"dda_level": _current_dp_context.get("dda_level", "EASY"),
			"scenario_id": sc_id,
			"category": String(_active_call.get("type", _active_call.get("category", "fire"))),
			"recommended_vehicle": String(_active_call.get("recommended_vehicle", ""))
		}
		state.call("update_bkt_mastery", dp_skill, label == "safe", telemetry)

	var caller_reply = String(result.get("caller_reply", ""))
	if _intake_stage >= 0:
		_silent_intake_tracking_from_llm(result, caller_reply != "")
	if caller_reply == "":
		caller_reply = _build_caller_chatbot_reply(user_text, label)
	
	if caller_reply != "":
		_append_transcript_line("Caller", caller_reply)
		
	var explanation = feedback
	if not hint.is_empty():
		explanation += "\n\nHint: " + hint
	_record_response_review(user_text, label, explanation, _get_scenario_options())
	_score_and_show_feedback(label, user_text, explanation)
	
	_is_waiting_for_llm = false
	if _typed_input:
		_typed_input.editable = true
		_safe_focus_input()


func _on_typed_text_submitted(_new_text: String) -> void:
	_on_typed_submit_pressed()

# Give focus to the text input so physical/native keyboards route text into it.
func _safe_focus_input() -> void:
	# Disabled to prevent native keyboard glitching on mobile
	pass

func _is_mobile_device() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("/Mobi|Android/i.test(navigator.userAgent)") == true:
			return true
	return false

func _on_keyboard_toggle_pressed() -> void:
	if not _virtual_keyboard:
		return
	_virtual_keyboard.visible = !_virtual_keyboard.visible
	
	# Sync the text to the virtual keyboard's internal text box when opening
	if _virtual_keyboard.visible and _typed_input:
		_virtual_keyboard.set_text(_typed_input.text)
	
	# Push the dispatch panel up so the text box isn't covered by the overlay keyboard
	if _dispatch_panel:
		if _virtual_keyboard.visible:
			var kb_height = _virtual_keyboard.get_keyboard_height()
			if kb_height == 0:
				# Fallback if size isn't computed yet (approx 5 rows * 85px + padding)
				kb_height = 480
			_dispatch_panel.offset_bottom = -kb_height
			_scroll_dialog_to_bottom()
		else:
			_dispatch_panel.offset_bottom = 0


func _unhandled_key_input(event: InputEvent) -> void:
	if not _typed_row or not _typed_row.visible or not _typed_input or not _typed_input.editable:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE:
			if _typed_input.text.length() > 0:
				_typed_input.text = _typed_input.text.substr(0, _typed_input.text.length() - 1)
				_typed_input.caret_column = _typed_input.text.length()
				if _virtual_keyboard and _virtual_keyboard.visible:
					_virtual_keyboard.set_text(_typed_input.text)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER:
			if _virtual_keyboard and _virtual_keyboard.visible:
				_virtual_keyboard.hide_requested.emit()
			_on_typed_submit_pressed()
			get_viewport().set_input_as_handled()
		elif event.unicode != 0:
			_typed_input.text += char(event.unicode)
			_typed_input.caret_column = _typed_input.text.length()
			if _virtual_keyboard and _virtual_keyboard.visible:
				_virtual_keyboard.set_text(_typed_input.text)
			get_viewport().set_input_as_handled()

func _handle_post_dispatch_chat(user_text: String) -> void:
	if _is_waiting_for_llm:
		return
	_is_waiting_for_llm = true
	if _typed_input:
		_typed_input.editable = false
		_typed_input.text = ""
	if _response_prompt_label:
		_response_prompt_label.text = "Caller is responding..."
		
	_append_transcript_line("Dispatcher", user_text)
	_score_professional_turn(user_text)

	var caller_reply = ""
	var label = "uncertain"
	var feedback = ""
	if _llm_http:
		var result = await _call_llm_evaluate_and_reply(user_text)
		if not result.is_empty():
			caller_reply = String(result.get("caller_reply", ""))
			label = String(result.get("label", "uncertain"))
			feedback = String(result.get("feedback", ""))
			
	if caller_reply == "":
		caller_reply = _build_enroute_caller_reply(user_text)
		
	if caller_reply != "":
		_append_transcript_line("Caller", caller_reply)
		
	_record_response_review(user_text, label, feedback, [])
		
	if _response_feedback_label:
		_response_feedback_label.text = "Good. Keep the caller safe and provide updates until units arrive."
	if _response_prompt_label:
		_response_prompt_label.text = "Units are en route. Continue pre-arrival instructions and gather updates."
		
	_is_waiting_for_llm = false
	if _typed_input:
		_typed_input.editable = true
		_safe_focus_input()

func _build_enroute_caller_reply(user_text: String) -> String:
	# Fallback: keyword matching
	var msg = user_text.to_lower()
	if _text_has_any(msg, ["evacuate", "outside", "exit", "leave", "safe area"]):
		return "Understood. We're evacuating now and moving to a safer spot."
	if _text_has_any(msg, ["stay low", "smoke", "cover", "breathe"]):
		return "Okay, we're staying low and covering our nose and mouth."
	if _text_has_any(msg, ["weapons", "armed", "gun", "knife"]):
		return "No weapons seen right now."
	if _text_has_any(msg, ["how many", "who", "injured", "patient"]):
		return "There are two adults and one child here. One adult has minor burns."
	if _text_has_any(msg, ["unlock", "door", "light", "pets", "gate"]):
		return "Copy, we'll unlock the gate and secure our dog inside."
	if _text_has_any(msg, ["stay on the line", "updates", "tell me"]):
		return "We'll stay on the line and keep giving updates."
	return "We're still waiting and following your instructions."
func _silent_intake_tracking_from_llm(result: Dictionary, _caller_reply_sent: bool = false) -> void:
	if _intake_stage < 0: return
	
	var is_ready = result.get("ready_for_dispatch", false) == true
	var caller_text = String(result.get("caller_reply", "")).to_lower()
	var actual_loc = String(_active_call.get("location", "")).to_lower()
	
	var state = get_node_or_null("/root/GameState")
	var is_perf = false
	if state and state.has_method("get_perfectionist_mode"):
		is_perf = state.call("get_perfectionist_mode")
	
	if not is_ready and not is_perf:
		var label = String(result.get("label", "uncertain")).to_lower()
		if label == "safe":
			is_ready = true
		elif _conversation_log.size() > 0:
			var last_msg = String(_conversation_log.back().get("text", "")).to_lower()
			if _text_has_any(last_msg, ["dispatch", "send", "sending", "en route", "on the way", "on their way", "responder", "paramedic", "police", "ambulance", "fire truck", "pnp", "mdrrmo", "bfp", "units"]):
				is_ready = true
		
		# Fallback heuristic
		if not is_ready and actual_loc != "":
			var loc_words = actual_loc.split(" ", false)
			for w in loc_words:
				var word = w.strip_edges().replace(",", "").replace(".", "").to_lower()
				if word.length() > 3 and caller_text.contains(word):
					is_ready = true
					break
		
	if is_ready:
		_intake_location_asked = true
		_intake_emergency_asked = true
		_set_intake_state(true, true)
		
		_intake_stage = -1
		_dispatch_phase_unlocked = true
		_set_vehicle_buttons_enabled(true)
		if _vehicle_grid:
			_vehicle_grid.visible = true
		if _assignment_label:
			_assignment_label.text = "Dispatch unlocked! AI detected you have sufficient details."
		if _typed_row:
			_typed_row.visible = true
		if _typed_input:
			_typed_input.placeholder_text = "Give safety guidance (evacuate, hazards, updates) while units travel..."
			_safe_focus_input()
		if _response_prompt_label:
			_response_prompt_label.text = "Units are en route. Continue pre-arrival instructions and gather updates."
		_begin_call_transcript_after_intake(result.has("caller_reply") and result.get("caller_reply") != "")

func _text_has_any(text: String, needles: Array) -> bool:
	for raw in needles:
		var needle = String(raw).to_lower()
		if needle != "" and text.find(needle) >= 0:
			return true
	return false

func _score_professional_turn(user_text: String) -> void:
	if _selected_mode_id == "easy_multiple_choice":
		return
	var msg = user_text.to_lower()
	var earned: Array[String] = []

	if _text_has_any(msg, ["911", "address", "location", "where"]):
		if _award_professional_checkpoint("opening_location", "Opening + Location", 8):
			earned.append("Opening + Location")
	if _text_has_any(msg, ["apartment", "unit", "landmark", "gate", "code", "near"]):
		if _award_professional_checkpoint("location_verify", "Location Verification", 4):
			earned.append("Location Verification")
	if _text_has_any(msg, ["callback", "phone", "contact", "number"]):
		if _award_professional_checkpoint("callback_number", "Callback Number", 4):
			earned.append("Callback Number")
	if _text_has_any(msg, ["what happened", "happened", "emergency", "incident"]):
		if _award_professional_checkpoint("what_happened", "4W: What", 5):
			earned.append("4W: What")
	if _text_has_any(msg, ["who", "how many", "inside", "suspect", "patient"]):
		if _award_professional_checkpoint("who_involved", "4W: Who", 5):
			earned.append("4W: Who")
	if _text_has_any(msg, ["when", "how long", "minutes ago", "just now"]):
		if _award_professional_checkpoint("when_happened", "4W: When", 5):
			earned.append("4W: When")
	if _text_has_any(msg, ["weapon", "armed", "gun", "knife"]):
		if _award_professional_checkpoint("weapons", "Weapons Check", 6):
			earned.append("Weapons Check")
	if _text_has_any(msg, ["cpr", "heimlich", "stay low", "stay quiet", "evacuate", "do not", "keep away", "leave now"]):
		if _award_professional_checkpoint("pre_arrival", "Pre-Arrival Instruction", 7):
			earned.append("Pre-Arrival Instruction")
	if _text_has_any(msg, ["unlock", "porch light", "pets", "stay on the line", "update me", "if anything changes"]):
		if _award_professional_checkpoint("scene_safety", "Post-Dispatch Safety", 6):
			earned.append("Post-Dispatch Safety")

	if not earned.is_empty() and _response_feedback_label:
		_response_feedback_label.text = "Response logged. Continue gathering critical details and safety updates."

func _award_professional_checkpoint(id: String, label: String, points: int) -> bool:
	if _professional_scored_tags.has(id):
		return false
	_professional_scored_tags[id] = true
	var awarded_points = 15
	_call_score += awarded_points
	if not _current_call_review.is_empty():
		_current_call_review["checks_total"] = int(_current_call_review.get("checks_total", 0)) + 1
		_current_call_review["checks_correct"] = int(_current_call_review.get("checks_correct", 0)) + 1
		var hits: Array = _current_call_review.get("protocol_hits", [])
		hits.append("%s (+%d)" % [label, awarded_points])
		_current_call_review["protocol_hits"] = hits
	return true

func _build_caller_chatbot_reply(user_text: String, label: String) -> String:
	# Fallback: keyword matching
	var msg = user_text.to_lower()
	var incident_type = String(_active_call.get("type", "")).to_lower()
	var location = String(_active_call.get("location", "the location"))

	if _text_has_any(msg, ["location", "where", "address", "saan", "lugar", "pwesto"]):
		return "We're at %s, near the main road." % location
	if _text_has_any(msg, ["what happened", "happened", "emergency", "incident", "ano", "nangyari", "saklolo", "tulong"]):
		return "There is an emergency here. We need help right now."
	if _text_has_any(msg, ["what started", "cause", "start", "dahilan"]):
		if incident_type == "fire":
			return "I think it started in the kitchen area."
		return "It just happened so fast."
	if _text_has_any(msg, ["callback", "phone", "number", "numero", "kontak"]):
		return "You can call me back at this number."
	if _text_has_any(msg, ["evac", "outside", "exit", "labas", "alis"]):
		return "Okay, we're moving everyone outside to a safer area now."
	if _text_has_any(msg, ["stay calm", "breathe", "kalma", "hinga"]):
		return "Thank you, that helps. I'm trying to stay calm and follow your instructions."
	
	if label == "safe":
		return "Understood. We'll do that and wait for help."
	if label == "unsafe":
		return "I'm not sure if that's safe... is there another way?"
	return "Please stay on the line with us. What should we do next?"


func _call_llm_evaluate_and_reply(dispatcher_text: String) -> Dictionary:
	"""Call Gemini API via LLMPersona to get evaluation and caller reply.
	Returns empty dictionary if request fails."""
	if _active_call.is_empty() or _llm_persona == null: return {}

	# ── Gather runtime context ────────────────────────────────────────────────
	var incident_type : String = String(_active_call.get("type", "fire"))
	var location      : String = String(_active_call.get("location", "Unknown"))
	var severity      : String = String(_active_call.get("severity", "medium"))
	var title         : String = String(_active_call.get("title", "Emergency Incident"))

	var transcript_text : String = ""
	for t in _conversation_log.slice(-20):
		transcript_text += "  " + String(t.get("speaker", "")) + ": " + String(t.get("text", "")) + "\n"

	var scenario_backstory : String = ""
	if typeof(_active_call.get("transcript")) == TYPE_ARRAY:
		for t in _active_call["transcript"]:
			if typeof(t) == TYPE_DICTIONARY:
				var sp  : String = String(t.get("speaker", "Caller"))
				var txt : String = String(t.get("text", ""))
				if "{location}" in txt:
					txt = txt.replace("{location}", location)
				scenario_backstory += "- " + sp + ": " + txt + "\n"

	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("get_locale"):
		_selected_locale = String(state.call("get_locale"))

	var lang_instruction : String = _llm_persona.lang_instruction_for(_selected_locale)
	var arrival_status   : String = "HAVE ARRIVED ON SCENE" if _services_arrived else "Still traveling (NOT on scene yet)"

	var is_perf   : bool   = state != null and state.has_method("get_perfectionist_mode") and bool(state.call("get_perfectionist_mode"))
	var perf_rules: String = ""
	if is_perf and _selected_mode_id == "professional_nlp_dispatch":
		perf_rules = _llm_persona.perfectionist_rules(_wrong_advice_count)

	# ── Build prompt via LLMPersona ──────────────────────────────────────────
	var sys_prompt : String = _llm_persona.build_system_prompt({
		"scenario_backstory" : scenario_backstory,
		"incident_type"      : incident_type,
		"title"              : title,
		"location"           : location,
		"severity"           : severity,
		"arrival_status"     : arrival_status,
		"transcript_text"    : transcript_text,
		"lang_instruction"   : lang_instruction,
		"perf_rules"         : perf_rules,
	})
	var user_msg : String = _llm_persona.build_user_message(dispatcher_text, lang_instruction)

	# ── Send request ─────────────────────────────────────────────────────────
	var payload = {
		"contents": [
			{
				"role": "user",
				"parts": [{"text": user_msg}]
			}
		],
		"systemInstruction": {
			"parts": [{"text": sys_prompt}]
		},
		"generationConfig": {
			"temperature": _llm_persona.TEMPERATURE,
			"maxOutputTokens": _llm_persona.MAX_TOKENS,
			"responseMimeType": "application/json"
		}
	}

	var req_id = "gemini_%d" % (Time.get_ticks_msec() % 100000)
	var perf_mgr = SafeScapePerformanceManager.get_instance()
	if perf_mgr:
		perf_mgr.record_api_request_start(req_id, "gemini_nlp")

	var endpoint = _llm_persona.GEMINI_ENDPOINT + _llm_persona.GEMINI_API_KEY
	var err = _llm_http.request(
		endpoint,
		_llm_persona.http_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		if perf_mgr:
			perf_mgr.record_api_request_end(req_id, false, 0, "HTTPRequest failed to dispatch: %d" % err)
		return {}

	var result = await _llm_http.request_completed
	var status_code: int = result[1]
	if status_code != 200:
		if perf_mgr:
			perf_mgr.record_api_request_end(req_id, false, status_code, "Gemini API HTTP status %d" % status_code)
		print("Gemini API Error: ", result[3].get_string_from_utf8())
		return {}

	if perf_mgr:
		perf_mgr.record_api_request_end(req_id, true, status_code)

	var body = JSON.parse_string(result[3].get_string_from_utf8())
	if typeof(body) != TYPE_DICTIONARY or not body.has("candidates"): return {}

	var content : String = body["candidates"][0]["content"]["parts"][0]["text"]
	var data = JSON.parse_string(content)
	if typeof(data) == TYPE_DICTIONARY:
		# Refresh is_perf in case it changed during the await
		is_perf = state != null and state.has_method("get_perfectionist_mode") and bool(state.call("get_perfectionist_mode"))
		if is_perf and _selected_mode_id == "professional_nlp_dispatch":
			var lbl : String = String(data.get("label", ""))
			if lbl == "safe":
				_wrong_advice_count = 0
			elif lbl == "unsafe" or lbl == "uncertain":
				_wrong_advice_count += 1
		return data
		
	print("Gemini API Parse Error. Content was: ", content)
	return {}

func _score_and_show_feedback(label: String, chosen_text: String, explanation: String) -> void:
	_clear_choice_buttons()
	if _typed_row and _selected_mode_id == "easy_multiple_choice":
		_typed_row.visible = false
	_response_quality = label

	# BKT mastery is updated via decision-context on choice completion

	# Score the response
	match label:
		"safe":
			_call_score += 20
		"uncertain":
			_call_score += 5
			_current_call_mistakes += 1
		"unsafe":
			_call_score -= 10
			_current_call_mistakes += 1
			
	if _current_call_mistakes > 0 and _operator_portrait and _operator_portrait.texture is AtlasTexture:
		var fw = _operator_portrait.texture.atlas.get_width() / 3
		var fh = _operator_portrait.texture.atlas.get_height()
		_operator_portrait.texture.region = _trim_region(_operator_portrait.texture.atlas, Rect2(0, 0, fw, fh)) # Serious (Leftmost) trimmed

	if _response_feedback_label:
		_response_feedback_label.text = explanation

	if _feedback_dialog:
		if _selected_mode_id != "easy_multiple_choice":
			_on_feedback_popup_closed()
			return
		var title_text = ""
		if label == "safe":
			title_text = "✅ Excellent Choice! (+20 pts)"
		elif label == "unsafe":
			title_text = "⚠️ Dangerous Choice! (-10 pts)"
		else:
			title_text = "✅ Okay Choice (+5 pts)"
			
		_feedback_popup_context = "response"
		var is_correct = (label == "safe")
		var is_unsafe = (label == "unsafe")
		_apply_dialog_color_and_juice(is_correct, is_unsafe)
		_feedback_dialog.dialog_text = "%s\n\nYour Action: %s\n\nWhy:\n%s" % [title_text, chosen_text, explanation]
		_feedback_dialog.popup_centered()
		_apply_dialog_juice(is_correct, is_unsafe)
		if _is_interactive_tutorial:
			await get_tree().process_frame
			if is_instance_valid(_feedback_dialog) and _feedback_dialog.visible:
				var ok_btn = _feedback_dialog.get_ok_button()
				if ok_btn:
					_show_tutorial_focus(ok_btn)
					_point_coach_at(ok_btn, "Click OK to continue.")
	else:
		_on_feedback_popup_closed()

func _apply_dialog_color_and_juice(is_correct: bool, is_error: bool) -> void:
	if _feedback_dialog == null:
		return
	var style = _feedback_dialog.get_theme_stylebox("panel")
	if style and style is StyleBoxFlat:
		var new_style = style.duplicate()
		if is_correct:
			new_style.bg_color = Color(0.1, 0.6, 0.1, 1.0)
		elif is_error:
			new_style.bg_color = Color(0.7, 0.1, 0.1, 1.0)
		else:
			new_style.bg_color = Color8(255, 244, 229)
		_feedback_dialog.add_theme_stylebox_override("panel", new_style)
		_feedback_dialog.add_theme_stylebox_override("embedded_border", new_style)
	
	if is_correct or is_error:
		_feedback_dialog.add_theme_color_override("title_color", Color.WHITE)
		var lbl = _feedback_dialog.get_label()
		if lbl:
			lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		_feedback_dialog.add_theme_color_override("title_color", Color8(44, 54, 72))
		var lbl = _feedback_dialog.get_label()
		if lbl:
			lbl.add_theme_color_override("font_color", Color8(44, 54, 72))

func _apply_dialog_juice(is_correct: bool, is_error: bool) -> void:
	if _feedback_dialog == null:
		return
	if is_error:
		var original_pos = _feedback_dialog.position
		var tw = _feedback_dialog.create_tween()
		var offset = 12
		var d = 0.05
		tw.tween_property(_feedback_dialog, "position:x", original_pos.x - offset, d)
		tw.tween_property(_feedback_dialog, "position:x", original_pos.x + offset, d)
		tw.tween_property(_feedback_dialog, "position:x", original_pos.x - offset/2.0, d)
		tw.tween_property(_feedback_dialog, "position:x", original_pos.x + offset/2.0, d)
		tw.tween_property(_feedback_dialog, "position:x", original_pos.x, d)
	elif is_correct:
		var orig_size = _feedback_dialog.size
		var orig_pos = _feedback_dialog.position
		var tw = _feedback_dialog.create_tween()
		var pop_size = Vector2i(orig_size.x + 40, orig_size.y + 20)
		var pop_pos = Vector2i(orig_pos.x - 20, orig_pos.y - 10)
		tw.parallel().tween_property(_feedback_dialog, "size", pop_size, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_feedback_dialog, "position", pop_pos, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().parallel().tween_property(_feedback_dialog, "size", orig_size, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_feedback_dialog, "position", orig_pos, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _on_feedback_popup_closed() -> void:
	if _feedback_popup_context == "tutorial_retry":
		_feedback_popup_context = ""
		if _is_interactive_tutorial and _choices_box:
			_choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
			var target = _choices_box.get_parent() if _choices_box.get_parent() is ScrollContainer else _choices_box
			_point_coach_at(target, "Try again! Select the safest response.")
		return
	if _feedback_popup_context == "end_call":
		_feedback_popup_context = ""
		_on_close_call_panel()
		return
	if _feedback_popup_context != "response":
		_feedback_popup_context = ""
		return
	_feedback_popup_context = ""

	if _response_feedback_label:
		if _selected_mode_id == "easy_multiple_choice":
			if _has_dispatched_vehicle:
				_response_feedback_label.text = "Action recorded. Keep caller calm while units travel to the scene."
			else:
				_response_feedback_label.text = "Action recorded. Dispatch required vehicles now."
	_start_dispatch_phase()
	_update_keyboard_toggle_button_state()

func _append_transcript_line(speaker: String, text: String) -> void:
	# Track conversation for LLM context
	_conversation_log.append({"speaker": speaker, "text": text})
	if _chat_box:
		var msg_hbox = HBoxContainer.new()
		msg_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var bubble_panel = PanelContainer.new()
		var bubble_style = StyleBoxFlat.new()
		bubble_style.corner_radius_top_left = 6
		bubble_style.corner_radius_top_right = 6
		bubble_style.corner_radius_bottom_left = 6
		bubble_style.corner_radius_bottom_right = 6
		bubble_style.content_margin_left = 10
		bubble_style.content_margin_top = 8
		bubble_style.content_margin_right = 10
		bubble_style.content_margin_bottom = 8
		bubble_panel.add_theme_stylebox_override("panel", bubble_style)
		
		var msg_label = RichTextLabel.new()
		msg_label.bbcode_enabled = true
		msg_label.fit_content = true
		msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_label.custom_minimum_size = Vector2(150, 0)
		msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var is_operator = (speaker == "911" or speaker == "Dispatcher")
		var is_system = (speaker == "System")
		
		if is_operator:
			bubble_style.bg_color = Color(0.12, 0.45, 0.55, 1.0)
			msg_label.add_theme_color_override("default_color", Color(0.9, 1.0, 1.0, 1.0))
			msg_label.text = text
			
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			msg_hbox.add_child(spacer)
			msg_hbox.add_child(bubble_panel)
		elif is_system:
			bubble_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
			msg_label.add_theme_color_override("default_color", Color(0.8, 0.85, 0.9, 1.0))
			msg_label.text = "[center][i]" + text + "[/i][/center]"
			
			var spacer_left = Control.new()
			spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var spacer_right = Control.new()
			spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			msg_hbox.add_child(spacer_left)
			msg_hbox.add_child(bubble_panel)
			msg_hbox.add_child(spacer_right)
		else: # Caller
			bubble_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
			msg_label.add_theme_color_override("default_color", Color(0.9, 0.8, 0.6, 1.0))
			msg_label.text = text
			
			msg_hbox.add_child(bubble_panel)
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			msg_hbox.add_child(spacer)
			
		bubble_panel.add_child(msg_label)
		_chat_box.add_child(msg_hbox)
		
		# Scroll to bottom reliably
		var scroll_timer = get_tree().create_timer(0.15)
		scroll_timer.timeout.connect(func():
			if is_instance_valid(_chat_box) and is_instance_valid(_chat_box.get_parent()):
				var scroll = _chat_box.get_parent()
				if scroll is ScrollContainer:
					scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		)

func _clear_choice_buttons() -> void:
	if _hint_button:
		_hint_button.visible = false
	if _hint_display_label:
		_hint_display_label.visible = false
	if _choices_box == null:
		return
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()

func _on_hint_button_pressed() -> void:
	if _active_call.is_empty():
		return
	
	_hint_button.visible = false
	var options = _active_call.get("options", [])
	var hint_text = "Proceed with caution."
	
	for opt in options:
		if opt.get("label", "") == "safe":
			hint_text = String(opt.get("explanation", "Choose the option that prioritizes life safety."))
			break
			
	if _hint_display_label:
		_hint_display_label.visible = true
		_hint_display_label.text = "[color=#f39c12]Hint:[/color] " + hint_text

func _set_vehicle_buttons_enabled(enabled: bool) -> void:
	for key in _vehicle_buttons.keys():
		var btn: Button = _vehicle_buttons[key]
		if btn:
			btn.disabled = not enabled

func _educational_vehicle_detail(vehicle_id: String, incident_type: String) -> String:
	match vehicle_id:
		"fire_truck":
			return "BFP teams suppress active fires, mitigate hazardous materials, and perform heavy technical rescue (e.g., extracting trapped victims)."
		"ambulance":
			return "MDRRMO teams provide life-saving medical care, bleeding control, oxygen support, and fast transport to the hospital."
		"police":
			return "PNP officers secure the area, manage suspects, protect bystanders, and keep responders safe while the incident is handled."
		_:
			return "This unit can respond, but matching the exact emergency type improves outcomes and response speed."



func _mismatch_vehicle_detail(selected_vehicle: String, recommended_list: Array[String], incident_type: String) -> String:
	var rec_details = PackedStringArray()
	for r in recommended_list:
		rec_details.append(_vehicle_name(r) + " should be prioritized because " + _educational_vehicle_detail(r, incident_type))
	var recommended_detail = "\n- ".join(rec_details)
	return "%s will still respond, but with reduced efficiency.\n\nBest practice:\n- %s" % [_vehicle_name(selected_vehicle), recommended_detail]

func _schedule_background_emergency_if_needed() -> void:
	if _next_call_timer == null:
		return
	if _remaining_shift_call_slots() <= 0:
		return
	if not _queued_calls.is_empty():
		return
	if _queued_calls.size() >= max_waiting_calls:
		return
	if not _next_call_timer.is_stopped():
		return
	var base_delay = _dispatch_rng.randf_range(dispatch_between_calls_min_s, dispatch_between_calls_max_s)
	var followup_delay = max(2.0, (base_delay * 0.55) / clamp(_day_difficulty_scale, 1.0, 1.75))
	_next_call_timer.start(followup_delay)

func _can_take_next_queued_call_now() -> bool:
	return _call_active and _has_dispatched_vehicle and _player_responded_this_round and not _queued_calls.is_empty()

func _update_keyboard_toggle_button_state() -> void:
	if _keyboard_toggle_button == null:
		return
	if _virtual_keyboard:
		_keyboard_toggle_button.disabled = false

func _on_vehicle_button_pressed(vehicle_id: String) -> void:
	if _has_dispatched_vehicle and _selected_mode_id == "easy_multiple_choice":
		return
	if _active_call.is_empty() or not _call_active:
		return
	if not _dispatch_phase_unlocked:
		if _response_feedback_label:
			_response_feedback_label.text = "Finish the caller conversation first. Dispatch unlocks after response review."
		return

	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_click()

	_has_dispatched_vehicle = true
	if _selected_mode_id == "easy_multiple_choice":
		_dispatch_phase_unlocked = false
	var btn = _vehicle_buttons.get(vehicle_id)
	if btn:
		btn.disabled = true

	var selected_vehicle = _canonical_vehicle_id(vehicle_id)
	var recommended_raw = _active_call.get("recommended_vehicle", "")
	var recommended_list: Array[String] = []
	if typeof(recommended_raw) == TYPE_ARRAY:
		for r in recommended_raw:
			if String(r) != "": recommended_list.append(_canonical_vehicle_id(String(r)))
	else:
		var parts = String(recommended_raw).split(",")
		for p in parts:
			var s = p.strip_edges()
			if s != "": recommended_list.append(_canonical_vehicle_id(s))
			
	var rec_names = PackedStringArray()
	for r in recommended_list:
		rec_names.append(_vehicle_name(r))
	var recommended_str = ", ".join(rec_names)

	var selected_name = _vehicle_name(selected_vehicle)
	
	_append_transcript_line("System", "Dispatching %s to %s." % [selected_name, String(_active_call.get("location", "scene"))])

	var correct_dispatch = recommended_list.has(selected_vehicle)
	var dispatch_title = ""
	var dispatch_explanation = ""
	var incident_type = String(_active_call.get("type", "fire"))
	if correct_dispatch:
		_call_score += 15
		dispatch_title = "✅ Great Dispatch! (+15 pts)"
		dispatch_explanation = "%s is a good unit for this emergency.\n\n%s" % [selected_name, _educational_vehicle_detail(selected_vehicle, incident_type)]
		if _assignment_label:
			_assignment_label.text = "Unit sent! (+15 pts) You can dispatch more units if needed."
	else:
		if _selected_mode_id == "easy_multiple_choice":
			dispatch_title = "Incorrect Unit Sent"
			dispatch_explanation = "This unit cannot handle the emergency. Please recall them and send the recommended unit(s): %s\n\nReason:\n%s" % [recommended_str, _mismatch_vehicle_detail(selected_vehicle, recommended_list, incident_type)]
			if _assignment_label:
				_assignment_label.text = "Incorrect unit sent. Try again."
			
			_has_dispatched_vehicle = false 
			_dispatch_phase_unlocked = true

			if _feedback_dialog:
				_feedback_popup_context = ""
				_apply_dialog_color_and_juice(false, true)
				_feedback_dialog.dialog_text = "%s\n\nYour Dispatch: %s\n\nWhy:\n%s" % [dispatch_title, selected_name, dispatch_explanation]
				_feedback_dialog.popup_centered(Vector2i(760, 320))
				_apply_dialog_juice(false, true)
				
			if btn:
				btn.disabled = false 
			_set_vehicle_buttons_enabled(true)
			return
		else:
			dispatch_title = "Incorrect Dispatch Sent"
			dispatch_explanation = "Recommended unit(s): %s\n%s" % [recommended_str, _mismatch_vehicle_detail(selected_vehicle, recommended_list, incident_type)]
			if _assignment_label:
				_assignment_label.text = "Unit sent. Recommended was %s." % recommended_str

	if _feedback_dialog:
		if _selected_mode_id == "easy_multiple_choice":
			_feedback_popup_context = "vehicle_dispatch"
			_apply_dialog_color_and_juice(correct_dispatch, not correct_dispatch)
			_feedback_dialog.dialog_text = "%s\n\nYour Dispatch: %s\n\nWhy:\n%s" % [dispatch_title, selected_name, dispatch_explanation]
			_feedback_dialog.popup_centered(Vector2i(760, 320))
			_apply_dialog_juice(correct_dispatch, not correct_dispatch)
	_record_vehicle_review(selected_vehicle, recommended_str, correct_dispatch, dispatch_explanation)

	if _selected_mode_id == "easy_multiple_choice":
		_set_vehicle_buttons_enabled(false)
	if _vehicle_grid:
		_vehicle_grid.visible = true
	_services_arrived = false

	var severity = String(_active_call.get("severity", "medium"))
	var base_travel_s = _travel_time_for(severity, correct_dispatch)
	var speed_mult = max(1.0, responder_speed_multiplier)
	var travel_s = max(0.8, base_travel_s / speed_mult)
	_pending_resolution_s = _resolution_time_for(severity, correct_dispatch, _response_quality)
	_follow_dispatched_vehicle = true
	_follow_vehicle_pos_valid = false
	if _timeline_label:
		_timeline_label.text = "Unit en route. ETA %.0fs" % travel_s
	if _response_prompt_label and _player_responded_this_round:
		_response_prompt_label.text = "Keep caller calm while units travel to the scene."
	if _selected_mode_id != "easy_multiple_choice":
		if _typed_row:
			_typed_row.visible = true
		if _typed_input:
			_typed_input.placeholder_text = "Continue talking to caller while units are en route..."
			_safe_focus_input()
	
	# Professional mode keeps the live call dialog open while units travel.
	if _selected_mode_id == "easy_multiple_choice":
		_minimize_call_during_dispatch()
	
	if _patrol_manager and _patrol_manager.has_method("dispatch_response_unit"):
		var requested_travel_s = travel_s
		if _selected_mode_id != "easy_multiple_choice":
			requested_travel_s = 0.0
		_patrol_manager.call("dispatch_response_unit", selected_vehicle, _active_call_world_position, requested_travel_s)
	if _arrival_timer:
		# Fallback only: primary arrival is now event-driven from actual responder movement.
		_arrival_timer.start(travel_s + 0.6)

	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "Unit dispatched! Just wait for them to arrive."
		_hide_coach_pointer()

	# Realism: new emergencies can still be reported while this call is resolving.
	_schedule_background_emergency_if_needed()
	_update_keyboard_toggle_button_state()

func _on_arrival_timeout() -> void:
	# Fallback path in case a responder signal is missed.
	if not _has_dispatched_vehicle:
		return
	_on_response_arrived("", _active_call_world_position)

func _on_response_arrived(_vehicle_id: String, _world_position: Vector2) -> void:
	if _active_call.is_empty():
		return
	if not _has_dispatched_vehicle:
		return
	if _services_arrived:
		return
	_follow_dispatched_vehicle = false
	_follow_vehicle_pos_valid = false
	_services_arrived = true
	if _arrival_timer:
		_arrival_timer.stop()
	
	# Restore call window only for easy mode where we minimized it.
	if _selected_mode_id == "easy_multiple_choice":
		pass
	else:
		if _resolution_timer:
			_resolution_timer.start(_pending_resolution_s)
	
	_update_keyboard_toggle_button_state()
	if _timeline_label:
		_timeline_label.text = "Emergency services arrived on scene. Call will auto-complete when incident is resolved."
	_append_transcript_line("System", "Units have arrived on scene. Operation in progress...")
	if _response_prompt_label and _selected_mode_id != "easy_multiple_choice":
		_response_prompt_label.text = "Units are handling the scene. Keep the caller safe."
	if _is_interactive_tutorial and _tutorial_label:
		_tutorial_label.text = "Units arrived. Great job, moving to the next call."
	
	# Easy mode can auto-close instantly. Professional Mode auto-closes via resolution timer.
	if _selected_mode_id == "easy_multiple_choice":
		if _is_interactive_tutorial:
			_run_tutorial_ui_demonstration()
		else:
			_complete_current_call(true, true, "Units arrived and secured the scene. Call closed.")

func _on_resolution_timeout() -> void:
	if _active_call.is_empty():
		return
	if _timeline_label:
		_timeline_label.text = "On-site response completed. Call ending in 2 seconds..."
	_append_transcript_line("System", "Incident operation completed.")

	var auto_end_timer = Timer.new()
	auto_end_timer.wait_time = 2.0
	auto_end_timer.one_shot = true
	auto_end_timer.timeout.connect(Callable(self, "_on_end_call_pressed"))
	auto_end_timer.timeout.connect(auto_end_timer.queue_free)
	add_child(auto_end_timer)
	auto_end_timer.start()

func _complete_current_call(include_speed_bonus: bool, show_completion_popup: bool, closure_line: String) -> void:
	_append_transcript_line("Dispatcher", closure_line)

	var elapsed = (Time.get_ticks_msec() / 1000.0) - _call_start_time
	var speed_bonus = 0
	if include_speed_bonus:
		var day_penalty = float(max(0, _current_day - 1))
		var fast_threshold = max(16.0, 30.0 - (day_penalty * 1.5))
		var medium_threshold = max(fast_threshold + 12.0, 60.0 - (day_penalty * 2.5))
		if elapsed < fast_threshold:
			speed_bonus = 10
		elif elapsed < medium_threshold:
			speed_bonus = 5

	_call_score += speed_bonus
	_call_score = max(_call_score, 0)
	_shift_score += _call_score
	_total_score += _call_score
	_calls_completed += 1
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("set_persistent_score"):
		state.call("set_persistent_score", _total_score)
	var details_str = ""
	if not _current_call_review.is_empty():
		_current_call_review["score"] = _call_score
		_shift_call_reviews.append(_current_call_review.duplicate(true))
		details_str = "\n\n--- Evaluation Details ---\n" + _build_shift_review_detail(_current_call_review)
		_current_call_review.clear()

	var speed_text = " (Speed bonus: +%d)" % speed_bonus if speed_bonus > 0 else ""
	_append_transcript_line("System", "Call Score: %d pts%s" % [_call_score, speed_text])
	_append_transcript_line("System", "Total Score: %d pts (%d calls completed)" % [_total_score, _calls_completed])

	if _score_label:
		_score_label.text = "Score: %d" % _total_score
	_update_shift_ui()
	_save_shift_state_to_game_state()

	# Cloud save hook (SafeScape web wrapper integration)
	var cs_mgr = get_node_or_null("/root/CloudSaveManager")
	if cs_mgr and cs_mgr.has_method("save_progress"):
		var sc_id = String(_active_call.get("template_id", _active_call.get("id", "")))
		var is_success = _call_score > 0
		cs_mgr.save_progress(
			_total_score,
			1,
			1 if is_success else 0,
			0 if is_success else 1,
			sc_id,
			false
		)
	
	if _shift_remaining_s <= 0 and _shift_score >= shift_min_score and not _shift_ready_announced:
		_shift_ready_announced = true
		if _hint_label:
			pass

	if _arrival_timer:
		_arrival_timer.stop()
	if _resolution_timer:
		_resolution_timer.stop()
	if _transcript_timer:
		_transcript_timer.stop()
		
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_ring"):
		am.stop_ring()

	_active_call.clear()
	# Hide it when the game is over
	if _keyboard_toggle_button:
		_keyboard_toggle_button.visible = false
	_has_dispatched_vehicle = false
	_services_arrived = false
	_follow_dispatched_vehicle = false
	_follow_vehicle_pos_valid = false
	_call_active = false
	_caller_lines.clear()
	_caller_line_index = 0
	_interactive_phase = 0
	_player_responded_this_round = false
	_intake_stage = -1
	_set_intake_state(false, false)

	if _is_interactive_tutorial:
		_is_interactive_tutorial = false
		_hide_coach_pointer()
		if _tutorial_panel:
			_tutorial_panel.queue_free()
			_tutorial_panel = null

		if state == null:
			state = get_node_or_null("/root/GameState")
		var was_forced = false
		if state:
			state.call("set_first_live_call_done")
			if state.has_method("get_force_tutorial") and state.call("get_force_tutorial"):
				state.call("set_force_tutorial", false)
				was_forced = true
				
		if was_forced:
			_show_kid_message("Tutorial Finished", "Returning to your saved shift / normal mode...")
			await get_tree().create_timer(3.0).timeout
			get_tree().reload_current_scene()
			return
			
	_interactive_phase = 0
	_player_responded_this_round = false


	if _dim_overlay:
		_dim_overlay.visible = false
	if _minimized_call_button:
		_minimized_call_button.visible = false
	if _dispatch_panel:
		_dispatch_panel.visible = false
	_set_vehicle_buttons_enabled(false)
	if _keyboard_toggle_button:
		if _selected_mode_id == "easy_multiple_choice":
			_keyboard_toggle_button.visible = false
		else:
			_keyboard_toggle_button.disabled = true
			# (was End Call button — now keyboard icon, no text property)

	if _hint_label and _llm_persona:
		var tips : Array = _llm_persona.dispatcher_tips()
		_hint_label.text = tips[randi() % tips.size()]

	if _calls_completed >= _max_calls_per_shift():
		if _next_call_timer:
			_next_call_timer.stop()
		_queued_calls.clear()
		_pending_call.clear()
		_update_shift_ui()
		if _shift_score < shift_min_score:
			_pending_day_restart = false
			if _hint_label:
				pass
			_show_shift_review(
				"Shift Failed",
				"You completed %d calls and scored %d points. Minimum required score is %d. Day %d will restart after you close this review." % [_calls_completed, _shift_score, shift_min_score, _current_day],
				"restart_day"
			)
			return
		if _hint_label:
			pass
		_show_shift_review(
			"Day Complete",
			"Great work! You met the shift requirements. Tap 'Proceed to Day %d' in the status box after reviewing your calls." % (_current_day + 1),
			""
		)
		return

	if show_completion_popup:
		var popup_msg = "Nice work! You helped the caller stay safe.\nCall score: %d\nTotal score: %d%s" % [_call_score, _total_score, details_str]
		_show_kid_message("Mission Complete!", popup_msg)
		if _kid_message_dialog != null:
			await _kid_message_dialog.confirmed

	if not _queued_calls.is_empty():
		if _next_call_timer:
			_next_call_timer.stop()
		_pending_call = _queued_calls.pop_front().duplicate(true)
		await get_tree().create_timer(randf_range(1.0, 5.0)).timeout
		_spawn_call_marker()
		if _hint_label and _llm_persona:
			var tips : Array = _llm_persona.dispatcher_tips()
			_hint_label.text = tips[randi() % tips.size()]
		return

	var base_delay = _dispatch_rng.randf_range(dispatch_between_calls_min_s, dispatch_between_calls_max_s)
	var next_delay = max(2.0, base_delay / clamp(_day_difficulty_scale, 1.0, 1.75))
	_schedule_next_call(next_delay)

func _on_end_call_pressed() -> void:
	if _active_call.is_empty():
		return
	if not _services_arrived:
		if _can_take_next_queued_call_now():
			_complete_current_call(false, false, "Call handed off to responders. Switching to the next queued emergency.")
			return
		if _response_feedback_label:
			_response_feedback_label.text = "You can end now only after arrival, or take the next queued call once conversation + dispatch are done."
		return

	_complete_current_call(true, true, "Call closed. Stay safe.")

func _on_close_call_panel() -> void:
	# Hide the panel to minimize it and re-enable map interactions.
	if _active_call.is_empty():
		if _dispatch_panel:
			_dispatch_panel.visible = false
		if _dim_overlay:
			_dim_overlay.visible = false
		if _minimized_call_button:
			_minimized_call_button.visible = false
		_hide_coach_pointer()
		_call_active = false
		return

	if _dim_overlay:
		_dim_overlay.visible = false
	if _dispatch_panel:
		_dispatch_panel.visible = false
	_call_active = false
	if _minimized_call_button:
		_minimized_call_button.visible = true
		_minimized_call_button.text = "Return to Call"
	if _hint_label:
		pass
	_hide_coach_pointer()

func _pick_random_road_position() -> Vector2:
	if not _buildings_px.is_empty():
		var idx = _dispatch_rng.randi_range(0, _buildings_px.size() - 1)
		var base: Vector2 = _buildings_px[idx]
		var jitter = Vector2(_dispatch_rng.randf_range(-16.0, 16.0), _dispatch_rng.randf_range(-16.0, 16.0))
		var pos = base + jitter
		pos.x = clamp(pos.x, 24.0, float(_img_w) - 24.0)
		pos.y = clamp(pos.y, 24.0, float(_img_h) - 24.0)
		return pos

	if _route_points_px.is_empty():
		return Vector2(float(_img_w) * 0.5, float(_img_h) * 0.5)
	var idx = _dispatch_rng.randi_range(0, _route_points_px.size() - 1)
	var base: Vector2 = _route_points_px[idx]
	var jitter = Vector2(_dispatch_rng.randf_range(-16.0, 16.0), _dispatch_rng.randf_range(-16.0, 16.0))
	var pos = base + jitter
	pos.x = clamp(pos.x, 24.0, float(_img_w) - 24.0)
	pos.y = clamp(pos.y, 24.0, float(_img_h) - 24.0)
	return pos

func _icon_for_call_type(call_type: String) -> Texture2D:
	match call_type:
		"fire":
			return _load_icon("res://assets/ui/icons/fire_truck.svg")
		"police":
			return _load_icon("res://assets/ui/icons/police.svg")
		"criminal":
			return _load_icon("res://assets/ui/icons/police.svg")
		_:
			return _load_icon("res://assets/ui/icons/ambulance.svg")

func _travel_time_for(_severity: String, correct_vehicle: bool) -> float:
	var state = get_node_or_null("/root/GameState")
	var difficulty = state.call("get_professional_difficulty") if state != null else "easy"
	
	if _selected_mode_id != "professional_nlp_dispatch":
		difficulty = "easy"
		
	var base = 10.0
	match difficulty:
		"easy":
			base = randf_range(10.0, 15.0)
		"medium":
			base = randf_range(30.0, 45.0)
		"hard":
			base = randf_range(60.0, 90.0)
			
	if not correct_vehicle:
		base += 15.0
	return base

func _resolution_time_for(severity: String, correct_vehicle: bool, response_quality: String) -> float:
	var base = 10.0
	match severity:
		"low":
			base = 8.0
		"medium":
			base = 14.0
		"high":
			base = 20.0
	if not correct_vehicle:
		base += 6.0
	if response_quality == "unsafe":
		base += 6.0
	elif response_quality == "safe":
		base = max(6.0, base - 2.0)
	return base

func _vehicle_name(vehicle_id: String) -> String:
	match _canonical_vehicle_id(vehicle_id):
		"fire_truck":
			return "BFP"
		"ambulance":
			return "MDRRMO"
		"police":
			return "PNP"
		_:
			return "Response Unit"

func _canonical_vehicle_id(vehicle_id: String) -> String:
	var key = vehicle_id.to_lower().strip_edges()
	match key:
		"police_mobile", "police_car", "patrol_car", "police_unit":
			return "police"
		"firetruck", "fire truck":
			return "fire_truck"
		"ems", "emergency_unit", "emergency":
			return "ambulance"
		_:
			return key

func _save_shift_state_to_game_state() -> void:
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("save_shift_progress"):
		var shift_data = {
			"total_score": _total_score,
			"shift_score": _shift_score,
			"calls_completed": _calls_completed,
			"shift_call_reviews": _shift_call_reviews,
			"shift_remaining_s": _shift_remaining_s
		}
		state.call("save_shift_progress", shift_data)

# Public entry-point called by the settings menu's Save & Exit button.
# Persists the current mid-shift state so it can be resumed later.
func serialize_session() -> void:
	_save_shift_state_to_game_state()



func _run_tutorial_ui_demonstration() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		_complete_current_call(true, true, "Units arrived and secured the scene. Call closed.")
		return
		
	if _tutorial_panel:
		_tutorial_panel.visible = false
		
	# Skip the blank 'X' clicking step and instantly transition to evaluation.
	_on_close_call_panel()
	if _minimized_call_button:
		_minimized_call_button.hide()
		
	_hide_coach_pointer()
	
	if _toggle_hud_button:
		_toggle_hud_button.visible = true
		_show_tutorial_focus(_toggle_hud_button)
		_point_coach_at(_toggle_hud_button, "Click the Information button to open it.")
		await _toggle_hud_button.pressed
		
		if _hud_panel and _hint_label:
			_show_tutorial_focus(_hint_label)
			_point_coach_at(_hint_label, "Click the tips box to show a different tip.")
			var old_index = _tip_index
			while _tip_index == old_index:
				await get_tree().process_frame
				
	var settings_btn: Button = get_node_or_null("CanvasLayer/SettingsButton")
	if settings_btn:
		_show_tutorial_focus(settings_btn)
		_point_coach_at(settings_btn, "Click Settings to change language and game settings.")
		# Wait for the player to press the settings button
		await settings_btn.pressed
		_hide_coach_pointer()
		_hide_tutorial_focus()
		
		# Give a frame so _on_home_pressed runs and adds the menu
		await get_tree().process_frame
		
		# Find the settings menu and run the in-menu tutorial (which runs with PROCESS_MODE_ALWAYS)
		# The menu's run_tutorial() will close the menu when done, emitting 'closed'
		var settings_menu_node: Node = null
		if canvas:
			for child in canvas.get_children():
				if child.has_method("run_tutorial"):
					settings_menu_node = child
					break
		
		if settings_menu_node:
			# Temporarily set this node to always process so we can await the closed signal while tree is paused
			var old_process_mode = process_mode
			process_mode = Node.PROCESS_MODE_ALWAYS
			settings_menu_node.run_tutorial()
			# The menu emits 'closed' then queue_frees and unpauses the tree
			await settings_menu_node.closed
			process_mode = old_process_mode
		else:
			# Fallback: just wait for unpause
			var old_process_mode = process_mode
			process_mode = Node.PROCESS_MODE_ALWAYS
			while get_tree().paused:
				await get_tree().process_frame
			process_mode = old_process_mode
		
		# Give frames for clean-up
		await get_tree().process_frame
		await get_tree().process_frame
	
	_hide_coach_pointer()

	var original_score = _total_score
	var original_shift_score = _shift_score
	_shift_score = shift_min_score
	_total_score = max(_total_score, shift_min_score)
	if _score_label:
		_score_label.text = "Score: %d" % _total_score
	_update_shift_ui()
	
	_show_shift_review("Shift Review (Tutorial)", "This screen appears when you end your shift to evaluate your performance.", "tutorial_demo", true)
	
	if _shift_review_dialog:
		var ok_btn = _shift_review_dialog.get_ok_button()
		if ok_btn:
			await get_tree().process_frame
			await get_tree().process_frame
			_show_tutorial_focus(ok_btn)
			_point_coach_at(ok_btn, "Click the OK button to proceed.")
		await _shift_review_dialog.confirmed
		
	# Cleanup
	_hide_coach_pointer()
	_hide_tutorial_focus()
	if _tutorial_panel:
		_tutorial_panel.queue_free()
		_tutorial_panel = null
	
	_shift_score = original_shift_score
	_total_score = original_score
	if _score_label:
		_score_label.text = "Score: %d" % _total_score
	_update_shift_ui()
	if _shift_review_dialog:
		_shift_review_dialog.hide()
		
	_complete_current_call(true, true, "Units arrived and secured the scene. Call closed.")

func _get_scenario_options() -> Array:
	if _active_call.is_empty(): return []
	var transcript: Array = _active_call.get("transcript", [])
	if transcript.is_empty() and _active_call.has("transcript_en"):
		transcript = _active_call.get("transcript_en", [])
	for i in range(transcript.size() - 1, -1, -1):
		var item = transcript[i]
		if typeof(item) == TYPE_DICTIONARY and item.has("options"):
			var spk = String(item.get("speaker", "")).to_lower()
			if spk == "911" or spk == "dispatcher" or spk == "operator":
				return item.get("options", [])
	return _active_call.get("options", [])

func _clean_option_text_for_normal_mode(text: String) -> String:
	var lower = text.to_lower()
	var stripped = text
	
	# English prefixes
	var en_prefixes = [
		"i am sending help right away. ",
		"i am sending help. ",
		"i will send someone. ",
		"i am sending an ambulance. "
	]
	for p in en_prefixes:
		if lower.begins_with(p):
			stripped = text.substr(p.length()).strip_edges()
			lower = stripped.to_lower()
	
	# Tagalog prefixes
	var tl_prefixes = [
		"padating na po ang tulong. "
	]
	for p in tl_prefixes:
		if lower.begins_with(p):
			stripped = text.substr(p.length()).strip_edges()
			lower = stripped.to_lower()
			
	# Cleanup any leftover dots or spaces - fallback to original text if empty
	if stripped.strip_edges() == "" or stripped == "." or stripped == ".." or stripped == "...":
		stripped = text.strip_edges()
		
	# Capitalize first letter if needed
	if stripped.length() > 0:
		stripped = stripped.left(1).to_upper() + stripped.substr(1)
		
	return stripped

func _get_scenario_bad_texts(fallback_defaults: Array) -> Array:
	var bad = []
	var scenario_opts: Array = _get_scenario_options()
	for opt in scenario_opts:
		if typeof(opt) == TYPE_DICTIONARY and String(opt.get("label", "")).to_lower() == "unsafe":
			var text = String(opt.get("text", "")).strip_edges()
			text = _clean_option_text_for_normal_mode(text)
			if text != "":
				bad.append(text)
	
	if bad.size() == 0:
		bad = fallback_defaults.duplicate()
	
	bad.shuffle()
	return bad

func _trim_region(tex: Texture2D, region: Rect2) -> Rect2:
	if not tex: return region
	var img = tex.get_image()
	if not img: return region
	var region_img = img.get_region(region)
	var used = region_img.get_used_rect()
	if used.size == Vector2i.ZERO: return region
	return Rect2(region.position.x + used.position.x, region.position.y + used.position.y, used.size.x, used.size.y)

func _layout_choice_buttons(buttons: Array) -> void:
	if _choices_box == null: return
	for c in _choices_box.get_children():
		c.queue_free()
		
	var count = buttons.size()
	if count == 0: return

	var row1 = HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 10)
	_choices_box.add_child(row1)

	var row2 = null
	if count > 2:
		row2 = HBoxContainer.new()
		row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_theme_constant_override("separation", 10)
		_choices_box.add_child(row2)

	for i in range(count):
		var btn = buttons[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 60)
		
		if count <= 2:
			row1.add_child(btn)
		elif count == 3:
			if i < 2:
				row1.add_child(btn)
			else:
				var spacer_left = Control.new()
				spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var spacer_right = Control.new()
				spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row2.add_child(spacer_left)
				row2.add_child(btn)
				btn.size_flags_stretch_ratio = 2.0
				row2.add_child(spacer_right)
		else:
			if i < 2:
				row1.add_child(btn)
			else:
				row2.add_child(btn)

		_animate_choice_button_attention(btn, i)

func _on_skip_tutorial_pressed() -> void:
	var state = get_node_or_null("/root/GameState")
	if state:
		if state.has_method("set_first_live_call_done"):
			state.call("set_first_live_call_done")
		state.call("complete_tutorial")
		state.call("select_mode", "easy_multiple_choice")
		if state.has_method("set_force_tutorial"):
			state.call("set_force_tutorial", false)
	_is_interactive_tutorial = false
	_hide_coach_pointer()
	_hide_tutorial_focus()
	if _tutorial_panel:
		_tutorial_panel.queue_free()
		_tutorial_panel = null
	get_tree().paused = false
	
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_ring"):
		am.stop_ring()
		
	get_tree().reload_current_scene()

# ── Developer Diagnostic Testing Commands ─────────────────────────────────────

func dev_finish_call() -> Dictionary:
	# 1. If no call is currently active, activate pending, queued, or generate a fresh one
	if _active_call.is_empty():
		if not _pending_call.is_empty():
			_active_call = _pending_call.duplicate(true)
			_pending_call.clear()
			_call_sequence += 1
		elif not _queued_calls.is_empty():
			_active_call = _queued_calls.pop_front().duplicate(true)
			_call_sequence += 1
		else:
			var gen = _generate_call_scenario()
			_active_call = gen.duplicate(true)
			_call_sequence += 1
		_on_answer_call_pressed()
	_call_active = true

	if _active_call.is_empty():
		return {
			"event": "dev_finish_call",
			"command": "finish_call",
			"day": _current_day,
			"call_score": 0,
			"persistent_total_score": _total_score,
			"shift_score": _shift_score,
			"calls_completed": _calls_completed,
			"max_calls": _max_calls_per_shift(),
			"success": false,
			"error": "Failed to activate emergency call"
		}

	# 2. Simulate correct/safe dialogue decision through existing scoring path
	var options: Array = _get_scenario_options()
	var safe_choice: Dictionary = {}
	for opt in options:
		if typeof(opt) == TYPE_DICTIONARY:
			var q = String(opt.get("quality", opt.get("label", ""))).to_lower()
			if q == "safe" or bool(opt.get("is_safe", false)) or bool(opt.get("correct", false)):
				safe_choice = opt
				break
	if safe_choice.is_empty() and options.size() > 0 and typeof(options[0]) == TYPE_DICTIONARY:
		safe_choice = options[0]

	var safe_text = String(safe_choice.get("text", "Remain calm, emergency responders are on the way."))
	var safe_expl = String(safe_choice.get("feedback", safe_choice.get("explanation", "Safe and effective response.")))

	# Update BKT mastery on correct choice
	var dp_skill = String(_current_dp_context.get("skill", SafeScapeScenarioSkillMapper.determine_skill(_active_call)))
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("update_bkt_mastery"):
		var telemetry = {
			"decision_point": _num_interactive_choices_answered + 1,
			"first_attempt_correct": true,
			"total_attempts": 1,
			"mistakes_count": 0,
			"final_attempt_correct": true,
			"options_presented": _current_dp_context.get("options_presented", 3),
			"dda_level": _current_dp_context.get("dda_level", "EASY"),
			"scenario_id": _current_dp_context.get("scenario_id", _active_call.get("template_id", "scenario_001")),
			"category": _current_dp_context.get("category", _active_call.get("type", "fire")),
			"recommended_vehicle": String(_active_call.get("recommended_vehicle", ""))
		}
		state.call("update_bkt_mastery", dp_skill, true, telemetry)

	_player_responded_this_round = true
	_append_transcript_line("Dispatcher", safe_text)
	_record_response_review(safe_text, "safe", safe_expl, options)
	_score_and_show_feedback("safe", safe_text, safe_expl)
	if _feedback_dialog:
		_feedback_dialog.hide()
	_feedback_popup_context = "response"
	_on_feedback_popup_closed()

	# 3. Simulate correct unit dispatch through existing dispatch path
	var rec_vehicle = ""
	var rec_list: Array = _active_call.get("recommended_units", [])
	if rec_list.size() > 0:
		rec_vehicle = _canonical_vehicle_id(String(rec_list[0]))
	elif _active_call.has("recommended_vehicle"):
		var rec_raw = _active_call.get("recommended_vehicle")
		if typeof(rec_raw) == TYPE_ARRAY and rec_raw.size() > 0:
			rec_vehicle = _canonical_vehicle_id(String(rec_raw[0]))
		else:
			rec_vehicle = _canonical_vehicle_id(String(rec_raw).split(",")[0].strip_edges())
	
	if rec_vehicle == "" or not (rec_vehicle in ["fire_truck", "ambulance", "police"]):
		var inc_type = String(_active_call.get("type", "fire")).to_lower()
		if inc_type == "fire":
			rec_vehicle = "fire_truck"
		elif inc_type == "medical":
			rec_vehicle = "ambulance"
		else:
			rec_vehicle = "police"

	_dispatch_phase_unlocked = true
	_has_dispatched_vehicle = false
	_call_active = true
	_on_vehicle_button_pressed(rec_vehicle)
	if _feedback_dialog:
		_feedback_dialog.hide()

	# 4. Simulate fast response for speed bonus and complete call through standard path
	_call_start_time = (Time.get_ticks_msec() / 1000.0) - 2.0
	_complete_current_call(true, false, "Units arrived on scene. Incident resolved successfully via finish_call dev command.")

	# 5. Clean up UI overlays
	if _dispatch_panel:
		_dispatch_panel.visible = false
	if _dim_overlay:
		_dim_overlay.visible = false

	var record = {
		"event": "dev_finish_call",
		"command": "finish_call",
		"day": _current_day,
		"call_score": _call_score,
		"persistent_total_score": _total_score,
		"shift_score": _shift_score,
		"calls_completed": _calls_completed,
		"max_calls": _max_calls_per_shift(),
		"success": true
	}
	return record

func dev_end_shift() -> Dictionary:
	var day_before = _current_day
	var state = get_node_or_null("/root/GameState")

	# 1. Stop active timers
	if _shift_timer:
		_shift_timer.stop()
	if _next_call_timer:
		_next_call_timer.stop()

	# 2. Clear call queues and active calls
	_queued_calls.clear()
	_pending_call.clear()
	_active_call.clear()
	_call_active = false
	if _dispatch_panel:
		_dispatch_panel.visible = false
	if _dim_overlay:
		_dim_overlay.visible = false
	if _feedback_dialog:
		_feedback_dialog.hide()
	if _shift_review_dialog:
		_shift_review_dialog.hide()

	# 3. Ensure shift qualification is satisfied for developer shortcut advancement
	_shift_score = max(_shift_score, shift_min_score)

	# 4. Advance shift using existing progression mechanism
	if state and state.has_method("record_shift_result"):
		state.call("record_shift_result", _shift_score, _calls_completed)
		if state.has_method("log_shift_summary"):
			state.call("log_shift_summary", _shift_score, _calls_completed)

	if state and state.has_method("clear_shift_progress"):
		state.call("clear_shift_progress")

	var day_after = state.call("get_current_day") if state and state.has_method("get_current_day") else day_before + 1
	var persistent_score = state.call("get_persistent_score") if state and state.has_method("get_persistent_score") else _total_score

	var record = {
		"event": "dev_end_shift",
		"command": "end_shift",
		"day_before": day_before,
		"day_after": day_after,
		"persistent_total_score": persistent_score,
		"shift_score_after": 0,
		"success": true
	}

	# 5. Reload scene to start the new day cleanly
	get_tree().reload_current_scene()

	return record
