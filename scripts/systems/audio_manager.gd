extends Node

## AudioManager – global autoload
## Handles BGM (looping background music), UI click SFX, and vehicle siren SFX.
##
## Volume hierarchy:
##   Master slider  -> AudioServer Master bus -> affects everything
##   BGM slider     -> _bgm_player.volume_db  -> music only
##   Siren slider   -> _siren_volume_db        -> dispatch sirens only
##   UI clicks      -> _click_player           -> ONLY affected by Master, NOT by Siren slider

const BGM_STREAMS = [
	preload("res://assets/Audio 2/BGM 1.wav"),
	preload("res://assets/Audio 2/BGM 2.wav"),
	preload("res://assets/Audio 2/BGM 3.wav"),
	preload("res://assets/Audio 2/BGM 4.wav"),
	preload("res://assets/Audio 2/BGM 5.wav")
]
const CLICK_STREAM = preload("res://assets/Audio 2/Click SFX.wav")
const RING_STREAM  = preload("res://assets/Audio 2/Phone Ring.mp3")

## Siren paths + per-file gain offsets to normalize perceived loudness.
const SIREN_DATA := {
	"police":     {"stream": preload("res://assets/Audio 2/Police Siren.mp3"),    "gain_db":  10.0},
	"fire_truck": {"stream": preload("res://assets/Audio 2/Firetruck - Siren.mp3"), "gain_db": 12.0},
	"ambulance":  {"stream": preload("res://assets/Audio 2/Ambulance Siren.mp3"),  "gain_db": -10.0},
}

var _siren_volume_db: float = -3.0

var _bgm_player:   AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _ring_player:  AudioStreamPlayer

var _bgm_interval_timer: Timer

# BGM shuffle-deck state — avoids immediate repeats across track changes.
var _bgm_shuffled_deck: Array = []
var _last_played_bgm_idx: int = -1
var _current_bgm_loops: int = 0

var _siren_players: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -6.0
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	_bgm_interval_timer = Timer.new()
	_bgm_interval_timer.name = "BGMIntervalTimer"
	_bgm_interval_timer.one_shot = true
	_bgm_interval_timer.timeout.connect(_on_bgm_interval_timeout)
	add_child(_bgm_interval_timer)

	_click_player = AudioStreamPlayer.new()
	_click_player.name = "ClickPlayer"
	_click_player.bus = "Master"
	_click_player.volume_db = 0.0
	if CLICK_STREAM:
		_click_player.stream = CLICK_STREAM as AudioStream
	add_child(_click_player)

	_ring_player = AudioStreamPlayer.new()
	_ring_player.name = "RingPlayer"
	_ring_player.bus = "Master"
	_ring_player.volume_db = 0.0
	if RING_STREAM:
		var ring_str = RING_STREAM as AudioStream
		ring_str.loop = true
		_ring_player.stream = ring_str
	add_child(_ring_player)

	await get_tree().process_frame
	_load_saved_volumes()

# ── Helper: true when current scene is the main menu ──────────────────────────
func _is_main_menu_active() -> bool:
	var scene = get_tree().current_scene
	if scene != null and scene.name == "MainMenu":
		return true
	# Fallback if current_scene isn't updated yet during _ready
	if get_tree().root.has_node("MainMenu"):
		return true
	return false

func _on_node_added(node: Node) -> void:
	if node.is_class("BaseButton") or node.is_class("Button") or node.is_class("TextureButton"):
		if not node.is_connected("pressed", Callable(self, "play_click")):
			node.pressed.connect(Callable(self, "play_click"))

func _set_stream_loop(stream: AudioStream, loop: bool) -> void:
	if stream == null:
		return
	if "loop_mode" in stream:
		stream.set("loop_mode", 1 if loop else 0)
	elif "loop" in stream:
		stream.set("loop", loop)

func _on_bgm_finished() -> void:
	if _is_main_menu_active():
		_play_specific_bgm(0)
	else:
		if _bgm_player.stream:
			var stream_length = _bgm_player.stream.get_length()
			_current_bgm_loops += 1
			var total_played_time = _current_bgm_loops * stream_length
			if total_played_time < 45.0:
				_bgm_player.play()
				return
		_bgm_interval_timer.start(randf_range(20.0, 40.0))

func _on_bgm_interval_timeout() -> void:
	if _is_main_menu_active():
		_play_specific_bgm(0)
	else:
		_play_random_bgm()

func _play_specific_bgm(idx: int) -> void:
	if idx < 0 or idx >= BGM_STREAMS.size():
		return
	var stream = BGM_STREAMS[idx] as AudioStream
	if not stream:
		return
	_bgm_player.stream = stream

	if _is_main_menu_active():
		_set_stream_loop(stream, true)
	else:
		# In game, we want the song to NOT loop so it triggers the finished signal
		_set_stream_loop(stream, false)
		_current_bgm_loops = 0

	_bgm_player.play()

