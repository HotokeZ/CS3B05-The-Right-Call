extends Node2D

signal response_arrived(vehicle_id: String, world_position: Vector2)
signal response_position_updated(vehicle_id: String, world_position: Vector2)

@export var route_file_path: String = "res://data/routes/citywide_patrol_route.json"
@export var bounds_file_path: String = "res://assets/maps/map.bounds.json"
@export var station_file_path: String = "res://data/gameplay/service_stations.json"
@export var image_width: int = 1024
@export var image_height: int = 1024
@export var min_cars_per_type: int = 1
@export var max_cars_per_type: int = 2
@export var default_speed_kph: float = 125.0
@export var disappear_km: float = 100.0
@export var respawn_delay_min: float = 5.0
@export var respawn_delay_max: float = 10.0
@export var dispatch_from_station_only: bool = true
@export var professional_response_speed_kph: float = 312.5
@export var route_graph_link_radius_px: float = 48.0
@export var route_graph_max_shortcuts_per_node: int = 4
@export var route_graph_cell_size_px: float = 64.0
@export var route_graph_max_nearest_rings: int = 3

var route_points: Array = []
var route_edges: Array = []  # Explicit edges from JSON [i, j] pairs
var regions = {
	"north": [],
	"east": [],
	"south": []
}
var _rng = RandomNumberGenerator.new()
var active_cars: Array = []
var _map_bounds: Dictionary = {}
var _service_stations: Array = []
var _route_px_points: Array = []
var _route_astar: AStar2D = AStar2D.new()
var _route_spatial_cells: Dictionary = {}
var _route_graph_ready: bool = false

var vehicle_types = ["police", "fire_truck", "ambulance"]
var vehicle_colors = {
	"police": Color8(10, 80, 255),
	"fire_truck": Color8(200, 20, 20),
	"ambulance": Color8(10, 200, 40)
}

# NOTE: building_pixels and _service_bases_norm are legacy fallbacks only.
# Station positions are loaded from station_file_path JSON at runtime.
# These hardcoded values are only used when no JSON station data is available.
var building_pixels = {}  # cleared to force JSON-loaded positions

var _service_bases_norm = {
	"ambulance": Vector2(0.5, 0.5),
	"police": Vector2(0.5, 0.5),
	"fire_truck": Vector2(0.5, 0.5)
}

func _ready() -> void:
	_rng.randomize()
	# Keep startup cheap on web/mobile-class devices.
	if OS.has_feature("web"):
		max_cars_per_type = min(max_cars_per_type, 2)
		route_graph_max_shortcuts_per_node = min(route_graph_max_shortcuts_per_node, 2)
		route_graph_link_radius_px = min(route_graph_link_radius_px, 40.0)
		route_graph_max_nearest_rings = min(route_graph_max_nearest_rings, 2)
	load_route()
	_build_route_graph()
	_load_service_stations()
	_snap_service_stations_to_route_points()
	_apply_service_station_bases()
	_load_bounds()
	_partition_regions()
	# stagger initial spawns with slight randomness
	var delay = 0.0
	for vtype in vehicle_types:
		for i in range(min_cars_per_type):
			_spawn_with_delay(delay + _rng.randf_range(0.0, 0.5), vtype)
			delay += 0.8

