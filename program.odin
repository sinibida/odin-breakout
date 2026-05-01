package main

import "core:slice"
import "phys"
import rl "vendor:raylib"

WINDOW_WIDTH :: 560
WINDOW_HEIGHT :: 480

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Breakout")

	camera := rl.Camera2D {
		offset = {WINDOW_WIDTH / 2.0, WINDOW_HEIGHT / 2.0},
		target = {0, 0},
		zoom   = 1,
	}

	ball_pos := rl.Vector2{0, 0}
	ball_dir := rl.Vector2Normalize(rl.Vector2{1, 1})
	ball_speed: f32 = 300
	ball_radius: f32 = 5

	bar_pos := rl.Vector2{0, 150}
	bar_size := rl.Vector2{100, 10}
	bar_vel_x: f32 = 0
	bar_acc_x: f32 = 5000
	bar_speed: f32 = 500

	board_x_min: f32 = -250
	board_x_max: f32 = 250
	board_y_min: f32 = -200
	board_y_max: f32 = 200

	// LATER: optimization, use Lilnked List instead.
	blocks := [dynamic; 64]rl.Rectangle {
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
	blocks_remove_queue := [dynamic; 64]int{}


	for !rl.WindowShouldClose() {
		bar_rectangle := rl.Rectangle {
			bar_pos.x - bar_size.x / 2,
			bar_pos.y - bar_size.y / 2,
			bar_size.x,
			bar_size.y,
		}
		board_rectangle := rl.Rectangle {
			board_x_min,
			board_y_min,
			board_x_max - board_x_min,
			board_y_max - board_y_min,
		}

		// Update
		{
			frame_time := rl.GetFrameTime()

			// bar movement
			if rl.IsKeyDown(rl.KeyboardKey.LEFT) do bar_vel_x -= bar_acc_x * frame_time
			else if rl.IsKeyDown(rl.KeyboardKey.RIGHT) do bar_vel_x += bar_acc_x * frame_time
			else {
				if (abs(bar_vel_x) < rl.EPSILON) {
					bar_vel_x = 0
				} else {
					bar_vel_x += (bar_vel_x > 0 ? -1 : 1) * bar_acc_x * frame_time
				}
			}
			bar_vel_x = rl.Clamp(bar_vel_x, -bar_speed, bar_speed)
			bar_pos.x += bar_vel_x * frame_time
			bar_pos.x = rl.Clamp(bar_pos.x, -200, 200)
			// Vel = 0 if the bar is clamped
			if bar_pos.x == 200 do bar_vel_x = bar_vel_x > 0 ? 0 : bar_vel_x
			if bar_pos.x == -200 do bar_vel_x = bar_vel_x < 0 ? 0 : bar_vel_x


			ball_pos += ball_dir * ball_speed * frame_time

			if col, ok := phys.get_collision_ball_rectangle_inner(ball_pos, ball_radius, board_rectangle);
			   ok {
				phys.handle_ball_collision(&ball_pos, &ball_dir, col)
			}

			if col, ok := phys.get_collision_ball_rectangle(ball_pos, ball_radius, bar_rectangle);
			   ok {
				phys.handle_ball_collision(&ball_pos, &ball_dir, col)
			}

			for block, idx in blocks {
				if col, ok := phys.get_collision_ball_rectangle(ball_pos, ball_radius, block); ok {
					phys.handle_ball_collision(&ball_pos, &ball_dir, col)
					append(&blocks_remove_queue, idx)
				}
			}

			slice.sort(blocks_remove_queue[:])
			#reverse for i in blocks_remove_queue {
				unordered_remove(&blocks, i)
			}
			clear(&blocks_remove_queue)
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

			rl.DrawCircleV(ball_pos, ball_radius, rl.RED)
			rl.DrawRectangleV(bar_pos - bar_size / 2, bar_size, rl.RED)

			rl.DrawRectangleLinesEx(board_rectangle, 1, rl.RED)

			rl.EndMode2D()
			rl.EndDrawing()
		}
	}

	rl.CloseWindow()
}
