extends Node2D

const GRID_SIZE := Vector2i(28, 18)
const CELL_SIZE := 24
const HUD_PRIMARY_HEIGHT := 84
const HUD_SECONDARY_HEIGHT := 30
const HUD_HEIGHT := HUD_PRIMARY_HEIGHT + HUD_SECONDARY_HEIGHT
const BOARD_PADDING := 24

const COLOR_BG_TOP := Color("1d1712")
const COLOR_BG_BOTTOM := Color("100d0a")
const COLOR_PANEL := Color("2a2018")
const COLOR_PANEL_EDGE := Color("674b34")
const COLOR_GRID_A := Color("4a4d50")
const COLOR_GRID_B := Color("3f4244")
const COLOR_GRID_LINE := Color(0.18, 0.16, 0.14, 0.55)
const COLOR_METAL_BRUSH := Color(0.79, 0.77, 0.72, 0.20)
const COLOR_METAL_SHADOW := Color(0.18, 0.17, 0.16, 0.22)
const COLOR_WALL_METAL := Color("57504a")
const COLOR_WALL_LIP := Color("7a6c5e")
const COLOR_COPPER := Color("b87333")
const COLOR_BRASS := Color("d0a45a")
const COLOR_STEAM := Color("d7c3a6", 0.4)
const COLOR_SNAKE_BODY := Color("6e4328")
const COLOR_SNAKE_HIGHLIGHT := Color("a76a3b")
const COLOR_SNAKE_HEAD := Color("835231")
const COLOR_FOOD := Color("9a653b")
const COLOR_TEXT := Color("e6d8bf")
const COLOR_DANGER := Color("d36641")
const BEAN_SPAWN_SHADOW := 0.10
const BEAN_SPAWN_APPEAR := 0.10
const BEAN_SPAWN_BOUNCE := 0.14
const BEAN_SPAWN_SETTLE := 0.08
const BEAN_SPAWN_TOTAL := BEAN_SPAWN_SHADOW + BEAN_SPAWN_APPEAR + BEAN_SPAWN_BOUNCE + BEAN_SPAWN_SETTLE
var grinder_size: int = 2
const GRINDER_TELEGRAPH_TIME := 2.0
const GRINDER_RELOCATE_INTERVAL := 5.0
const GRIND_POP_LIFE := 0.20
const GRIND_STEP_INTERVAL := 0.035
const GRINDER_DOSE_CAP := 18
const WASTE_FRESHNESS_PENALTY := 3.0
const GROUND_FRESHNESS_GAIN := 2.0
const WASTE_SPILL_LIFE := 0.45
const FRESHNESS_MAX := 100.0
const FRESHNESS_DRAIN_PER_SEC := 0.5
const RALLY_RADIUS_CELLS := 3.0
const RALLY_COOLDOWN_SEC := 3.0
const RESUME_COUNTDOWN_SEC := 3.0
const EXTRACTION_AUTO_PULL_SEC := 36.0
const EXTRACTION_FRESHNESS_MISS_PENALTY := 5.0
const BURR_ROTATION_INTERVAL := 8.0
const PLAYFIELD_SAFE_MARGIN := 1
const CHAIN_SCATTER_FRESHNESS_LOSS := 2.0
const CONVEYOR_PUSH_INTERVAL := 0.8
const OIL_SLICK_SLIDE_SEC := 1.0
const PISTON_INTERVAL := 12.0
const PISTON_TELEGRAPH_SEC := 2.0
const PISTON_ACTIVE_SEC := 3.0
const PEBBLE_COUNT := 6
const ROTTEN_BEAN_COUNT := 5
const BROKEN_BEAN_COUNT := 5
const ROTTEN_SPREAD_INTERVAL := 1.0
const SHAKE_PURGE_WINDOW_SEC := 0.45
const SHAKE_PURGE_TURNS := 3
const DECAF_COUNT := 3
const WATER_DROP_COUNT := 3
const DECAF_MOVE_INTERVAL := 0.45
const WATER_DROP_MOVE_INTERVAL := 0.24
const ENEMY_BEAN_LOSS_FRESHNESS := 5.0
const SCOOP_INTERVAL := 14.0
const SCOOP_TELEGRAPH_SEC := 2.0
const SCOOP_RADIUS_CELLS := 2.6
const ARM_INTERVAL := 11.0
const ARM_TELEGRAPH_SEC := 1.0
const ARM_ACTIVE_SEC := 0.8
const ARM_PUSH_CELLS := 2
const LEVEL_ORDER := ["level_1_hopper", "level_2_sort", "level_3_roast"]

## Water puddles (L2+)
const WASHED_BUFF_DURATION        := 10.0   ## seconds the Washed ×1.5 buff lasts
const WATER_WASHED_SCORE_MULT     := 1.5
const WATER_EXPOSURE_LIMIT        := 2.0    ## seconds in water before bean loss
## Pressure Release (L3)
const PRESSURE_RELEASE_TELEGRAPH_SEC := 2.0
const PRESSURE_RELEASE_PUSH_CELLS   := 2

var board_origin := Vector2.ZERO
var board_size := Vector2.ZERO
var ui_scale := 1.0
var _last_viewport_size := Vector2.ZERO

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var idle_beans: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()

var score := 0
var best_score := 0

var performance_score := 0
var adaptive_enemy_speed := 1.0
var saved_high_score := 0
var move_interval := 0.1444  # 0.9x speed constant
var move_accumulator := 0.0
var freshness := FRESHNESS_MAX
var is_paused := false
var game_over := false
var time_alive := 0.0
var hud_font: Font

enum GameState {
	START_MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	LEVEL_COMPLETE,
}

var game_state: GameState = GameState.START_MENU
var start_menu_index := 0
var pause_menu_index := 0
var start_menu_options := ["START RUN", "QUIT"]
var pause_menu_options := ["RESUME", "RESTART", "QUIT"]
var wake_pulses: Array[Dictionary] = []
var bean_spawn_timer := 0.0
var bean_trickle_interval := 8.0
var bean_spawn_age: Dictionary = {}
var grinder_origin: Vector2i = Vector2i(-1, -1)
var grinder_angle := 0.0
var grinder_active := false
var grinder_telegraph_timer := 0.0
var grinder_relocate_timer := 0.0
var is_grinding := false
var grind_step_timer := 0.0
var grind_pops: Array[Dictionary] = []
var grind_grounded_count := 0
var grind_wasted_count := 0
var waste_spills: Array[Dictionary] = []
var rally_cooldown_left := 0.0
var resume_countdown_left := 0.0
var extraction_active := false
var extraction_timer := 0.0
var extraction_base_score := 0
var extraction_feedback := ""
var extraction_feedback_ttl := 0.0
var burr_timer := BURR_ROTATION_INTERVAL
var burr_phase_index := 0
var grinding_teeth_cells: Array[Vector2i] = []
var gear_gap_cells: Array[Vector2i] = []
var oil_slick_cells: Array[Vector2i] = []
var conveyor_cells: Dictionary = {}
var conveyor_push_timer := CONVEYOR_PUSH_INTERVAL
var oil_slick_timer := 0.0
var piston_timer := PISTON_INTERVAL
var piston_telegraph_left := 0.0
var piston_active_left := 0.0
var piston_row := -1
var pebble_cells: Array[Vector2i] = []
var rotten_bean_cells: Array[Vector2i] = []
var broken_bean_cells: Array[Vector2i] = []
var broken_segment_indices: Array[int] = []
var rotten_segment_indices: Array[int] = []
var decaf_segment_indices: Array[int] = []
var rotten_spread_timer := ROTTEN_SPREAD_INTERVAL
var shake_combo_window_left := 0.0
var shake_combo_count := 0
var decaf_beans: Array[Dictionary] = []
var water_drops: Array[Dictionary] = []
var decaf_move_timer := DECAF_MOVE_INTERVAL
var water_drop_move_timer := WATER_DROP_MOVE_INTERVAL
var scoop_timer := SCOOP_INTERVAL
var scoop_telegraph_left := 0.0
var scoop_center := Vector2i(-1, -1)
var arm_timer := ARM_INTERVAL
var arm_telegraph_left := 0.0
var arm_active_left := 0.0
var arm_is_row := true
var arm_line_index := -1
var arm_push_dir := Vector2i.RIGHT
var arm_applied := false

## Level / wave integration ------------------------------------------------
const WaveManagerScript = preload("res://scripts/gameplay/wave_manager.gd")
@export var level_id: String = "level_1_hopper"
var wave_mgr: WaveManagerScript
## Runtime flags driven by the active level config.
var extraction_timer_enabled: bool = true
var piston_enabled: bool = true
var machine_hazards_enabled: bool = true
var ingredient_hazards_enabled: bool = true
var enemies_enabled: bool = true
## Trickle count is updated each time a new wave starts.
var current_trickle_per_rotation: int = 2
## Runtime flags for L2/L3 mechanics.
var water_puddles_enabled: bool = false
var pressure_release_enabled: bool = false
## Per-level machine-cycle intervals (set by _apply_level_config).
var active_burr_interval: float = BURR_ROTATION_INTERVAL
var active_piston_interval: float = PISTON_INTERVAL
var active_pressure_interval: float = 15.0
## Water puddle state.
var water_puddle_cells: Array[Vector2i] = []
var washed_buff_timer: float = 0.0
var water_exposure_timer: float = 0.0
## Pressure-release state.
var pressure_release_timer: float = 0.0
var pressure_release_telegraph_timer: float = 0.0
var pressure_vent_side: int = 0   ## 0=left→R  1=right→L  2=top→D  3=bottom→U
## Mid-wave blade relocation: 0=none  -1=every 15 s  N=N remaining relocations.
var mid_wave_relocations_remaining: int = 0

func _ready() -> void:
	wave_mgr = WaveManagerScript.new()
	wave_mgr.wave_started.connect(_on_wave_started)
	wave_mgr.wave_completed.connect(_on_wave_completed)
	wave_mgr.level_cleared.connect(_on_level_cleared)
	wave_mgr.init(level_id)
	rng.randomize()
	load_high_score()
	hud_font = ThemeDB.fallback_font
	_update_ui_scale()
	_last_viewport_size = Vector2(get_window().size)

	set_process(true)
	set_physics_process(true)
	snake.clear()
	idle_beans.clear()
	wake_pulses.clear()
	bean_spawn_age.clear()
	bean_spawn_timer = 0.0
	grinder_origin = Vector2i(-1, -1)
	grinder_angle = 0.0
	grinder_active = false
	grinder_telegraph_timer = 0.0
	grinder_relocate_timer = GRINDER_RELOCATE_INTERVAL
	is_grinding = false
	grind_step_timer = 0.0
	grind_pops.clear()
	grind_grounded_count = 0
	grind_wasted_count = 0
	waste_spills.clear()
	rally_cooldown_left = 0.0
	resume_countdown_left = 0.0
	extraction_active = false
	extraction_timer = 0.0
	extraction_base_score = 0
	extraction_feedback = ""
	extraction_feedback_ttl = 0.0
	burr_timer = BURR_ROTATION_INTERVAL
	burr_phase_index = 0
	grinding_teeth_cells.clear()
	gear_gap_cells.clear()
	oil_slick_cells.clear()
	conveyor_cells.clear()
	conveyor_push_timer = CONVEYOR_PUSH_INTERVAL
	oil_slick_timer = 0.0
	piston_timer = PISTON_INTERVAL
	piston_telegraph_left = 0.0
	piston_active_left = 0.0
	piston_row = -1
	pebble_cells.clear()
	rotten_bean_cells.clear()
	broken_bean_cells.clear()
	broken_segment_indices.clear()
	rotten_segment_indices.clear()
	decaf_segment_indices.clear()
	rotten_spread_timer = ROTTEN_SPREAD_INTERVAL
	shake_combo_window_left = 0.0
	shake_combo_count = 0
	decaf_beans.clear()
	water_drops.clear()
	decaf_move_timer = DECAF_MOVE_INTERVAL
	water_drop_move_timer = WATER_DROP_MOVE_INTERVAL
	scoop_timer = SCOOP_INTERVAL
	scoop_telegraph_left = 0.0
	scoop_center = Vector2i(-1, -1)
	arm_timer = ARM_INTERVAL
	arm_telegraph_left = 0.0
	arm_active_left = 0.0
	arm_is_row = true
	arm_line_index = -1
	arm_push_dir = Vector2i.RIGHT
	arm_applied = false
	game_state = GameState.START_MENU
	best_score = max(best_score, saved_high_score)

func load_high_score() -> void:
	var save_file := ConfigFile.new()
	if save_file.load("user://kamikaze_save.cfg") != OK:
		saved_high_score = 0
		return
	saved_high_score = int(save_file.get_value("scores", "high_score", 0))

func save_high_score_if_needed() -> void:
	if score <= saved_high_score:
		return
	saved_high_score = score
	var save_file := ConfigFile.new()
	save_file.set_value("scores", "high_score", saved_high_score)
	save_file.save("user://kamikaze_save.cfg")

func start_new_run() -> void:
	score = 0
	move_accumulator = 0.0
	freshness = FRESHNESS_MAX
	time_alive = 0.0
	game_over = false
	is_paused = false

	snake.clear()
	var start := Vector2i(int(GRID_SIZE.x / 2), int(GRID_SIZE.y / 2))
	snake.append(start)

	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	idle_beans.clear()
	bean_spawn_age.clear()

	# Apply level-specific config before placing the grinder or hazards.
	wave_mgr.init(level_id)
	_apply_level_config()
	_update_ui_scale()

	place_grinder_random()
	setup_machine_hazards()
	setup_ingredient_hazards()
	setup_enemy_hazards()
	# Initial beans are spawned by _on_wave_started when wave_mgr.begin_level() fires.
	bean_spawn_timer = 0.0
	grinder_angle = 0.0
	grinder_active = false
	grinder_telegraph_timer = GRINDER_TELEGRAPH_TIME
	grinder_relocate_timer = 999999.0      ## wave_mgr sets the real value via _on_wave_started
	is_grinding = false
	grind_step_timer = 0.0
	grind_pops.clear()
	grind_grounded_count = 0
	grind_wasted_count = 0
	waste_spills.clear()
	rally_cooldown_left = 0.0
	resume_countdown_left = 0.0
	extraction_active = false
	extraction_timer = 0.0
	extraction_base_score = 0
	extraction_feedback = ""
	extraction_feedback_ttl = 0.0
	burr_timer = active_burr_interval
	burr_phase_index = 0
	conveyor_push_timer = CONVEYOR_PUSH_INTERVAL
	oil_slick_timer = 0.0
	piston_timer = active_piston_interval
	piston_telegraph_left = 0.0
	piston_active_left = 0.0
	piston_row = -1
	broken_segment_indices.clear()
	rotten_segment_indices.clear()
	decaf_segment_indices.clear()
	rotten_spread_timer = ROTTEN_SPREAD_INTERVAL
	shake_combo_window_left = 0.0
	shake_combo_count = 0
	decaf_move_timer = DECAF_MOVE_INTERVAL
	water_drop_move_timer = WATER_DROP_MOVE_INTERVAL
	scoop_timer = SCOOP_INTERVAL
	scoop_telegraph_left = 0.0
	scoop_center = Vector2i(-1, -1)
	arm_timer = ARM_INTERVAL
	arm_telegraph_left = 0.0
	arm_active_left = 0.0
	arm_is_row = true
	arm_line_index = -1
	arm_push_dir = Vector2i.RIGHT
	arm_applied = false
	wake_pulses.clear()
	water_puddle_cells.clear()
	washed_buff_timer            = 0.0
	water_exposure_timer         = 0.0
	pressure_release_timer       = 0.0
	pressure_release_telegraph_timer = 0.0
	pressure_vent_side           = 0
	mid_wave_relocations_remaining = 0

	# Begin the first wave — fires wave_started signal which spawns the initial batch.
	wave_mgr.begin_level()
	queue_redraw()

