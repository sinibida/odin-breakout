
// LEFTOFF:
// - Bar healing -> function
// - Reread
// - Bar Collision Throttling

package comp

import "../lib"
import "../phys"
import "core:math"
import "core:slice"
import rl "vendor:raylib"

Game_State_Aiming :: struct {
	aim_angle: f32,
	aim_speed: f32,
	aim_range: f32,
	aim_dir:   f32,
}
game_state_aiming_init :: proc() -> Game_State_Aiming {
	return Game_State_Aiming {
		aim_angle = 0,
		aim_speed = 2,
		aim_range = math.PI * 0.45,
		aim_dir = -1,
	}
}

Game_State_Shooting :: struct {}

Game_State_Player_Dead :: struct {}

Game_State :: union {
	Game_State_Aiming,
	Game_State_Shooting,
	Game_State_Player_Dead,
}

Player :: struct {
	health:     i32,
	max_health: i32,
	score:      i32,
}

Ball :: struct {
	pos:    rl.Vector2,
	dir:    rl.Vector2,
	speed:  f32,
	radius: f32,
}
ball_move :: proc(ball: ^Ball) {
	frame_time := rl.GetFrameTime()
	ball.pos += ball.dir * ball.speed * frame_time
}

Block :: struct {
	rect:       rl.Rectangle,
	max_health: i32,
	health:     i32,
}

Enemy :: struct {
	max_health: i32,
	health:     i32,
}

Gameplay_Struct :: struct {
	game_state:          Game_State,
	camera:              rl.Camera2D,
	ball:                Ball,
	bar:                 Bar,
	board:               Board,
	block_gen:           Block_Gen,
	blocks:              [dynamic]Block,
	blocks_remove_queue: [dynamic]int,
	player:              Player,
	enemy:               Enemy,
	run_cnt:             i32,
}

// `defer gp_st_free(st)` please!!!!!
gp_st_init :: proc() -> Gameplay_Struct {
	game_state: Game_State = game_state_aiming_init()

	camera := rl.Camera2D {
		offset = {lib.WINDOW_WIDTH / 2.0, lib.WINDOW_HEIGHT / 2.0},
		target = {0, 0},
		zoom   = 1,
	}

	ball := Ball {
		pos    = rl.Vector2{0, 130},
		dir    = rl.Vector2Normalize(rl.Vector2{1, -1}),
		speed  = 500,
		radius = 5,
	}

	bar := Bar {
		pos         = rl.Vector2{0, 150},
		size        = rl.Vector2{INITIAL_BAR_MAX_WIDTH, 10},
		max_width   = INITIAL_BAR_MAX_WIDTH,
		vel_x       = 0,
		acc_x       = 5000,
		speed       = 500,
		drain_speed = 15,
		active      = true,
	}

	board := Board {
		x_min = -250,
		x_max = 250,
		y_min = -180,
		y_max = 180,
	}

	blocks := make([dynamic]Block)
	blocks_remove_queue := make([dynamic]int)

	block_gen := Block_Gen {
		prob    = 0.5,
		width   = 40,
		height  = 20,
		gap     = 10,
		col_cnt = 7,
		y_min   = -140,
	}

	player := Player {
		health     = 10,
		max_health = 10,
		score      = 0,
	}

	enemy := Enemy {
		max_health = 20,
		health     = 20,
	}

	return {
		ball = ball,
		bar = bar,
		blocks = blocks,
		blocks_remove_queue = blocks_remove_queue,
		block_gen = block_gen,
		board = board,
		game_state = game_state,
		camera = camera,
		player = player,
		enemy = enemy,
		run_cnt = 0,
	}
}

gp_st_free :: proc(st: ^Gameplay_Struct) {
	delete(st.blocks)
	delete(st.blocks_remove_queue)
}

gp_st_update :: proc(st: ^Gameplay_Struct) {
	gp_st_t(st)

	switch &gs in st.game_state {
	case Game_State_Aiming:
		gp_st_update_aiming(st, &gs)
	case Game_State_Shooting:
		gp_st_update_shooting(st, &gs)
	case Game_State_Player_Dead:
		gp_st_update_player_dead(st, &gs)
	}

	gp_st_clear_blocks_remove_queue(st)
}

gp_st_t :: proc(st: ^Gameplay_Struct) {
	bar_t(&st.bar)
}

