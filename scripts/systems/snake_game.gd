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
const COLOR_SNAKE_BODY := Color("91613b")
const COLOR_SNAKE_HIGHLIGHT := Color("d7a16c")
const COLOR_SNAKE_HEAD := Color("c4864f")
const COLOR_FOOD := Color("e2bf77")
const COLOR_TEXT := Color("e6d8bf")
const COLOR_DANGER := Color("d36641")

var board_origin := Vector2.ZERO
var board_size := Vector2.ZERO

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var food := Vector2i.ZERO
var rng := RandomNumberGenerator.new()

var score := 0
var best_score := 0
var move_interval := 0.13
var move_accumulator := 0.0
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
	start_new_run()
	game_state = GameState.START_MENU

func start_new_run() -> void:
	score = 0
	move_interval = 0.13
	move_accumulator = 0.0
	time_alive = 0.0
	game_over = false
	is_paused = false

	snake.clear()
	var start := Vector2i(int(GRID_SIZE.x / 2), int(GRID_SIZE.y / 2))
	snake.append(start)

	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	spawn_food()
	queue_redraw()

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

func spawn_food() -> void:
	var occupied := {}
	for segment in snake:
		occupied[segment] = true

	while true:
		var candidate := Vector2i(rng.randi_range(0, GRID_SIZE.x - 1), rng.randi_range(0, GRID_SIZE.y - 1))
		if not occupied.has(candidate):
			food = candidate
			return

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
	move_accumulator += delta

	while move_accumulator >= move_interval:
		move_accumulator -= move_interval
		step_game()

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y

func is_cell_blocked(cell: Vector2i, grows: bool) -> bool:
	if not in_bounds(cell):
		return true

	# Moving into the current tail cell is allowed if the snake does not grow this step.
	var body_limit := snake.size()
	if not grows:
		body_limit -= 1

	for i: int in range(body_limit):
		if snake[i] == cell:
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
	direction = next_direction
	var grows := (snake[0] + direction) == food
	var new_head := snake[0] + direction

	if is_cell_blocked(new_head, grows):
		var bounced_dir := reflected_direction(direction, grows)
		if bounced_dir == Vector2i.ZERO:
			queue_redraw()
			return
		direction = bounced_dir
		next_direction = bounced_dir
		grows = (snake[0] + direction) == food
		new_head = snake[0] + direction

		if is_cell_blocked(new_head, grows):
			queue_redraw()
			return

	snake.push_front(new_head)

	if grows:
		score += 10
		best_score = max(best_score, score)
		move_interval = max(0.07, move_interval - 0.0025)
		spawn_food()
	else:
		snake.pop_back()

	queue_redraw()

func trigger_game_over() -> void:
	game_over = true
	game_state = GameState.GAME_OVER
	best_score = max(best_score, score)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_background()
	draw_machine_frame()
	draw_grid()
	draw_food()
	draw_snake()
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

func draw_food() -> void:
	var center := grid_to_pixel(food) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), COLOR_FOOD, true)
	draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), Color(0.20, 0.14, 0.08, 0.85), false, 2.0)
	draw_rect(Rect2(center - Vector2(1, 9), Vector2(2, 4)), COLOR_COPPER, true)
	draw_rect(Rect2(center - Vector2(9, 1), Vector2(18, 2)), Color("7f5a33"), true)

func draw_snake() -> void:
	for i in snake.size():
		var segment := snake[i]
		var top_left := grid_to_pixel(segment)
		var body_color := COLOR_SNAKE_HEAD if i == 0 else COLOR_SNAKE_BODY
		var highlight := COLOR_SNAKE_HIGHLIGHT if i == 0 else COLOR_COPPER
		var seam_color := Color("3a2718") if i == 0 else Color("4b3321")

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
	var radius_x := CELL_SIZE * 0.34
	var radius_y := CELL_SIZE * 0.40

	# Bean silhouette built from a core plus rounded ends.
	draw_rect(Rect2(center + Vector2(-radius_x + 2.0, -radius_y), Vector2(radius_x * 2.0 - 4.0, radius_y * 2.0)), fill, true)
	draw_circle(center + Vector2(-radius_x + 2.0, 0.0), radius_y, fill)
	draw_circle(center + Vector2(radius_x - 2.0, 0.0), radius_y, fill)

	# Metallic warm highlight.
	draw_rect(Rect2(center + Vector2(-radius_x + 4.0, -radius_y + 2.0), Vector2(radius_x * 1.45, 3.0)), highlight, true)
	draw_circle(center + Vector2(-radius_x + 3.0, -1.0), 3.0, highlight)

	# Center groove for coffee-bean identity.
	for j: int in range(5):
		var offset := -4.0 + float(j) * 2.0
		draw_line(center + Vector2(offset * 0.35, -6.0 + float(j) * 3.0), center + Vector2(offset * 0.65, -2.5 + float(j) * 3.0), seam, 1.0)

	# Pixel-ish border.
	draw_rect(Rect2(center + Vector2(-radius_x + 1.0, -radius_y), Vector2(radius_x * 2.0 - 2.0, radius_y * 2.0)), Color(0.16, 0.11, 0.08, 0.85), false, 1.0)

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

	var controls := "Arrows / WASD Move   Esc Pause Menu   Enter Select"
	draw_string(hud_font, Vector2(520, 64), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

	if game_state == GameState.START_MENU:
		draw_start_menu()

	if game_state == GameState.PAUSED:
		draw_pause_menu()

	if game_state == GameState.GAME_OVER:
		draw_centered_panel("PRESSURE LOST", "Press Enter to restart")

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
		var selected := i == start_menu_index
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
		var selected := i == pause_menu_index
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
