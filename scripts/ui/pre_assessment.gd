extends Control

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

# --- BFP Fire Safety Modules Study & Quiz Data ---
var modules_data: Dictionary = {}

# --- State Variables ---
var _current_screen: String = "hub" # "hub", "study", "quiz"
var _active_module_num: int = 1
var _quiz_q_idx: int = 0
var _quiz_correct_count: int = 0
var _selected_choice: int = -1
var _study_rich_label: RichTextLabel = null
var _hub_scroll: ScrollContainer = null
var _hub_vbox: VBoxContainer = null
var _active_questions: Array = []

# --- UI Nodes ---
@onready var root_vbox: VBoxContainer = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/QuizScroll/VBox
@onready var count_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/QuizScroll/VBox/QuestionCountLabel
@onready var question_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/QuizScroll/VBox/QuestionLabel
@onready var choices_box: VBoxContainer = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/QuizScroll/VBox/ChoicesBox
@onready var feedback_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/QuizScroll/VBox/FeedbackLabel

@onready var back_btn: Button = $CanvasLayer/Root/Margin/Layout/Footer/BackButton
@onready var next_btn: Button = $CanvasLayer/Root/Margin/Layout/Footer/NextButton

func _state() -> Node:
	return get_node_or_null("/root/GameState")

func _ready() -> void:
	var viewport: Viewport = get_viewport()
	if viewport:
		viewport.snap_2d_transforms_to_pixel = true
		viewport.snap_2d_vertices_to_pixel = true
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

	var font: Font = count_label.get_theme_font("font")
	if font is FontFile:
		font.multichannel_signed_distance_field = false
		font.generate_mipmaps = false
	elif font is FontVariation and font.base_font is FontFile:
		font.base_font.multichannel_signed_distance_field = false
		font.base_font.generate_mipmaps = false

	back_btn.pressed.connect(_on_back_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	
	var state = _state()
	var loc = "taglish"
	if state and state.has_method("get_locale"):
		loc = String(state.call("get_locale"))
	_localize_modules_data(loc)

	var body_panel = get_node_or_null("CanvasLayer/Root/Margin/Layout/Body")
	if body_panel:
		var body_style = StyleBoxTexture.new()
		body_style.texture = load("res://assets/ui/pixel/wood_frame.png")
		body_style.texture_margin_left = 24
		body_style.texture_margin_right = 24
		body_style.texture_margin_top = 24
		body_style.texture_margin_bottom = 24
		body_style.content_margin_left = 32
		body_style.content_margin_right = 32
		body_style.content_margin_top = 32
		body_style.content_margin_bottom = 32
		body_panel.add_theme_stylebox_override("panel", body_style)

	for btn in [back_btn, next_btn]:
		if btn:
			btn.custom_minimum_size = Vector2(0, 52)
			btn.add_theme_font_size_override("font_size", 17)
			btn.add_theme_color_override("font_color", Color8(44, 54, 72))
			btn.add_theme_color_override("font_hover_color", Color8(44, 54, 72))
			btn.add_theme_color_override("font_pressed_color", Color8(44, 54, 72))
			btn.add_theme_color_override("font_focus_color", Color8(44, 54, 72))

			var normal = StyleBoxFlat.new()
			normal.bg_color = Color8(255, 205, 104) if btn == back_btn else Color8(92, 195, 255)
			normal.border_width_left = 3
			normal.border_width_top = 3
			normal.border_width_right = 3
			normal.border_width_bottom = 3
			normal.border_color = Color8(44, 54, 72)
			normal.corner_radius_top_left = 0
			normal.corner_radius_top_right = 0
			normal.corner_radius_bottom_left = 0
			normal.corner_radius_bottom_right = 0

			var hover = normal.duplicate()
			hover.bg_color = Color8(255, 219, 135) if btn == back_btn else Color8(117, 210, 255)

			var pressed = hover.duplicate()
			pressed.bg_color = hover.bg_color.darkened(0.1)

			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_stylebox_override("pressed", pressed)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("focus", hover)
		
	_load_hub_screen()

# --- Style helpers ---

## Build a flat-color StyleBoxFlat with the shared card border settings.
## Caller sets .bg_color on the returned object before using it.
func _make_flat_border_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.corner_radius_top_left    = 0
	s.corner_radius_top_right   = 0
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.border_width_left   = 3
	s.border_width_top    = 3
	s.border_width_right  = 3
	s.border_width_bottom = 3
	s.border_color        = Color8(44, 54, 72)
	s.content_margin_left   = 12
	s.content_margin_top    = 8
	s.content_margin_right  = 12
	s.content_margin_bottom = 8
	return s

# --- Screen Loaders ---

func _load_hub_screen() -> void:
	_current_screen = "hub"
	_selected_choice = -1
	_quiz_q_idx = 0
	_quiz_correct_count = 0
	
	if _study_rich_label:
		_study_rich_label.visible = false
		
	choices_box.visible = false
	question_label.visible = true
	
	var state = _state()
	
	count_label.text = state.call("translate", "The Right Call\nEmergency Dispatch Academy") if state else "The Right Call\nEmergency Dispatch Academy"
	
	var completed_count = state.get_completed_modules_count() if state else 0
	
	if completed_count >= 6:
		question_label.text = state.call("translate", "Congratulations! You completed all 6 BFP modules and earned the The Right Call Emergency Dispatch Academy Certification! 🏆\nAll professional difficulty settings and modular scenarios are fully unlocked!") if state else "Congratulations! You completed all 6 BFP modules and earned the The Right Call Emergency Dispatch Academy Certification! 🏆\nAll professional difficulty settings and modular scenarios are fully unlocked!"
		next_btn.text = state.call("translate", "Start Gameplay Tutorial") if state else "Start Gameplay Tutorial"
		next_btn.disabled = false
		next_btn.visible = true
	else:
		question_label.text = state.call("translate", "Pass each module assessment to certify. Every 2 modules finished unlocks a new dispatch difficulty!\nStudy BFP Fire Safety volumes and complete their quizzes below:")
		next_btn.disabled = true
		next_btn.visible = false
	
	# Setup Scroll Container dynamically to avoid screen overflow
	if _hub_scroll == null:
		_hub_scroll = ScrollContainer.new()
		_hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_hub_scroll.custom_minimum_size = Vector2(0, 180)
		_hub_vbox = VBoxContainer.new()
		_hub_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hub_scroll.add_child(_hub_vbox)
		root_vbox.add_child(_hub_scroll)
		# Position scroll container below question label
		root_vbox.move_child(_hub_scroll, 3)
		
	_hub_scroll.visible = true
	_hub_vbox.add_theme_constant_override("separation", 10)
	
	# Clear the scroll vbox children
	for c in _hub_vbox.get_children():
		c.queue_free()
		
	for mod_num in range(1, 7):
		if not modules_data.has(mod_num):
			continue
		var mod_data = modules_data[mod_num]
		var is_passed = state.call("is_module_completed", mod_num) if state else false
		
		# Sequentially unlock: a module is available if it's passed or if it's the next unpassed module
		var is_available = mod_num == 1 or is_passed
		if mod_num > 1 and state:
			is_available = state.call("is_module_completed", mod_num - 1) or is_passed
			
		var card = PanelContainer.new()
		var card_style = _make_flat_border_style()
		if is_passed:
			card_style.bg_color = Color(0.18, 0.45, 0.22, 0.95)  # Passed green
		elif is_available:
			card_style.bg_color = Color(0.14, 0.35, 0.40, 1.0)   # Available teal
		else:
			card_style.bg_color = Color(0.35, 0.38, 0.42, 0.7)   # Locked gray
		card.add_theme_stylebox_override("panel", card_style)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var text_vbox = VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title_lbl = Label.new()
		var status_str = "[ PASSED ✅ ]" if is_passed else ("[ STUDY GUIDE 📖 ]" if is_available else "[ LOCKED 🔒 ]")
		if state:
			status_str = state.call("translate", status_str)
		title_lbl.text = "%s %s" % [mod_data["title"], status_str]
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color.WHITE)
		text_vbox.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = String(mod_data["summary"])
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
		text_vbox.add_child(desc_lbl)
		
		hbox.add_child(text_vbox)
		
		var btn_hbox = HBoxContainer.new()
		
		var study_btn = Button.new()
		study_btn.text = state.call("translate", "Study Guide") if state else "Study Guide"
		study_btn.disabled = not is_available
		study_btn.custom_minimum_size = Vector2(100, 36)
		_style_module_btn(study_btn, is_passed or is_available)
		study_btn.pressed.connect(Callable(self , "_load_study_screen").bind(mod_num))
		btn_hbox.add_child(study_btn)
		
		var quiz_btn = Button.new()
		if is_passed:
			quiz_btn.text = state.call("translate", "Retake Quiz") if state else "Retake Quiz"
			quiz_btn.disabled = not is_available
			_style_module_btn(quiz_btn, is_available)
			quiz_btn.pressed.connect(Callable(self , "_start_quiz").bind(mod_num))
		else:
			quiz_btn.text = state.call("translate", "Take Quiz") if state else "Take Quiz"
			quiz_btn.disabled = not is_available
			_style_module_btn(quiz_btn, is_available)
			quiz_btn.pressed.connect(Callable(self , "_start_quiz").bind(mod_num))
		btn_hbox.add_child(quiz_btn)
		
		hbox.add_child(btn_hbox)
		card.add_child(hbox)
		_hub_vbox.add_child(card)
		
	feedback_label.text = ""
	back_btn.text = state.call("translate", "Exit to Main Menu") if state else "Exit to Main Menu"