gp_st_update_aiming :: proc(st: ^Gameplay_Struct, gs: ^Game_State_Aiming) {
	frame_time := rl.GetFrameTime()

	// aim_angle alternates between -aim_range & aim_range
	gs.aim_angle += frame_time * gs.aim_speed * gs.aim_dir
	if gs.aim_angle > gs.aim_range {
		gs.aim_angle = gs.aim_range - (gs.aim_angle - gs.aim_range)
		gs.aim_dir *= -1
	}
	if gs.aim_angle < -gs.aim_range {
		gs.aim_angle = -gs.aim_range - (gs.aim_angle + gs.aim_range)
		gs.aim_dir *= -1
	}
	
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
		sin, cos := math.sincos(gs.aim_angle + math.PI)
		st.ball.dir = {sin, cos}
		st.game_state = Game_State_Shooting{}
	}
}

gp_st_update_shooting :: proc(st: ^Gameplay_Struct, gs: ^Game_State_Shooting) {
	bar_drain(&st.bar)

	bar_move(&st.bar, st.board.x_min, st.board.x_max)
	ball_move(&st.ball)

	gp_st_handle_collision(st)

	// Pressing SPACE mid-shooting kills the ball
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
		gp_st_on_ball_death(st)
	}

	if st.ball.pos.y > st.board.y_max {
		gp_st_on_ball_death(st)
	}
}

gp_st_handle_collision :: proc(st: ^Gameplay_Struct) {
	bar_rectangle := bar_get_rectangle(&st.bar)
	board_rectangle := board_get_collider_rectangle(&st.board)

	// Board collision
	if col, ok := phys.get_collision_ball_rectangle_inner(
		st.ball.pos,
		st.ball.radius,
		board_rectangle,
	); ok {
		phys.handle_ball_collision(&st.ball.pos, &st.ball.dir, col)
		if st.bar.active do bar_heal(&st.bar, 4)
	}

	// Bar collision
	if st.bar.active && st.bar.t_no_col <= 0 {
		if col, ok := phys.get_collision_ball_rectangle(
			st.ball.pos,
			st.ball.radius,
			bar_rectangle,
		); ok {
			if st.bar.active do bar_heal(&st.bar, 4)
			st.player.score += 10

			st.bar.t_no_col = BAR_COLLISION_THROTTLE

			phys.handle_ball_collision(&st.ball.pos, &st.ball.dir, col)
		}
	}

	// Block collision
	for &block, idx in st.blocks {
		if col, ok := phys.get_collision_ball_rectangle(st.ball.pos, st.ball.radius, block.rect);
		   ok {
			block.health -= 1
			st.player.score += 5
			if block.health == 0 {
				append(&st.blocks_remove_queue, idx)
				st.player.score += 15
				st.enemy.health -= 1
			}

			// Allows the ball to go tutututututututtutu between block & bar
			st.bar.t_no_col = 0

			phys.handle_ball_collision(&st.ball.pos, &st.ball.dir, col)
		}
	}
}

gp_st_on_ball_death :: proc(st: ^Gameplay_Struct) {
	bar_rectangle := bar_get_rectangle(&st.bar)

	// Reset bar & ball
	gp_st_reset_bar_ball(st)

	// push a row of blocks
	block_gen_push(&st.block_gen, &st.blocks)
	block_gen_append_row(&st.block_gen, &st.blocks)
	for &block, idx in st.blocks {
		// Damages player if block touches bar line
		if block.rect.y + block.rect.height > bar_rectangle.y {
			st.player.health = st.player.health - 1
			append(&st.blocks_remove_queue, idx)
		}
	}

	// update game state
	if st.player.health <= 0 {
		st.game_state = Game_State_Player_Dead{}
	} else {
		st.game_state = game_state_aiming_init()
	}
}

gp_st_reset_bar_ball :: proc(st: ^Gameplay_Struct) {
	st.ball.pos = rl.Vector2{0, 130}
	st.bar.pos.x = 0
	st.bar.vel_x = 0
	st.bar.size.x = 100
	st.bar.active = true
}

gp_st_reset_run :: proc(st: ^Gameplay_Struct) {
	gp_st_reset_bar_ball(st)

	clear(&st.blocks) // Surely this won't cause problems... right?
	st.game_state = game_state_aiming_init()
	st.enemy.health = st.enemy.max_health
	st.player.health = st.player.max_health
	st.player.score = 0
}