func random_inner_cell(occupied: Dictionary) -> Vector2i:
	for _i: int in range(300):
		var candidate := Vector2i(
			rng.randi_range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.x - 1 - PLAYFIELD_SAFE_MARGIN),
			rng.randi_range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.y - 1 - PLAYFIELD_SAFE_MARGIN)
		)
		if not occupied.has(candidate) and not is_grinder_cell(candidate):
			occupied[candidate] = true
			return candidate
	return Vector2i(PLAYFIELD_SAFE_MARGIN + 1, PLAYFIELD_SAFE_MARGIN + 1)

func setup_machine_hazards() -> void:
	grinding_teeth_cells.clear()
	gear_gap_cells.clear()
	oil_slick_cells.clear()
	conveyor_cells.clear()

	if not machine_hazards_enabled:
		return

	var occupied := {}
	for cell in get_grinder_cells():
		occupied[cell] = true

	for _i: int in range(4):
		grinding_teeth_cells.append(random_inner_cell(occupied))
	for _j: int in range(6):
		gear_gap_cells.append(random_inner_cell(occupied))
	for _k: int in range(4):
		oil_slick_cells.append(random_inner_cell(occupied))

	var top_row := rng.randi_range(3, GRID_SIZE.y - 4)
	var bottom_row := rng.randi_range(3, GRID_SIZE.y - 4)
	if abs(top_row - bottom_row) < 3:
		bottom_row = clampi(bottom_row + 3, 3, GRID_SIZE.y - 4)
	for x: int in range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.x - PLAYFIELD_SAFE_MARGIN):
		conveyor_cells[Vector2i(x, top_row)] = Vector2i.RIGHT
		conveyor_cells[Vector2i(x, bottom_row)] = Vector2i.LEFT

func setup_ingredient_hazards() -> void:
	pebble_cells.clear()
	rotten_bean_cells.clear()
	broken_bean_cells.clear()

	if not ingredient_hazards_enabled:
		return

	var occupied := {}
	for cell in get_grinder_cells():
		occupied[cell] = true
	for cell in grinding_teeth_cells:
		occupied[cell] = true
	for cell in gear_gap_cells:
		occupied[cell] = true
	for cell in oil_slick_cells:
		occupied[cell] = true
	for cell_key in conveyor_cells.keys():
		occupied[cell_key] = true

	for _i: int in range(PEBBLE_COUNT):
		pebble_cells.append(random_inner_cell(occupied))
	for _j: int in range(ROTTEN_BEAN_COUNT):
		rotten_bean_cells.append(random_inner_cell(occupied))
	for _k: int in range(BROKEN_BEAN_COUNT):
		broken_bean_cells.append(random_inner_cell(occupied))

func random_cardinal_dir() -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	return dirs[rng.randi_range(0, dirs.size() - 1)]

func setup_enemy_hazards() -> void:
	decaf_beans.clear()
	water_drops.clear()

	if not enemies_enabled:
		return

	var occupied := {}
	for cell in get_grinder_cells():
		occupied[cell] = true
	for cell in grinding_teeth_cells:
		occupied[cell] = true
	for cell in gear_gap_cells:
		occupied[cell] = true
	for cell in oil_slick_cells:
		occupied[cell] = true
	for cell in pebble_cells:
		occupied[cell] = true
	for cell in rotten_bean_cells:
		occupied[cell] = true
	for cell in broken_bean_cells:
		occupied[cell] = true
	for cell_key in conveyor_cells.keys():
		occupied[cell_key] = true

	for _i: int in range(DECAF_COUNT):
		var cell := random_inner_cell(occupied)
		decaf_beans.append({"cell": cell, "dir": random_cardinal_dir()})

	for _j: int in range(WATER_DROP_COUNT):
		var wcell := random_inner_cell(occupied)
		water_drops.append({"cell": wcell, "dir": random_cardinal_dir()})

func is_cell_in_list(cell: Vector2i, list: Array[Vector2i]) -> bool:
	for entry in list:
		if entry == cell:
			return true
	return false

func is_pebble_at(cell: Vector2i) -> bool:
	return is_cell_in_list(cell, pebble_cells)

func is_rotten_bean_at(cell: Vector2i) -> bool:
	return is_cell_in_list(cell, rotten_bean_cells)

func is_broken_bean_at(cell: Vector2i) -> bool:
	return is_cell_in_list(cell, broken_bean_cells)

func remove_vector2i_from_list(cell: Vector2i, list: Array[Vector2i]) -> bool:
	for i: int in range(list.size()):
		if list[i] == cell:
			list.remove_at(i)
			return true
	return false

func remove_rotten_bean_at(cell: Vector2i) -> bool:
	return remove_vector2i_from_list(cell, rotten_bean_cells)

func remove_broken_bean_at(cell: Vector2i) -> bool:
	return remove_vector2i_from_list(cell, broken_bean_cells)

func has_index(indices: Array[int], idx: int) -> bool:
	for existing in indices:
		if existing == idx:
			return true
	return false

func add_index_unique(indices: Array[int], idx: int) -> void:
	if idx < 0:
		return
	if not has_index(indices, idx):
		indices.append(idx)

func prune_segment_indices() -> void:
	for i: int in range(broken_segment_indices.size() - 1, -1, -1):
		var idx := broken_segment_indices[i]
		if idx < 0 or idx >= snake.size():
			broken_segment_indices.remove_at(i)
	for j: int in range(rotten_segment_indices.size() - 1, -1, -1):
		var ridx := rotten_segment_indices[j]
		if ridx < 0 or ridx >= snake.size():
			rotten_segment_indices.remove_at(j)
	for k: int in range(decaf_segment_indices.size() - 1, -1, -1):
		var didx := decaf_segment_indices[k]
		if didx < 0 or didx >= snake.size():
			decaf_segment_indices.remove_at(k)

func shift_segment_indices(delta: int) -> void:
	for i: int in range(broken_segment_indices.size()):
		broken_segment_indices[i] += delta
	for j: int in range(rotten_segment_indices.size()):
		rotten_segment_indices[j] += delta
	for k: int in range(decaf_segment_indices.size()):
		decaf_segment_indices[k] += delta
	prune_segment_indices()

func infect_nearest_chain_beans(count: int) -> void:
	var added := 0
	for idx: int in range(1, snake.size()):
		if not has_index(rotten_segment_indices, idx):
			rotten_segment_indices.append(idx)
			added += 1
			if added >= count:
				break

func spread_rotten_infection() -> void:
	if rotten_segment_indices.is_empty():
		return
	var pending: Array[int] = []
	for idx in rotten_segment_indices:
		var left := idx - 1
		var right := idx + 1
		if left >= 1 and left < snake.size() and not has_index(rotten_segment_indices, left):
			add_index_unique(pending, left)
		if right >= 1 and right < snake.size() and not has_index(rotten_segment_indices, right):
			add_index_unique(pending, right)
	for idx in pending:
		add_index_unique(rotten_segment_indices, idx)

func is_on_conveyor(cell: Vector2i) -> bool:
	return conveyor_cells.has(cell)

func conveyor_dir_for(cell: Vector2i) -> Vector2i:
	if conveyor_cells.has(cell):
		return conveyor_cells[cell]
	return Vector2i.ZERO

func scatter_chain_from_index(start_index: int) -> void:
	if snake.size() <= start_index:
		return

	var detached_count := snake.size() - start_index
	for i: int in range(start_index, snake.size()):
		var bean := snake[i]
		if in_bounds(bean) and not is_idle_bean_at(bean) and not is_grinder_cell(bean):
			idle_beans.append(bean)
			bean_spawn_age[bean_key(bean)] = BEAN_SPAWN_TOTAL
			spawn_wake_pulse(bean)

	snake.resize(start_index)
	prune_segment_indices()
	freshness = maxf(0.0, freshness - float(detached_count) * CHAIN_SCATTER_FRESHNESS_LOSS)
	performance_score -= 1
	update_adaptive_difficulty()
	if freshness <= 0.0:
		trigger_game_over()

func scatter_on_hazard_contact() -> void:
	scatter_chain_from_index(1)

func apply_gear_gap_break() -> void:
	for i: int in range(1, snake.size()):
		if is_cell_in_list(snake[i], gear_gap_cells):
			scatter_chain_from_index(i)
			return

func apply_conveyor_push() -> void:
	for i: int in range(snake.size()):
		var seg := snake[i]
		if not is_on_conveyor(seg):
			continue
		var dir := conveyor_dir_for(seg)
		var pushed := seg + dir
		if in_bounds(pushed) and not (piston_active_left > 0.0 and pushed.y == piston_row):
			snake[i] = pushed

func trigger_piston_telegraph() -> void:
	piston_row = rng.randi_range(2, GRID_SIZE.y - 3)
	piston_telegraph_left = PISTON_TELEGRAPH_SEC

func trigger_piston_slam() -> void:
	piston_active_left = PISTON_ACTIVE_SEC
	piston_telegraph_left = 0.0

	for i: int in range(1, snake.size()):
		if snake[i].y == piston_row:
			scatter_chain_from_index(i)
			return

func remove_tail_beans(count: int, freshness_per_bean: float) -> void:
	var removed := 0
	while removed < count and snake.size() > 1:
		snake.pop_back()
		removed += 1
	prune_segment_indices()
	if removed > 0:
		freshness = maxf(0.0, freshness - freshness_per_bean * float(removed))
		if freshness <= 0.0:
			trigger_game_over()

func apply_decaf_hit() -> void:
	if snake.is_empty():
		return
	var head := snake[0]
	for i: int in range(decaf_beans.size()):
		var cell: Vector2i = decaf_beans[i]["cell"]
		if cell != head:
			continue
		var converted := 0
		for idx: int in range(1, snake.size()):
			if not has_index(decaf_segment_indices, idx):
				decaf_segment_indices.append(idx)
				converted += 1
				if converted >= 3:
					break
			extraction_feedback = "Decaf spread"
			extraction_feedback_ttl = 1.0
			break

func update_decaf_beans(delta: float) -> void:
	decaf_move_timer -= delta * adaptive_enemy_speed
	if decaf_move_timer > 0.0:
		return
	decaf_move_timer += DECAF_MOVE_INTERVAL
	for i: int in range(decaf_beans.size()):
		var cell: Vector2i = decaf_beans[i]["cell"]
		var dir: Vector2i = decaf_beans[i]["dir"]
		var next := cell + dir
		if not in_bounds(next) or is_pebble_at(next) or is_grinder_cell(next):
			dir = random_cardinal_dir()
			next = cell + dir
			if not in_bounds(next) or is_pebble_at(next) or is_grinder_cell(next):
				next = cell
		decaf_beans[i]["dir"] = dir
		decaf_beans[i]["cell"] = next

func update_water_drops(delta: float) -> void:
	water_drop_move_timer -= delta * adaptive_enemy_speed
	if water_drop_move_timer > 0.0:
		return
	water_drop_move_timer += WATER_DROP_MOVE_INTERVAL
	for i: int in range(water_drops.size()):
		var cell: Vector2i = water_drops[i]["cell"]
		var dir: Vector2i = water_drops[i]["dir"]
		var next := cell + dir
		if not in_bounds(next) or is_pebble_at(next):
			if next.x < 0 or next.x >= GRID_SIZE.x:
				dir.x = -dir.x
			if next.y < 0 or next.y >= GRID_SIZE.y:
				dir.y = -dir.y
			if is_pebble_at(next):
				dir = random_cardinal_dir()
			next = cell + dir
			if not in_bounds(next) or is_pebble_at(next):
				next = cell
		water_drops[i]["dir"] = dir
		water_drops[i]["cell"] = next

func apply_water_drop_hits() -> void:
	if snake.is_empty():
		return
	var head := snake[0]
	for drop in water_drops:
		var cell: Vector2i = drop["cell"]
		if cell == head:
			remove_tail_beans(rng.randi_range(1, 2), ENEMY_BEAN_LOSS_FRESHNESS)
			extraction_feedback = "Water hit"
			extraction_feedback_ttl = 1.0
			return

func apply_scoop_effect() -> void:
	if scoop_center.x < 0 or snake.is_empty():
		return
	var center_v := Vector2(scoop_center.x + 0.5, scoop_center.y + 0.5)
	var to_remove: Array[int] = []
	for idx: int in range(snake.size()):
		var seg := snake[idx]
		var seg_v := Vector2(seg.x + 0.5, seg.y + 0.5)
		if center_v.distance_to(seg_v) <= SCOOP_RADIUS_CELLS:
			to_remove.append(idx)

	if to_remove.is_empty():
		return
	if has_index(to_remove, 0):
		trigger_game_over()
		return

	to_remove.sort()
	var removed := 0
	for i: int in range(to_remove.size() - 1, -1, -1):
		snake.remove_at(to_remove[i])
		removed += 1
	prune_segment_indices()
	if removed > 0:
		freshness = maxf(0.0, freshness - ENEMY_BEAN_LOSS_FRESHNESS * float(removed))
		extraction_feedback = "Scooped"
		extraction_feedback_ttl = 1.0
		if freshness <= 0.0:
			trigger_game_over()

