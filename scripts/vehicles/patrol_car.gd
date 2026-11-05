extends Node2D

signal finished(car: Node)

@export var vehicle_type: String = "police"
@export var color: Color = Color8(0, 0, 255)
@export var speed_kph: float = 50.0
@export var disappear_km: float = 100.0

var _points: Array = []
var _image_width: int = 0
var _image_height: int = 0
var _map_width_m: float = 1.0
var _map_height_m: float = 1.0
var _total_length_m: float = 1.0
var _total_length_px: float = 1.0
var _pixels_per_meter: float = 1.0  # Cached ratio; avoids per-frame division
var _traveled_m: float = 0.0
var _pf: PathFollow2D = null
var _rng := RandomNumberGenerator.new()
var _current_speed_kph: float = 0.0
var _target_speed_kph: float = 0.0
var _speed_change_timer: float = 0.0
var _sprite: Sprite2D = null
var _anim_timer: float = 0.0

func _init():
	_rng.randomize()

# ── Helper: decode a normalized route point from either Dict or Array format ──
func _parse_route_point(p: Variant, out_nx: Array, out_ny: Array) -> bool:
	if typeof(p) == TYPE_DICTIONARY:
		out_nx[0] = float(p.get("x", 0.0))
		out_ny[0] = float(p.get("y", 0.0))
		return true
	elif typeof(p) == TYPE_ARRAY and (p as Array).size() >= 2:
		out_nx[0] = float(p[0])
		out_ny[0] = float(p[1])
		return true
	return false

func setup(points: Array, map_bounds: Dictionary, image_w: int, image_h: int,
		vehicle_color: Color, speed_kph_in: float, _disappear_km_in: float,
		start_fraction: float = -1.0) -> void:

	_points = points.duplicate(true)
	_image_width  = int(image_w)
	_image_height = int(image_h)

	var minx = float(map_bounds.get("minx", 0.0))
	var miny = float(map_bounds.get("miny", 0.0))
	var maxx = float(map_bounds.get("maxx", 1.0))
	var maxy = float(map_bounds.get("maxy", 1.0))
	_map_width_m  = (maxx - minx) if (maxx - minx) != 0.0 else 1.0
	_map_height_m = (maxy - miny) if (maxy - miny) != 0.0 else 1.0

	speed_kph     = float(speed_kph_in)
	disappear_km  = _rng.randf_range(100.0, 500.0)
	_current_speed_kph   = clamp(speed_kph, 30.0, 80.0)
	_target_speed_kph    = _current_speed_kph
	_speed_change_timer  = _rng.randf_range(1.5, 4.0)

	# ── Build Path2D ─────────────────────────────────────────────────────────
	var route_path = Path2D.new()
	var curve = Curve2D.new()
	var nx_buf = [0.0]
	var ny_buf = [0.0]
	for p in _points:
		if _parse_route_point(p, nx_buf, ny_buf):
			curve.add_point(Vector2(nx_buf[0] * float(_image_width),
			                        ny_buf[0] * float(_image_height)))
	route_path.curve = curve
	add_child(route_path)

	_pf = PathFollow2D.new()
	_pf.loop = false
	_pf.rotates = false
	route_path.add_child(_pf)

	# ── Vehicle sprite / fallback polygon ────────────────────────────────────
	var icon_path := "res://assets/The Right Call Sprites/policeeesprite.png"
	match vehicle_type:
		"fire_truck":
			icon_path = "res://assets/The Right Call Sprites/firetrucksprite.png"
		"ambulance":
			icon_path = "res://assets/The Right Call Sprites/ambulancesprite.png"

	if ResourceLoader.exists(icon_path):
		var tex = load(icon_path)
		if tex is Texture2D:
			var sprite = Sprite2D.new()
			sprite.texture = tex
			sprite.hframes = 4
			sprite.scale = Vector2(2.0, 2.0)
			sprite.modulate = Color.WHITE
			_pf.add_child(sprite)
			_sprite = sprite
			tex = null  # release local reference
		else:
			_pf.add_child(_make_fallback_polygon())
	else:
		_pf.add_child(_make_fallback_polygon())

	# ── Compute total lengths and cache pixels-per-meter ─────────────────────
	_total_length_m  = 0.0
	_total_length_px = 0.0
	for i in range(curve.get_point_count() - 1):
		var p1 = curve.get_point_position(i)
		var p2 = curve.get_point_position(i + 1)
		_total_length_px += p1.distance_to(p2)
		var dx_norm = (p2.x - p1.x) / float(_image_width)
		var dy_norm = (p2.y - p1.y) / float(_image_height)
		_total_length_m  += sqrt(
			(dx_norm * _map_width_m) * (dx_norm * _map_width_m) +
			(dy_norm * _map_height_m) * (dy_norm * _map_height_m)
		)

	if _total_length_m  <= 0.0: _total_length_m  = 1.0
	if _total_length_px <= 0.0: _total_length_px = 1.0

	# Cache once — used every frame to convert m/s → px/s.
	_pixels_per_meter = _total_length_px / _total_length_m

	# ── Starting position along path ─────────────────────────────────────────
	_pf.progress = (
		clamp(start_fraction, 0.0, 1.0) * _total_length_px
		if start_fraction >= 0.0
		else _rng.randf() * _total_length_px
	)

	_traveled_m = 0.0
	set_process(true)

