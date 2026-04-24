extends Node2D

const GRID_SIZE := Vector2i(28, 18)
const CELL_SIZE := 24
const HUD_HEIGHT := 84
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
const GRINDER_SIZE := 2
const GRINDER_TELEGRAPH_TIME := 2.0
const GRINDER_RELOCATE_INTERVAL := 5.0
const GRIND_POP_LIFE := 0.20
const GRIND_STEP_INTERVAL := 0.035
const GRINDER_DOSE_CAP := 18
const FRESHNESS_MAX := 100.0
const FRESHNESS_DRAIN_PER_SEC := 2.8

var board_origin := Vector2.ZERO
var board_size := Vector2.ZERO

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var idle_beans: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()

var score := 0
var best_score := 0
var move_interval := 0.13
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
	GAME_OVER
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

func _ready() -> void:
	rng.randomize()
	hud_font = ThemeDB.fallback_font
	var viewport_size := get_viewport_rect().size
	board_size = Vector2(GRID_SIZE.x * CELL_SIZE, GRID_SIZE.y * CELL_SIZE)
	board_origin = Vector2(
		floor((viewport_size.x - board_size.x) * 0.5),
		HUD_HEIGHT + BOARD_PADDING
	)

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
	game_state = GameState.START_MENU

func start_new_run() -> void:
	score = 0
	move_interval = 0.13
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
	place_grinder_random()
	spawn_idle_beans(rng.randi_range(8, 15))
	bean_spawn_timer = 0.0
	grinder_angle = 0.0
	grinder_active = false
	grinder_telegraph_timer = GRINDER_TELEGRAPH_TIME
	grinder_relocate_timer = GRINDER_RELOCATE_INTERVAL
	is_grinding = false
	grind_step_timer = 0.0
	grind_pops.clear()
	grind_grounded_count = 0
	wake_pulses.clear()
	queue_redraw()

func can_spawn_leader(cell: Vector2i) -> bool:
	return in_bounds(cell) and not is_grinder_cell(cell) and not is_idle_bean_at(cell)

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
	snake.append(spawn_cell)
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT

func spawn_grind_pop(cell: Vector2i) -> void:
	var center := grid_to_pixel(cell) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	grind_pops.append({"position": center, "ttl": GRIND_POP_LIFE, "life": GRIND_POP_LIFE})

func begin_grind_sequence() -> void:
	if is_grinding or snake.is_empty():
		return
	is_grinding = true
	grind_step_timer = 0.0
	grind_grounded_count = 0

func process_grind(delta: float) -> void:
	if not is_grinding:
		return

	grind_step_timer += delta
	while grind_step_timer >= GRIND_STEP_INTERVAL and is_grinding:
		grind_step_timer -= GRIND_STEP_INTERVAL
		if snake.is_empty():
			is_grinding = false
			spawn_new_leader_bean()
			return

		var consumed: Vector2i = snake.pop_front()
		spawn_grind_pop(consumed)
		if grind_grounded_count < GRINDER_DOSE_CAP:
			grind_grounded_count += 1
			score += 2
			best_score = max(best_score, score)

		if snake.is_empty():
			is_grinding = false
			grind_grounded_count = 0
			spawn_new_leader_bean()
			return

func bean_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func spawn_wake_pulse(cell: Vector2i) -> void:
	var center := grid_to_pixel(cell) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	wake_pulses.append({"position": center, "ttl": 0.42, "life": 0.42})

func set_pause_state(paused: bool) -> void:
	is_paused = paused
	game_state = GameState.PAUSED if paused else GameState.PLAYING
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

	var spawned := 0
	var attempts := 0
	var max_attempts := GRID_SIZE.x * GRID_SIZE.y * 3

	while spawned < count and attempts < max_attempts:
		attempts += 1
		var candidate := Vector2i(rng.randi_range(0, GRID_SIZE.x - 1), rng.randi_range(0, GRID_SIZE.y - 1))
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
	for y: int in range(GRINDER_SIZE):
		for x: int in range(GRINDER_SIZE):
			cells.append(grinder_origin + Vector2i(x, y))
	return cells