func update_scoop(delta: float) -> void:
	if scoop_telegraph_left > 0.0:
		scoop_telegraph_left = maxf(0.0, scoop_telegraph_left - delta)
		if scoop_telegraph_left <= 0.0:
			apply_scoop_effect()
			scoop_center = Vector2i(-1, -1)
			scoop_timer = SCOOP_INTERVAL
		return

	scoop_timer -= delta * adaptive_enemy_speed
	if scoop_timer <= 0.0:
		scoop_timer += SCOOP_INTERVAL
		scoop_telegraph_left = SCOOP_TELEGRAPH_SEC
		scoop_center = Vector2i(
			rng.randi_range(2, GRID_SIZE.x - 3),
			rng.randi_range(2, GRID_SIZE.y - 3)
		)

func apply_mechanical_arm_push() -> void:
	if arm_line_index < 0:
		return
	for i: int in range(snake.size()):
		var seg := snake[i]
		var on_line := (arm_is_row and seg.y == arm_line_index) or ((not arm_is_row) and seg.x == arm_line_index)
		if not on_line:
			continue
		var pushed := seg
		for _j: int in range(ARM_PUSH_CELLS):
			var next := pushed + arm_push_dir
			if not in_bounds(next):
				break
			pushed = next
		snake[i] = pushed

func update_mechanical_arm(delta: float) -> void:
	if arm_active_left > 0.0:
		arm_active_left = maxf(0.0, arm_active_left - delta)
		if not arm_applied:
			apply_mechanical_arm_push()
			arm_applied = true
		if arm_active_left <= 0.0:
			arm_line_index = -1
		return

	if arm_telegraph_left > 0.0:
		arm_telegraph_left = maxf(0.0, arm_telegraph_left - delta)
		if arm_telegraph_left <= 0.0:
			arm_active_left = ARM_ACTIVE_SEC
			arm_applied = false
		return

	arm_timer -= delta * adaptive_enemy_speed
	if arm_timer <= 0.0:
		arm_timer += ARM_INTERVAL
		arm_telegraph_left = ARM_TELEGRAPH_SEC
		arm_is_row = rng.randi_range(0, 1) == 0
		arm_line_index = rng.randi_range(2, (GRID_SIZE.y - 3) if arm_is_row else (GRID_SIZE.x - 3))
		arm_push_dir = random_cardinal_dir()
		if arm_is_row:
			arm_push_dir.y = 0
			if arm_push_dir.x == 0:
				arm_push_dir.x = 1
		else:
			arm_push_dir.x = 0
			if arm_push_dir.y == 0:
				arm_push_dir.y = 1

func extraction_multiplier(seconds: float) -> float:
	if seconds <= 15.0:
		return 0.5
	if seconds <= 20.0:
		return 0.8
	if seconds <= 29.0:
		return 1.0
	if seconds <= 35.0:
		return 0.8
	return 0.5

func extraction_label(seconds: float) -> String:
	if seconds <= 15.0:
		return "Sour pull"
	if seconds <= 20.0:
		return "Early pull"
	if seconds <= 29.0:
		return "Perfetto"
	if seconds <= 35.0:
		return "Late pull"
	return "Bitter auto-pull"

func finalize_extraction(auto_pull: bool) -> void:
	if not extraction_active:
		return
	# Level 1 has no extraction timing pressure — always pulls at ×1.0.
	var mult := 1.0 if not extraction_timer_enabled else extraction_multiplier(extraction_timer)
	var final_score := int(round(float(extraction_base_score) * mult))
	var delta := final_score - extraction_base_score
	score += delta
	best_score = max(best_score, score)

	if mult == 1.0 and extraction_base_score == 36:
		performance_score += 5
		score += 500
		freshness = minf(100.0, freshness + 15.0)
		extraction_feedback = "GOD SHOT!"
	else:
		extraction_feedback = extraction_label(extraction_timer)

	update_adaptive_difficulty()
	extraction_feedback_ttl = 1.8
	if auto_pull:
		freshness = maxf(0.0, freshness - EXTRACTION_FRESHNESS_MISS_PENALTY)
		performance_score -= 1
		update_adaptive_difficulty()
	extraction_active = false
	extraction_timer = 0.0
	extraction_base_score = 0

func begin_extraction_from_grind(grounded_count: int) -> void:
	if grounded_count <= 0:
		return
	if extraction_active:
		finalize_extraction(false)
	extraction_active = true
	extraction_timer = 0.0
	extraction_base_score = grounded_count * 2

func trigger_rally_call() -> void:
	if game_state != GameState.PLAYING or rally_cooldown_left > 0.0 or snake.is_empty():
		return
	rally_cooldown_left = RALLY_COOLDOWN_SEC
	var head := snake[0]
	var recruited: Array[Vector2i] = []
	var recruited_broken: Array[Vector2i] = []
	for i: int in range(idle_beans.size() - 1, -1, -1):
		var bean := idle_beans[i]
		if head.distance_to(bean) <= RALLY_RADIUS_CELLS:
			idle_beans.remove_at(i)
			bean_spawn_age.erase(bean_key(bean))
			recruited.append(bean)
			spawn_wake_pulse(bean)
	for j: int in range(broken_bean_cells.size() - 1, -1, -1):
		var broken := broken_bean_cells[j]
		if head.distance_to(broken) <= RALLY_RADIUS_CELLS:
			broken_bean_cells.remove_at(j)
			recruited_broken.append(broken)
			spawn_wake_pulse(broken)
	for bean in recruited:
		snake.append(bean)
	for broken in recruited_broken:
		snake.append(broken)
		add_index_unique(broken_segment_indices, snake.size() - 1)

func trigger_burr_rotation() -> void:
	var phases: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var push_dir: Vector2i = phases[burr_phase_index]
	burr_phase_index = (burr_phase_index + 1) % phases.size()

	var pushed_snake: Array[Vector2i] = []
	for seg in snake:
		var new_seg := seg
		for _i: int in range(2):
			var next := new_seg + push_dir
			if not in_bounds(next):
				break
			new_seg = next
		pushed_snake.append(new_seg)
	snake = pushed_snake

func can_spawn_leader(cell: Vector2i) -> bool:
	return (
		in_bounds(cell)
		and is_inside_spawn_safe_area(cell)
		and not is_grinder_cell(cell)
		and not is_idle_bean_at(cell)
		and not is_pebble_at(cell)
		and not is_rotten_bean_at(cell)
		and not is_broken_bean_at(cell)
	)

func is_inside_spawn_safe_area(cell: Vector2i) -> bool:
	return (
		cell.x >= PLAYFIELD_SAFE_MARGIN
		and cell.y >= PLAYFIELD_SAFE_MARGIN
		and cell.x <= GRID_SIZE.x - 1 - PLAYFIELD_SAFE_MARGIN
		and cell.y <= GRID_SIZE.y - 1 - PLAYFIELD_SAFE_MARGIN
	)

func find_leader_spawn_cell() -> Vector2i:
	var preferred := Vector2i(int(GRID_SIZE.x / 2), int(GRID_SIZE.y / 2))
	if can_spawn_leader(preferred):
		return preferred

	for _i: int in range(240):
		var candidate := Vector2i(rng.randi_range(0, GRID_SIZE.x - 1), rng.randi_range(0, GRID_SIZE.y - 1))
		if can_spawn_leader(candidate):
			return candidate

	for y: int in range(GRID_SIZE.y):
		for x: int in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			if can_spawn_leader(cell):
				return cell

	return Vector2i(0, 0)

func spawn_new_leader_bean() -> void:
	var spawn_cell := find_leader_spawn_cell()
	snake.clear()
	broken_segment_indices.clear()
	rotten_segment_indices.clear()
	snake.append(spawn_cell)
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var random_dir: Vector2i = directions[rng.randi_range(0, directions.size() - 1)]
	direction = random_dir
	next_direction = random_dir

func spawn_grind_pop(cell: Vector2i) -> void:
	var center := grid_to_pixel(cell) + Vector2(cell_px() * 0.5, cell_px() * 0.5)
	grind_pops.append({"position": center, "ttl": GRIND_POP_LIFE, "life": GRIND_POP_LIFE})

func spawn_waste_spill(cell: Vector2i) -> void:
	var center := grid_to_pixel(cell) + Vector2(cell_px() * 0.5, cell_px() * 0.5)
	var grinder_center := grid_to_pixel(grinder_origin) + Vector2(cell_px(), cell_px())
	var outward := (center - grinder_center).normalized()
	if outward.length() < 0.01:
		outward = Vector2(1.0 if rng.randi_range(0, 1) == 0 else -1.0, 0.0)

	var vx := outward.x * rng.randf_range(90.0, 140.0)
	var vy := -rng.randf_range(35.0, 70.0)
	waste_spills.append({
		"position": center,
		"velocity": Vector2(vx, vy),
		"ttl": WASTE_SPILL_LIFE,
		"life": WASTE_SPILL_LIFE
	})

func begin_grind_sequence() -> void:
	if is_grinding or snake.is_empty():
		return
	is_grinding = true
	grind_step_timer = 0.0
	grind_grounded_count = 0
	grind_wasted_count = 0

func process_grind(delta: float) -> void:
	if not is_grinding:
		return

	grind_step_timer += delta
	while grind_step_timer >= GRIND_STEP_INTERVAL and is_grinding:
		grind_step_timer -= GRIND_STEP_INTERVAL
		if snake.is_empty():
			is_grinding = false
			begin_extraction_from_grind(grind_grounded_count)
			spawn_new_leader_bean()
			return

		var consumed_broken := has_index(broken_segment_indices, 0)
		var consumed: Vector2i = snake.pop_front()
		shift_segment_indices(-1)
		if grind_grounded_count < GRINDER_DOSE_CAP:
			spawn_grind_pop(consumed)
			grind_grounded_count += 1
			var grind_pts: int = int(round(2.0 * (WATER_WASHED_SCORE_MULT if washed_buff_timer > 0.0 else 1.0)))
			if consumed_broken:
				grind_pts = maxi(1, grind_pts - 1)
			score += grind_pts
			best_score = max(best_score, score)
			freshness = minf(FRESHNESS_MAX, freshness + GROUND_FRESHNESS_GAIN)
		else:
			grind_wasted_count += 1
			freshness = maxf(0.0, freshness - WASTE_FRESHNESS_PENALTY)
			performance_score -= 1
			update_adaptive_difficulty()
			spawn_waste_spill(consumed)
			if freshness <= 0.0:
				trigger_game_over()
				return

		if snake.is_empty():
			is_grinding = false
			begin_extraction_from_grind(grind_grounded_count)

			if grind_grounded_count == GRINDER_DOSE_CAP:
				performance_score += 1
			if grind_wasted_count > 0:
				performance_score -= (grind_wasted_count / 3)
			update_adaptive_difficulty()

			grind_grounded_count = 0
			grind_wasted_count = 0
			spawn_new_leader_bean()
			return

func bean_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func spawn_wake_pulse(cell: Vector2i) -> void:
	var center := grid_to_pixel(cell) + Vector2(cell_px() * 0.5, cell_px() * 0.5)
	wake_pulses.append({"position": center, "ttl": 0.42, "life": 0.42})

func set_pause_state(paused: bool) -> void:
	is_paused = paused
	game_state = GameState.PAUSED if paused else GameState.PLAYING
	if paused:
		resume_countdown_left = 0.0
	else:
		resume_countdown_left = RESUME_COUNTDOWN_SEC
	queue_redraw()

func activate_start_option() -> void:
	if start_menu_index == 0:
		start_new_run()
		game_state = GameState.PLAYING
	else:
		get_tree().quit()

func activate_pause_option() -> void:
	match pause_menu_index:
		0:
			set_pause_state(false)
		1:
			start_new_run()
			game_state = GameState.PLAYING
		2:
			get_tree().quit()

func _get_level_index(lid: String) -> int:
	for i: int in range(LEVEL_ORDER.size()):
		if LEVEL_ORDER[i] == lid:
			return i
	return -1

func _has_next_level() -> bool:
	var idx := _get_level_index(level_id)
	if idx < 0:
		return false
	return idx < LEVEL_ORDER.size() - 1

func _next_level_id() -> String:
	var idx := _get_level_index(level_id)
	if idx < 0 or idx >= LEVEL_ORDER.size() - 1:
		return ""
	return str(LEVEL_ORDER[idx + 1])

func _advance_to_next_level() -> bool:
	var next_id := _next_level_id()
	if next_id.is_empty():
		return false
	level_id = next_id
	wave_mgr.init(level_id)
	_apply_level_config()
	return true

func is_idle_bean_at(cell: Vector2i) -> bool:
	for bean in idle_beans:
		if bean == cell:
			return true
	return false

func remove_idle_bean_at(cell: Vector2i) -> bool:
	for i: int in range(idle_beans.size()):
		if idle_beans[i] == cell:
			idle_beans.remove_at(i)
			bean_spawn_age.erase(bean_key(cell))
			return true
	return false

func spawn_idle_beans(count: int) -> void:
	if count <= 0:
		return

	var occupied := {}
	for segment in snake:
		occupied[segment] = true
	for bean in idle_beans:
		occupied[bean] = true
	for grinder_cell in get_grinder_cells():
		occupied[grinder_cell] = true
	for pebble in pebble_cells:
		occupied[pebble] = true
	for rotten in rotten_bean_cells:
		occupied[rotten] = true
	for broken in broken_bean_cells:
		occupied[broken] = true

	var spawned := 0
	var attempts := 0
	var max_attempts := GRID_SIZE.x * GRID_SIZE.y * 3

	while spawned < count and attempts < max_attempts:
		attempts += 1
		var candidate := Vector2i(
			rng.randi_range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.x - 1 - PLAYFIELD_SAFE_MARGIN),
			rng.randi_range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.y - 1 - PLAYFIELD_SAFE_MARGIN)
		)
		if occupied.has(candidate):
			continue
		occupied[candidate] = true
		idle_beans.append(candidate)
		bean_spawn_age[bean_key(candidate)] = 0.0
		spawned += 1

func get_grinder_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if grinder_origin.x < 0 or grinder_origin.y < 0:
		return cells
	for y: int in range(grinder_size):
		for x: int in range(grinder_size):
			cells.append(grinder_origin + Vector2i(x, y))
	return cells

func is_grinder_cell(cell: Vector2i) -> bool:
	if grinder_origin.x < 0 or grinder_origin.y < 0:
		return false
	return (
		cell.x >= grinder_origin.x
		and cell.y >= grinder_origin.y
		and cell.x < grinder_origin.x + grinder_size
		and cell.y < grinder_origin.y + grinder_size
	)