gp_st_clear_blocks_remove_queue :: proc(st: ^Gameplay_Struct) {
	slice.sort(st.blocks_remove_queue[:])
	#reverse for i in st.blocks_remove_queue {
		unordered_remove(&st.blocks, i)
	}
	clear(&st.blocks_remove_queue)
}

gp_st_update_player_dead :: proc(st: ^Gameplay_Struct, gs: ^Game_State_Player_Dead) {
	// TODO: allow user to select and/or buy upgrade with score earned
	gp_st_reset_run(st)
	st.run_cnt += 1
	// TODO: Make Player Stronger
}

gp_st_draw :: proc(st: ^Gameplay_Struct) {
	bar_rectangle := bar_get_rectangle(&st.bar)
	board_rectangle := board_get_draw_rectangle(&st.board)
	bar_hit_lerp := st.bar.t_no_col / BAR_COLLISION_THROTTLE

	rl.BeginDrawing()
	rl.BeginMode2D(st.camera)

	rl.ClearBackground(lib.MYWHITE)

	// Draw Blocks
	for block in st.blocks {
		health_lost_rate := 1 - (f32(block.health) / f32(block.max_health))
		fill_rect := block.rect
		fill_rect.x += block.rect.width * 0.5 * health_lost_rate
		fill_rect.width -= block.rect.width * health_lost_rate

		rl.DrawRectangleGradientEx(fill_rect, lib.MYBLUE, lib.MYWHITE, lib.MYWHITE, lib.MYBLUE)
		rl.DrawRectangleLinesEx(block.rect, 1, lib.MYBLUE)

		text := rl.TextFormat("%d", block.health)
		tx, ty := lib.get_text_pos_rect_origin(text, block.rect, {0.5, 0.5}, 10)
		rl.DrawText(text, tx, ty, 10, lib.MYBLUE)
	}


	// Ball
	rl.DrawCircleV(st.ball.pos, st.ball.radius, lib.MYRED)

	// Bar
	if st.bar.active {
		fill_color := rl.ColorLerp(lib.MYRED, lib.MYWHITE, bar_hit_lerp)
		rl.DrawRectangleRec(bar_rectangle, fill_color)
		rl.DrawRectangleLinesEx(bar_rectangle, 1, lib.MYRED)
	}

	// Board
	rl.DrawRectangleLinesEx(board_rectangle, 1, lib.MYRED)

	// Aim Line
	if gs, ok := st.game_state.(Game_State_Aiming); ok {
		sin, cos := math.sincos(gs.aim_angle + math.PI)
		rl.DrawLineV(st.ball.pos, st.ball.pos + rl.Vector2{sin, cos} * 200, lib.MYRED)
	}

	bottom_rect := rl.Rectangle {
		board_rectangle.x,
		board_rectangle.y + board_rectangle.height + 4,
		board_rectangle.width,
		20,
	}

	// Enemy health bar
	{
		value := st.enemy.health
		max_value := st.enemy.max_health
		color := lib.MYBLUE

		health_bar_rect := board_rectangle
		health_bar_rect.height = 10
		health_bar_rect.y -= 14

		lib.draw_health_bar(value, max_value, health_bar_rect, color)
	}

	// Score
	score_text_width: i32
	{
		score_text_width = lib.draw_score_text(
			st.player.score,
			7,
			20,
			2,
			st.board.x_max,
			st.board.y_max + 5,
			{1, 0},
		)
	}

	bottom_left_rect := bottom_rect
	bottom_left_rect.width -= f32(score_text_width + 8)

	// Draw Health Bar
	{
		value := st.player.health
		max_value := st.player.max_health
		color := lib.MYRED

		health_bar_rect := bottom_left_rect
		health_bar_rect.height = 10

		lib.draw_health_bar(value, max_value, health_bar_rect, color)
	}

	// Draw run info (STUB)
	{
		text: cstring = rl.TextFormat("RUN %03d  GOLD 00000 WWHAT???", st.run_cnt + 1)
		tx := bottom_left_rect.x
		ty := bottom_left_rect.y + bottom_left_rect.height
		lib.draw_mono_text(text, 10, 1, tx, ty, {0, 1})
	}

	rl.EndMode2D()
	rl.EndDrawing()
}