func is_grinder_cell(cell: Vector2i) -> bool:
	if grinder_origin.x < 0 or grinder_origin.y < 0:
		return false
	return (
		cell.x >= grinder_origin.x
		and cell.y >= grinder_origin.y
		and cell.x < grinder_origin.x + GRINDER_SIZE
		and cell.y < grinder_origin.y + GRINDER_SIZE
	)

func place_grinder_random(previous_origin: Vector2i = Vector2i(-1, -1)) -> void:
	var tries := 0
	var max_tries := 200
	while tries < max_tries:
		tries += 1
		var candidate := Vector2i(
			rng.randi_range(0, GRID_SIZE.x - GRINDER_SIZE),
			rng.randi_range(0, GRID_SIZE.y - GRINDER_SIZE)
		)
		var overlaps := false
		for y: int in range(GRINDER_SIZE):
			for x: int in range(GRINDER_SIZE):
				var cell := candidate + Vector2i(x, y)
				if snake.has(cell) or is_idle_bean_at(cell):
					overlaps = true
					break
				if previous_origin.x >= 0 and previous_origin.y >= 0 and (
					cell.x >= previous_origin.x
					and cell.y >= previous_origin.y
					and cell.x < previous_origin.x + GRINDER_SIZE
					and cell.y < previous_origin.y + GRINDER_SIZE
				):
					overlaps = true
					break
			if overlaps:
				break
		if not overlaps:
			grinder_origin = candidate
			return

	# Fallback should be rare; still keep grinder in a valid in-bounds area.
	grinder_origin = Vector2i(1, 1)

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

		if key_event.keycode == KEY_SPACE and game_state == GameState.PLAYING:
			set_pause_state(true)
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
	if candidate == -direction:
		return
	next_direction = candidate

func _physics_process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return

	time_alive += delta
	freshness = maxf(0.0, freshness - FRESHNESS_DRAIN_PER_SEC * delta)
	if freshness <= 0.0:
		trigger_game_over()
		return

	if not grinder_active:
		grinder_telegraph_timer = maxf(0.0, grinder_telegraph_timer - delta)
		if grinder_telegraph_timer <= 0.0:
			grinder_active = true
	else:
		grinder_relocate_timer = maxf(0.0, grinder_relocate_timer - delta)
		if grinder_relocate_timer <= 0.0:
			var previous_origin := grinder_origin
			grinder_active = false
			grinder_telegraph_timer = GRINDER_TELEGRAPH_TIME
			grinder_relocate_timer = GRINDER_RELOCATE_INTERVAL
			place_grinder_random(previous_origin)
	bean_spawn_timer += delta
	while bean_spawn_timer >= bean_trickle_interval:
		bean_spawn_timer -= bean_trickle_interval
		spawn_idle_beans(rng.randi_range(2, 3))

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
	return false

func rotate_left(dir: Vector2i) -> Vector2i:
	if dir == Vector2i.UP:
		return Vector2i.LEFT
	if dir == Vector2i.LEFT:
		return Vector2i.DOWN
	if dir == Vector2i.DOWN:
		return Vector2i.RIGHT
	return Vector2i.UP

func rotate_right(dir: Vector2i) -> Vector2i:
	if dir == Vector2i.UP:
		return Vector2i.RIGHT
	if dir == Vector2i.RIGHT:
		return Vector2i.DOWN
	if dir == Vector2i.DOWN:
		return Vector2i.LEFT
	return Vector2i.UP

func reflected_direction(current_dir: Vector2i, grows: bool) -> Vector2i:
	var left_dir := rotate_left(current_dir)
	var right_dir := rotate_right(current_dir)
	var head := snake[0]
	var left_ok := not is_cell_blocked(head + left_dir, grows)
	var right_ok := not is_cell_blocked(head + right_dir, grows)

	if left_ok and right_ok:
		return left_dir if rng.randi_range(0, 1) == 0 else right_dir
	if left_ok:
		return left_dir
	if right_ok:
		return right_dir

	# If both 90-degree turns are blocked, allow any valid move to avoid death on contact.
	for fallback_dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if not is_cell_blocked(head + fallback_dir, grows):
			return fallback_dir

	# Fully trapped (extremely rare): stay in place this tick.
	return Vector2i.ZERO