func place_grinder_random(previous_origin: Vector2i = Vector2i(-1, -1)) -> void:
	var tries := 0
	var max_tries := 200
	while tries < max_tries:
		tries += 1
		var candidate := Vector2i(
			rng.randi_range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.x - grinder_size - PLAYFIELD_SAFE_MARGIN),
			rng.randi_range(PLAYFIELD_SAFE_MARGIN, GRID_SIZE.y - grinder_size - PLAYFIELD_SAFE_MARGIN)
		)
		var overlaps := false
		for y: int in range(grinder_size):
			for x: int in range(grinder_size):
				var cell := candidate + Vector2i(x, y)
				if snake.has(cell) or is_idle_bean_at(cell):
					overlaps = true
					break
				if previous_origin.x >= 0 and previous_origin.y >= 0 and (
					cell.x >= previous_origin.x
					and cell.y >= previous_origin.y
					and cell.x < previous_origin.x + grinder_size
						and cell.y < previous_origin.y + grinder_size
				):
					overlaps = true
					break
			if overlaps:
				break
		if not overlaps:
			grinder_origin = candidate
			return

	# Fallback should be rare; still keep grinder in a valid in-bounds area.
	grinder_origin = Vector2i(PLAYFIELD_SAFE_MARGIN, PLAYFIELD_SAFE_MARGIN)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey

		if game_state == GameState.START_MENU:
			if key_event.keycode == KEY_UP or key_event.keycode == KEY_W:
				start_menu_index = posmod(start_menu_index - 1, start_menu_options.size())
				queue_redraw()
				return
			if key_event.keycode == KEY_DOWN or key_event.keycode == KEY_S:
				start_menu_index = posmod(start_menu_index + 1, start_menu_options.size())
				queue_redraw()
				return
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				activate_start_option()
				return

		if key_event.keycode == KEY_ESCAPE:
			if game_state == GameState.PLAYING:
				pause_menu_index = 0
				set_pause_state(true)
				return
			elif game_state == GameState.PAUSED:
				set_pause_state(false)
				return
			elif game_state == GameState.START_MENU:
				get_tree().quit()
				return
			elif game_state == GameState.LEVEL_COMPLETE:
				game_state = GameState.START_MENU
				return

		if game_state == GameState.PAUSED:
			if key_event.keycode == KEY_UP or key_event.keycode == KEY_W:
				pause_menu_index = posmod(pause_menu_index - 1, pause_menu_options.size())
				queue_redraw()
				return
			if key_event.keycode == KEY_DOWN or key_event.keycode == KEY_S:
				pause_menu_index = posmod(pause_menu_index + 1, pause_menu_options.size())
				queue_redraw()
				return
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				activate_pause_option()
				return

		if game_state == GameState.GAME_OVER:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				start_new_run()
				game_state = GameState.PLAYING
				return
			if key_event.keycode == KEY_ESCAPE:
				game_state = GameState.START_MENU
				return

		if game_state == GameState.LEVEL_COMPLETE:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				_advance_to_next_level()
				start_new_run()
				game_state = GameState.PLAYING
				return
			if key_event.keycode == KEY_ESCAPE:
				game_state = GameState.START_MENU
				return

		if key_event.keycode == KEY_SPACE and game_state == GameState.PLAYING:
			trigger_rally_call()
			return

		if game_state == GameState.PLAYING and (key_event.keycode == KEY_E or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
			finalize_extraction(false)
			return

		if game_state != GameState.PLAYING:
			return

		if key_event.keycode == KEY_W:
			try_set_direction(Vector2i.UP)
		elif key_event.keycode == KEY_S:
			try_set_direction(Vector2i.DOWN)
		elif key_event.keycode == KEY_A:
			try_set_direction(Vector2i.LEFT)
		elif key_event.keycode == KEY_D:
			try_set_direction(Vector2i.RIGHT)

	if game_state != GameState.PLAYING:
		return

	if event.is_action_pressed("ui_up"):
		try_set_direction(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		try_set_direction(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		try_set_direction(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		try_set_direction(Vector2i.RIGHT)

func try_set_direction(candidate: Vector2i) -> void:
	if game_over:
		return
	if oil_slick_timer > 0.0:
		return
	if candidate == -direction:
		return
	if candidate != next_direction:
		if shake_combo_window_left > 0.0:
			shake_combo_count += 1
		else:
			shake_combo_count = 1
		shake_combo_window_left = SHAKE_PURGE_WINDOW_SEC
		if shake_combo_count >= SHAKE_PURGE_TURNS and not rotten_segment_indices.is_empty():
			rotten_segment_indices.clear()
			extraction_feedback = "Rot purged"
			extraction_feedback_ttl = 1.1
	next_direction = candidate

func _physics_process(delta: float) -> void:
	if Vector2(get_window().size) != _last_viewport_size:
		_update_ui_scale()
		_last_viewport_size = Vector2(get_window().size)

	if game_state != GameState.PLAYING:
		return

	# Always advance the wave manager timer so banners expire on schedule.
	wave_mgr.update(delta)

	# While a wave banner (start/end/level-clear) is displayed, freeze all
	# gameplay logic — no movement, no freshness drain, no hazard ticks.
	if wave_mgr.is_in_banner():
		queue_redraw()
		return

	# Level fully complete — transition to the level-complete screen.
	if wave_mgr.is_done():
		game_state = GameState.LEVEL_COMPLETE
		best_score  = max(best_score, score)
		save_high_score_if_needed()
		queue_redraw()
		return

	if resume_countdown_left > 0.0:
		resume_countdown_left = maxf(0.0, resume_countdown_left - delta)
		queue_redraw()
		return

	time_alive += delta

	# Washed buff decays each frame.  The buff itself is granted in step_game()
	# when the leader actually steps onto a puddle cell.
	washed_buff_timer = maxf(0.0, washed_buff_timer - delta)


	freshness = maxf(0.0, freshness - FRESHNESS_DRAIN_PER_SEC * delta)
	if freshness <= 0.0:
		trigger_game_over()
		return

	rally_cooldown_left = maxf(0.0, rally_cooldown_left - delta)
	if extraction_active:
		extraction_timer += delta
		if extraction_timer >= EXTRACTION_AUTO_PULL_SEC:
			finalize_extraction(true)

	burr_timer -= delta
	if burr_timer <= 0.0:
		burr_timer += active_burr_interval
		trigger_burr_rotation()

	if machine_hazards_enabled:
		conveyor_push_timer -= delta
		if conveyor_push_timer <= 0.0:
			conveyor_push_timer += CONVEYOR_PUSH_INTERVAL
			apply_conveyor_push()

	oil_slick_timer = maxf(0.0, oil_slick_timer - delta)
	shake_combo_window_left = maxf(0.0, shake_combo_window_left - delta)
	if shake_combo_window_left <= 0.0:
		shake_combo_count = 0

	if not rotten_segment_indices.is_empty():
		rotten_spread_timer -= delta
		if rotten_spread_timer <= 0.0:
			rotten_spread_timer += ROTTEN_SPREAD_INTERVAL
			spread_rotten_infection()

	if piston_enabled:
		if piston_active_left > 0.0:
			piston_active_left = maxf(0.0, piston_active_left - delta)
		elif piston_telegraph_left > 0.0:
			piston_telegraph_left = maxf(0.0, piston_telegraph_left - delta)
			if piston_telegraph_left <= 0.0:
				trigger_piston_slam()
		else:
			piston_timer -= delta
			if piston_timer <= 0.0:
				piston_timer += active_piston_interval
				trigger_piston_telegraph()

	if enemies_enabled:
		update_decaf_beans(delta)
		apply_decaf_hit()
		update_water_drops(delta)
		apply_water_drop_hits()
		update_scoop(delta)
		update_mechanical_arm(delta)

	# Pressure Release — L3 only.
	if pressure_release_enabled:
		if pressure_release_telegraph_timer > 0.0:
			pressure_release_telegraph_timer = maxf(0.0, pressure_release_telegraph_timer - delta)
			if pressure_release_telegraph_timer <= 0.0:
				apply_pressure_release()
				pressure_release_timer = active_pressure_interval
		else:
			pressure_release_timer -= delta
			if pressure_release_timer <= 0.0:
				trigger_pressure_release_telegraph()

	var steer_axis := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if steer_axis.length() > 0.0:
		var dx := 0
		var dy := 0
		if steer_axis.x > 0.2:
			dx = 1
		elif steer_axis.x < -0.2:
			dx = -1
		if steer_axis.y > 0.2:
			dy = 1
		elif steer_axis.y < -0.2:
			dy = -1
		if dx != 0 or dy != 0:
			try_set_direction(Vector2i(dx, dy))

	if not grinder_active:
		grinder_telegraph_timer = maxf(0.0, grinder_telegraph_timer - delta)
		if grinder_telegraph_timer <= 0.0:
			grinder_active = true
	else:
		# Mid-wave blade relocation (wave-config-driven; 0 = disabled).
		if mid_wave_relocations_remaining != 0:
			grinder_relocate_timer -= delta
			if grinder_relocate_timer <= 0.0:
				var previous_origin := grinder_origin
				grinder_active          = false
				grinder_telegraph_timer = GRINDER_TELEGRAPH_TIME
				if mid_wave_relocations_remaining == -1:
					grinder_relocate_timer = 15.0     ## continuous every 15 s (L3 W3)
				else:
					mid_wave_relocations_remaining -= 1
					grinder_relocate_timer = 30.0 if mid_wave_relocations_remaining > 0 else 999999.0
				place_grinder_random(previous_origin)

	bean_spawn_timer += delta
	while bean_spawn_timer >= bean_trickle_interval:
		bean_spawn_timer -= bean_trickle_interval
		spawn_idle_beans(current_trickle_per_rotation)

	# Check whether the current wave's cumulative score target has been reached.
	check_wave_completion()

	if is_grinding:
		process_grind(delta)
		queue_redraw()
		return

	move_accumulator += delta

	while move_accumulator >= move_interval:
		move_accumulator -= move_interval
		step_game()

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y

func is_cell_blocked(cell: Vector2i, _grows: bool) -> bool:
	if not in_bounds(cell):
		return true
	if piston_active_left > 0.0 and piston_row >= 0 and cell.y == piston_row:
		return true
	if is_pebble_at(cell):
		return true
	return false

func reflected_direction(current_dir: Vector2i, grows: bool) -> Vector2i:
	var head := snake[0]
	var bounced := current_dir
	var attempted := head + current_dir

	if attempted.x < 0 or attempted.x >= GRID_SIZE.x:
		bounced.x = -bounced.x
	if attempted.y < 0 or attempted.y >= GRID_SIZE.y:
		bounced.y = -bounced.y

	if bounced != Vector2i.ZERO and not is_cell_blocked(head + bounced, grows):
		return bounced

	var fallback_dirs: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1)
	]
	for fallback_dir in fallback_dirs:
		if not is_cell_blocked(head + fallback_dir, grows):
			return fallback_dir

	return Vector2i.ZERO

func step_game() -> void:
	if snake.is_empty():
		return

	direction = next_direction
	var target := snake[0] + direction
	var grows_idle := is_idle_bean_at(target)
	var grows_broken := is_broken_bean_at(target)
	var grows := grows_idle or grows_broken
	var new_head := snake[0] + direction
	var blocked_by_pebble := is_pebble_at(new_head)

	if is_cell_blocked(new_head, grows):
		if blocked_by_pebble and snake.size() > 1:
			scatter_on_hazard_contact()
		var bounced_dir := reflected_direction(direction, grows)
		if bounced_dir == Vector2i.ZERO:
			queue_redraw()
			return
		direction = bounced_dir
		next_direction = bounced_dir
		target = snake[0] + direction
		grows_idle = is_idle_bean_at(target)
		grows_broken = is_broken_bean_at(target)
		grows = grows_idle or grows_broken
		new_head = snake[0] + direction

		if is_cell_blocked(new_head, grows):
			queue_redraw()
			return

	snake.push_front(new_head)
	shift_segment_indices(1)

	if grinder_active and is_grinder_cell(new_head):
		# Preserve normal movement length before grind starts.
		# Without this, a non-growth move into the grinder keeps an extra tail segment.
		if not grows and snake.size() > 1:
			snake.pop_back()
		elif grows:
			remove_idle_bean_at(new_head)
			spawn_wake_pulse(new_head)
		begin_grind_sequence()
		queue_redraw()
		return

	if grows:
		if grows_idle:
			remove_idle_bean_at(new_head)
		if grows_broken:
			remove_broken_bean_at(new_head)
			add_index_unique(broken_segment_indices, snake.size() - 1)
		spawn_wake_pulse(new_head)
	else:
		snake.pop_back()
		prune_segment_indices()

	if is_rotten_bean_at(new_head):
		remove_rotten_bean_at(new_head)
		infect_nearest_chain_beans(2)
		spawn_wake_pulse(new_head)

	# Water puddle: grant Washed buff on each step through a puddle cell.
	if water_puddles_enabled and is_water_puddle_at(new_head):
		washed_buff_timer = minf(WASHED_BUFF_DURATION, washed_buff_timer + 5.0)
		extraction_feedback     = "Washed! ×1.5"
		extraction_feedback_ttl = 1.2

	if is_cell_in_list(new_head, grinding_teeth_cells):
		scatter_on_hazard_contact()

	if is_cell_in_list(new_head, oil_slick_cells):
		oil_slick_timer = OIL_SLICK_SLIDE_SEC

	apply_gear_gap_break()

	queue_redraw()

func trigger_game_over() -> void:
	game_over = true
	game_state = GameState.GAME_OVER
	is_grinding = false
	extraction_active = false
	extraction_timer = 0.0
	extraction_base_score = 0
	grind_grounded_count = 0
	grind_wasted_count = 0
	best_score = max(best_score, score)
	save_high_score_if_needed()
	queue_redraw()

# ---------------------------------------------------------------------------
# Water puddles
# ---------------------------------------------------------------------------

func _setup_water_puddles() -> void:
	var wave_cfg: Dictionary = wave_mgr.get_current_wave_config()
	var puddle_count: int    = int(wave_cfg.get("water_puddle_count", 0))
	water_puddle_cells.clear()
	if puddle_count <= 0:
		return
	var occupied := {}
	for cell in snake:
		occupied[cell] = true
	for cell in get_grinder_cells():
		occupied[cell] = true
	for cell in idle_beans:
		occupied[cell] = true
	for cell in grinding_teeth_cells:
		occupied[cell] = true
	for cell in gear_gap_cells:
		occupied[cell] = true
	for cell in pebble_cells:
		occupied[cell] = true
	for _i: int in range(puddle_count):
		water_puddle_cells.append(random_inner_cell(occupied))


func is_water_puddle_at(cell: Vector2i) -> bool:
	return is_cell_in_list(cell, water_puddle_cells)


# ---------------------------------------------------------------------------
# Pressure Release
# ---------------------------------------------------------------------------

func trigger_pressure_release_telegraph() -> void:
	pressure_vent_side               = rng.randi_range(0, 3)
	pressure_release_telegraph_timer = PRESSURE_RELEASE_TELEGRAPH_SEC


func apply_pressure_release() -> void:
	var push_dir := Vector2i.RIGHT
	match pressure_vent_side:
		0: push_dir = Vector2i.RIGHT
		1: push_dir = Vector2i.LEFT
		2: push_dir = Vector2i.DOWN
		_: push_dir = Vector2i.UP

	for i: int in range(snake.size()):
		var seg := snake[i]
		for _j: int in range(PRESSURE_RELEASE_PUSH_CELLS):
			var candidate := seg + push_dir
			if in_bounds(candidate):
				seg = candidate
			else:
				break
		snake[i] = seg

	for i: int in range(idle_beans.size()):
		var bean := idle_beans[i]
		for _j: int in range(PRESSURE_RELEASE_PUSH_CELLS):
			var candidate := bean + push_dir
			if in_bounds(candidate):
				bean = candidate
			else:
				break
		idle_beans[i] = bean

	# If the push landed the head on an active grinder, start grinding immediately.
	if not snake.is_empty() and grinder_active and is_grinder_cell(snake[0]):
		begin_grind_sequence()
	queue_redraw()


# ---------------------------------------------------------------------------
# Level / wave integration
# ---------------------------------------------------------------------------

## Reads the active level's config from WaveManager and applies all runtime flags.
func _apply_level_config() -> void:
	var data: Dictionary = wave_mgr.get_level_data()
	move_interval                = float(data.get("base_move_interval", 0.13))
	grinder_size                 = int(data.get("grinder_size", 2))
	extraction_timer_enabled     = bool(data.get("extraction_timer_enabled", true))
	piston_enabled               = bool(data.get("piston_enabled", true))
	machine_hazards_enabled      = bool(data.get("machine_hazards_enabled", true))
	ingredient_hazards_enabled   = bool(data.get("ingredient_hazards_enabled", true))
	enemies_enabled              = bool(data.get("enemies_enabled", true))
	water_puddles_enabled        = bool(data.get("water_puddles_enabled", false))
	pressure_release_enabled     = bool(data.get("pressure_release_enabled", false))
	active_burr_interval         = float(data.get("burr_interval", BURR_ROTATION_INTERVAL))
	active_piston_interval       = float(data.get("piston_interval", PISTON_INTERVAL))
	active_pressure_interval     = float(data.get("pressure_interval", 15.0))


## Called when wave_mgr emits wave_started.
## Spawns the initial bean batch for this wave and updates the trickle rate.
func _on_wave_started(wave_idx: int, _wave_name: String, initial_batch: int, trickle: int) -> void:
	current_trickle_per_rotation = trickle
	bean_spawn_timer             = 0.0

	# Configure mid-wave blade relocation from the wave config.
	var wave_cfg: Dictionary    = wave_mgr.get_current_wave_config()
	var blade_relocates: int    = int(wave_cfg.get("blade_relocates", 0))
	mid_wave_relocations_remaining = blade_relocates
	if blade_relocates == -1:
		grinder_relocate_timer = 15.0          ## continuous every 15 s
	elif blade_relocates > 0:
		grinder_relocate_timer = 30.0          ## first mid-wave relocation in 30 s
	else:
		grinder_relocate_timer = 999999.0      ## blade stays fixed this wave

	# For waves after the first, telegraph a fresh blade position.
	if wave_idx > 0:
		var prev := grinder_origin
		grinder_active          = false
		grinder_telegraph_timer = GRINDER_TELEGRAPH_TIME
		place_grinder_random(prev)

	# Setup water puddles for this wave (count read from wave config).
	water_puddle_cells.clear()
	if water_puddles_enabled:
		_setup_water_puddles()

	# Reset pressure-release timer for the new wave.
	if pressure_release_enabled:
		pressure_release_timer           = active_pressure_interval
		pressure_release_telegraph_timer = 0.0

	spawn_idle_beans(initial_batch)


## Called when wave_mgr emits wave_completed.
func _on_wave_completed(_wave_idx: int) -> void:
	# Placeholder for future per-wave-end effects (SFX, score tally flash, etc.).
	pass


## Called when wave_mgr emits level_cleared.
## The banner is still showing at this point; the LEVEL_COMPLETE transition
## happens in _physics_process once wave_mgr.is_done() returns true.
func _on_level_cleared(_lid: String) -> void:
	pass


## Check whether the running score has crossed the current wave's cumulative
## target.  Call once per physics frame after any score update.
func check_wave_completion() -> void:
	if not wave_mgr.is_playing():
		return
	if score >= wave_mgr.get_wave_score_target():
		wave_mgr.complete_wave()


# ---------------------------------------------------------------------------
# Wave banner drawing
# ---------------------------------------------------------------------------

## Draws the full-screen wave-transition banner overlay.
## Uses a sine-envelope so the panel fades in and out over the banner duration.
func draw_wave_banner() -> void:
	if not wave_mgr.is_in_banner():
		return

	var viewport_size := get_viewport_rect().size
	var progress: float = float(wave_mgr.get_banner_progress())   # 0 → 1
	var alpha: float    = sin(progress * PI)                      # 0 → 1 → 0

	# Semi-opaque darkened bar across the middle third of the screen.
	var panel_h   := viewport_size.y * 0.30
	var panel_y   := (viewport_size.y - panel_h) * 0.5
	var panel_rect := Rect2(0.0, panel_y, viewport_size.x, panel_h)
	draw_rect(panel_rect, Color(0.07, 0.05, 0.03, 0.90 * alpha), true)
	draw_rect(panel_rect, Color(COLOR_PANEL_EDGE.r, COLOR_PANEL_EDGE.g,
			COLOR_PANEL_EDGE.b, alpha), false, 2.0)
	# Horizontal accent lines.
	draw_line(
		Vector2(0.0, panel_y),
		Vector2(viewport_size.x, panel_y),
		Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, alpha * 0.8), 2.0)
	draw_line(
		Vector2(0.0, panel_y + panel_h),
		Vector2(viewport_size.x, panel_y + panel_h),
		Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, alpha * 0.8), 2.0)

	var title: String = str(wave_mgr.get_banner_title())
	var sub: String   = str(wave_mgr.get_banner_sub_text())
	var title_y := panel_y + panel_h * 0.42
	var sub_y   := panel_y + panel_h * 0.72

	draw_string(hud_font, Vector2(panel_rect.position.x, title_y), title,
			HORIZONTAL_ALIGNMENT_CENTER, viewport_size.x, 34,
			Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, alpha))
	draw_string(hud_font, Vector2(panel_rect.position.x, sub_y), sub,
			HORIZONTAL_ALIGNMENT_CENTER, viewport_size.x, 18,
			Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, alpha * 0.9))


