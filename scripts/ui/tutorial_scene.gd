extends Control

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ROUTE_SCENE_NEW := "res://scenes/maps/route_scene_temp.tscn"
const ROUTE_SCENE_LEGACY := "res://scenes/maps/route_scene.tscn"

func _get_route_scene() -> String:
	var state = get_node_or_null("/root/GameState")
	if state and state.has_method("get_use_legacy_map"):
		if state.call("get_use_legacy_map"):
			return ROUTE_SCENE_LEGACY
	return ROUTE_SCENE_NEW
const THEME_BG := Color8(255, 244, 229)
const TEXT_DARK := Color8(44, 54, 72)

var _steps: Array = []
var _index: int = 0
var _cached_state: Node = null  # Cached at _ready; avoids repeated tree lookups

var tutorial_translations: Dictionary = {
	"tl": {
		"academy_title": "BFP Sta. Cruz Emergency Dispatch Academy",
		"academy_subtitle": "Alamin ang karaniwang pamamaraan ng pag-dispatch at ang opisyal na mga BFP Fire Safety Modules.",
		"steps": {
			"intro_community": {
				"title": "BFP Community Relations (Volume 0)",
				"body": "Maligayang pagdating sa Bureau of Fire Protection (BFP) Dispatcher Simulator! Kinakailangan ang pagtawag sa 911 o lokal na emergency hotline UNA sa anumang matinding banta. Sasabihin ng mga dispatcher ang lokasyon at magpapadala ng tulong habang sinusuportahan mo ang tumatawag.",
				"coach_tip": "Paalala: Ang unang hakbang sa anumang emergency ay ang pag-abiso agad sa mga propesyonal."
			},
			"children_safety": {
				"title": "Modyul 1: Kaligtasan sa Sunog para sa mga Bata (Volume 1)",
				"body": "Alamin kung paano tuturuan ang mga bata ng kaligtasan sa buhay:\n1. EDITH (Exit Drills In The Home) upang magsanay ng mga ruta ng paglabas.\n2. Gumapang ng mababa sa ilalim ng usok dahil ang nakalalasong usok ay tumataas; mas malinis ang hangin malapit sa sahig.\n3. Stop, Drop, and Roll kung masunog ang damit. Huwag kailanman tumakbo!",
				"coach_tip": "Sa usok, sabihin sa mga tumatawag na manatiling mababa. Kung sila ay nasusunog, ang pagtakbo ay nagpapakain ng oxygen sa apoy."
			},
			"teenagers_safety": {
				"title": "Modyul 2: Kaligtasan sa Sunog para sa mga Teenager (Volume 2)",
				"body": "Turuan ang mga teenager na kilalanin ang mga karaniwang panganib sa tahanan:\n1. Sunog sa Kusina/Grasa: Takpan ng metal na takip, basang tela, o baking soda. Huwag kailanman gumamit ng tubig dahil nagdudulot ito ng sumasabog na fireball!\n2. Kuryente: Iwasang mag-overload ng mga saksakan gamit ang mga multi-plug adapter.",
				"coach_tip": "Ang pagbuhos ng tubig sa mainit na sunog ng grasa ay nagpapakalat agad ng nasusunog na langis. Palaging takpan ang mga sunog sa grasa."
			},
			"young_adults_safety": {
				"title": "Modyul 3: Kaligtasan sa Sunog para sa mga Young Adult (Volume 3)",
				"body": "Turuan ang paggamit ng extinguisher sa pamamagitan ng PASS na paraan: Pull the pin (Hilahin ang pin), Aim (Itutok sa ibaba), Squeeze (Pisilin ang lever), at Sweep (I-sweep side-to-side).\nIturo din ang Spinal Stabilization: Huwag kailanman galawin ang isang nasugatang biktima ng trauma/pagkahulog maliban kung may agarang banta mula sa sunog.",
				"coach_tip": "Ang paggalaw sa biktima ng pagkahulog ay maaaring pumutol sa spinal cord. Panatilihin silang tahimik, mainit, at kalmado."
			},
			"general_public_safety": {
				"title": "Modyul 4: Kaligtasan sa Sunog para sa Pangkalahatan (Volume 4)",
				"body": "Ituro ang kaligtasan sa gas leak: Kung makalanghap ng LPG/gas, patayin agad ang main valve kung ligtas at i-ventilate. HUWAG i-on o i-off ang mga ilaw o saksakan ng kuryente, at huwag gumawa ng spark, dahil maaari itong magdolot ng instant at malakas na pagsabog!",
				"coach_tip": "Ang pag-flick ng switch ng kuryente ay lumilikha ng maliit na spark na madaling mag-apoy ng concentrated LPG gas."
			},
			"business_safety": {
				"title": "Modyul 5: Mga Establisyemento ng Negosyo (Volume 5)",
				"body": "Ang kaligtasan sa lugar ng trabaho ay nangangailangan ng pagpapanatiling malinis ng mga emergency exit at daanan sa lahat ng oras. Ang pag-prop open ng mga fire door ay hindi ligtas; dapat silang manatiling sarado upang harangan ang apoy at maiwasan ang pagkalat ng usok sa ibang mga zone.",
				"coach_tip": "Ang mga naka-lock o baradong fire exit ang pangunahing sanhi ng mga malalaking trahedya ng sunog sa negosyo."
			},
			"vulnerable_individuals_safety": {
				"title": "Modyul 6: Espesyal na Pangangalaga at mga Vulnerable na Indibidwal (Volume 6)",
				"body": "Suportahan ang mga vulnerable na mamamayan habang lumilikas: magtalaga ng mga buddies para sa mga matatanda, may kapansanan, o mga bata.\nPara sa mga medikal na emerhensya tulad ng stroke, kilalanin ang FAST (Face, Arm, Speech, Time) at huwag kailanman magbigay ng pagkain/tubig upang maiwasan ang choking.",
				"coach_tip": "Palaging unahin ang pagtulong sa mga hindi makagalaw o makalikas nang madali nang mag-isa."
			}
		}
	},
	"taglish": {
		"academy_title": "BFP Sta. Cruz Emergency Dispatch Academy",
		"academy_subtitle": "Learn standard dispatch procedures at ang official BFP Fire Safety Modules.",
		"steps": {
			"intro_community": {
				"title": "BFP Community Relations (Volume 0)",
				"body": "Welcome sa Bureau of Fire Protection (BFP) Dispatcher Simulator! Standard operating procedures require na tumawag sa 911 o sa local emergency hotline FIRST kapag may severe threat. Mag-establish ang dispatchers ng location at magpapadala ng tulong habang sinusuportahan mo ang caller.",
				"coach_tip": "Remember: Ang first step ng kahit anong emergency ay i-notify ang mga professionals immediately."
			},
			"children_safety": {
				"title": "Module 1: Fire Safety for Children (Volume 1)",
				"body": "Learn to teach children life safety:\n1. EDITH (Exit Drills In The Home) para mag-practice ng exit paths.\n2. Crawl Low sa ilalim ng smoke dahil umaakyat ang toxic smoke; mas malinis ang hangin sa may sahig.\n3. Stop, Drop, and Roll kapag nasunog ang damit. Never tumakbo!",
				"coach_tip": "Kapag may smoke, stay low. Kapag sila naman ang nasunog, ang pagtakbo ay nagpapakain ng oxygen sa apoy."
			},
			"teenagers_safety": {
				"title": "Module 2: Fire Safety for Teenagers (Volume 2)",
				"body": "Turuan ang teenagers na makilala ang common domestic hazards:\n1. Grease/Kitchen Fire: Smother gamit ang metal lid, damp cloth, o baking soda. Never gumamit ng tubig dahil magdudulot ito ng explosive fireball!\n2. Electrical: Iwasang mag-overload ng outlets gamit ang multi-plug adapters.",
				"coach_tip": "Ang pagbuhos ng tubig sa mainit na grease fire ay magpapakalat ng burning oil instantly. Palaging smother ang grease fires."
			},
			"young_adults_safety": {
				"title": "Module 3: Fire Safety for Young Adults (Volume 3)",
				"body": "Ituro ang extinguisher usage gamit ang PASS method: Pull the pin, Aim sa base ng apoy, Squeeze ang lever, at Sweep side-to-side.\nIturo din ang Spinal Stabilization: Never galawin ang injured trauma/fall victim unless may immediate threat ng sunog.",
				"coach_tip": "Ang paggalaw ng fall victim ay pwedeng pumutol ng spinal cord. Keep them still, warm, and calm."
			},
			"general_public_safety": {
				"title": "Module 4: Fire Safety for General Public (Volume 4)",
				"body": "Ituro ang gas leak safety: Kapag nakamoy ng LPG/gas, patayin agad ang main valve kung safe at mag-ventilate. DO NOT mag-flick ng light/electrical switches, at huwag gumawa ng sparks, dahil pwedeng magdulot ng instant, massive explosion!",
				"coach_tip": "Ang pag-flick ng electrical switch ay gumagawa ng maliit na spark na madaling mag-ignite ng concentrated LPG gas."
			},
			"business_safety": {
				"title": "Module 5: Business Establishments (Volume 5)",
				"body": "Kailangan sa workplace safety ang pagpapanatiling malinis ng emergency exits at pathways at all times. Hindi safe ang pag-prop open ng fire doors; kailangang manatiling sarado ang mga ito para ma-compartmentalize ang fire at maiwasan ang pagkalat ng smoke.",
				"coach_tip": "Ang mga locked o blocked fire exits ang pangunahing sanhi ng major business fire tragedies."
			},
			"vulnerable_individuals_safety": {
				"title": "Module 6: Special Care & Vulnerable Individuals (Volume 6)",
				"body": "Support vulnerable citizens habang nag-e-evacuate: mag-assign ng buddies para sa elderly, disabled, o bata.\nPara sa medical emergencies tulad ng stroke, kilalanin ang FAST (Face, Arm, Speech, Time) at never magbigay ng pagkain/tubig para maiwasan ang choking.",
				"coach_tip": "Palaging i-prioritize ang pagtulong sa mga hindi makagalaw o makalikas nang madali nang mag-isa."
			}
		}
	}
}