func _load_study_screen(mod_num: int) -> void:
	_current_screen = "study"
	_active_module_num = mod_num
	
	if _hub_scroll:
		_hub_scroll.visible = false
	choices_box.visible = false
	
	var mod_data = modules_data[mod_num]
	count_label.text = mod_data["title"]
	question_label.visible = false
	
	if _study_rich_label == null:
		_study_rich_label = RichTextLabel.new()
		_study_rich_label.bbcode_enabled = true
		_study_rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_study_rich_label.fit_content = true
		_study_rich_label.add_theme_color_override("default_color", Color8(44, 54, 72))
		_study_rich_label.add_theme_font_size_override("normal_font_size", 16)
		root_vbox.add_child(_study_rich_label)
		# Position rich label below QuestionCount label
		root_vbox.move_child(_study_rich_label, 2)
		
	_study_rich_label.text = mod_data["study_text"]
	_study_rich_label.visible = true
	
	feedback_label.text = ""
	
	var state = _state()
	back_btn.text = state.call("translate", "Back to Module Hub") if state else "Back to Module Hub"
	
	var is_passed = state.call("is_module_completed", mod_num) if state else false
	if is_passed:
		if mod_num == 5:
			next_btn.text = state.call("translate", "Start Shift") if state else "Start Shift"
		else:
			next_btn.text = state.call("translate", "Return to Hub") if state else "Return to Hub"
		next_btn.disabled = false
		next_btn.visible = true
	else:
		next_btn.text = state.call("translate", "Take Module Quiz") if state else "Take Module Quiz"
		next_btn.disabled = false
		next_btn.visible = true