## Draws the level-complete overlay (shown after the wave banner resolves to DONE).
func draw_level_complete_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size    := Vector2(480.0, 240.0)
	var panel_pos     := (viewport_size - panel_size) * 0.5
	var next_label    := "Enter: Play Again"
	if _has_next_level():
		next_label = "Enter: Next Level"

	draw_rect(Rect2(panel_pos, panel_size), Color(0.08, 0.06, 0.04, 0.96), true)
	draw_rect(Rect2(panel_pos, panel_size), COLOR_PANEL_EDGE, false, 3.0)

	draw_string(hud_font, panel_pos + Vector2(34.0, 56.0),
			wave_mgr.get_level_display_name().to_upper() + " — COMPLETE!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, COLOR_BRASS)
	draw_string(hud_font, panel_pos + Vector2(34.0, 96.0),
			"Final Score: %d" % score,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_TEXT)
	draw_string(hud_font, panel_pos + Vector2(34.0, 126.0),
			"Best Score:  %d" % saved_high_score,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_TEXT)
	draw_string(hud_font, panel_pos + Vector2(34.0, 168.0),
			next_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_BRASS)
	draw_string(hud_font, panel_pos + Vector2(34.0, 196.0),
			"Esc:   Return to Menu",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_BRASS)

func _process(delta: float) -> void:
	if Vector2(get_window().size) != _last_viewport_size:
		_update_ui_scale()
		_last_viewport_size = Vector2(get_window().size)

	if game_state == GameState.PLAYING or game_state == GameState.LEVEL_COMPLETE or wave_mgr.is_in_banner():
		grinder_angle += delta * 3.0

	if extraction_feedback_ttl > 0.0:
		extraction_feedback_ttl = maxf(0.0, extraction_feedback_ttl - delta)

	for key: String in bean_spawn_age.keys():
		var age: float = float(bean_spawn_age[key]) + delta
		bean_spawn_age[key] = minf(age, BEAN_SPAWN_TOTAL)

	for i: int in range(wake_pulses.size() - 1, -1, -1):
		wake_pulses[i]["ttl"] = float(wake_pulses[i]["ttl"]) - delta
		if float(wake_pulses[i]["ttl"]) <= 0.0:
			wake_pulses.remove_at(i)

	for i: int in range(grind_pops.size() - 1, -1, -1):
		grind_pops[i]["ttl"] = float(grind_pops[i]["ttl"]) - delta
		if float(grind_pops[i]["ttl"]) <= 0.0:
			grind_pops.remove_at(i)

	for i: int in range(waste_spills.size() - 1, -1, -1):
		var ttl: float = float(waste_spills[i]["ttl"]) - delta
		waste_spills[i]["ttl"] = ttl
		if ttl <= 0.0:
			waste_spills.remove_at(i)
			continue

		var vel: Vector2 = waste_spills[i]["velocity"]
		vel.y += 260.0 * delta
		waste_spills[i]["velocity"] = vel
		waste_spills[i]["position"] = Vector2(waste_spills[i]["position"]) + vel * delta

	queue_redraw()

func update_adaptive_difficulty() -> void:
	if performance_score <= -3:
		bean_trickle_interval = 8.0 / 0.7
		adaptive_enemy_speed = 0.7
	elif performance_score >= 7:
		bean_trickle_interval = 8.0 / 1.6
		adaptive_enemy_speed = 1.6
	elif performance_score >= 3:
		bean_trickle_interval = 8.0 / 1.3
		adaptive_enemy_speed = 1.3
	else:
		bean_trickle_interval = 8.0
		adaptive_enemy_speed = 1.0

func _draw() -> void:
	draw_background()
	draw_machine_frame()
	draw_grid()
	draw_machine_hazards()
	draw_water_puddles()
	draw_grinder()
	draw_ingredient_hazards()
	draw_enemy_hazards()
	draw_idle_beans()
	draw_snake()
	draw_grind_pops()
	draw_waste_spills()
	draw_wake_pulses()
	draw_pressure_release_fx()
	draw_hud()
	draw_wave_banner()

## Draws blue water-puddle pools on the field (L2 + L3 feature).
func draw_water_puddles() -> void:
	if water_puddle_cells.is_empty():
		return
	var t := float(Time.get_ticks_msec()) * 0.001
	for puddle in water_puddle_cells:
		var pp     := grid_to_pixel(puddle)
		var center := pp + Vector2(cell_px() * 0.5, cell_px() * 0.5)
		draw_circle(center, cell_px() * 0.44, Color(0.12, 0.38, 0.68, 0.30))
		draw_circle(center, cell_px() * 0.27, Color(0.22, 0.58, 0.92, 0.20))
		var ripple_r := cell_px() * 0.17 + sin(t * 1.8 + float(puddle.x + puddle.y) * 0.7) * 2.5
		draw_arc(center, ripple_r, 0.0, TAU, 18, Color(0.55, 0.78, 1.0, 0.28), 1.2)


## Draws the Pressure-Release steam telegraph indicator (L3 feature).
func draw_pressure_release_fx() -> void:
	if not pressure_release_enabled or pressure_release_telegraph_timer <= 0.0:
		return
	var t     := 1.0 - clampf(pressure_release_telegraph_timer / PRESSURE_RELEASE_TELEGRAPH_SEC, 0.0, 1.0)
	var alpha := t * 0.6
	var bar_col  := Color(0.75, 0.90, 1.0, alpha)
	var text_col := Color(0.85, 0.97, 1.0, minf(1.0, alpha * 2.0))
	match pressure_vent_side:
		0:  ## Left vent → push right
			draw_rect(Rect2(board_origin.x, board_origin.y, 10.0, board_size.y), bar_col, true)
			draw_string(hud_font, board_origin + Vector2(14.0, board_size.y * 0.5),
					"STEAM →", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_col)
		1:  ## Right vent → push left
			draw_rect(Rect2(board_origin.x + board_size.x - 10.0, board_origin.y, 10.0, board_size.y), bar_col, true)
			draw_string(hud_font, board_origin + Vector2(board_size.x - 72.0, board_size.y * 0.5),
					"← STEAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_col)
		2:  ## Top vent → push down
			draw_rect(Rect2(board_origin.x, board_origin.y, board_size.x, 10.0), bar_col, true)
			draw_string(hud_font, board_origin + Vector2(board_size.x * 0.5 - 32.0, 18.0),
					"STEAM ↓", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_col)
		_:  ## Bottom vent → push up
			draw_rect(Rect2(board_origin.x, board_origin.y + board_size.y - 10.0, board_size.x, 10.0), bar_col, true)
			draw_string(hud_font, board_origin + Vector2(board_size.x * 0.5 - 32.0, board_size.y - 14.0),
					"↑ STEAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_col)


func draw_enemy_hazards() -> void:
	for i in range(decaf_beans.size()):
		var cell: Vector2i = decaf_beans[i]["cell"]
		var px := grid_to_pixel(cell)
		draw_coffee_bean(px, Color("66bb6a"), Color("81c784"), Color("388e3c"))

	for drop in water_drops:
		var cell: Vector2i = drop["cell"]
		var px := grid_to_pixel(cell)
		var center := px + Vector2(cell_px() * 0.5, cell_px() * 0.5)
		draw_circle(center, cell_px() * 0.35, Color(0.26, 0.65, 0.96, 0.7))
		draw_circle(center + Vector2(-2.0, -3.0) * ui_scale, cell_px() * 0.1, Color(0.8, 0.95, 1.0, 0.8))

	if scoop_telegraph_left > 0.0:
		var t := 1.0 - (scoop_telegraph_left / SCOOP_TELEGRAPH_SEC)
		var center := grid_to_pixel(scoop_center) + Vector2(cell_px() * 0.5, cell_px() * 0.5)
		var radius := cell_px() * SCOOP_RADIUS_CELLS * t
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.4))

	if arm_telegraph_left > 0.0:
		var alpha := 1.0 - (arm_telegraph_left / ARM_TELEGRAPH_SEC)
		var px := grid_to_pixel(Vector2i(0, arm_line_index) if arm_is_row else Vector2i(arm_line_index, 0))
		if arm_is_row:
			draw_rect(Rect2(board_origin.x, px.y, board_size.x, cell_px()), Color(1.0, 0.0, 0.0, alpha * 0.3), true)
		else:
			draw_rect(Rect2(px.x, board_origin.y, cell_px(), board_size.y), Color(1.0, 0.0, 0.0, alpha * 0.3), true)
	elif arm_active_left > 0.0:
		var progress := 1.0 - (arm_active_left / ARM_ACTIVE_SEC)
		var thickness := cell_px() * 0.8
		if arm_is_row:
			var cx := board_origin.x + (board_size.x * progress) if arm_push_dir == Vector2i.RIGHT else board_origin.x + board_size.x * (1.0 - progress)
			var y := grid_to_pixel(Vector2i(0, arm_line_index)).y
			draw_rect(Rect2(cx - thickness/2, y, thickness, cell_px()), Color(0.6, 0.6, 0.6, 1.0), true)
		else:
			var cy := board_origin.y + (board_size.y * progress) if arm_push_dir == Vector2i.DOWN else board_origin.y + board_size.y * (1.0 - progress)
			var x := grid_to_pixel(Vector2i(arm_line_index, 0)).x
			draw_rect(Rect2(x, cy - thickness/2, cell_px(), thickness), Color(0.6, 0.6, 0.6, 1.0), true)

func draw_ingredient_hazards() -> void:
	for pebble in pebble_cells:
		var pp := grid_to_pixel(pebble)
		draw_circle(pp + Vector2(cell_px() * 0.32, cell_px() * 0.58), 5.2 * ui_scale, Color("6e7377"))
		draw_circle(pp + Vector2(cell_px() * 0.56, cell_px() * 0.50), 6.5 * ui_scale, Color("85898c"))
		draw_circle(pp + Vector2(cell_px() * 0.72, cell_px() * 0.62), 4.6 * ui_scale, Color("666b70"))

	for rotten in rotten_bean_cells:
		var rp := grid_to_pixel(rotten)
		draw_coffee_bean(rp, Color("3f4a2a"), Color("6e8a44"), Color("222813"))
		var mark := rp + Vector2(cell_px() * 0.5, cell_px() * 0.45)
		draw_line(mark + Vector2(-3, -3), mark + Vector2(3, 3), Color("b4d176"), 1.0)
		draw_line(mark + Vector2(-3, 3), mark + Vector2(3, -3), Color("b4d176"), 1.0)

	for broken in broken_bean_cells:
		var bp := grid_to_pixel(broken)
		draw_coffee_bean(bp, Color("8b5a36"), Color("c88a55"), Color("351f12"))
		var crack := bp + Vector2(cell_px() * 0.48, cell_px() * 0.28)
		draw_line(crack + Vector2(-2, 0), crack + Vector2(2, 4), Color("f0d3ac"), 1.2)
		draw_line(crack + Vector2(2, 4), crack + Vector2(-1, 8), Color("f0d3ac"), 1.2)

func draw_machine_hazards() -> void:
	var time_phase := float(Time.get_ticks_msec()) * 0.001

	for cell_key in conveyor_cells.keys():
		var cell := cell_key as Vector2i
		var dir := conveyor_dir_for(cell)
		var pos := grid_to_pixel(cell)
		draw_rect(Rect2(pos + Vector2(1.0, 1.0) * ui_scale, Vector2(cell_px() - 2.0 * ui_scale, cell_px() - 2.0 * ui_scale)), Color(0.25, 0.28, 0.30, 0.75), true)
		for s: int in range(3):
			var phase := fmod(time_phase * 20.0 + float(s) * 6.0, cell_px())
			if dir == Vector2i.RIGHT or dir == Vector2i.LEFT:
				var x := pos.x + phase
				draw_line(Vector2(x, pos.y + 4.0 * ui_scale), Vector2(x - 6.0 * ui_scale * float(dir.x), pos.y + cell_px() - 4.0 * ui_scale), Color(0.70, 0.72, 0.74, 0.35), 1.0)
			else:
				var y := pos.y + phase
				draw_line(Vector2(pos.x + 4.0 * ui_scale, y), Vector2(pos.x + cell_px() - 4.0 * ui_scale, y - 6.0 * ui_scale * float(dir.y)), Color(0.70, 0.72, 0.74, 0.35), 1.0)

	for gap_cell in gear_gap_cells:
		var gp := grid_to_pixel(gap_cell)
		draw_rect(Rect2(gp + Vector2(2.0, 2.0) * ui_scale, Vector2(cell_px() - 4.0 * ui_scale, cell_px() - 4.0 * ui_scale)), Color(0.06, 0.06, 0.07, 0.90), true)
		draw_rect(Rect2(gp + Vector2(2.0, 2.0) * ui_scale, Vector2(cell_px() - 4.0 * ui_scale, cell_px() - 4.0 * ui_scale)), Color(0.25, 0.25, 0.27, 0.65), false, 1.0)

	for oil_cell in oil_slick_cells:
		var op := grid_to_pixel(oil_cell)
		draw_rect(Rect2(op + Vector2(3.0, 4.0) * ui_scale, Vector2(cell_px() - 6.0 * ui_scale, cell_px() - 8.0 * ui_scale)), Color(0.09, 0.08, 0.08, 0.85), true)
		draw_line(op + Vector2(5.0, 9.0) * ui_scale, op + Vector2(cell_px() - 6.0 * ui_scale, 7.0 * ui_scale), Color(0.58, 0.58, 0.62, 0.28), 1.0)

	for tooth_cell in grinding_teeth_cells:
		var tp := grid_to_pixel(tooth_cell) + Vector2(cell_px() * 0.5, cell_px() * 0.5)
		draw_circle(tp, cell_px() * 0.30, Color(0.62, 0.62, 0.60, 0.95))
		for i: int in range(8):
			var ang := grinder_angle * 1.4 + float(i) * TAU / 8.0
			var inner := tp + Vector2(cos(ang), sin(ang)) * (cell_px() * 0.28)
			var outer := tp + Vector2(cos(ang), sin(ang)) * (cell_px() * 0.42)
			draw_line(inner, outer, Color(0.82, 0.82, 0.78, 0.92), 2.0)

	if piston_row >= 0:
		var y := board_origin.y + float(piston_row) * cell_px()
		if piston_telegraph_left > 0.0:
			var t := 1.0 - clampf(piston_telegraph_left / PISTON_TELEGRAPH_SEC, 0.0, 1.0)
			var tele_col := Color(0.80, 0.20, 0.14, 0.20 + 0.45 * t)
			draw_rect(Rect2(board_origin.x, y, board_size.x, cell_px()), tele_col, true)
			draw_string(hud_font, Vector2(board_origin.x + 10.0, y + 17.0), "PISTON WARNING", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f1c39d"))
		elif piston_active_left > 0.0:
			draw_rect(Rect2(board_origin.x, y, board_size.x, cell_px()), Color(0.42, 0.42, 0.44, 0.95), true)
			draw_rect(Rect2(board_origin.x, y, board_size.x, cell_px()), Color(0.78, 0.78, 0.75, 0.7), false, 2.0)

func draw_background() -> void:
	var viewport_size := Vector2(get_window().size)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), COLOR_BG_TOP, true)

	var stripe_count := 24
	for i in stripe_count:
		var t := float(i) / float(stripe_count)
		var y := t * viewport_size.y
		var shade := COLOR_BG_TOP.lerp(COLOR_BG_BOTTOM, t)
		draw_rect(Rect2(0.0, y, viewport_size.x, viewport_size.y / stripe_count + 1.0), shade, true)

	var steam_offset := fmod(Time.get_ticks_msec() * 0.02, 64.0)
	for i in 18:
		var px := float((i * 83) % int(viewport_size.x + 120)) - steam_offset
		var py := 120.0 + sin((i + Time.get_ticks_msec() * 0.0015)) * 8.0 + float((i * 47) % 380)
		draw_rect(Rect2(px, py, 6, 3), COLOR_STEAM, true)
		draw_rect(Rect2(px + 2, py - 2, 3, 2), COLOR_STEAM, true)

