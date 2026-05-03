
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
INITIAL_AIM_SPEED: f32 : 2
INITIAL_AIM_RANGE: f32 : math.PI * 0.45
INITIAL_AIM_DIR: f32 : -1

Game_State_Shooting :: struct {}

Game_State :: union {
	Game_State_Aiming,
	Game_State_Shooting,
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
}

// `defer gp_st_free(st)` please!!!!!
gp_st_init :: proc() -> Gameplay_Struct {
	game_state: Game_State = Game_State_Aiming {
		aim_angle = 0,
		aim_speed = INITIAL_AIM_SPEED,
		aim_range = INITIAL_AIM_RANGE,
		aim_dir   = INITIAL_AIM_DIR,
	}

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
		drain_speed = 10,
		active      = true,
	}

	board := Board {
		x_min = -250,
		x_max = 250,
		y_min = -200,
		y_max = 200,
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
	}
}

gp_st_free :: proc(st: ^Gameplay_Struct) {
	delete(st.blocks)
	delete(st.blocks_remove_queue)
}

gp_st_update :: proc(st: ^Gameplay_Struct) {
	switch &gs in st.game_state {
	case Game_State_Aiming:
		gp_st_update_aiming(st, &gs)
	case Game_State_Shooting:
		gp_st_update_shooting(st, &gs)
	}

	gp_st_clear_blocks_remove_queue(st)
}

@(private)
gp_st_update_aiming :: proc(st: ^Gameplay_Struct, gs: ^Game_State_Aiming) {
	frame_time := rl.GetFrameTime()
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

@(private)
gp_st_update_shooting :: proc(st: ^Gameplay_Struct, gs: ^Game_State_Shooting) {
	gp_st_handle_collision(st)
	bar_move(&st.bar, st.board.x_min, st.board.x_max)
	bar_drain(&st.bar)
	ball_move(&st.ball)
	if st.ball.pos.y > st.board.y_max {
		gp_st_on_ball_death(st)
	}
}

@(private)
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
		if st.bar.active do bar_heal(&st.bar, 2)
	}

	// Bar collision
	if st.bar.active {
		if col, ok := phys.get_collision_ball_rectangle(
			st.ball.pos,
			st.ball.radius,
			bar_rectangle,
		); ok {
			phys.handle_ball_collision(&st.ball.pos, &st.ball.dir, col)
			if st.bar.active do bar_heal(&st.bar, 2)
			// TODO: Bar collision score+ <- needs throttling
			st.player.score += 10
		}
	}

	// Block collision
	for &block, idx in st.blocks {
		if col, ok := phys.get_collision_ball_rectangle(st.ball.pos, st.ball.radius, block.rect);
		   ok {
			phys.handle_ball_collision(&st.ball.pos, &st.ball.dir, col)
			block.health -= 1
			st.player.score += 5
			if block.health == 0 {
				append(&st.blocks_remove_queue, idx)
				st.player.score += 15
			}
		}
	}
}

gp_st_on_ball_death :: proc(st: ^Gameplay_Struct) {
	bar_rectangle := bar_get_rectangle(&st.bar)

	// Reset bar & ball
	st.ball.pos = rl.Vector2{0, 130}
	st.bar.pos.x = 0
	st.bar.vel_x = 0
	st.bar.size.x = 100
	st.bar.active = true

	// push a row of blocks
	block_gen_push(&st.block_gen, &st.blocks)
	block_gen_append_row(&st.block_gen, &st.blocks)
	for &block, idx in st.blocks {
		// Damages player if block touches bar line
		if block.rect.y + block.rect.height > bar_rectangle.y {
			st.player.health = max(0, st.player.health - 1)
			append(&st.blocks_remove_queue, idx)
		}
	}

	// update state
	st.game_state = Game_State_Aiming {
		aim_angle = 0,
		aim_speed = INITIAL_AIM_SPEED,
		aim_range = INITIAL_AIM_RANGE,
		aim_dir   = INITIAL_AIM_DIR,
	}
}

gp_st_clear_blocks_remove_queue :: proc(st: ^Gameplay_Struct) {
	slice.sort(st.blocks_remove_queue[:])
	#reverse for i in st.blocks_remove_queue {
		unordered_remove(&st.blocks, i)
	}
	clear(&st.blocks_remove_queue)
}

gp_st_draw :: proc(st: ^Gameplay_Struct) {
	bar_rectangle := bar_get_rectangle(&st.bar)
	board_rectangle := board_get_draw_rectangle(&st.board)

	rl.BeginDrawing()
	rl.BeginMode2D(st.camera)

	rl.ClearBackground(rl.RAYWHITE)

	// Draw Blocks
	for block in st.blocks {
		health_lost_rate := 1 - (f32(block.health) / f32(block.max_health))
		fill_rect := block.rect
		fill_rect.x += block.rect.width * 0.5 * health_lost_rate
		fill_rect.width -= block.rect.width * health_lost_rate
		rl.DrawRectangleGradientEx(fill_rect, rl.RED, rl.RAYWHITE, rl.RAYWHITE, rl.RED)
		rl.DrawRectangleLinesEx(block.rect, 1, rl.RED)
		health_text := rl.TextFormat("%d", block.health)
		health_text_width := rl.MeasureText(health_text, 10)
		rl.DrawText(
			health_text,
			i32(block.rect.x + block.rect.width / 2) - health_text_width / 2,
			i32(block.rect.y + block.rect.height / 2) - 5,
			10,
			rl.RAYWHITE,
		)
	}

	// Draw Health Bar
	{
		health_rate := f32(st.player.health) / f32(st.player.max_health)
		health_bar_rect := rl.Rectangle {
			st.board.x_min,
			st.board.y_min - 20,
			st.board.x_max - st.board.x_min,
			10,
		}
		fill_rect := health_bar_rect
		fill_rect.width *= health_rate
		rl.DrawRectangleRec(fill_rect, rl.RED)
		rl.DrawRectangleLinesEx(health_bar_rect, 1, rl.RED)
		rl.DrawText(
			rl.TextFormat("%d/%d", st.player.health, st.player.max_health),
			i32(health_bar_rect.x) + 2,
			i32(health_bar_rect.y),
			10,
			rl.RAYWHITE,
		)
	}

	// Ball
	rl.DrawCircleV(st.ball.pos, st.ball.radius, rl.RED)

	// Bar
	rl.DrawRectangleRec(bar_rectangle, rl.RED)

	// Board
	rl.DrawRectangleLinesEx(board_rectangle, 1, rl.RED)

	// Aim Line
	if gs, ok := st.game_state.(Game_State_Aiming); ok {
		sin, cos := math.sincos(gs.aim_angle + math.PI)
		rl.DrawLineV(st.ball.pos, st.ball.pos + rl.Vector2{sin, cos} * 200, rl.RED)
	}

	// Score
	rl.DrawText(
		rl.TextFormat("%07d", st.player.score),
		i32(st.board.x_min),
		i32(st.board.y_max) + 5,
		20,
		rl.BLACK,
	)

	rl.EndMode2D()
	rl.EndDrawing()
}