# ── Helper to build the fallback triangle marker ──────────────────────────────
func _make_fallback_polygon() -> Polygon2D:
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, -10), Vector2(8, 10), Vector2(-8, 10)])
	poly.color = Color.WHITE
	return poly

func _process(delta: float) -> void:
	if _pf == null:
		return

	var traveled_target_m = disappear_km * 1000.0
	var remaining_m = max(0.0, traveled_target_m - _traveled_m)

	# Speed cap as vehicle approaches end of its patrol distance.
	var max_allowed_speed = 80.0
	if remaining_m <= 5000.0:
		max_allowed_speed = max(0.0, 80.0 * (remaining_m / 5000.0))
	if remaining_m <= 50.0:
		max_allowed_speed = 0.0

	# Periodic random speed target changes.
	_speed_change_timer -= delta
	if _speed_change_timer <= 0.0:
		_target_speed_kph   = _rng.randf_range(30.0, 80.0)
		_speed_change_timer = _rng.randf_range(1.5, 4.0)

	_target_speed_kph = min(_target_speed_kph, max_allowed_speed)

	# Smooth acceleration / deceleration.
	const ACCEL_RATE := 25.0  # km/h per second
	var diff = _target_speed_kph - _current_speed_kph
	_current_speed_kph = clamp(
		_current_speed_kph + clamp(diff, -ACCEL_RATE * delta, ACCEL_RATE * delta),
		0.0, max_allowed_speed
	)

	# Convert speed to pixels-per-second using the cached ratio.
	const SPEED_MULTIPLIER := 12.0
	var speed_mps     = (_current_speed_kph * SPEED_MULTIPLIER) / 3.6
	var speed_px_per_s = speed_mps * _pixels_per_meter
	var inc_px        = speed_px_per_s * delta

	var prev_pos  = _pf.position
	var new_progress = _pf.progress + inc_px

	if _total_length_px > 0 and new_progress >= _total_length_px:
		despawn_vehicle()
		return

	_pf.progress = new_progress

	# Sprite animation and flip.
	if _sprite:
		_anim_timer    += delta * 10.0
		_sprite.frame   = int(_anim_timer) % 4
		var curr_pos    = _pf.position
		if curr_pos.x < prev_pos.x - 0.1:
			_sprite.flip_h = true
		elif curr_pos.x > prev_pos.x + 0.1:
			_sprite.flip_h = false

	_traveled_m += speed_mps * delta
	if _traveled_m >= traveled_target_m or max_allowed_speed <= 0.0:
		despawn_vehicle()

func despawn_vehicle() -> void:
	set_process(false)
	set_physics_process(false)
	emit_signal("finished", self)
	queue_free()

func stop_and_remove() -> void:
	set_process(false)
	queue_free()

func get_vehicle_position() -> Vector2:
	return _pf.position if _pf else global_position
