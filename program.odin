package main

import "core:math"
import "core:slice"
import "phys"
import rl "vendor:raylib"

Game_State_Aiming :: struct {
	aim_angle: f32,
	aim_speed: f32,
	aim_range: f32,
	aim_dir:   f32,
}
INITIAL_AIM_SPEED: f32 = 2
INITIAL_AIM_RANGE: f32 = math.PI * 0.45
INITIAL_AIM_DIR: f32 = -1
Game_State_Shooting :: struct {}

Game_State :: union {
	Game_State_Aiming,
	Game_State_Shooting,
}

Ball :: struct {
	pos:    rl.Vector2,
	dir:    rl.Vector2,
	speed:  f32,
	radius: f32,
}

Bar :: struct {
	pos:         rl.Vector2,
	size:        rl.Vector2,
	vel_x:       f32,
	acc_x:       f32,
	speed:       f32,
	drain_speed: f32,
}

WINDOW_WIDTH :: 560
WINDOW_HEIGHT :: 480

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Breakout")

	game_state: Game_State = Game_State_Aiming {
		aim_angle = 0,
		aim_speed = INITIAL_AIM_SPEED,
		aim_range = INITIAL_AIM_RANGE,
		aim_dir   = INITIAL_AIM_DIR,
	}

	camera := rl.Camera2D {
		offset = {WINDOW_WIDTH / 2.0, WINDOW_HEIGHT / 2.0},
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
		size        = rl.Vector2{100, 10},
		vel_x       = 0,
		acc_x       = 5000,
		speed       = 500,
		drain_speed = 10,
	}

	board_x_min: f32 = -250
	board_x_max: f32 = 250
	board_y_min: f32 = -200
	board_y_max: f32 = 200

	// LATER: optimization, use Lilnked List instead.
	blocks := [dynamic; 128]rl.Rectangle {
		{-100, -100, 40, 20},
		{-50, -100, 40, 20},
		{0, -100, 40, 20},
		{50, -100, 40, 20},
		{100, -100, 40, 20},
		{-100, -70, 40, 20},
		{-50, -70, 40, 20},
		{0, -70, 40, 20},
		{50, -70, 40, 20},
		{100, -70, 40, 20},
		{-100, -40, 40, 20},
		{-50, -40, 40, 20},
		{0, -40, 40, 20},
		{50, -40, 40, 20},
		{100, -40, 40, 20},
	}
	blocks_remove_queue := [dynamic; 128]int{}


	for !rl.WindowShouldClose() {
		bar_rectangle := rl.Rectangle {
			bar.pos.x - bar.size.x / 2,
			bar.pos.y - bar.size.y / 2,
			bar.size.x,
			bar.size.y,
		}
		board_rectangle := rl.Rectangle {
			board_x_min,
			board_y_min,
			board_x_max - board_x_min,
			100000,
		}
		board_draw_rectangle := rl.Rectangle {
			board_x_min,
			board_y_min,
			board_x_max - board_x_min,
			board_y_max - board_y_min,
		}

		// Update
		{
			frame_time := rl.GetFrameTime()

			switch &gs in game_state {
			case Game_State_Aiming:
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
					ball.dir = {sin, cos}
					game_state = Game_State_Shooting{}
				}
			case Game_State_Shooting:
				// Collision Check
				if col, ok := phys.get_collision_ball_rectangle_inner(
					ball.pos,
					ball.radius,
					board_rectangle,
				); ok {
					phys.handle_ball_collision(&ball.pos, &ball.dir, col)
				}

				if col, ok := phys.get_collision_ball_rectangle(
					ball.pos,
					ball.radius,
					bar_rectangle,
				); ok {
					phys.handle_ball_collision(&ball.pos, &ball.dir, col)
				}

				for &block, idx in blocks {
					if col, ok := phys.get_collision_ball_rectangle(ball.pos, ball.radius, block);
					   ok {
						phys.handle_ball_collision(&ball.pos, &ball.dir, col)
						append(&blocks_remove_queue, idx)
					}
				}

				// bar movement
				bar_range := board_x_max - bar.size.x / 2
				if rl.IsKeyDown(rl.KeyboardKey.LEFT) do bar.vel_x -= bar.acc_x * frame_time
				else if rl.IsKeyDown(rl.KeyboardKey.RIGHT) do bar.vel_x += bar.acc_x * frame_time
				else {
					if (abs(bar.vel_x) < rl.EPSILON) {
						bar.vel_x = 0
					} else {
						bar.vel_x += (bar.vel_x > 0 ? -1 : 1) * bar.acc_x * frame_time
					}
				}
				bar.vel_x = rl.Clamp(bar.vel_x, -bar.speed, bar.speed)
				bar.pos.x += bar.vel_x * frame_time
				bar.pos.x = rl.Clamp(bar.pos.x, -bar_range, bar_range)
				// Vel = 0 if the bar is clamped
				if bar.pos.x == bar_range do bar.vel_x = bar.vel_x > 0 ? 0 : bar.vel_x
				if bar.pos.x == -bar_range do bar.vel_x = bar.vel_x < 0 ? 0 : bar.vel_x

				// Bar Draining
				if bar.size.x > 0 do bar.size.x -= bar.drain_speed * frame_time
				if bar.size.x <= 0 do bar.size.x = 0

				// Ball movement
				ball.pos += ball.dir * ball.speed * frame_time

				if ball.pos.y > board_y_max {
					ball.pos = rl.Vector2{0, 130}
					bar.pos.x = 0
					bar.vel_x = 0
					bar.size.x = 100
					game_state = Game_State_Aiming {
						aim_angle = 0,
						aim_speed = INITIAL_AIM_SPEED,
						aim_range = INITIAL_AIM_RANGE,
						aim_dir   = INITIAL_AIM_DIR,
					}
				}

				// Clearing block remove queue

				slice.sort(blocks_remove_queue[:])
				#reverse for i in blocks_remove_queue {
					unordered_remove(&blocks, i)
				}
				clear(&blocks_remove_queue)
			}

		}

		// Draw
		{
			rl.BeginDrawing()
			rl.BeginMode2D(camera)

			rl.ClearBackground(rl.RAYWHITE)

			for block in blocks {
				rl.DrawRectangleGradientEx(block, rl.RED, rl.RAYWHITE, rl.RAYWHITE, rl.RED)
				rl.DrawRectangleLinesEx(block, 1, rl.RED)
			}

			rl.DrawCircleV(ball.pos, ball.radius, rl.RED)
			rl.DrawRectangleRec(bar_rectangle, rl.RED)

			rl.DrawRectangleLinesEx(board_draw_rectangle, 1, rl.RED)

			if gs, ok := game_state.(Game_State_Aiming); ok {
				sin, cos := math.sincos(gs.aim_angle + math.PI)
				rl.DrawLineV(ball.pos, ball.pos + rl.Vector2{sin, cos} * 200, rl.RED)
			}

			rl.EndMode2D()
			rl.EndDrawing()
		}
	}

	rl.CloseWindow()
}
