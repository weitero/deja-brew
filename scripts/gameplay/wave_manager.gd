class_name WaveManager
extends RefCounted

## Manages wave progression, score targets, and level transitions for all levels.
##
## Usage:
##   var wm := WaveManager.new()
##   wm.wave_started.connect(_on_wave_started)
##   wm.wave_completed.connect(_on_wave_completed)
##   wm.level_cleared.connect(_on_level_cleared)
##   wm.init("level_1_hopper")
##   wm.begin_level()
##   # In _physics_process: wm.update(delta)
##   # After score changes: if wm.is_playing() and score >= wm.get_wave_score_target(): wm.complete_wave()

signal wave_started(wave_index: int, wave_name: String, initial_batch: int, trickle_per_rotation: int)
signal wave_completed(wave_index: int)
signal level_cleared(level_id: String)

enum WaveState {
	IDLE,               ## Not yet started.
	WAVE_START_BANNER,  ## Showing the wave name banner before gameplay resumes.
	PLAYING,            ## Active wave gameplay.
	WAVE_END_BANNER,    ## Showing wave-complete banner before next wave.
	LEVEL_CLEAR_BANNER, ## Showing level-clear banner before transitioning out.
	DONE,               ## Level fully complete; transition to Brew Station / next level.
}

const WAVE_BANNER_SEC   := 2.5
const LEVEL_CLEAR_SEC   := 3.5

## All per-level and per-wave configuration data.
const LEVEL_DATA := {
	"level_1_hopper": {
		"display_name": "The Hopper",
		"target_score": 720,
		## ~45 px/s (75 % of the 0.13 normal interval).
		"base_move_interval": 0.175,
		## 3 x 3 blade zone makes the grinder easier to hit (tutorial).
		"grinder_size": 3,
		"extraction_timer_enabled": false,
		"piston_enabled": false,
		"machine_hazards_enabled": false,
		"ingredient_hazards_enabled": false,
		"enemies_enabled": false,
		"water_puddles_enabled": false,
		"pressure_release_enabled": false,
		"waves": [
			{
				"name": "First Steps",
				"initial_batch": 8,
				"trickle_per_rotation": 2,
				"blade_relocates": 0,
				## Cumulative score threshold to end this wave.
				"wave_score_target": 100,
			},
			{
				"name": "Filling the Basket",
				"initial_batch": 12,
				"trickle_per_rotation": 2,
				"blade_relocates": 0,
				"wave_score_target": 360,
			},
			{
				"name": "The Rush",
				"initial_batch": 15,
				"trickle_per_rotation": 3,
				## Blade relocates once mid-wave (handled by run_manager).
				"blade_relocates": 1,
				"wave_score_target": 720,
			},
		],
	},
	"level_2_sort": {
		"display_name": "The Sort",
		"target_score": 800,
		"base_move_interval": 0.13,
		"grinder_size": 2,
		"extraction_timer_enabled": true,
		"piston_enabled": true,
		"machine_hazards_enabled": true,
		"ingredient_hazards_enabled": true,
		"enemies_enabled": false,
		"water_puddles_enabled": true,
		"pressure_release_enabled": false,
		"waves": [
			{
				"name": "Wake Up Call",
				"initial_batch": 10,
				"trickle_per_rotation": 2,
				"blade_relocates": 0,
				"water_puddle_count": 0,
				"wave_score_target": 267,
			},
			{
				"name": "Conveyor Chaos",
				"initial_batch": 12,
				"trickle_per_rotation": 3,
				"blade_relocates": 0,
				"water_puddle_count": 3,
				"wave_score_target": 534,
			},
			{
				"name": "The Wash",
				"initial_batch": 15,
				"trickle_per_rotation": 3,
				"blade_relocates": 2,
				"water_puddle_count": 8,
				"wave_score_target": 800,
			},
		],
	},
	"level_3_roast": {
		"display_name": "The Roast",
		"target_score": 1500,
		"base_move_interval": 0.11,
		"grinder_size": 2,
		"extraction_timer_enabled": true,
		"piston_enabled": true,
		"machine_hazards_enabled": true,
		"ingredient_hazards_enabled": true,
		"enemies_enabled": true,
		"water_puddles_enabled": true,
		"pressure_release_enabled": true,
		"burr_interval": 6.0,
		"piston_interval": 9.0,
		"pressure_interval": 12.0,
		"waves": [
			{
				"name": "The Order Board",
				"initial_batch": 12,
				"trickle_per_rotation": 3,
				"blade_relocates": 0,
				"water_puddle_count": 3,
				"wave_score_target": 500,
			},
			{
				"name": "Scoop Warning",
				"initial_batch": 10,
				"trickle_per_rotation": 4,
				"blade_relocates": 0,
				"water_puddle_count": 3,
				"wave_score_target": 1000,
			},
			{
				"name": "Final Pour",
				"initial_batch": 15,
				"trickle_per_rotation": 4,
				## -1 = relocate every 15 s throughout the wave.
				"blade_relocates": -1,
				"water_puddle_count": 5,
				"wave_score_target": 1500,
			},
		],
	},
}

var level_id: String                = "level_1_hopper"
var current_wave: int               = 0
var wave_state: WaveState           = WaveState.IDLE
var transition_timer: float         = 0.0

