extends CanvasLayer

signal text_changed(new_text: String)
signal submit_pressed()
signal hide_requested()

var _abc_container: VBoxContainer
var _symbols_container: VBoxContainer
var _is_shifted: bool = false
var _letter_buttons: Array = []
var _outer_margin: MarginContainer
var _text_input: LineEdit

# Backspace logic
var _backspace_held: bool = false
var _backspace_timer: Timer

# Spacebar scrub logic
var _is_dragging_space: bool = false
var _drag_start_x: float = 0.0
var _drag_start_caret: int = 0
var _did_drag_space: bool = false

const _FONT_PATH := "res://assets/Fonts/VCR_OSD_MONO_1.001.ttf"
const KEY_HEIGHT := 85
const FONT_SIZE := 32

func _init() -> void:
	layer = 100
	visible = false

func _ready() -> void:
	# ── Invisible background button to catch clicks outside keyboard ──────
	var bg_click = Button.new()
	bg_click.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_click.flat = true
	bg_click.focus_mode = Control.FOCUS_NONE
	bg_click.pressed.connect(func(): hide_requested.emit())
	add_child(bg_click)

	# ── Full screen root container that aligns children to the bottom ──────
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_END
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_backspace_timer = Timer.new()
	_backspace_timer.one_shot = true
	_backspace_timer.timeout.connect(_on_backspace_timeout)
	add_child(_backspace_timer)

	# ── Outer margin for the actual keyboard & top bar ──────────────
	_outer_margin = MarginContainer.new()
	_outer_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	_outer_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer_margin.add_theme_constant_override("margin_left", 0)
	_outer_margin.add_theme_constant_override("margin_right", 0)
	_outer_margin.add_theme_constant_override("margin_bottom", 0)
	_outer_margin.add_theme_constant_override("margin_top", 0)
	root.add_child(_outer_margin)

	# ── Dark background (Gboard style dark theme) ──────────────────────────
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.15, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outer_margin.add_child(bg)

	# ── Vertical layout for Top Bar + Keyboard Keys ────────────────────────
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_outer_margin.add_child(main_vbox)

	# ── Top Bar (Text Input + Hide Button) ─────────────────────────────────
	var top_bar_margin = MarginContainer.new()
	top_bar_margin.add_theme_constant_override("margin_left", 12)
	top_bar_margin.add_theme_constant_override("margin_right", 12)
	top_bar_margin.add_theme_constant_override("margin_top", 12)
	top_bar_margin.add_theme_constant_override("margin_bottom", 12)
	main_vbox.add_child(top_bar_margin)

	var top_bar_hbox = HBoxContainer.new()
	top_bar_hbox.add_theme_constant_override("separation", 12)
	top_bar_margin.add_child(top_bar_hbox)

	_text_input = LineEdit.new()
	_text_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_input.custom_minimum_size = Vector2(0, 60)
	_text_input.add_theme_font_size_override("font_size", FONT_SIZE)
	_text_input.placeholder_text = "Type your response..."
	# Disable native keyboard for this box too, since we are using our own keys
	_text_input.virtual_keyboard_enabled = false
	_text_input.focus_mode = Control.FOCUS_NONE 
	
	var text_style = StyleBoxFlat.new()
	text_style.bg_color = Color(0.18, 0.20, 0.22, 1.0)
	text_style.corner_radius_top_left = 6
	text_style.corner_radius_top_right = 6
	text_style.corner_radius_bottom_left = 6
	text_style.corner_radius_bottom_right = 6
	_text_input.add_theme_stylebox_override("normal", text_style)
	_text_input.add_theme_stylebox_override("focus", text_style)
	_text_input.add_theme_stylebox_override("read_only", text_style)
	top_bar_hbox.add_child(_text_input)

	# ── Invisible overlay to permanently block native mobile keyboard ──────
	var tap_overlay = Button.new()
	tap_overlay.flat = true
	tap_overlay.focus_mode = Control.FOCUS_NONE
	tap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_input.add_child(tap_overlay)

	var hide_btn = Button.new()
	hide_btn.text = "Hide ▼"
	hide_btn.custom_minimum_size = Vector2(100, 60)
	hide_btn.add_theme_font_size_override("font_size", 24)
	hide_btn.focus_mode = Control.FOCUS_NONE
	_style_action_btn(hide_btn, Color(0.20, 0.22, 0.24, 1.0))
	hide_btn.pressed.connect(func(): hide_requested.emit())
	top_bar_hbox.add_child(hide_btn)

	# ── Inner padding for key rows ─────────────────────────────────────────
	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 8)
	inner_margin.add_theme_constant_override("margin_right", 8)
	inner_margin.add_theme_constant_override("margin_top", 0)
	inner_margin.add_theme_constant_override("margin_bottom", 24)
	main_vbox.add_child(inner_margin)

	# ── ABC keyboard tab ───────────────────────────────────────────────────
	_abc_container = VBoxContainer.new()
	_abc_container.add_theme_constant_override("separation", 8)
	inner_margin.add_child(_abc_container)

	# ── Symbols keyboard tab (hidden by default) ───────────────────────────
	_symbols_container = VBoxContainer.new()
	_symbols_container.add_theme_constant_override("separation", 8)
	_symbols_container.visible = false
	inner_margin.add_child(_symbols_container)

	_build_abc_layout()
	_build_symbols_layout()