func _start_quiz(mod_num: int) -> void:
	_active_module_num = mod_num
	_quiz_q_idx = 0
	_quiz_correct_count = 0
	
	if not modules_data.has(mod_num):
		push_error("Module not found: " + str(mod_num))
		return
		
	var mod_data = modules_data[mod_num]
	var original_questions: Array = mod_data["questions"]
	
	# Create a copy of the questions list
	var shuffled_questions = original_questions.duplicate(true)
	shuffled_questions.shuffle()
	
	_active_questions = []
	for q in shuffled_questions:
		var opts: Array = q["options"]
		var correct_ans_idx: int = q["answer"]
		var correct_text = opts[correct_ans_idx]
		
		var opts_copy = opts.duplicate()
		opts_copy.shuffle()
		
		var new_ans_idx = opts_copy.find(correct_text)
		if new_ans_idx == -1:
			new_ans_idx = 0
			
		_active_questions.append({
			"q": q["q"],
			"options": opts_copy,
			"answer": new_ans_idx,
			"hint": q["hint"]
		})
		
	_load_quiz_screen_at_current_index()

func _load_quiz_screen_at_current_index() -> void:
	_current_screen = "quiz"
	_selected_choice = -1
	
	if _hub_scroll:
		_hub_scroll.visible = false
	if _study_rich_label:
		_study_rich_label.visible = false
		
	choices_box.visible = true
	
	var mod_data = modules_data[_active_module_num]
	var q_data = _active_questions[_quiz_q_idx]
	
	var state = _state()
	var total_q = _active_questions.size()
	if state:
		var q_tpl = state.call("translate", " - Question %d of %d")
		count_label.text = String(mod_data["title"]) + (q_tpl % [_quiz_q_idx + 1, total_q])
	else:
		count_label.text = "%s - Question %d of %d" % [mod_data["title"], _quiz_q_idx + 1, total_q]
		
	question_label.text = q_data["q"]
	question_label.visible = true
	
	# Clear choices box and render options
	for c in choices_box.get_children():
		c.queue_free()
		
	var i = 0
	for opt in q_data["options"]:
		var btn = Button.new()
		btn.text = opt
		btn.custom_minimum_size = Vector2(0, 42)
		
		# Adding basic multiple choice styling
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.35, 0.40, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color8(44, 54, 72)
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		
		var hover = style.duplicate()
		hover.bg_color = Color(0.2, 0.45, 0.50, 1.0)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("focus", hover)
		
		btn.pressed.connect(Callable(self , "_on_choice_selected").bind(i))
		choices_box.add_child(btn)
		i += 1
		
	feedback_label.text = ""
	back_btn.text = state.call("translate", "Exit Quiz (Lose Progress)") if state else "Exit Quiz (Lose Progress)"
	next_btn.text = state.call("translate", "Next Question") if state else "Next Question"
	next_btn.disabled = true
	next_btn.visible = true