@onready var root_bg: ColorRect = $CanvasLayer/Root
@onready var title_label: Label = $CanvasLayer/Root/Margin/Layout/Header/TitleLabel
@onready var subtitle_label: Label = $CanvasLayer/Root/Margin/Layout/Header/SubtitleLabel
@onready var step_counter_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/Content/StepCounterLabel
@onready var step_title_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/Content/StepTitleLabel
@onready var step_body_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/Content/StepBodyLabel
@onready var coach_tip_label: Label = $CanvasLayer/Root/Margin/Layout/Body/BodyMargin/Content/CoachTipLabel
@onready var back_button: Button = $CanvasLayer/Root/Margin/Layout/Footer/BackButton
@onready var next_button: Button = $CanvasLayer/Root/Margin/Layout/Footer/NextButton
@onready var finish_button: Button = $CanvasLayer/Root/Margin/Layout/Footer/FinishButton
var skip_button: Button = null

func _state() -> Node:
	return get_node_or_null("/root/GameState")

func _ready() -> void:
	_cached_state = get_node_or_null("/root/GameState")
	var state = _cached_state
	if state:
		_steps = state.call("get_tutorial_steps")
		title_label.text = String(state.call("get_tutorial_title"))
		subtitle_label.text = String(state.call("get_tutorial_subtitle"))

		# Translate tutorial steps dynamically.
		var loc = "taglish"
		if state.has_method("get_locale"):
			loc = String(state.call("get_locale"))
		if loc in ["tl", "taglish"]:
			var t_data = tutorial_translations[loc]
			title_label.text = t_data["academy_title"]
			subtitle_label.text = t_data["academy_subtitle"]
			for s in _steps:
				var s_id = String(s.get("id", ""))
				if t_data["steps"].has(s_id):
					var sd = t_data["steps"][s_id]
					s["title"] = sd["title"]
					s["body"] = sd["body"]
					s["coach_tip"] = sd["coach_tip"]
	else:
		_steps = []
		title_label.text = "Tutorial"
		subtitle_label.text = "Game state system unavailable."
	
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip Tutorial"
	if back_button and back_button.get_parent():
		back_button.get_parent().add_child(skip_button)
		back_button.get_parent().move_child(skip_button, 1) # next to Back button
	
	skip_button.pressed.connect(func():
		var st = _cached_state
		if st:
			st.call("complete_tutorial")
			st.call("select_mode", "easy_multiple_choice")
		get_tree().change_scene_to_file(_get_route_scene())
	)
	
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	finish_button.pressed.connect(_on_finish_pressed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_kids_theme()
	_refresh_step()

func _on_viewport_resized() -> void:
	_apply_kids_theme()

func _style_footer_button(btn: Button, base_color: Color, hover_color: Color, is_mobile: bool) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, 74 if is_mobile else 52)
	btn.add_theme_font_size_override("font_size", 23 if is_mobile else 17)
	btn.add_theme_color_override("font_color", TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", TEXT_DARK)
	btn.add_theme_color_override("font_focus_color", TEXT_DARK)

	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
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
	hover.bg_color = hover_color

	var pressed = hover.duplicate()
	pressed.bg_color = hover_color.darkened(0.1)

	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.72, 0.76, 0.8, 0.85)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

