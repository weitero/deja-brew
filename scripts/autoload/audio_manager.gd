extends Node

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var _bgm_machine: AudioStreamPlayer
var _bgm_cafe: AudioStreamPlayer
var _ambient_hum: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _stream_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("audio_manager")
	_setup_players()
	_load_stream_cache()
	_start_bgm_layers()

func _setup_players() -> void:
	_bgm_machine = AudioStreamPlayer.new()
	_bgm_machine.name = "BgmMachine"
	_bgm_machine.bus = BUS_MUSIC
	_bgm_machine.volume_db = -14.0
	add_child(_bgm_machine)

	_bgm_cafe = AudioStreamPlayer.new()
	_bgm_cafe.name = "BgmCafe"
	_bgm_cafe.bus = BUS_MUSIC
	_bgm_cafe.volume_db = -22.0
	add_child(_bgm_cafe)

	_ambient_hum = AudioStreamPlayer.new()
	_ambient_hum.name = "AmbientHum"
	_ambient_hum.bus = BUS_SFX
	_ambient_hum.volume_db = -18.0
	add_child(_ambient_hum)

	for i: int in range(8):
		var p := AudioStreamPlayer2D.new()
		p.name = "Sfx%d" % i
		p.bus = BUS_SFX
		p.max_distance = 1800.0
		p.attenuation = 1.4
		add_child(p)
		_sfx_pool.append(p)

func _load_stream_cache() -> void:
	var paths := _collect_audio_paths("res://assets/audio")
	for p in paths:
		var stream := load(p)
		if stream == null:
			continue
		var key := String(p.get_file().get_basename()).to_lower()
		_stream_cache[key] = stream

func _collect_audio_paths(base: String) -> Array[String]:
	var result: Array[String] = []
	_scan_dir(base, result)
	return result

func _scan_dir(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full, out)
		else:
			var ext := entry.get_extension().to_lower()
			if ext == "ogg" or ext == "wav" or ext == "mp3":
				out.append(full)
	dir.list_dir_end()

func _match_stream(keys: Array[String]) -> AudioStream:
	for key in keys:
		for existing in _stream_cache.keys():
			if String(existing).findn(key) >= 0:
				return _stream_cache[existing]
	return null

func _start_bgm_layers() -> void:
	_bgm_machine.stream = _match_stream(["machine", "industrial", "bgm", "music"])
	_bgm_cafe.stream = _match_stream(["cafe", "coffee", "ambient", "layer"])
	_ambient_hum.stream = _match_stream(["hum", "machine_loop", "loop"])
	if _bgm_machine.stream:
		_bgm_machine.play()
	if _bgm_cafe.stream:
		_bgm_cafe.play()
	if _ambient_hum.stream:
		_ambient_hum.play()

func start_ambience() -> void:
	if _ambient_hum.stream and not _ambient_hum.playing:
		_ambient_hum.play()

func stop_all() -> void:
	_bgm_machine.stop()
	_bgm_cafe.stop()
	_ambient_hum.stop()
	for p in _sfx_pool:
		p.stop()

func set_machine_intensity(value: float) -> void:
	var t := clampf(value, 0.0, 1.0)
	_bgm_machine.volume_db = lerpf(-20.0, -8.0, t)
	_bgm_cafe.volume_db = lerpf(-26.0, -14.0, 1.0 - t)
	_ambient_hum.pitch_scale = lerpf(0.92, 1.15, t)

func _find_free_sfx() -> AudioStreamPlayer2D:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0] if not _sfx_pool.is_empty() else null

func _play_event(keys: Array[String], world_pos: Vector2 = Vector2.ZERO, pitch := 1.0, volume_db := 0.0) -> void:
	var stream := _match_stream(keys)
	if stream == null:
		return
	var player := _find_free_sfx()
	if player == null:
		return
	player.stream = stream
	player.global_position = world_pos
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

func play_menu_move() -> void:
	_play_event(["menu_move", "navigate", "tick", "ui_move"], Vector2.ZERO, 1.0, -8.0)

func play_menu_confirm() -> void:
	_play_event(["menu_confirm", "confirm", "select", "ui_confirm"], Vector2.ZERO, 1.0, -6.0)

func play_wave_start() -> void:
	_play_event(["wave", "start", "stinger"], Vector2.ZERO, 1.0, -4.0)

func play_rally(world_pos: Vector2) -> void:
	_play_event(["rally", "call", "whistle"], world_pos, 1.0, -3.0)

func play_grind(world_pos: Vector2) -> void:
	_play_event(["grind", "crusher", "impact"], world_pos, randf_range(0.92, 1.08), -5.0)

func play_hazard(world_pos: Vector2) -> void:
	_play_event(["hazard", "hit", "metal", "impact"], world_pos, randf_range(0.9, 1.15), -4.0)

func play_extraction() -> void:
	_play_event(["pull", "shot", "espresso", "extract"], Vector2.ZERO, 1.0, -3.0)

func play_god_shot() -> void:
	_play_event(["god", "gold", "success", "perfect"], Vector2.ZERO, 1.0, -2.0)

func play_game_over() -> void:
	_play_event(["game_over", "fail", "loss"], Vector2.ZERO, 1.0, -2.0)