# --- Button Handlers ---

func _on_choice_selected(choice_idx: int) -> void:
	_selected_choice = choice_idx
	var q_data = _active_questions[_quiz_q_idx]
	var state = _state()
	
	# Lock choice buttons
	for i in range(choices_box.get_child_count()):
		choices_box.get_child(i).disabled = true
		
	if choice_idx == q_data["answer"]:
		_quiz_correct_count += 1
		
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.1, 0.6, 0.1, 1.0)
		style_bg.content_margin_left = 12
		style_bg.content_margin_right = 12
		style_bg.content_margin_top = 12
		style_bg.content_margin_bottom = 12
		feedback_label.add_theme_stylebox_override("normal", style_bg)
		feedback_label.add_theme_color_override("font_color", Color.WHITE)
		var prefix = state.call("translate", "Correct! ") if state else "Correct! "
		feedback_label.text = prefix + String(q_data["hint"])
		
		var original_scale: Vector2 = feedback_label.scale
		feedback_label.pivot_offset = feedback_label.size / 2.0
		var fw_tween: Tween = feedback_label.create_tween()
		fw_tween.tween_property(feedback_label, "scale", original_scale * 1.15, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fw_tween.tween_property(feedback_label, "scale", original_scale, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		# Color selected button green
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 0.2, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color8(44, 54, 72)
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		choices_box.get_child(choice_idx).add_theme_stylebox_override("disabled", style)
		
		var target_btn = choices_box.get_child(choice_idx)
		target_btn.add_theme_color_override("font_color", Color.GREEN)
		target_btn.add_theme_color_override("font_disabled_color", Color.GREEN)
		
		# Pop Effect Juice
		var btn_original_scale: Vector2 = target_btn.scale
		target_btn.pivot_offset = target_btn.size / 2.0
		var tween: Tween = target_btn.create_tween()
		tween.tween_property(target_btn, "scale", btn_original_scale * 1.15, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target_btn, "scale", btn_original_scale, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.7, 0.1, 0.1, 1.0)
		style_bg.content_margin_left = 12
		style_bg.content_margin_right = 12
		style_bg.content_margin_top = 12
		style_bg.content_margin_bottom = 12
		feedback_label.add_theme_stylebox_override("normal", style_bg)
		feedback_label.add_theme_color_override("font_color", Color.WHITE)
		var prefix = state.call("translate", "Incorrect! Remember: ") if state else "Incorrect! Remember: "
		feedback_label.text = prefix + String(q_data["hint"])
		
		var original_pos: Vector2 = feedback_label.position
		var fw_tween: Tween = feedback_label.create_tween()
		var shake_offset: float = 12.0
		var duration: float = 0.05
		fw_tween.tween_property(feedback_label, "position:x", original_pos.x - shake_offset, duration)
		fw_tween.tween_property(feedback_label, "position:x", original_pos.x + shake_offset, duration)
		fw_tween.tween_property(feedback_label, "position:x", original_pos.x - (shake_offset / 2.0), duration)
		fw_tween.tween_property(feedback_label, "position:x", original_pos.x + (shake_offset / 2.0), duration)
		fw_tween.tween_property(feedback_label, "position:x", original_pos.x, duration)
		
		# Color selected button red and correct button green
		var style_red = StyleBoxFlat.new()
		style_red.bg_color = Color(0.7, 0.2, 0.2, 1.0)
		style_red.border_width_left = 2
		style_red.border_width_top = 2
		style_red.border_width_right = 2
		style_red.border_width_bottom = 2
		style_red.border_color = Color8(44, 54, 72)
		style_red.corner_radius_top_left = 0
		style_red.corner_radius_top_right = 0
		style_red.corner_radius_bottom_left = 0
		style_red.corner_radius_bottom_right = 0
		choices_box.get_child(choice_idx).add_theme_stylebox_override("disabled", style_red)
		
		var target_btn = choices_box.get_child(choice_idx)
		target_btn.add_theme_color_override("font_color", Color.RED)
		target_btn.add_theme_color_override("font_disabled_color", Color.RED)
		
		# Shake Effect Juice
		var btn_original_pos: Vector2 = target_btn.position
		var btn_tween: Tween = target_btn.create_tween()
		var btn_shake_offset: float = 8.0
		var btn_duration: float = 0.05
		btn_tween.tween_property(target_btn, "position:x", btn_original_pos.x - btn_shake_offset, btn_duration)
		btn_tween.tween_property(target_btn, "position:x", btn_original_pos.x + btn_shake_offset, btn_duration)
		btn_tween.tween_property(target_btn, "position:x", btn_original_pos.x - (btn_shake_offset / 2.0), btn_duration)
		btn_tween.tween_property(target_btn, "position:x", btn_original_pos.x + (btn_shake_offset / 2.0), btn_duration)
		btn_tween.tween_property(target_btn, "position:x", btn_original_pos.x, btn_duration)
		
		var style_green = StyleBoxFlat.new()
		style_green.bg_color = Color(0.2, 0.6, 0.2, 1.0)
		style_green.border_width_left = 2
		style_green.border_width_top = 2
		style_green.border_width_right = 2
		style_green.border_width_bottom = 2
		style_green.border_color = Color8(44, 54, 72)
		style_green.corner_radius_top_left = 0
		style_green.corner_radius_top_right = 0
		style_green.corner_radius_bottom_left = 0
		style_green.corner_radius_bottom_right = 0
		choices_box.get_child(q_data["answer"]).add_theme_stylebox_override("disabled", style_green)

	# If last question, adjust Next Button text
	var total_q = _active_questions.size()
	if _quiz_q_idx == total_q - 1:
		if _quiz_correct_count >= 8:
			if _active_module_num == 5:
				next_btn.text = state.call("translate", "Pass Module! Start Shift") if state else "Pass Module! Start Shift"
			else:
				next_btn.text = state.call("translate", "Pass Module! Return to Hub") if state else "Pass Module! Return to Hub"
		else:
			next_btn.text = state.call("translate", "Quiz Failed (%d/10). Retry Module") % [_quiz_correct_count] if state else "Quiz Failed (%d/10). Retry Module" % [_quiz_correct_count]
			
	next_btn.disabled = false

func _on_next_pressed() -> void:
	if _current_screen == "hub":
		var state = _state()
		var completed_count = state.get_completed_modules_count() if state else 0
		if completed_count >= 6:
			# Direct to tutorial!
			get_tree().change_scene_to_file("res://scenes/maps/route_scene.tscn")
		else:
			# Skip quizzes / complete all modules!
			if state:
				for m_num in range(1, 7):
					state.complete_module(m_num)
			_load_hub_screen()
	elif _current_screen == "study":
		var state = _state()
		var is_passed = state.call("is_module_completed", _active_module_num) if state else false
		if is_passed:
			if _active_module_num == 5:
				get_tree().change_scene_to_file("res://scenes/maps/route_scene.tscn")
				return
			_load_hub_screen()
		else:
			_start_quiz(_active_module_num)
	elif _current_screen == "quiz":
		var total_q = _active_questions.size()
		if _quiz_q_idx < total_q - 1:
			_quiz_q_idx += 1
			_load_quiz_screen_at_current_index()
		else:
			# Quiz is finished!
			if _quiz_correct_count >= 8:
				var state = _state()
				if state:
					state.call("complete_module", _active_module_num)
					
					# Initialize BKT priors based on quiz scores
					var category = "fire"
					if _active_module_num == 3 or _active_module_num == 4:
						category = "medical"
					elif _active_module_num == 6:
						category = "criminal"
					
					var score_ratio = float(_quiz_correct_count) / 10.0
					if state.has_method("init_bkt_prior"):
						state.call("init_bkt_prior", category, score_ratio)
					
					if _active_module_num == 5:
						get_tree().change_scene_to_file("res://scenes/maps/route_scene.tscn")
						return
					_load_hub_screen()
			else:
				# Failed and retrying
				_start_quiz(_active_module_num)

func _on_back_pressed() -> void:
	if _current_screen == "hub":
		get_tree().change_scene_to_file(MENU_SCENE)
	elif _current_screen == "study":
		_load_hub_screen()
	elif _current_screen == "quiz":
		_load_hub_screen()

# --- Styling Helpers ---

func _style_module_btn(btn: Button, active: bool) -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color8(44, 54, 72)
	
	if active:
		style.bg_color = Color8(255, 174, 66) # Soft orange
		btn.add_theme_color_override("font_color", Color8(44, 54, 72))
		btn.add_theme_color_override("font_hover_color", Color8(44, 54, 72))
		btn.add_theme_color_override("font_pressed_color", Color8(44, 54, 72))
		btn.add_theme_color_override("font_focus_color", Color8(44, 54, 72))
	else:
		style.bg_color = Color(0.5, 0.5, 0.5, 0.5)
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.8))
		btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.8))
		btn.add_theme_color_override("font_focus_color", Color(0.8, 0.8, 0.8))
		
	btn.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	if active:
		hover.bg_color = Color8(255, 193, 96) # Lighter orange
	else:
		hover.bg_color = Color(0.55, 0.55, 0.55, 0.5)
	
	var pressed = hover.duplicate()
	pressed.bg_color = hover.bg_color.darkened(0.1)

	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _localize_modules_data(loc: String) -> void:
	var path := "res://data/gameplay/bfp_modules.json"
	if not FileAccess.file_exists(path):
		push_error("BFP modules JSON file not found: " + path)
		return
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read BFP modules JSON file: " + path)
		return
		
	var json_text := file.get_as_text()
	file.close()
	
	var raw_data = JSON.parse_string(json_text)
	if not (raw_data is Dictionary):
		push_error("Invalid JSON format in BFP modules file")
		return
		
	modules_data.clear()
	for k in raw_data.keys():
		var mod_num = int(k)
		var raw_mod = raw_data[k]
		
		# Helper inline to fetch localized value
		var title_str = _get_loc_val(raw_mod.get("title", {}), loc)
		var summary_str = _get_loc_val(raw_mod.get("summary", {}), loc)
		var study_text_str = _get_loc_val(raw_mod.get("study_text", {}), loc)
		
		var raw_questions = raw_mod.get("questions", {})
		var q_list = []
		if raw_questions is Dictionary:
			if raw_questions.has(loc):
				q_list = raw_questions[loc]
			elif raw_questions.has("en"):
				q_list = raw_questions["en"]
			elif raw_questions.keys().size() > 0:
				q_list = raw_questions[raw_questions.keys()[0]]
		elif raw_questions is Array:
			q_list = raw_questions
			
		var final_questions = []
		for q_item in q_list:
			final_questions.append({
				"q": q_item.get("q", ""),
				"options": q_item.get("options", []),
				"answer": int(q_item.get("answer", 0)),
				"hint": q_item.get("hint", "")
			})
			
		modules_data[mod_num] = {
			"title": title_str,
			"summary": summary_str,
			"study_text": study_text_str,
			"questions": final_questions
		}

func _get_loc_val(dict: Variant, loc: String) -> String:
	if not (dict is Dictionary):
		return String(dict)
	if dict.has(loc):
		return String(dict[loc])
	if dict.has("en"):
		return String(dict["en"])
	if dict.keys().size() > 0:
		return String(dict[dict.keys()[0]])
	return ""