func step_game() -> void:
	if snake.is_empty():
		return

	direction = next_direction
	var grows := is_idle_bean_at(snake[0] + direction)
	var new_head := snake[0] + direction

	if is_cell_blocked(new_head, grows):
		var bounced_dir := reflected_direction(direction, grows)
		if bounced_dir == Vector2i.ZERO:
			queue_redraw()
			return
		direction = bounced_dir
		next_direction = bounced_dir
		grows = is_idle_bean_at(snake[0] + direction)
		new_head = snake[0] + direction

		if is_cell_blocked(new_head, grows):
			queue_redraw()
			return

	snake.push_front(new_head)

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
		move_interval = max(0.07, move_interval - 0.0025)
		remove_idle_bean_at(new_head)
		spawn_wake_pulse(new_head)
	else:
		snake.pop_back()

	queue_redraw()

func trigger_game_over() -> void:
	game_over = true
	game_state = GameState.GAME_OVER
	is_grinding = false
	grind_grounded_count = 0
	best_score = max(best_score, score)
	queue_redraw()

func _process(delta: float) -> void:
	if game_state == GameState.PLAYING:
		grinder_angle += delta * 3.0

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

	queue_redraw()

func _draw() -> void:
	draw_background()
	draw_machine_frame()
	draw_grid()
	draw_grinder()
	draw_idle_beans()
	draw_snake()
	draw_grind_pops()
	draw_wake_pulses()
	draw_hud()

func draw_background() -> void:
	var viewport_size := get_viewport_rect().size
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
			var cell_pos := board_origin + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var base_color := COLOR_GRID_A if ((x + y) % 2 == 0) else COLOR_GRID_B
			draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), base_color, true)

			var streak_seed := float((x * 13 + y * 29) % 5)
			for s: int in range(3):
				var sy := cell_pos.y + 4.0 + float(s) * 7.0
				var alpha := 0.09 + streak_seed * 0.02
				draw_line(
					Vector2(cell_pos.x + 2.0, sy),
					Vector2(cell_pos.x + float(CELL_SIZE) - 2.0, sy),
					Color(COLOR_METAL_BRUSH.r, COLOR_METAL_BRUSH.g, COLOR_METAL_BRUSH.b, alpha),
					1.0
				)

			if ((x * 7 + y * 3) % 4) == 0:
				draw_line(
					Vector2(cell_pos.x + 5.0, cell_pos.y + 3.0),
					Vector2(cell_pos.x + 8.0, cell_pos.y + float(CELL_SIZE) - 3.0),
					COLOR_METAL_SHADOW,
					1.0
				)

			draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), COLOR_GRID_LINE, false, 1.0)

