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
	snake.append(start + Vector2i.LEFT)
	snake.append(start + Vector2i.LEFT * 2)
	snake.append(start + Vector2i.LEFT * 3)

	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	spawn_food()
	queue_redraw()

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
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey

		if key_event.keycode == KEY_SPACE and not game_over:
			is_paused = not is_paused

		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			if game_over:
				start_new_run()

		if key_event.keycode == KEY_W:
			try_set_direction(Vector2i.UP)
		elif key_event.keycode == KEY_S:
			try_set_direction(Vector2i.DOWN)
		elif key_event.keycode == KEY_A:
			try_set_direction(Vector2i.LEFT)
		elif key_event.keycode == KEY_D:
			try_set_direction(Vector2i.RIGHT)

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
	if game_over or is_paused:
		return

	time_alive += delta
	move_accumulator += delta

	while move_accumulator >= move_interval:
		move_accumulator -= move_interval
		step_game()

func step_game() -> void:
	direction = next_direction
	var new_head := snake[0] + direction

	if new_head.x < 0 or new_head.y < 0 or new_head.x >= GRID_SIZE.x or new_head.y >= GRID_SIZE.y:
		trigger_game_over()
		return

	for segment in snake:
		if segment == new_head:
			trigger_game_over()
			return

	snake.push_front(new_head)

	if new_head == food:
		score += 10
		best_score = max(best_score, score)
		move_interval = max(0.07, move_interval - 0.0025)
		spawn_food()
	else:
		snake.pop_back()

	queue_redraw()

func trigger_game_over() -> void:
	game_over = true
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

		draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(CELL_SIZE - 4, CELL_SIZE - 4)), body_color, true)
		draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL_SIZE - 8, 5)), highlight, true)
		draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(CELL_SIZE - 4, CELL_SIZE - 4)), Color(0.16, 0.11, 0.08, 0.8), false, 1.0)

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

	var controls := "Arrows / WASD Move   Space Pause   Enter Restart   Esc Quit"
	draw_string(hud_font, Vector2(520, 64), controls, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ccb99a"))

	if is_paused and not game_over:
		draw_centered_panel("PAUSED", "Press Space to continue")

	if game_over:
		draw_centered_panel("PRESSURE LOST", "Press Enter to restart")

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