## Index of the wave that most recently finished — kept for banner text after
## current_wave is incremented.
var _completed_wave_index: int      = -1

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func init(p_level_id: String) -> void:
	level_id              = p_level_id
	current_wave          = 0
	wave_state            = WaveState.IDLE
	transition_timer      = 0.0
	_completed_wave_index = -1


## Start the first wave.  Call once after init().
func begin_level() -> void:
	current_wave = 0
	_enter_wave_start_banner()


## Call every physics frame so the wave manager advances its timers.
func update(delta: float) -> void:
	if transition_timer <= 0.0:
		return
	transition_timer = maxf(0.0, transition_timer - delta)
	if transition_timer > 0.0:
		return

	match wave_state:
		WaveState.WAVE_START_BANNER:
			wave_state = WaveState.PLAYING
		WaveState.WAVE_END_BANNER:
			current_wave += 1
			if current_wave >= get_wave_count():
				wave_state       = WaveState.LEVEL_CLEAR_BANNER
				transition_timer = LEVEL_CLEAR_SEC
				emit_signal("level_cleared", level_id)
			else:
				_enter_wave_start_banner()
		WaveState.LEVEL_CLEAR_BANNER:
			wave_state = WaveState.DONE


## Call when the current-wave score target has been reached.
func complete_wave() -> void:
	if wave_state != WaveState.PLAYING:
		return
	_completed_wave_index = current_wave
	wave_state            = WaveState.WAVE_END_BANNER
	transition_timer      = WAVE_BANNER_SEC
	emit_signal("wave_completed", current_wave)

# ---------------------------------------------------------------------------
# State queries
# ---------------------------------------------------------------------------

func is_playing() -> bool:
	return wave_state == WaveState.PLAYING


## True while any banner (start, end, or level-clear) is visible.
## The run_manager should freeze physics during this time.
func is_in_banner() -> bool:
	return wave_state in [
		WaveState.WAVE_START_BANNER,
		WaveState.WAVE_END_BANNER,
		WaveState.LEVEL_CLEAR_BANNER,
	]


func is_done() -> bool:
	return wave_state == WaveState.DONE

# ---------------------------------------------------------------------------
# Config accessors
# ---------------------------------------------------------------------------

func get_level_data() -> Dictionary:
	return LEVEL_DATA.get(level_id, LEVEL_DATA["level_1_hopper"])


func get_wave_count() -> int:
	return (get_level_data()["waves"] as Array).size()


func get_wave_config(wave_index: int) -> Dictionary:
	var waves: Array = get_level_data()["waves"]
	if wave_index >= 0 and wave_index < waves.size():
		return waves[wave_index]
	return {}


func get_current_wave_config() -> Dictionary:
	return get_wave_config(current_wave)


## Cumulative score the player must reach to complete the current wave.
func get_wave_score_target() -> int:
	return get_current_wave_config().get("wave_score_target", get_level_score_target())


## Total score target for the whole level (equals the final wave's wave_score_target).
func get_level_score_target() -> int:
	return get_level_data().get("target_score", 300)


func get_level_display_name() -> String:
	return get_level_data().get("display_name", level_id)


## 1-based wave number for UI display.
func get_display_wave_number() -> int:
	return current_wave + 1

# ---------------------------------------------------------------------------
# Banner helpers
# ---------------------------------------------------------------------------

## Progress fraction 0 -> 1 over the duration of the current banner.
func get_banner_progress() -> float:
	var total := WAVE_BANNER_SEC if wave_state != WaveState.LEVEL_CLEAR_BANNER else LEVEL_CLEAR_SEC
	return 1.0 - clampf(transition_timer / total, 0.0, 1.0)


func get_banner_title() -> String:
	match wave_state:
		WaveState.WAVE_START_BANNER:
			var cfg := get_current_wave_config()
			return "WAVE %d  —  %s" % [current_wave + 1, cfg.get("name", "")]
		WaveState.WAVE_END_BANNER:
			return "WAVE %d COMPLETE!" % (_completed_wave_index + 1)
		WaveState.LEVEL_CLEAR_BANNER:
			return "LEVEL CLEAR!"
	return ""


func get_banner_sub_text() -> String:
	match wave_state:
		WaveState.WAVE_START_BANNER:
			var cfg := get_current_wave_config()
			return "Batch: %d beans  ·  Trickle: %d / rotation" % [
				cfg.get("initial_batch", 8),
				cfg.get("trickle_per_rotation", 2),
			]
		WaveState.WAVE_END_BANNER:
			if _completed_wave_index + 1 < get_wave_count():
				return "Get ready for the next wave..."
			else:
				return "Preparing final pour..."
		WaveState.LEVEL_CLEAR_BANNER:
			return get_level_display_name() + "  —  Complete!"
	return ""

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _enter_wave_start_banner() -> void:
	wave_state       = WaveState.WAVE_START_BANNER
	transition_timer = WAVE_BANNER_SEC
	var cfg          := get_current_wave_config()
	emit_signal(
		"wave_started",
		current_wave,
		cfg.get("name", "Wave %d" % (current_wave + 1)),
		cfg.get("initial_batch", 8),
		cfg.get("trickle_per_rotation", 2),
	)