func _apply_kids_theme() -> void:
	var vp_width = get_viewport().get_visible_rect().size.x
	var is_mobile = vp_width <= 900.0

	if root_bg:
		root_bg.color = THEME_BG

	var body_panel: PanelContainer = get_node_or_null("CanvasLayer/Root/Margin/Layout/Body")
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

	if title_label:
		title_label.add_theme_font_size_override("font_size", 42 if is_mobile else 32)
		title_label.add_theme_color_override("font_color", TEXT_DARK)
	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 22 if is_mobile else 17)
		subtitle_label.add_theme_color_override("font_color", Color8(72, 82, 98))
	if step_counter_label:
		step_counter_label.add_theme_font_size_override("font_size", 20 if is_mobile else 15)
		step_counter_label.add_theme_color_override("font_color", Color8(72, 82, 98))
	if step_title_label:
		step_title_label.add_theme_font_size_override("font_size", 36 if is_mobile else 28)
		step_title_label.add_theme_color_override("font_color", TEXT_DARK)
	if step_body_label:
		step_body_label.add_theme_font_size_override("font_size", 26 if is_mobile else 20)
		step_body_label.add_theme_color_override("font_color", TEXT_DARK)
	if coach_tip_label:
		coach_tip_label.add_theme_font_size_override("font_size", 22 if is_mobile else 17)
		coach_tip_label.add_theme_color_override("font_color", Color8(140, 88, 34))

	_style_footer_button(back_button, Color8(255, 205, 104), Color8(255, 219, 135), is_mobile)
	_style_footer_button(next_button, Color8(92, 195, 255), Color8(117, 210, 255), is_mobile)
	_style_footer_button(finish_button, Color8(109, 205, 119), Color8(132, 220, 140), is_mobile)
	if skip_button:
		_style_footer_button(skip_button, Color8(255, 120, 120), Color8(255, 140, 140), is_mobile)