func draw_machine_frame() -> void:
	var frame_outer := Rect2(board_origin - Vector2(22, 22), board_size + Vector2(44, 44))
	var wall_rect := Rect2(board_origin - Vector2(12, 12), board_size + Vector2(24, 24))
	var inner_lip := Rect2(board_origin - Vector2(4, 4), board_size + Vector2(8, 8))

	draw_rect(frame_outer, COLOR_PANEL_EDGE, true)
	draw_rect(wall_rect, COLOR_WALL_METAL, true)
	draw_rect(inner_lip, COLOR_WALL_LIP, false, 2.0)
	draw_rect(Rect2(frame_outer.position + Vector2(4, 4), frame_outer.size - Vector2(8, 8)), COLOR_PANEL, false, 1.0)

	var left_pipe := Rect2(frame_outer.position.x - 12, frame_outer.position.y + 16, 10, frame_outer.size.y - 32)
	var right_pipe := Rect2(frame_outer.end.x + 2, frame_outer.position.y + 16, 10, frame_outer.size.y - 32)
	var top_pipe := Rect2(frame_outer.position.x + 16, frame_outer.position.y - 12, frame_outer.size.x - 32, 10)
	var bottom_pipe := Rect2(frame_outer.position.x + 16, frame_outer.end.y + 2, frame_outer.size.x - 32, 10)

	draw_rect(left_pipe, COLOR_COPPER, true)
	draw_rect(right_pipe, COLOR_COPPER, true)
	draw_rect(top_pipe, COLOR_COPPER, true)
	draw_rect(bottom_pipe, COLOR_COPPER, true)

	# Pipe highlights and seams to fake cylindrical metal.
	draw_line(Vector2(left_pipe.position.x + 2, left_pipe.position.y), Vector2(left_pipe.position.x + 2, left_pipe.end.y), COLOR_BRASS, 1.0)
	draw_line(Vector2(right_pipe.position.x + 2, right_pipe.position.y), Vector2(right_pipe.position.x + 2, right_pipe.end.y), COLOR_BRASS, 1.0)
	draw_line(Vector2(top_pipe.position.x, top_pipe.position.y + 2), Vector2(top_pipe.end.x, top_pipe.position.y + 2), COLOR_BRASS, 1.0)
	draw_line(Vector2(bottom_pipe.position.x, bottom_pipe.position.y + 2), Vector2(bottom_pipe.end.x, bottom_pipe.position.y + 2), COLOR_BRASS, 1.0)

	var rivet_count_x := 12
	for i: int in range(rivet_count_x):
		var t := float(i) / float(rivet_count_x - 1)
		var rx := lerpf(wall_rect.position.x + 14.0, wall_rect.end.x - 14.0, t)
		var top_rivet := Vector2(rx, wall_rect.position.y + 6.0)
		var bottom_rivet := Vector2(rx, wall_rect.end.y - 6.0)
		draw_circle(top_rivet, 2.3, COLOR_BRASS)
		draw_circle(bottom_rivet, 2.3, COLOR_BRASS)
		draw_circle(top_rivet, 0.9, COLOR_PANEL)
		draw_circle(bottom_rivet, 0.9, COLOR_PANEL)

	var rivet_count_y := 8
	for j: int in range(rivet_count_y):
		var u := float(j) / float(rivet_count_y - 1)
		var ry := lerpf(wall_rect.position.y + 14.0, wall_rect.end.y - 14.0, u)
		var left_rivet := Vector2(wall_rect.position.x + 6.0, ry)
		var right_rivet := Vector2(wall_rect.end.x - 6.0, ry)
		draw_circle(left_rivet, 2.3, COLOR_BRASS)
		draw_circle(right_rivet, 2.3, COLOR_BRASS)
		draw_circle(left_rivet, 0.9, COLOR_PANEL)
		draw_circle(right_rivet, 0.9, COLOR_PANEL)

func draw_grid() -> void:
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var cell_pos := board_origin + Vector2(x * cell_px(), y * cell_px())
			var base_color := COLOR_GRID_A if ((x + y) % 2 == 0) else COLOR_GRID_B
			draw_rect(Rect2(cell_pos, Vector2(cell_px(), cell_px())), base_color, true)

			var streak_seed := float((x * 13 + y * 29) % 5)
			for s: int in range(3):
				var sy := cell_pos.y + 4.0 * ui_scale + float(s) * 7.0 * ui_scale
				var alpha := 0.09 + streak_seed * 0.02
				draw_line(
					Vector2(cell_pos.x + 2.0 * ui_scale, sy),
					Vector2(cell_pos.x + cell_px() - 2.0 * ui_scale, sy),
					Color(COLOR_METAL_BRUSH.r, COLOR_METAL_BRUSH.g, COLOR_METAL_BRUSH.b, alpha),
					1.0
				)

			if ((x * 7 + y * 3) % 4) == 0:
				draw_line(
					Vector2(cell_pos.x + 5.0 * ui_scale, cell_pos.y + 3.0 * ui_scale),
					Vector2(cell_pos.x + 8.0 * ui_scale, cell_pos.y + cell_px() - 3.0 * ui_scale),
					COLOR_METAL_SHADOW,
					1.0
				)

			draw_rect(Rect2(cell_pos, Vector2(cell_px(), cell_px())), COLOR_GRID_LINE, false, 1.0)

