extends Node2D

@export var route_file_path: String = "res://data/routes/citywide_patrol_route.json"
@export var image_width: int = 1024
@export var image_height: int = 1024
@export var duration: float = 60.0
@export var loop_patrol: bool = true
@export var patrol_speed: float = 1.0
@export var spawn_pin: bool = true

var _pf: PathFollow2D = null

func _ready():
	call_deferred("_deferred_load")


func _deferred_load() -> void:
	if FileAccess.file_exists(route_file_path):
		_load_and_play(route_file_path)
	else:
		push_error("Route file not found: %s" % route_file_path)


func _load_and_play(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("Failed to open route file: %s" % path)
		return

	var parsed = JSON.parse_string(f.get_as_text())

	# Normalize parsed result — handle both raw value and error-wrapper formats.
	var root: Variant
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		if parsed.get("error") != OK:
			push_error("Failed to parse JSON in route file: %s" % path)
			return
		root = parsed.get("result")
	else:
		root = parsed

	var pts: Array = []
	if typeof(root) == TYPE_DICTIONARY and root.has("points"):
		pts = root.get("points")
	elif typeof(root) == TYPE_ARRAY:
		pts = root
	else:
		push_error("Route file has no 'points' array: %s" % path)
		return

	# When this node is not responsible for spawning visuals, stop early.
	if not spawn_pin:
		return

	# ── Build Path2D from route points ───────────────────────────────────────
	var route_path = Path2D.new()
	var curve = Curve2D.new()
	for p in pts:
		var nx: float
		var ny: float
		if typeof(p) == TYPE_DICTIONARY:
			nx = float(p.get("x", 0.0))
			ny = float(p.get("y", 0.0))
		elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
			nx = float(p[0])
			ny = float(p[1])
		else:
			push_error("Invalid point format in route data")
			continue
		curve.add_point(Vector2(nx * float(image_width), ny * float(image_height)))
	route_path.curve = curve
	add_child(route_path)

	var pf = PathFollow2D.new()
	route_path.add_child(pf)
	_pf = pf

	# ── Visual pin ───────────────────────────────────────────────────────────
	if ResourceLoader.exists("res://pin.png"):
		var pin_texture: Texture2D = load("res://pin.png")
		if pin_texture:
			var sprite = Sprite2D.new()
			sprite.texture = pin_texture
			pf.add_child(sprite)
	else:
		var poly = Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(0, -8), Vector2(6, 8), Vector2(-6, 8)])
		poly.color = Color8(255, 80, 0)
		pf.add_child(poly)

	# ── Compute total path length ────────────────────────────────────────────
	var total_length: float = 0.0
	for i in range(curve.get_point_count() - 1):
		total_length += curve.get_point_position(i).distance_to(curve.get_point_position(i + 1))

	pf.progress = 0.0

	# ── Animate PathFollow2D.progress directly — no _process poll needed ─────
	var travel_time = duration / patrol_speed
	var tw = get_tree().create_tween()

	var is_patrol_loop: bool = (
		typeof(root) == TYPE_DICTIONARY
		and root.get("is_loop", false)
		and loop_patrol
	)

	if is_patrol_loop:
		tw.set_loops()
		tw.tween_property(pf, "progress", total_length, travel_time).set_trans(Tween.TRANS_LINEAR)
	else:
		tw.tween_property(pf, "progress", total_length, travel_time) \
			.set_trans(Tween.TRANS_LINEAR) \
			.set_ease(Tween.EASE_IN_OUT)