func _load_service_stations() -> void:
	_service_stations.clear()
	if not FileAccess.file_exists(station_file_path):
		return
	var f = FileAccess.open(station_file_path, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	var root = parsed
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("stations"):
		root = parsed.get("stations")
	if typeof(root) != TYPE_ARRAY:
		return

	for row_any in root:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var vtype = String(row.get("type", "")).strip_edges().to_lower()
		if not vehicle_types.has(vtype):
			continue
		var nx = clamp(float(row.get("x", 0.5)), 0.0, 1.0)
		var ny = clamp(float(row.get("y", 0.5)), 0.0, 1.0)
		var station = {
			"type": vtype,
			"name": String(row.get("name", _vehicle_name(vtype) + " Station")),
			"x": nx,
			"y": ny
		}
		_service_stations.append(station)


func _apply_service_station_bases() -> void:
	# If a station exists for a responder type, use the first one as its dispatch base.
	for vtype in vehicle_types:
		for st_any in _service_stations:
			var st: Dictionary = st_any
			if String(st.get("type", "")) == vtype:
				_service_bases_norm[vtype] = Vector2(float(st.get("x", 0.5)), float(st.get("y", 0.5)))
				break

func _closest_route_px_point(px_point: Vector2) -> Vector2:
	if _route_px_points.is_empty():
		return px_point
	var best_idx = 0
	var best_dist = INF
	for i in range(_route_px_points.size()):
		var d = (_route_px_points[i] as Vector2).distance_squared_to(px_point)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return _route_px_points[best_idx]

func _snap_service_stations_to_route_points() -> void:
	# x/y = building center (for pin display) — do NOT overwrite.
	# spawn_x/spawn_y = nearest road tile (for vehicle spawning).
	# If spawn_x/spawn_y are already set from JSON, use them as-is.
	# If missing (old JSON format), snap x/y to nearest road and store as spawn_x/spawn_y.
	if _service_stations.is_empty() or _route_px_points.is_empty():
		return
	for i in range(_service_stations.size()):
		var st: Dictionary = _service_stations[i]
		if st.has("spawn_x") and st.has("spawn_y"):
			continue  # spawn point already set in JSON, skip
		# Legacy fallback: snap building center to nearest road for spawn
		var nx = clamp(float(st.get("x", 0.5)), 0.0, 1.0)
		var ny = clamp(float(st.get("y", 0.5)), 0.0, 1.0)
		var raw_px = Vector2(nx * float(image_width), ny * float(image_height))
		var snapped_px = _closest_route_px_point(raw_px)
		st["spawn_x"] = clamp(snapped_px.x / float(max(1, image_width)), 0.0, 1.0)
		st["spawn_y"] = clamp(snapped_px.y / float(max(1, image_height)), 0.0, 1.0)
		_service_stations[i] = st

func load_route() -> void:
	if not FileAccess.file_exists(route_file_path):
		push_error("Route file not found: %s" % route_file_path)
		return
	var f = FileAccess.open(route_file_path, FileAccess.READ)
	if not f:
		push_error("Failed to open route file: %s" % route_file_path)
		return
	var txt = f.get_as_text()
	var parsed = JSON.parse_string(txt)
	var root = parsed
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		# handle wrapper
		if parsed.get("error") != OK:
			push_error("Failed to parse route JSON: %s" % route_file_path)
			return
		root = parsed.get("result")

	if typeof(root) == TYPE_DICTIONARY and root.has("points"):
		route_points = root.get("points")
		# Also load explicit edges if present (prevents diagonal shortcuts)
		if root.has("edges"):
			route_edges = root.get("edges")
		else:
			route_edges = []
	elif typeof(root) == TYPE_ARRAY:
		route_points = root
		route_edges = []
	else:
		push_error("Route data does not contain points")
		return
	_route_astar.clear()
	_route_spatial_cells.clear()
	_route_graph_ready = false

func _load_bounds() -> void:
	if FileAccess.file_exists(bounds_file_path):
		var bf = FileAccess.open(bounds_file_path, FileAccess.READ)
		if bf:
			var bj = JSON.parse_string(bf.get_as_text())
			if typeof(bj) == TYPE_DICTIONARY:
				_map_bounds = bj
			else:
				_map_bounds = {}
	else:
		_map_bounds = {}

func _partition_regions() -> void:
	# Partition route points into three geographic bands (north, east, south)
	if route_points.size() == 0:
		return
	var xs: Array = []
	var ys: Array = []
	for p in route_points:
		var x = 0.0
		var y = 0.0
		if typeof(p) == TYPE_DICTIONARY:
			x = float(p.get("x", 0.0))
			y = float(p.get("y", 0.0))
		elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
			x = float(p[0])
			y = float(p[1])
		xs.append(x)
		ys.append(y)

	var xmin = xs.min()
	var xmax = xs.max()
	var ymin = ys.min()
	var ymax = ys.max()
	var xspan = xmax - xmin
	var yspan = ymax - ymin
	if xspan <= 0 or yspan <= 0:
		return

	var top_th = ymin + yspan / 3.0
	var bottom_th = ymin + 2.0 * yspan / 3.0
	var right_th = xmin + 2.0 * xspan / 3.0

	# Build contiguous segments for named regions using a top-level helper
	regions["north"] = _build_segments_for_label("north", top_th, bottom_th, right_th)
	regions["east"] = _build_segments_for_label("east", top_th, bottom_th, right_th)
	regions["south"] = _build_segments_for_label("south", top_th, bottom_th, right_th)

	# If any region is empty, fallback to picking larger slices
	for k in ["north", "east", "south"]:
		if regions[k].size() == 0:
			# fallback: pick contiguous slices from route
			var fallback: Array = []
			var idx = int((_rng.randf() * max(0, route_points.size() - 200)))
			for j in range(idx, min(idx + 300, route_points.size())):
				fallback.append(route_points[j])
			regions[k] = [fallback]

func _spawn_with_delay(delay: float, preferred_type: String = "") -> void:
	# Use await to wait for the timer then spawn
	await get_tree().create_timer(delay).timeout
	_spawn_car(preferred_type)

func _spawn_car(preferred_type: String = "") -> void:
	# Choose vehicle type
	var vtype = preferred_type
	if not vehicle_types.has(vtype):
		var available = []
		for t in vehicle_types:
			if _count_active_cars_of_type(t) < max_cars_per_type:
				available.append(t)
		if available.is_empty():
			# Capacity full — schedule a retry.
			_spawn_with_delay(_rng.randf_range(respawn_delay_min, respawn_delay_max))
			return
		vtype = available[_rng.randi_range(0, available.size() - 1)]
	else:
		if _count_active_cars_of_type(vtype) >= max_cars_per_type:
			_spawn_with_delay(_rng.randf_range(respawn_delay_min, respawn_delay_max))
			return

	var vcolor = vehicle_colors.get(vtype, Color8(255, 255, 255))

	# Spawn patrol from its designated station and move out along a random direction.
	var seg: Array = _route_slice_from_station(vtype)
	if seg.size() < 8:
		seg = _random_route_slice()
	if seg.size() < 8:
		return

	# instantiate PatrolCar
	var script = load("res://scripts/vehicles/patrol_car.gd")
	var car = script.new()
	car.vehicle_type = vtype
	car.color = vcolor
	# set up the car
	var start_frac = -1.0
	car.setup(seg, _map_bounds, image_width, image_height, vcolor, default_speed_kph, disappear_km, 0.0)
	car.connect("finished", Callable(self, "_on_car_finished"))
	add_child(car)
	active_cars.append(car)

	# Try to spawn next car if we still have capacity overall
	_spawn_with_delay(_rng.randf_range(respawn_delay_min, respawn_delay_max))

func _route_slice_from_station(vtype: String, min_len: int = 240, max_len: int = 420) -> Array:
	"""Build a road-only patrol path starting from the station using graph-based random walk."""
	if _route_px_points.is_empty() or not _route_graph_ready:
		return []

	# Find the start index: the route node closest to the station's spawn point (road tile)
	var base_px = _norm_to_px(_spawn_norm_for_type(vtype))
	var start_idx = _closest_route_index_for_px(base_px)

	# Walk the road graph randomly, following actual edges, for slice_len steps
	var steps = _rng.randi_range(min_len, max_len)
	var visited_order: Array = [start_idx]
	var current_idx = start_idx
	var prev_idx = -1

	for _step in range(steps):
		# Get all connected neighbours from AStar graph
		var neighbours = _route_astar.get_point_connections(current_idx)
		if neighbours.size() == 0:
			break
			
		var valid_neighbours = []
		for n in neighbours:
			if n != prev_idx or neighbours.size() == 1:
				valid_neighbours.append(n)
				
		# Pick a random neighbour
		var next_idx = int(valid_neighbours[_rng.randi_range(0, valid_neighbours.size() - 1)])
		visited_order.append(next_idx)
		prev_idx = current_idx
		current_idx = next_idx

	# Convert node indices to route_points entries for patrol_car.setup()
	var seg: Array = []
	for idx in visited_order:
		if idx >= 0 and idx < route_points.size():
			seg.append(route_points[idx])
	return seg

func _norm_to_px(norm_pos: Vector2) -> Vector2:
	var nx = clamp(norm_pos.x, 0.0, 1.0)
	var ny = clamp(norm_pos.y, 0.0, 1.0)
	return Vector2(nx * float(image_width), ny * float(image_height))

func _base_norm_for_type(vtype: String) -> Vector2:
	# FIRST: use loaded station data (x/y = building center for pin display)
	for st_any in _service_stations:
		var st = st_any as Dictionary
		if String(st.get("type", "")) == vtype:
			var nx = float(st.get("x", 0.5))
			var ny = float(st.get("y", 0.5))
			return Vector2(nx, ny)
	# Fallback: legacy hardcoded positions
	if building_pixels.has(vtype):
		var px = building_pixels[vtype]
		var ref_w = max(float(image_width), 2048.0)
		var ref_h = max(float(image_height), 2048.0)
		return Vector2(px.x / ref_w, px.y / ref_h)
	var base = _service_bases_norm.get(vtype, Vector2(0.5, 0.5))
	if base is Vector2:
		return base
	return Vector2(0.5, 0.5)

func _spawn_norm_for_type(vtype: String) -> Vector2:
	"""Returns the normalized spawn position (nearest road tile) for a vehicle type.
	This is where vehicles physically appear when spawning from the station."""
	# Check for spawn_x/spawn_y in loaded station data first
	for st_any in _service_stations:
		var st = st_any as Dictionary
		if String(st.get("type", "")) == vtype:
			if st.has("spawn_x") and st.has("spawn_y"):
				return Vector2(float(st.get("spawn_x")), float(st.get("spawn_y")))
			# Fall back to building center if no explicit spawn point
			return Vector2(float(st.get("x", 0.5)), float(st.get("y", 0.5)))
	# Final fallback
	return _base_norm_for_type(vtype)

func _closest_route_index_to_point(px_point: Vector2) -> int:
	if _route_graph_ready:
		return _closest_route_index_for_px(px_point)
	if route_points.is_empty():
		return 0
	var best_idx = 0
	var best_dist = INF
	for i in range(route_points.size()):
		var p = route_points[i]
		var nx = 0.0
		var ny = 0.0
		if typeof(p) == TYPE_DICTIONARY:
			nx = float(p.get("x", 0.0))
			ny = float(p.get("y", 0.0))
		elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
			nx = float(p[0])
			ny = float(p[1])
		var px = Vector2(nx * float(image_width), ny * float(image_height))
		var d = px.distance_squared_to(px_point)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx

func _start_fraction_for_vehicle_type(vtype: String) -> float:
	if route_points.is_empty():
		return _rng.randf()
	var base_norm = _base_norm_for_type(vtype)
	var base_px = _norm_to_px(base_norm)
	var idx = _closest_route_index_to_point(base_px)
	if route_points.size() <= 1:
		return 0.0
	return clamp(float(idx) / float(route_points.size() - 1), 0.0, 1.0)

func _vehicle_icon_path(vtype: String) -> String:
	match vtype:
		"fire_truck":
			return "res://assets/The Right Call Sprites/firetrucksprite.png"
		"ambulance":
			return "res://assets/The Right Call Sprites/ambulancesprite.png"
		_:
			return "res://assets/The Right Call Sprites/policeeesprite.png"

func _vehicle_name(vtype: String) -> String:
	match vtype:
		"fire_truck":
			return "Fire Truck"
		"ambulance":
			return "Ambulance"
		_:
			return "Police"

func get_service_station_markers() -> Array:
	var out: Array = []
	if _service_stations.is_empty():
		for k in vehicle_types:
			var norm: Vector2 = _base_norm_for_type(k)
			out.append({
				"type": String(k),
				"name": _vehicle_name(String(k)) + " Station",
				"position": _norm_to_px(norm)
			})
		return out

	for st_any in _service_stations:
		var st: Dictionary = st_any
		var norm = Vector2(float(st.get("x", 0.5)), float(st.get("y", 0.5)))
		out.append({
			"type": String(st.get("type", "police")),
			"name": String(st.get("name", "Station")),
			"position": _norm_to_px(norm)
		})
	return out

func _closest_active_car_of_type(vtype: String, target_world: Vector2) -> Node:
	var best_car: Node = null
	var best_dist = INF
	var target_local = _as_manager_local_point(target_world)
	for car in active_cars:
		if car == null or not car.is_inside_tree():
			continue
		if not car.has_method("get_vehicle_position"):
			continue
		if String(car.get("vehicle_type")) != vtype:
			continue
		var car_pos = car.call("get_vehicle_position")
		if car_pos is Vector2:
			var local_car = _as_manager_local_point(car_pos)
			var d = local_car.distance_squared_to(target_local)
			if d < best_dist:
				best_dist = d
				best_car = car
	return best_car

func _closest_active_car(target_world: Vector2) -> Node:
	var best_car: Node = null
	var best_dist = INF
	var target_local = _as_manager_local_point(target_world)
	for car in active_cars:
		if car == null or not car.is_inside_tree():
			continue
		if not car.has_method("get_vehicle_position"):
			continue
		var car_pos = car.call("get_vehicle_position")
		if car_pos is Vector2:
			var local_car = _as_manager_local_point(car_pos)
			var d = local_car.distance_squared_to(target_local)
			if d < best_dist:
				best_dist = d
				best_car = car
	return best_car

func _as_manager_local_point(point: Vector2) -> Vector2:
	var p = point
	var bounds = Rect2(Vector2.ZERO, Vector2(float(image_width), float(image_height)))
	if not bounds.has_point(p):
		p = to_local(point)
	p.x = clamp(p.x, 0.0, float(image_width))
	p.y = clamp(p.y, 0.0, float(image_height))
	return p

func dispatch_response_unit(vtype: String, target_world: Vector2, travel_s: float = 2.0) -> void:
	var source = _norm_to_px(_base_norm_for_type(vtype))
	target_world = _as_manager_local_point(target_world)
	if not dispatch_from_station_only:
		var car = _closest_active_car_of_type(vtype, target_world)
		if car == null:
			car = _closest_active_car(target_world)
		if car:
			var car_pos = car.call("get_vehicle_position")
			if car_pos is Vector2:
				source = _as_manager_local_point(car_pos)
		else:
			# Ensure at least one matching patrol appears in circulation.
			_spawn_car(vtype)

	source = _as_manager_local_point(source)
	if travel_s <= 0.0:
		travel_s = _travel_time_from_source_to_target_s(source, target_world)
	travel_s = max(1.0, travel_s)

	var responder = Node2D.new()
	responder.position = source
	var anim_script = GDScript.new()
	anim_script.source_code = """
extends Node2D
var _sprite: Sprite2D
var _anim_timer: float = 0.0
var _prev_pos: Vector2
func _ready():
	_prev_pos = position
	for c in get_children():
		if c is Sprite2D:
			_sprite = c
			break
func _process(delta):
	if _sprite:
		_anim_timer += delta * 10.0
		_sprite.frame = int(_anim_timer) % 4
		if position.x < _prev_pos.x - 0.1:
			_sprite.flip_h = true
		elif position.x > _prev_pos.x + 0.1:
			_sprite.flip_h = false
	_prev_pos = position
"""
	anim_script.reload()
	responder.set_script(anim_script)

	var icon_path = _vehicle_icon_path(vtype)
	if ResourceLoader.exists(icon_path):
		var tex = load(icon_path)
		if tex is Texture2D:
			var sprite = Sprite2D.new()
			sprite.texture = tex
			sprite.hframes = 4
			sprite.scale = Vector2(2.0, 2.0)
			responder.add_child(sprite)
			
	add_child(responder)

	# ── Siren ─────────────────────────────────────────────────────────────
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_siren(responder, vtype)

	# Find a path using route waypoints instead of direct line
	var path = _find_path_through_route(source, target_world)
	if path.size() < 2:
		path = [source, target_world]
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	emit_signal("response_position_updated", vtype, responder.position)
	
	# Animate along the path waypoints
	var total_dist = 0.0
	for i in range(1, path.size()):
		total_dist += (path[i - 1] as Vector2).distance_to(path[i] as Vector2)
	total_dist = max(total_dist, 1.0)
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var segment_dist = a.distance_to(b)
		# Keep animation duration aligned with gameplay ETA.
		var segment_time = max(0.08, (segment_dist / total_dist) * max(0.25, travel_s))
		tween.tween_method(Callable(self, "_set_responder_position").bind(responder, vtype), a, b, segment_time)

	# Stop siren and emit arrival exactly when responder reaches destination, then fade out.
	tween.tween_callback(func():
		if am:
			am.stop_siren(responder))
	tween.tween_callback(Callable(self, "_emit_response_arrived").bind(vtype, target_world))
	tween.tween_property(responder, "modulate:a", 0.0, 0.25)
	tween.finished.connect(responder.queue_free)


func _travel_time_from_source_to_target_s(source: Vector2, target_world: Vector2) -> float:
	if _map_bounds.is_empty():
		# Fallback to map pixels if we don't have georeferenced bounds.
		var pixel_distance_m = source.distance_to(target_world) * 6.5
		return pixel_distance_m / max(1.0, (professional_response_speed_kph * 1000.0) / 3600.0)
	var src_m = _px_to_mercator(source)
	var dst_m = _px_to_mercator(target_world)
	var distance_m = src_m.distance_to(dst_m)
	return distance_m / max(1.0, (professional_response_speed_kph * 1000.0) / 3600.0)

func _px_to_mercator(px: Vector2) -> Vector2:
	var minx = float(_map_bounds.get("minx", 0.0))
	var miny = float(_map_bounds.get("miny", 0.0))
	var maxx = float(_map_bounds.get("maxx", 1.0))
	var maxy = float(_map_bounds.get("maxy", 1.0))
	var tx = clamp(px.x / float(max(1, image_width)), 0.0, 1.0)
	var ty = clamp(px.y / float(max(1, image_height)), 0.0, 1.0)
	return Vector2(lerp(minx, maxx, tx), lerp(miny, maxy, ty))

func _emit_response_arrived(vehicle_id: String, world_position: Vector2) -> void:
	emit_signal("response_arrived", vehicle_id, world_position)

func _set_responder_position(pos: Vector2, responder: Node2D, vehicle_id: String) -> void:
	if responder == null or not is_instance_valid(responder):
		return
	responder.position = pos
	emit_signal("response_position_updated", vehicle_id, pos)

func _route_point_to_px(pt) -> Vector2:
	var nx = 0.0
	var ny = 0.0
	if typeof(pt) == TYPE_DICTIONARY:
		nx = float(pt.get("x", 0.0))
		ny = float(pt.get("y", 0.0))
	elif typeof(pt) == TYPE_ARRAY and pt.size() >= 2:
		nx = float(pt[0])
		ny = float(pt[1])
	return Vector2(nx * float(image_width), ny * float(image_height))

func _build_route_graph() -> void:
	_route_px_points.clear()
	_route_astar.clear()
	_route_spatial_cells.clear()
	if route_points.is_empty():
		_route_graph_ready = false
		return

	for pt in route_points:
		_route_px_points.append(_route_point_to_px(pt))

	var total_points = _route_px_points.size()
	if total_points == 0:
		_route_graph_ready = false
		return

	# Add all route points as graph nodes and index into spatial hash.
	for i in range(total_points):
		var p = _route_px_points[i] as Vector2
		_route_astar.add_point(i, p)
		_add_point_to_spatial_index(i, p)

	# If the JSON supplies explicit edges, use those ONLY — no shortcuts.
	# This enforces strict road-only navigation (no diagonal cuts).
	if not route_edges.is_empty():
		for edge_any in route_edges:
			if typeof(edge_any) == TYPE_ARRAY and (edge_any as Array).size() >= 2:
				var ea = edge_any as Array
				var i = int(ea[0])
				var j = int(ea[1])
				if i >= 0 and i < total_points and j >= 0 and j < total_points:
					if not _route_astar.are_points_connected(i, j):
						_route_astar.connect_points(i, j, true)
	else:
		# Fallback: sequential links + radius-based shortcuts (old behaviour)
		for i in range(total_points - 1):
			if not _route_astar.are_points_connected(i, i + 1):
				_route_astar.connect_points(i, i + 1, true)

		var radius = max(8.0, route_graph_link_radius_px)
		var radius_sq = radius * radius
		var max_shortcuts = max(0, route_graph_max_shortcuts_per_node)
		for i in range(total_points):
			var pi = _route_px_points[i] as Vector2
			var candidates = _collect_candidates_in_radius(pi, radius)
			var nearby: Array = []
			for c_any in candidates:
				var j = int(c_any)
				if j == i:
					continue
				if abs(j - i) <= 1:
					continue
				var pj = _route_px_points[j] as Vector2
				var dsq = pi.distance_squared_to(pj)
				if dsq <= radius_sq:
					nearby.append({"idx": j, "dist": dsq})

			nearby.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
			var added = 0
			for item in nearby:
				if added >= max_shortcuts:
					break
				var j = int(item["idx"])
				if not _route_astar.are_points_connected(i, j):
					_route_astar.connect_points(i, j, true)
					added += 1

	_route_graph_ready = true

func _spatial_key(cx: int, cy: int) -> String:
	return str(cx) + ":" + str(cy)

func _cell_coords_for_point(px: Vector2) -> Vector2i:
	var cell = max(4.0, route_graph_cell_size_px)
	return Vector2i(int(floor(px.x / cell)), int(floor(px.y / cell)))

func _add_point_to_spatial_index(node_id: int, px: Vector2) -> void:
	var c = _cell_coords_for_point(px)
	var key = _spatial_key(c.x, c.y)
	if not _route_spatial_cells.has(key):
		_route_spatial_cells[key] = []
	(_route_spatial_cells[key] as Array).append(node_id)

func _collect_candidates_in_radius(px: Vector2, radius: float) -> Array:
	var out: Array = []
	if _route_spatial_cells.is_empty():
		return out
	var c = _cell_coords_for_point(px)
	var cell = max(4.0, route_graph_cell_size_px)
	var ring = int(ceil(radius / cell))
	for dx in range(-ring, ring + 1):
		for dy in range(-ring, ring + 1):
			var key = _spatial_key(c.x + dx, c.y + dy)
			if _route_spatial_cells.has(key):
				out.append_array(_route_spatial_cells[key] as Array)
	return out

func _closest_route_index_for_px(px: Vector2) -> int:
	if not _route_graph_ready or _route_px_points.is_empty():
		return 0

	var center = _cell_coords_for_point(px)
	var max_rings = max(1, route_graph_max_nearest_rings)
	var best_idx = 0
	var best_dist = INF
	var found_any = false

	for ring in range(max_rings + 1):
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if ring > 0 and abs(dx) < ring and abs(dy) < ring:
					continue
				var key = _spatial_key(center.x + dx, center.y + dy)
				if not _route_spatial_cells.has(key):
					continue
				for idx_any in (_route_spatial_cells[key] as Array):
					var idx = int(idx_any)
					var d = (_route_px_points[idx] as Vector2).distance_squared_to(px)
					if d < best_dist:
						best_dist = d
						best_idx = idx
						found_any = true
		if found_any and ring >= 1:
			break

	if not found_any:
		for i in range(_route_px_points.size()):
			var d = (_route_px_points[i] as Vector2).distance_squared_to(px)
			if d < best_dist:
				best_dist = d
				best_idx = i
	return best_idx

func _simplify_polyline(points: Array) -> Array:
	if points.size() <= 2:
		return points
	var simplified: Array = [points[0]]
	for i in range(1, points.size() - 1):
		var a = simplified[simplified.size() - 1] as Vector2
		var b = points[i] as Vector2
		var c = points[i + 1] as Vector2
		var ab = b - a
		var bc = c - b
		if ab.length_squared() < 9.0:
			continue
		if bc.length_squared() < 9.0:
			continue
		var turn_cos = ab.normalized().dot(bc.normalized())
		# Skip tiny direction changes to reduce jitter in tweened movement.
		if turn_cos > 0.995:
			continue
		simplified.append(b)
	simplified.append(points[points.size() - 1])
	return simplified

func _find_path_through_route(from: Vector2, to: Vector2) -> Array:
	if route_points.is_empty():
		return [from, to]
	if not _route_graph_ready:
		_build_route_graph()
	if not _route_graph_ready or _route_px_points.is_empty():
		return [from, to]

	var start_idx = _closest_route_index_for_px(from)
	var end_idx = _closest_route_index_for_px(to)
	if start_idx == end_idx:
		return [from, _route_px_points[start_idx], to]

	var id_path = _route_astar.get_id_path(start_idx, end_idx)
	if id_path.is_empty():
		return [from, to]

	var path: Array = [from]
	for id_any in id_path:
		var idx = int(id_any)
		path.append(_route_px_points[idx])
	path.append(to)

	return _simplify_polyline(path)

func _region_load_cmp(a, b) -> int:
	# Compare how many active cars are in the region by testing their centroid
	var a_count = 0
	var b_count = 0
	for car in active_cars:
		if car and car.is_inside_tree():
			var cx = 0.0
			var cy = 0.0
			# guess region by car position normalized
			if car.has_method("get_global_position"):
				cx = car.global_position.x / float(image_width)
				cy = car.global_position.y / float(image_height)
				if a == "north" and cy < 0.33:
					a_count += 1
				if a == "east" and cx > 0.66:
					a_count += 1
				if a == "south" and cy > 0.66:
					a_count += 1
				if b == "north" and cy < 0.33:
					b_count += 1
				if b == "east" and cx > 0.66:
					b_count += 1
				if b == "south" and cy > 0.66:
					b_count += 1
	# prefer region with smaller count (ascending)
	return a_count - b_count

func _on_car_finished(car: Node) -> void:
	var vtype = ""
	if car.has_method("get") and car.get("vehicle_type") != null:
		vtype = String(car.get("vehicle_type"))
	# remove from active list if present
	if car in active_cars:
		active_cars.erase(car)
	# schedule a replacement spawn of the same type so fleet stays balanced
	var delay = _rng.randf_range(respawn_delay_min, respawn_delay_max)
	if vtype != "":
		_spawn_with_delay(delay, vtype)
	else:
		_spawn_with_delay(delay)

func stop_all() -> void:
	for car in active_cars:
		if car and car.is_inside_tree():
			car.stop_and_remove()
	active_cars.clear()

# ── Helper: count active patrol cars of a given type ─────────────────────────
func _count_active_cars_of_type(vtype: String) -> int:
	var count = 0
	for car in active_cars:
		if car and car.is_inside_tree() and String(car.get("vehicle_type")) == vtype:
			count += 1
	return count

func _random_route_slice(min_len: int = 200, max_len: int = 400) -> Array:
	"""Graph-based random walk from a random road node — stays strictly on roads."""
	if _route_px_points.is_empty() or not _route_graph_ready:
		return []
	var steps = _rng.randi_range(min_len, max_len)
	var start_idx = _rng.randi_range(0, _route_px_points.size() - 1)
	var visited_order: Array = [start_idx]
	var current_idx = start_idx
	var prev_idx = -1
	for _step in range(steps):
		var neighbours = _route_astar.get_point_connections(current_idx)
		if neighbours.size() == 0:
			break
		var valid_neighbours = []
		for n in neighbours:
			if n != prev_idx or neighbours.size() == 1:
				valid_neighbours.append(n)
		var next_idx = int(valid_neighbours[_rng.randi_range(0, valid_neighbours.size() - 1)])
		visited_order.append(next_idx)
		prev_idx = current_idx
		current_idx = next_idx
	var seg: Array = []
	for idx in visited_order:
		if idx >= 0 and idx < route_points.size():
			seg.append(route_points[idx])
	return seg


func _build_segments_for_label(label: String, top_th: float, bottom_th: float, right_th: float) -> Array:
	var segs: Array = []
	var cur: Array = []
	for p in route_points:
		var x = 0.0
		var y = 0.0
		if typeof(p) == TYPE_DICTIONARY:
			x = float(p.get("x", 0.0))
			y = float(p.get("y", 0.0))
		elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
			x = float(p[0])
			y = float(p[1])

		var ok: bool = false
		if label == "north":
			ok = y < top_th
		elif label == "east":
			ok = x > right_th
		elif label == "south":
			ok = y > bottom_th

		if ok:
			cur.append(p)
		else:
			if cur.size() > 8:
				segs.append(cur.duplicate(true))
			cur.clear()

	if cur.size() > 8:
		segs.append(cur.duplicate(true))

	return segs