func draw_grinder() -> void:
	if grinder_origin.x < 0 or grinder_origin.y < 0:
		return

	var grinder_pos := grid_to_pixel(grinder_origin)
	var grinder_size_px := Vector2(cell_px() * float(grinder_size), cell_px() * float(grinder_size))
	var grinder_rect := Rect2(grinder_pos, grinder_size_px)
	var center := grinder_rect.position + grinder_rect.size * 0.5

	if not grinder_active:
		var pulse := 0.65 + 0.35 * sin(grinder_angle * 2.0)
		var spin_offset := Vector2(cos(grinder_angle), sin(grinder_angle)) * 2.0
		var shadow_col := Color(0.05, 0.04, 0.03, 0.24 + 0.12 * pulse)
		var halo_col := Color(0.20, 0.16, 0.12, 0.20 + 0.10 * pulse)
		draw_rect(grinder_rect, Color(0.0, 0.0, 0.0, 0.10), true)
		draw_arc(center + spin_offset, cell_px() * 0.86, 0.0, TAU, 32, shadow_col, 3.0)
		draw_arc(center - spin_offset, cell_px() * 0.62, 0.0, TAU, 28, halo_col, 2.0)

		for i: int in range(4):
			var ang := grinder_angle + float(i) * PI * 0.5
			var dir := Vector2(cos(ang), sin(ang))
			var p0 := center + dir * (6.0 * ui_scale)
			var p1 := center + dir * (cell_px() * 0.86)
			draw_line(p0, p1, Color(0.08, 0.07, 0.06, 0.38), 2.0)

		if game_state == GameState.PLAYING:
			var tele_text := "GRINDER INCOMING"
			var text_pos := grinder_rect.position + Vector2(-8, -8)
			text_pos.x = clampf(text_pos.x, board_origin.x + 4.0, board_origin.x + board_size.x - 150.0)
			text_pos.y = clampf(text_pos.y, board_origin.y + 14.0, board_origin.y + board_size.y - 6.0)
			draw_string(hud_font, text_pos, tele_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d0a45a"))
		return

	# Housing occupying grinder_size × grinder_size cells.
	draw_rect(grinder_rect, Color("2f302f"), true)
	draw_rect(grinder_rect, Color("6f6a61"), false, 2.0)
	draw_rect(Rect2(grinder_rect.position + Vector2(2, 2), grinder_rect.size - Vector2(4, 4)), Color("3d3e3d"), false, 1.0)

	# Rotating inner ring and blades.
	draw_arc(center, cell_px() * 0.82, 0.0, TAU, 36, Color("938d82"), 2.0)
	draw_arc(center, cell_px() * 0.42, 0.0, TAU, 24, Color("1e1f1f"), 2.0)

	for i: int in range(4):
		var ang := grinder_angle + float(i) * PI * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var tip := center + dir * (cell_px() * 0.76)
		var inner_l := center + side * 2.5
		var inner_r := center - side * 2.5
		draw_colored_polygon([inner_l, tip, inner_r], Color("b9b1a4"))

	# Bolt in the middle.
	draw_circle(center, 4.0, Color("c7b59b"))
	draw_circle(center, 1.5, Color("4d3a28"))

func draw_idle_beans() -> void:
	var ticks := float(Time.get_ticks_msec()) * 0.001
	for bean in idle_beans:
		var top_left := grid_to_pixel(bean)
		var center := top_left + Vector2(cell_px() * 0.5, cell_px() * 0.5)
		var age: float = float(bean_spawn_age.get(bean_key(bean), BEAN_SPAWN_TOTAL))
		var y_offset := 0.0
		var alpha := 1.0

		if age < BEAN_SPAWN_SHADOW:
			var shadow_t := age / BEAN_SPAWN_SHADOW
			var shadow_w := lerpf(3.0 * ui_scale, cell_px() * 0.72, shadow_t)
			var shadow_h := lerpf(1.0 * ui_scale, 4.0 * ui_scale, shadow_t)
			var shadow_col := Color(0.08, 0.06, 0.04, lerpf(0.12, 0.36, shadow_t))
			draw_rect(Rect2(center + Vector2(-shadow_w * 0.5, cell_px() * 0.36), Vector2(shadow_w, shadow_h)), shadow_col, true)
			continue

		if age < BEAN_SPAWN_SHADOW + BEAN_SPAWN_APPEAR:
			var appear_t := (age - BEAN_SPAWN_SHADOW) / BEAN_SPAWN_APPEAR
			y_offset = lerpf(-8.0, -2.0, appear_t)
			alpha = appear_t
		elif age < BEAN_SPAWN_SHADOW + BEAN_SPAWN_APPEAR + BEAN_SPAWN_BOUNCE:
			var bounce_t := (age - BEAN_SPAWN_SHADOW - BEAN_SPAWN_APPEAR) / BEAN_SPAWN_BOUNCE
			if bounce_t < 0.5:
				y_offset = lerpf(-2.0, 3.0, bounce_t * 2.0)
			else:
				y_offset = lerpf(3.0, 0.0, (bounce_t - 0.5) * 2.0)
		else:
			var settle_t := (age - BEAN_SPAWN_SHADOW - BEAN_SPAWN_APPEAR - BEAN_SPAWN_BOUNCE) / BEAN_SPAWN_SETTLE
			y_offset = lerpf(0.7, 0.0, clampf(settle_t, 0.0, 1.0))

		var shadow_alpha := 0.24 if age >= BEAN_SPAWN_SHADOW + BEAN_SPAWN_APPEAR else 0.15
		draw_rect(Rect2(center + Vector2(-cell_px() * 0.34, cell_px() * 0.36), Vector2(cell_px() * 0.68, 3.0 * ui_scale)), Color(0.09, 0.07, 0.05, shadow_alpha), true)

		var fill_col := Color(COLOR_FOOD.r, COLOR_FOOD.g, COLOR_FOOD.b, alpha)
		var hi_col := Color(0.77, 0.54, 0.33, alpha)
		var seam_col := Color(0.25, 0.16, 0.10, alpha)
		draw_coffee_bean(top_left + Vector2(0.0, y_offset), fill_col, hi_col, seam_col)

		# Only fully-settled beans emit the idle zzz marker.
		if age >= BEAN_SPAWN_TOTAL:
			for i: int in range(3):
				var t := ticks + float(i) * 0.37 + float(bean.x * 11 + bean.y * 7) * 0.03
				var drift := Vector2((float(i) * 7.0 + sin(t * 2.2) * 2.0) * ui_scale, (-12.0 - float(i) * 6.0 - fmod(t * 10.0, 5.0)) * ui_scale)
				var z_alpha := 0.35 + float(i) * 0.22
				var z_col := Color(COLOR_STEAM.r, COLOR_STEAM.g, COLOR_STEAM.b, z_alpha)
				draw_string(hud_font, center + drift, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round((14 + i * 3) * ui_scale)), z_col)

func draw_wake_pulses() -> void:
	for pulse in wake_pulses:
		var ttl := float(pulse["ttl"])
		var life := float(pulse["life"])
		var t := 1.0 - clampf(ttl / life, 0.0, 1.0)
		var center: Vector2 = pulse["position"]
		var radius := lerpf(4.0, 18.0, t)
		var ring_col := Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, 0.7 * (1.0 - t))
		draw_arc(center, radius, 0.0, TAU, 24, ring_col, 2.0)

		for i: int in range(6):
			var ang := float(i) * TAU / 6.0 + t * 1.1
			var p0 := center + Vector2(cos(ang), sin(ang)) * (radius - 2.0)
			var p1 := center + Vector2(cos(ang), sin(ang)) * (radius + 5.0)
			draw_line(p0, p1, Color(COLOR_COPPER.r, COLOR_COPPER.g, COLOR_COPPER.b, 0.6 * (1.0 - t)), 1.0)

func draw_grind_pops() -> void:
	for pop in grind_pops:
		var ttl := float(pop["ttl"])
		var life := float(pop["life"])
		var t := 1.0 - clampf(ttl / life, 0.0, 1.0)
		var center: Vector2 = pop["position"]
		var ring_r := lerpf(3.0, 12.0, t)
		var core_r := lerpf(4.0, 1.0, t)
		var alpha := 0.9 * (1.0 - t)

		draw_circle(center, core_r, Color(0.68, 0.52, 0.34, alpha))
		draw_arc(center, ring_r, 0.0, TAU, 18, Color(0.88, 0.72, 0.46, alpha), 1.8)

		for i: int in range(5):
			var ang := float(i) * TAU / 5.0 + t * 0.9
			var p0 := center + Vector2(cos(ang), sin(ang)) * (ring_r - 1.0)
			var p1 := center + Vector2(cos(ang), sin(ang)) * (ring_r + 3.0)
			draw_line(p0, p1, Color(0.95, 0.80, 0.55, alpha), 1.0)

func draw_waste_spills() -> void:
	for spill in waste_spills:
		var ttl := float(spill["ttl"])
		var life := float(spill["life"])
		var t := 1.0 - clampf(ttl / life, 0.0, 1.0)
		var pos: Vector2 = spill["position"]
		var alpha := 0.95 * (1.0 - t)

		draw_rect(Rect2(pos - Vector2(4.0, 3.0), Vector2(8.0, 6.0)), Color(0.62, 0.40, 0.24, alpha), true)
		draw_rect(Rect2(pos - Vector2(3.0, 2.0), Vector2(6.0, 4.0)), Color(0.77, 0.54, 0.33, alpha * 0.75), false, 1.0)
		if t < 0.45:
			draw_string(hud_font, pos + Vector2(7.0, -6.0), "clink", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.89, 0.78, 0.62, alpha * 0.9))

func draw_snake() -> void:
	for i in snake.size():
		var segment := snake[i]
		var top_left := grid_to_pixel(segment)
		var body_color := COLOR_SNAKE_HEAD if i == 0 else COLOR_SNAKE_BODY
		var highlight := COLOR_SNAKE_HIGHLIGHT if i == 0 else COLOR_COPPER
		var seam_color := Color("2f1c11") if i == 0 else Color("3a2416")
		if i > 0 and has_index(rotten_segment_indices, i):
			body_color = Color("4b5a2f")
			highlight = Color("7f9e4b")
			seam_color = Color("273016")

		draw_coffee_bean(top_left, body_color, highlight, seam_color)

		if i == 0:
			var eye_color := Color("231910")
			var eye_base := top_left + Vector2(cell_px() * 0.5, cell_px() * 0.5)
			if direction == Vector2i.UP:
				draw_rect(Rect2(eye_base + Vector2(-5, -7), Vector2(3, 3)), eye_color, true)
				draw_rect(Rect2(eye_base + Vector2(2, -7), Vector2(3, 3)), eye_color, true)
			elif direction == Vector2i.DOWN:
				draw_rect(Rect2(eye_base + Vector2(-5, 4), Vector2(3, 3)), eye_color, true)
				draw_rect(Rect2(eye_base + Vector2(2, 4), Vector2(3, 3)), eye_color, true)
			elif direction == Vector2i.LEFT:
				draw_rect(Rect2(eye_base + Vector2(-7, -5), Vector2(3, 3)), eye_color, true)
				draw_rect(Rect2(eye_base + Vector2(-7, 2), Vector2(3, 3)), eye_color, true)
			else:
				draw_rect(Rect2(eye_base + Vector2(4, -5), Vector2(3, 3)), eye_color, true)
				draw_rect(Rect2(eye_base + Vector2(4, 2), Vector2(3, 3)), eye_color, true)

func draw_coffee_bean(top_left: Vector2, fill: Color, highlight: Color, seam: Color) -> void:
	var center := top_left + Vector2(cell_px() * 0.5, cell_px() * 0.5)
	var radius_x := cell_px() * 0.33
	var radius_y := cell_px() * 0.39
	var edge_col := Color(0.14, 0.09, 0.06, fill.a)
	var left_center := center + Vector2(-radius_x + 2.4, 0.0)
	var right_center := center + Vector2(radius_x - 2.4, 0.0)

	# Bean body: two lobes and a center bridge for a natural bean silhouette.
	draw_circle(left_center, radius_y, fill)
	draw_circle(right_center, radius_y, fill)
	draw_rect(
		Rect2(
			center + Vector2(-radius_x + 2.4, -radius_y + 1.2),
			Vector2((radius_x - 2.4) * 2.0, (radius_y - 1.2) * 2.0)
		),
		fill,
		true
	)

	# Edge darkening makes the bean read as rounded and glossy.
	draw_arc(left_center, radius_y, PI * 0.72, PI * 1.35, 14, edge_col, 1.2)
	draw_arc(right_center, radius_y, -PI * 0.35, PI * 0.35, 14, edge_col, 1.2)
	draw_rect(
		Rect2(
			center + Vector2(-radius_x + 1.8, -radius_y + 0.8),
			Vector2((radius_x - 1.8) * 2.0, (radius_y - 0.8) * 2.0)
		),
		edge_col,
		false,
		1.0
	)

	# Soft specular highlight on the upper-left, like polished roast surface.
	draw_circle(center + Vector2(-4.0, -3.6) * ui_scale, 3.4 * ui_scale, Color(highlight.r, highlight.g, highlight.b, highlight.a * 0.9))
	draw_rect(
		Rect2(center + Vector2(-7.0, -6.6) * ui_scale, Vector2(8.4, 2.2) * ui_scale),
		Color(highlight.r, highlight.g, highlight.b, highlight.a * 0.55),
		true
	)

	# Curved center crack (bean seam).
	var seam_top := center + Vector2(-0.8, -7.2) * ui_scale
	for j: int in range(7):
		var jy := float(j)
		var xwobble := sin(jy * 0.9) * 1.2
		var p0 := seam_top + Vector2(xwobble, jy * 2.2) * ui_scale
		var p1 := seam_top + Vector2(xwobble + 0.6, jy * 2.2 + 1.3) * ui_scale
		draw_line(p0, p1, seam, 1.1 * ui_scale)