func _refresh_step() -> void:
	var state = _cached_state
	if _steps.is_empty():
		step_counter_label.text = "No tutorial steps configured."
		step_title_label.text = "Tutorial unavailable"
		step_body_label.text = "Add tutorial steps to data/gameplay/tutorial_steps.json."
		coach_tip_label.text = ""
		back_button.disabled = true
		next_button.disabled = true
		finish_button.disabled = false
		return

	if state:
		back_button.text = state.call("translate", "Back")
		next_button.text = state.call("translate", "Next")
		finish_button.text = state.call("translate", "Finish")

	var step: Dictionary = _steps[_index]
	
	if state:
		var counter_tpl = state.call("translate", "Lesson %d of %d")
		step_counter_label.text = counter_tpl % [_index + 1, _steps.size()]
	else:
		step_counter_label.text = "Lesson %d of %d" % [_index + 1, _steps.size()]
		
	step_title_label.text = String(step.get("title", "Untitled lesson"))
	step_body_label.text = String(step.get("body", ""))
	
	if state:
		var coach_tpl = state.call("translate", "Coach tip: %s")
		coach_tip_label.text = coach_tpl % String(step.get("coach_tip", ""))
	else:
		coach_tip_label.text = "Coach tip: %s" % String(step.get("coach_tip", ""))
		
	back_button.disabled = _index == 0
	next_button.disabled = _index >= _steps.size() - 1
	finish_button.disabled = _index < _steps.size() - 1

func _on_back_pressed() -> void:
	if _index > 0:
		_index -= 1
		_refresh_step()

func _on_next_pressed() -> void:
	if _index < _steps.size() - 1:
		_index += 1
		_refresh_step()

func _on_finish_pressed() -> void:
	var state = _cached_state
	if state:
		state.call("complete_tutorial")
		state.call("select_mode", "easy_multiple_choice")
	get_tree().change_scene_to_file(_get_route_scene())