func _play_random_bgm() -> void:
	if _bgm_shuffled_deck.is_empty():
		_reshuffle_bgm_deck()
	var idx = _bgm_shuffled_deck.pop_front()
	_last_played_bgm_idx = idx
	_play_specific_bgm(idx)

func _reshuffle_bgm_deck() -> void:
	_bgm_shuffled_deck.clear()
	for i in range(BGM_STREAMS.size()):
		if i == 0:
			continue  # BGM 1 is reserved for Main Menu only
		_bgm_shuffled_deck.append(i)
	_bgm_shuffled_deck.shuffle()

	# Prevent the same track from playing twice in a row across reshuffles.
	if _bgm_shuffled_deck.size() > 1 and _bgm_shuffled_deck[0] == _last_played_bgm_idx:
		var tmp = _bgm_shuffled_deck[0]
		_bgm_shuffled_deck[0] = _bgm_shuffled_deck[1]
		_bgm_shuffled_deck[1] = tmp

## Apply saved audio volumes from GameState.
func _load_saved_volumes() -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_audio_volumes"):
		return
	var vols: Dictionary = state.call("get_audio_volumes")
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx,
			linear_to_db(max(float(vols.get("master", 1.0)), 0.001)))
	if _bgm_player:
		_bgm_player.volume_db = linear_to_db(max(float(vols.get("bgm", 0.7)), 0.001)) - 6.0
	_siren_volume_db = linear_to_db(max(float(vols.get("siren", 0.7)), 0.001)) - 3.0

## Start BGM if it is not already playing.
func play_bgm() -> void:
	if _is_main_menu_active():
		_bgm_interval_timer.stop()
		if _bgm_player.stream == null or _bgm_player.stream != BGM_STREAMS[0]:
			_play_specific_bgm(0)
		elif not _bgm_player.playing:
			_bgm_player.play()
	else:
		if _bgm_player.stream == BGM_STREAMS[0]:
			# Transitioned from main menu: stop main menu BGM, start interval
			_bgm_player.stop()
			_bgm_interval_timer.start(randf_range(10.0, 20.0))
		elif _bgm_player.stream == null:
			# Not playing anything yet, start interval
			if _bgm_interval_timer.is_stopped():
				_bgm_interval_timer.start(randf_range(5.0, 15.0))
		elif not _bgm_player.playing:
			if _bgm_interval_timer.is_stopped():
				_bgm_player.play()

## Stop BGM.
func stop_bgm() -> void:
	if _bgm_interval_timer:
		_bgm_interval_timer.stop()
	if _bgm_player:
		_bgm_player.stop()

## Play the UI click sound.
func play_click() -> void:
	if _click_player and _click_player.stream:
		_click_player.play()

## Start playing the phone ring sound (loops).
func play_ring() -> void:
	if _ring_player and not _ring_player.playing:
		_ring_player.play()

## Stop the phone ring sound.
func stop_ring() -> void:
	if _ring_player:
		_ring_player.stop()

func play_siren(responder: Node, vehicle_type: String) -> void:
	if responder == null or not is_instance_valid(responder):
		return
	var vtype = vehicle_type.to_lower().strip_edges()
	if not SIREN_DATA.has(vtype):
		vtype = "police"
	var entry: Dictionary = SIREN_DATA[vtype]
	var stream = entry["stream"] as AudioStream
	if not stream:
		return

	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.set_meta("vtype", vtype)
	player.volume_db = _siren_volume_db + float(entry["gain_db"])
	stream.loop = true
	player.stream = stream
	responder.add_child(player)
	player.play()

	var responder_id = responder.get_instance_id()
	_siren_players[responder_id] = player

	# Automatically remove entry when player or responder exits the tree / is freed
	player.tree_exited.connect(func():
		_siren_players.erase(responder_id)
	)
	responder.tree_exited.connect(func():
		_siren_players.erase(responder_id)
	)

func stop_siren(responder: Node) -> void:
	if responder == null:
		return
	var iid = responder.get_instance_id()
	if _siren_players.has(iid):
		var p = _siren_players[iid]
		_siren_players.erase(iid)
		if is_instance_valid(p):
			var tween = create_tween()
			tween.tween_property(p, "volume_db", -80.0, 2.0).set_trans(Tween.TRANS_SINE)
			tween.finished.connect(func():
				if is_instance_valid(p):
					p.stop()
					p.queue_free()
			)

func set_siren_volume_db(db: float) -> void:
	_siren_volume_db = db
	for iid in _siren_players.keys():
		var p = _siren_players[iid]
		if is_instance_valid(p):
			var vtype = p.get_meta("vtype", "") if p.has_meta("vtype") else ""
			var offset: float = float(SIREN_DATA[vtype]["gain_db"]) if SIREN_DATA.has(vtype) else 0.0
			p.volume_db = db + offset
		else:
			_siren_players.erase(iid)

func stop_all_sfx() -> void:
	stop_bgm()
	stop_ring()
	for iid in _siren_players.keys():
		var p = _siren_players[iid]
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_siren_players.clear()