func draw_hud() -> void:
	var viewport_size := get_viewport_rect().size
	var hud_rect := Rect2(0.0, 0.0, viewport_size.x, HUD_HEIGHT)
	draw_rect(hud_rect, Color("261b14"), true)
	draw_rect(Rect2(0.0, HUD_PRIMARY_HEIGHT, viewport_size.x, HUD_SECONDARY_HEIGHT), Color("1f1611"), true)
	draw_line(Vector2(0, HUD_PRIMARY_HEIGHT), Vector2(viewport_size.x, HUD_PRIMARY_HEIGHT), COLOR_PANEL_EDGE, 1.0)
	draw_line(Vector2(0, HUD_HEIGHT), Vector2(viewport_size.x, HUD_HEIGHT), COLOR_PANEL_EDGE, 2.0)

	# Level name replaces the old placeholder title.
	var level_title: String = str(wave_mgr.get_level_display_name()).to_upper()
	draw_string(hud_font, Vector2(28, 30), level_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_BRASS)

	# Wave progress: "Wave X / 3" + compact score-vs-target bar.
	var wave_num: int    = int(wave_mgr.get_display_wave_number())
	var wave_total: int  = int(wave_mgr.get_wave_count())
	var wave_target: int = int(wave_mgr.get_wave_score_target())
	var wave_label  := "Wave %d/%d  Target: %d" % [wave_num, wave_total, wave_target]
	draw_string(hud_font, Vector2(28, 50), wave_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_TEXT)

	# Thin progress bar showing score vs. wave target.
	var bar_rect  := Rect2(28.0, 56.0, 220.0, 6.0)
	var bar_ratio := clampf(float(score) / float(maxi(wave_target, 1)), 0.0, 1.0)
	draw_rect(bar_rect, Color("1a140f"), true)
	draw_rect(bar_rect, COLOR_PANEL_EDGE, false, 1.0)
	var bar_fill_col := COLOR_BRASS if bar_ratio >= 0.9 else Color("6f9f52")
	draw_rect(Rect2(bar_rect.position + Vector2(1, 1), Vector2((bar_rect.size.x - 2.0) * bar_ratio, bar_rect.size.y - 2.0)), bar_fill_col, true)

	var score_text := "Score: %d   Best: %d" % [score, best_score]
	draw_string(hud_font, Vector2(28, 76), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TEXT)

	var chain_count := snake.size()
	var chain_col := Color("6aa75a") if chain_count <= 14 else (COLOR_BRASS if chain_count <= GRINDER_DOSE_CAP else COLOR_DANGER)
	draw_string(hud_font, Vector2(330, 34), "Chain: %d" % chain_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, chain_col)

	var speed_text := "Speed: %.1fx" % (0.13 / move_interval)
	draw_string(hud_font, Vector2(330, 64), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)

	var fresh_panel := Rect2(520.0, 16.0, 320.0, 24.0)
	var freshness_ratio: float = clampf(freshness / FRESHNESS_MAX, 0.0, 1.0)
	var fill_color := Color("6f9f52") if freshness_ratio > 0.5 else (Color("c68b42") if freshness_ratio > 0.25 else COLOR_DANGER)
	draw_rect(fresh_panel, Color("1a140f"), true)
	draw_rect(fresh_panel, COLOR_PANEL_EDGE, false, 2.0)
	draw_rect(Rect2(fresh_panel.position + Vector2(2, 2), Vector2((fresh_panel.size.x - 4.0) * freshness_ratio, fresh_panel.size.y - 4.0)), fill_color, true)
	draw_string(hud_font, Vector2(522, 34), "Freshness: %d%%" % int(round(freshness)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)

	var dose_count: int = grind_grounded_count if is_grinding else mini(snake.size(), GRINDER_DOSE_CAP)
	draw_portafilter_hud(Vector2(520.0, 44.0), dose_count, GRINDER_DOSE_CAP)

	var rally_state := "READY" if rally_cooldown_left <= 0.0 else "%.1fs" % rally_cooldown_left
	var rally_ratio := 1.0 - clampf(rally_cooldown_left / RALLY_COOLDOWN_SEC, 0.0, 1.0)
	var rally_row_y := HUD_PRIMARY_HEIGHT + 20.0
	draw_string(hud_font, Vector2(28.0, rally_row_y), "Rally Cooldown", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_BRASS)
	var rally_bar := Rect2(172.0, HUD_PRIMARY_HEIGHT + 7.0, 200.0, 16.0)
	draw_rect(rally_bar, Color("1a140f"), true)
	draw_rect(rally_bar, COLOR_PANEL_EDGE, false, 1.0)
	draw_rect(Rect2(rally_bar.position + Vector2(2.0, 2.0), Vector2((rally_bar.size.x - 4.0) * rally_ratio, rally_bar.size.y - 4.0)), Color("8c5c36"), true)
	draw_string(hud_font, Vector2(388.0, rally_row_y), rally_state, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)

	var burr_left := burr_timer
	var piston_left := piston_timer if piston_telegraph_left <= 0.0 and piston_active_left <= 0.0 else (piston_telegraph_left if piston_telegraph_left > 0.0 else piston_active_left)
	var piston_state := "Idle"
	if piston_telegraph_left > 0.0:
		piston_state = "Warn"
	elif piston_active_left > 0.0:
		piston_state = "Slam"
	var slip_state := "SLIP" if oil_slick_timer > 0.0 else "Grip"
	draw_string(hud_font, Vector2(470.0, rally_row_y), "Gear", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_TEXT)
	draw_string(hud_font, Vector2(510.0, rally_row_y), "%.1fs" % burr_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_BRASS)
	draw_string(hud_font, Vector2(610.0, rally_row_y), "Piston %s %.1fs" % [piston_state, piston_left], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_TEXT)
	draw_string(hud_font, Vector2(790.0, rally_row_y), "Oil %s" % slip_state, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_TEXT)
	if pressure_release_enabled:
		var steam_left := pressure_release_timer if pressure_release_telegraph_timer <= 0.0 else pressure_release_telegraph_timer
		var steam_label := "Steam %.1fs" % steam_left
		draw_string(hud_font, Vector2(858.0, rally_row_y), steam_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a8d4e8"))

	if extraction_active:
		var cup_rect := Rect2(860.0, 12.0, 78.0, 58.0)
		var cup_fill_ratio := clampf(extraction_timer / EXTRACTION_AUTO_PULL_SEC, 0.0, 1.0)
		var cup_col := Color("d2bf9f")
		if extraction_timer <= 15.0:
			cup_col = Color("d6c7ad")
		elif extraction_timer <= 20.0:
			cup_col = Color("d4a46a")
		elif extraction_timer <= 29.0:
			cup_col = Color("ffd16b")
		elif extraction_timer <= 35.0:
			cup_col = Color("9a6a43")
		else:
			cup_col = Color("3b2a1c")

		draw_rect(cup_rect, Color("2a1f17"), true)
		draw_rect(cup_rect, COLOR_PANEL_EDGE, false, 2.0)
		var fill_h := (cup_rect.size.y - 10.0) * cup_fill_ratio
		draw_rect(Rect2(cup_rect.position.x + 5.0, cup_rect.end.y - 5.0 - fill_h, cup_rect.size.x - 10.0, fill_h), cup_col, true)
		draw_string(hud_font, cup_rect.position + Vector2(8.0, 20.0), "Pull", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)
		draw_string(hud_font, cup_rect.position + Vector2(8.0, 40.0), "%.1fs" % extraction_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_TEXT)

	if extraction_feedback_ttl > 0.0:
		draw_string(hud_font, Vector2(860.0, 70.0), extraction_feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_BRASS)
	if washed_buff_timer > 0.0:
		draw_string(hud_font, Vector2(860.0, 80.0), "Washed ×1.5  %.0fs" % washed_buff_timer,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6fa8dc"))

	var controls := "Arrows / WASD Move   Space Rally   E/Enter Pull Shot   Esc Pause"
	var frame_bottom := board_origin.y + board_size.y + 22.0
	var footer_y := frame_bottom + 34.0
	var footer_rect := Rect2(0.0, footer_y - 18.0, viewport_size.x, 28.0)
	draw_rect(footer_rect, Color(0.12, 0.09, 0.07, 0.75), true)
	draw_line(Vector2(0.0, footer_rect.position.y), Vector2(viewport_size.x, footer_rect.position.y), COLOR_PANEL_EDGE, 1.0)
	draw_string(hud_font, Vector2(28.0, footer_y), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

	if game_state == GameState.START_MENU:
		draw_start_menu()

	if game_state == GameState.PAUSED:
		draw_pause_menu()

	if game_state == GameState.GAME_OVER:
		draw_game_over_panel()

	if game_state == GameState.LEVEL_COMPLETE:
		draw_level_complete_panel()

	if game_state == GameState.PLAYING and resume_countdown_left > 0.0:
		var countdown := int(ceil(resume_countdown_left))
		draw_centered_panel("RESUMING", "%d" % countdown)

func draw_portafilter_hud(pos: Vector2, dose_count: int, dose_cap: int) -> void:
	var body := Rect2(pos.x + 62.0, pos.y + 9.0, 186.0, 16.0)
	var count_box := Rect2(pos.x + 256.0, pos.y + 5.0, 56.0, 24.0)
	var ratio: float = clampf(float(dose_count) / float(dose_cap), 0.0, 1.0)

	# Label and bar are separated so they never overlap.
	draw_string(hud_font, Vector2(pos.x, pos.y + 22.0), "Dose", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_BRASS)
	draw_rect(body, Color("3c2f24"), true)
	draw_rect(body, Color("8d6a48"), false, 2.0)

	var inner := Rect2(body.position + Vector2(2.0, 2.0), body.size - Vector2(4.0, 4.0))
	draw_rect(inner, Color("1d140f"), true)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), Color("8c5c36"), true)

	# Tick separators for 18g capacity.
	for i: int in range(1, 6):
		var tx := inner.position.x + inner.size.x * float(i) / 6.0
		draw_line(Vector2(tx, inner.position.y), Vector2(tx, inner.end.y), Color(0.12, 0.09, 0.07, 0.35), 1.0)

	draw_rect(count_box, Color("2a1f17"), true)
	draw_rect(count_box, COLOR_PANEL_EDGE, false, 1.0)
	draw_string(hud_font, Vector2(count_box.position.x + 8.0, count_box.position.y + 17.0), "%d/%d" % [dose_count, dose_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_TEXT)

func draw_game_over_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(430.0, 220.0)
	var panel_pos := (viewport_size - panel_size) * 0.5

	draw_rect(Rect2(panel_pos, panel_size), Color(0.11, 0.08, 0.06, 0.96), true)
	draw_rect(Rect2(panel_pos, panel_size), COLOR_PANEL_EDGE, false, 3.0)

	draw_string(hud_font, panel_pos + Vector2(34.0, 54.0), "PRESSURE LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, COLOR_DANGER)
	draw_string(hud_font, panel_pos + Vector2(34.0, 92.0), "Final Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)
	draw_string(hud_font, panel_pos + Vector2(34.0, 122.0), "Best Score: %d" % saved_high_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)
	draw_string(hud_font, panel_pos + Vector2(34.0, 160.0), "Enter: Restart Run", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_BRASS)
	draw_string(hud_font, panel_pos + Vector2(34.0, 186.0), "Esc: Return to Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_BRASS)

func draw_start_menu() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(460, 250)
	var panel_pos := (viewport_size - panel_size) * 0.5

	draw_rect(Rect2(panel_pos, panel_size), Color(0.11, 0.08, 0.06, 0.96), true)
	draw_rect(Rect2(panel_pos, panel_size), COLOR_PANEL_EDGE, false, 3.0)
	draw_string(hud_font, panel_pos + Vector2(36, 52), "KAMIKAZE SNAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, COLOR_BRASS)
	draw_string(hud_font, panel_pos + Vector2(36, 82), "Inside the machine. Stay sharp.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TEXT)

	for i: int in range(start_menu_options.size()):
		var y := panel_pos.y + 132.0 + float(i) * 42.0
		var selected: bool = (i == start_menu_index)
		if selected:
			draw_rect(Rect2(panel_pos.x + 30.0, y - 24.0, panel_size.x - 60.0, 30.0), Color(0.45, 0.30, 0.17, 0.45), true)
			draw_rect(Rect2(panel_pos.x + 30.0, y - 24.0, panel_size.x - 60.0, 30.0), COLOR_BRASS, false, 2.0)
			draw_string(hud_font, Vector2(panel_pos.x + 52.0, y - 3.0), "> " + start_menu_options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COLOR_BRASS)
		else:
			draw_string(hud_font, Vector2(panel_pos.x + 52.0, y - 3.0), "  " + start_menu_options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COLOR_TEXT)

	draw_string(hud_font, panel_pos + Vector2(36, 228), "W/S or Up/Down to navigate, Enter to select, Esc to quit", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

func draw_pause_menu() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(420, 250)
	var panel_pos := (viewport_size - panel_size) * 0.5

	draw_rect(Rect2(panel_pos, panel_size), Color(0.11, 0.08, 0.06, 0.96), true)
	draw_rect(Rect2(panel_pos, panel_size), COLOR_PANEL_EDGE, false, 3.0)
	draw_string(hud_font, panel_pos + Vector2(38, 56), "PAUSE VALVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, COLOR_DANGER)
	draw_string(hud_font, panel_pos + Vector2(38, 86), "Machine pressure is on hold.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TEXT)

	for i: int in range(pause_menu_options.size()):
		var y := panel_pos.y + 132.0 + float(i) * 36.0
		var selected: bool = (i == pause_menu_index)
		if selected:
			draw_rect(Rect2(panel_pos.x + 32.0, y - 22.0, panel_size.x - 64.0, 28.0), Color(0.45, 0.30, 0.17, 0.45), true)
			draw_rect(Rect2(panel_pos.x + 32.0, y - 22.0, panel_size.x - 64.0, 28.0), COLOR_BRASS, false, 2.0)
			draw_string(hud_font, Vector2(panel_pos.x + 52.0, y - 2.0), "> " + pause_menu_options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, COLOR_BRASS)
		else:
			draw_string(hud_font, Vector2(panel_pos.x + 52.0, y - 2.0), "  " + pause_menu_options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, COLOR_TEXT)

	draw_string(hud_font, panel_pos + Vector2(38, 226), "Resume starts a 3-2-1 countdown", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

func draw_centered_panel(title: String, subtitle: String) -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(360.0, 130.0) * ui_scale
	var panel_pos := (viewport_size - panel_size) * 0.5

	draw_rect(Rect2(panel_pos, panel_size), Color(0.11, 0.08, 0.06, 0.95), true)
	draw_rect(Rect2(panel_pos, panel_size), COLOR_PANEL_EDGE, false, 3.0)

	draw_string(hud_font, panel_pos + Vector2(44, 55), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, COLOR_DANGER)
	draw_string(hud_font, panel_pos + Vector2(44, 92), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)

func grid_to_pixel(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x * cell_px(), cell.y * cell_px())

func cell_px() -> float:
	return float(CELL_SIZE) * ui_scale

func _update_ui_scale() -> void:
	var viewport_size := Vector2(get_window().size)
	var board_w := float(GRID_SIZE.x * CELL_SIZE)
	var board_h := float(GRID_SIZE.y * CELL_SIZE)
	var available_w := maxf(320.0, viewport_size.x - BOARD_PADDING * 2.0)
	var available_h := maxf(240.0, viewport_size.y - HUD_HEIGHT - BOARD_PADDING * 2.0)
	ui_scale = maxf(0.65, minf(available_w / board_w, available_h / board_h))
	board_size = Vector2(board_w, board_h) * ui_scale
	board_origin = Vector2(
		floor((viewport_size.x - board_size.x) * 0.5),
		HUD_HEIGHT + BOARD_PADDING
	)