func draw_grinder() -> void:
	if grinder_origin.x < 0 or grinder_origin.y < 0:
		return

	var grinder_pos := grid_to_pixel(grinder_origin)
	var grinder_size_px := Vector2(float(CELL_SIZE * GRINDER_SIZE), float(CELL_SIZE * GRINDER_SIZE))
	var grinder_rect := Rect2(grinder_pos, grinder_size_px)
	var center := grinder_rect.position + grinder_rect.size * 0.5

	if not grinder_active:
		var pulse := 0.65 + 0.35 * sin(grinder_angle * 2.0)
		var spin_offset := Vector2(cos(grinder_angle), sin(grinder_angle)) * 2.0
		var shadow_col := Color(0.05, 0.04, 0.03, 0.24 + 0.12 * pulse)
		var halo_col := Color(0.20, 0.16, 0.12, 0.20 + 0.10 * pulse)
		draw_rect(grinder_rect, Color(0.0, 0.0, 0.0, 0.10), true)
		draw_arc(center + spin_offset, CELL_SIZE * 0.86, 0.0, TAU, 32, shadow_col, 3.0)
		draw_arc(center - spin_offset, CELL_SIZE * 0.62, 0.0, TAU, 28, halo_col, 2.0)

		for i: int in range(4):
			var ang := grinder_angle + float(i) * PI * 0.5
			var dir := Vector2(cos(ang), sin(ang))
			var p0 := center + dir * 6.0
			var p1 := center + dir * (CELL_SIZE * 0.86)
			draw_line(p0, p1, Color(0.08, 0.07, 0.06, 0.38), 2.0)

		if game_state == GameState.PLAYING:
			var tele_text := "GRINDER INCOMING"
			draw_string(hud_font, grinder_rect.position + Vector2(-8, -8), tele_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d0a45a"))
		return

	# Housing occupying exactly 2x2 cells.
	draw_rect(grinder_rect, Color("2f302f"), true)
	draw_rect(grinder_rect, Color("6f6a61"), false, 2.0)
	draw_rect(Rect2(grinder_rect.position + Vector2(2, 2), grinder_rect.size - Vector2(4, 4)), Color("3d3e3d"), false, 1.0)

	# Rotating inner ring and blades.
	draw_arc(center, CELL_SIZE * 0.82, 0.0, TAU, 36, Color("938d82"), 2.0)
	draw_arc(center, CELL_SIZE * 0.42, 0.0, TAU, 24, Color("1e1f1f"), 2.0)

	for i: int in range(4):
		var ang := grinder_angle + float(i) * PI * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var tip := center + dir * (CELL_SIZE * 0.76)
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
		var center := top_left + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
		var age: float = float(bean_spawn_age.get(bean_key(bean), BEAN_SPAWN_TOTAL))
		var y_offset := 0.0
		var alpha := 1.0

		if age < BEAN_SPAWN_SHADOW:
			var shadow_t := age / BEAN_SPAWN_SHADOW
			var shadow_w := lerpf(3.0, CELL_SIZE * 0.72, shadow_t)
			var shadow_h := lerpf(1.0, 4.0, shadow_t)
			var shadow_col := Color(0.08, 0.06, 0.04, lerpf(0.12, 0.36, shadow_t))
			draw_rect(Rect2(center + Vector2(-shadow_w * 0.5, CELL_SIZE * 0.36), Vector2(shadow_w, shadow_h)), shadow_col, true)
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
		draw_rect(Rect2(center + Vector2(-CELL_SIZE * 0.34, CELL_SIZE * 0.36), Vector2(CELL_SIZE * 0.68, 3.0)), Color(0.09, 0.07, 0.05, shadow_alpha), true)

		var fill_col := Color(COLOR_FOOD.r, COLOR_FOOD.g, COLOR_FOOD.b, alpha)
		var hi_col := Color(0.77, 0.54, 0.33, alpha)
		var seam_col := Color(0.25, 0.16, 0.10, alpha)
		draw_coffee_bean(top_left + Vector2(0.0, y_offset), fill_col, hi_col, seam_col)

		# Only fully-settled beans emit the idle zzz marker.
		if age >= BEAN_SPAWN_TOTAL:
			for i: int in range(3):
				var t := ticks + float(i) * 0.37 + float(bean.x * 11 + bean.y * 7) * 0.03
				var drift := Vector2(float(i) * 7.0 + sin(t * 2.2) * 2.0, -12.0 - float(i) * 6.0 - fmod(t * 10.0, 5.0))
				var z_alpha := 0.35 + float(i) * 0.22
				var z_col := Color(COLOR_STEAM.r, COLOR_STEAM.g, COLOR_STEAM.b, z_alpha)
				draw_string(hud_font, center + drift, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14 + i * 3, z_col)

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

func draw_snake() -> void:
	for i in snake.size():
		var segment := snake[i]
		var top_left := grid_to_pixel(segment)
		var body_color := COLOR_SNAKE_HEAD if i == 0 else COLOR_SNAKE_BODY
		var highlight := COLOR_SNAKE_HIGHLIGHT if i == 0 else COLOR_COPPER
		var seam_color := Color("2f1c11") if i == 0 else Color("3a2416")

		draw_coffee_bean(top_left, body_color, highlight, seam_color)

		if i == 0:
			var eye_color := Color("231910")
			var eye_base := top_left + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
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
	var center := top_left + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	var radius_x := CELL_SIZE * 0.33
	var radius_y := CELL_SIZE * 0.39
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
	draw_circle(center + Vector2(-4.0, -3.6), 3.4, Color(highlight.r, highlight.g, highlight.b, highlight.a * 0.9))
	draw_rect(
		Rect2(center + Vector2(-7.0, -6.6), Vector2(8.4, 2.2)),
		Color(highlight.r, highlight.g, highlight.b, highlight.a * 0.55),
		true
	)

	# Curved center crack (bean seam).
	var seam_top := center + Vector2(-0.8, -7.2)
	for j: int in range(7):
		var jy := float(j)
		var xwobble := sin(jy * 0.9) * 1.2
		var p0 := seam_top + Vector2(xwobble, jy * 2.2)
		var p1 := seam_top + Vector2(xwobble + 0.6, jy * 2.2 + 1.3)
		draw_line(p0, p1, seam, 1.1)

func draw_hud() -> void:
	var viewport_size := get_viewport_rect().size
	var hud_rect := Rect2(0.0, 0.0, viewport_size.x, HUD_HEIGHT)
	draw_rect(hud_rect, Color("261b14"), true)
	draw_line(Vector2(0, HUD_HEIGHT), Vector2(viewport_size.x, HUD_HEIGHT), COLOR_PANEL_EDGE, 2.0)

	var title := "STEAMPUNK SNAKE"
	draw_string(hud_font, Vector2(28, 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, COLOR_BRASS)

	var score_text := "Score: %d   Best: %d" % [score, best_score]
	draw_string(hud_font, Vector2(28, 64), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)

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

	var controls := "Arrows / WASD Move   Esc Pause Menu   Enter Select"
	draw_string(hud_font, Vector2(520, 64), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

	if game_state == GameState.START_MENU:
		draw_start_menu()

	if game_state == GameState.PAUSED:
		draw_pause_menu()

	if game_state == GameState.GAME_OVER:
		draw_centered_panel("PRESSURE LOST", "Press Enter to restart")

func draw_portafilter_hud(pos: Vector2, dose_count: int, dose_cap: int) -> void:
	var body := Rect2(pos.x + 24.0, pos.y + 8.0, 124.0, 18.0)
	var handle := Rect2(pos.x + 148.0, pos.y + 12.0, 26.0, 10.0)
	var ratio: float = clampf(float(dose_count) / float(dose_cap), 0.0, 1.0)

	# Portafilter body and handle.
	draw_rect(body, Color("3c2f24"), true)
	draw_rect(body, Color("8d6a48"), false, 2.0)
	draw_rect(handle, Color("6c4f35"), true)
	draw_rect(handle, Color("3a291a"), false, 1.0)

	# Dose fill inside basket.
	var inner := Rect2(body.position + Vector2(2.0, 2.0), body.size - Vector2(4.0, 4.0))
	draw_rect(inner, Color("1d140f"), true)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), Color("8c5c36"), true)

	# Tick separators for 18g capacity.
	for i: int in range(1, 6):
		var tx := inner.position.x + inner.size.x * float(i) / 6.0
		draw_line(Vector2(tx, inner.position.y), Vector2(tx, inner.end.y), Color(0.12, 0.09, 0.07, 0.35), 1.0)

	draw_string(hud_font, Vector2(pos.x, pos.y + 22.0), "Dose", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_BRASS)
	draw_string(hud_font, Vector2(pos.x + 184.0, pos.y + 22.0), "%d/%d" % [dose_count, dose_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)

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

	draw_string(hud_font, panel_pos + Vector2(38, 226), "Esc resumes instantly", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

func draw_centered_panel(title: String, subtitle: String) -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(360, 130)
	var panel_pos := (viewport_size - panel_size) * 0.5

	draw_rect(Rect2(panel_pos, panel_size), Color(0.11, 0.08, 0.06, 0.95), true)
	draw_rect(Rect2(panel_pos, panel_size), COLOR_PANEL_EDGE, false, 3.0)

	draw_string(hud_font, panel_pos + Vector2(44, 55), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, COLOR_DANGER)
	draw_string(hud_font, panel_pos + Vector2(44, 92), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)

func grid_to_pixel(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