func get_keyboard_height() -> float:
	if _outer_margin:
		return _outer_margin.size.y
	return 0.0

func set_text(text: String) -> void:
	if _text_input:
		_text_input.text = text
		_text_input.caret_column = text.length()

# ── Button factory ─────────────────────────────────────────────────────────
func _create_btn(label_text: String) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, KEY_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var font = load(_FONT_PATH)
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.25, 0.26, 0.28, 1.0) # Medium grey
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var pressed_sb = normal.duplicate()
	pressed_sb.bg_color = Color(0.35, 0.36, 0.38, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	var hover_sb = normal.duplicate()
	hover_sb.bg_color = Color(0.30, 0.31, 0.33, 1.0)
	btn.add_theme_stylebox_override("hover", hover_sb)

	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))

	return btn

func _style_action_btn(btn: Button, normal_color: Color) -> void:
	var sb = btn.get_theme_stylebox("normal").duplicate()
	sb.bg_color = normal_color
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb = sb.duplicate()
	hover_sb.bg_color = normal_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_sb)
	var pressed_sb = sb.duplicate()
	pressed_sb.bg_color = normal_color.lightened(0.3)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

# ── ABC layout ─────────────────────────────────────────────────────────────
func _build_abc_layout() -> void:
	var rows = [
		["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
		["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
		["a", "s", "d", "f", "g", "h", "j", "k", "l"],
		["Shift", "z", "x", "c", "v", "b", "n", "m", "Bksp"],
		["?123", ",", "Space", ".", "Enter"]
	]
	
	var action_color = Color(0.18, 0.20, 0.22, 1.0)
	var enter_color = Color(0.10, 0.45, 0.90, 1.0)
	
	for row_keys in rows:
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 6)
		_abc_container.add_child(hbox)
		for key in row_keys:
			var btn = _create_btn(key)
			if key == "Space":
				btn.size_flags_stretch_ratio = 4.0
				btn.text = "English"
			elif key in ["Shift", "Bksp", "?123"]:
				btn.size_flags_stretch_ratio = 1.4
				_style_action_btn(btn, action_color)
			elif key == "Enter":
				btn.size_flags_stretch_ratio = 1.4
				_style_action_btn(btn, enter_color)
				
			if key.length() == 1 and key != key.to_upper():
				_letter_buttons.append(btn)
			
			if key == "Bksp":
				btn.button_down.connect(_on_backspace_down)
				btn.button_up.connect(_on_backspace_up)
			elif key == "Space":
				btn.gui_input.connect(_on_space_gui_input)
				btn.pressed.connect(func():
					if not _did_drag_space:
						_on_key_pressed("Space")
				)
			else:
				btn.pressed.connect(_on_key_pressed.bind(key))
				
			hbox.add_child(btn)

# ── Symbols layout ─────────────────────────────────────────────────────────
func _build_symbols_layout() -> void:
	var rows = [
		["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
		["@", "#", "$", "_", "&", "-", "+", "(", ")", "/"],
		["=", "\\", "<", "*", "\"", "'", ":", ";", "!", "?", "Bksp"],
		["ABC", ",", "Space", ".", "Enter"]
	]
	
	var action_color = Color(0.18, 0.20, 0.22, 1.0)
	var enter_color = Color(0.10, 0.45, 0.90, 1.0)
	
	for row_keys in rows:
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 6)
		_symbols_container.add_child(hbox)
		for key in row_keys:
			var btn = _create_btn(key)
			if key == "Space":
				btn.size_flags_stretch_ratio = 4.0
				btn.text = "English"
			elif key in ["ABC", "Bksp"]:
				btn.size_flags_stretch_ratio = 1.4
				_style_action_btn(btn, action_color)
			elif key == "Enter":
				btn.size_flags_stretch_ratio = 1.4
				_style_action_btn(btn, enter_color)
			if key == "Bksp":
				btn.button_down.connect(_on_backspace_down)
				btn.button_up.connect(_on_backspace_up)
			elif key == "Space":
				btn.gui_input.connect(_on_space_gui_input)
				btn.pressed.connect(func():
					if not _did_drag_space:
						_on_key_pressed("Space")
				)
			else:
				btn.pressed.connect(_on_key_pressed.bind(key))
			hbox.add_child(btn)

# ── Key handler ────────────────────────────────────────────────────────────
func _on_key_pressed(key: String) -> void:
	if not _text_input:
		return
		
	var t = _text_input.text
	
	match key:
		"Shift":
			_is_shifted = !_is_shifted
			for btn in _letter_buttons:
				btn.text = btn.text.to_upper() if _is_shifted else btn.text.to_lower()
		"Bksp":
			if t.length() > 0:
				var c = _text_input.caret_column
				if c > 0:
					_text_input.text = t.substr(0, c - 1) + t.substr(c)
					_text_input.caret_column = c - 1
					text_changed.emit(_text_input.text)

		"?123":
			_abc_container.visible = false
			_symbols_container.visible = true
		"ABC":
			_abc_container.visible = true
			_symbols_container.visible = false
		"Enter":
			submit_pressed.emit()
			hide_requested.emit()
		"Space":
			_text_input.text += " "
			_text_input.caret_column = _text_input.text.length()
			text_changed.emit(_text_input.text)
		_:
			var output := key
			if _is_shifted and output.length() == 1 and output != output.to_upper():
				output = output.to_upper()
				_is_shifted = false
				for btn in _letter_buttons:
					btn.text = btn.text.to_lower()
			
			var c = _text_input.caret_column
			_text_input.text = t.substr(0, c) + output + t.substr(c)
			_text_input.caret_column = c + output.length()
			text_changed.emit(_text_input.text)

# ── New Pro Features ────────────────────────────────────────────────────────
func _on_backspace_down() -> void:
	_on_key_pressed("Bksp")
	_backspace_held = true
	_backspace_timer.start(0.4)

func _on_backspace_up() -> void:
	_backspace_held = false
	_backspace_timer.stop()

func _on_backspace_timeout() -> void:
	if _backspace_held:
		_on_key_pressed("Bksp")
		_backspace_timer.start(0.05)

func _on_space_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging_space = true
			_drag_start_x = event.global_position.x
			if _text_input:
				_drag_start_caret = _text_input.caret_column
			_did_drag_space = false
		else:
			_is_dragging_space = false
	elif (event is InputEventMouseMotion or (event.get_class() == "InputEventScreenDrag")) and _is_dragging_space:
		var dx = event.global_position.x - _drag_start_x
		if abs(dx) > 15:
			_did_drag_space = true
			var chars_to_move = int(dx / 15.0)
			if _text_input:
				var new_caret = _drag_start_caret + chars_to_move
				new_caret = clamp(new_caret, 0, _text_input.text.length())
				_text_input.caret_column = new_caret
