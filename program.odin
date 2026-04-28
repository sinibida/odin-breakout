package main

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
	bar_pos := rl.Vector2{0, 150}
	bar_size := rl.Vector2{100, 10}
	bar_speed: f32 = 500

	for !rl.WindowShouldClose() {
		frame_time := rl.GetFrameTime()

		if rl.IsKeyDown(rl.KeyboardKey.LEFT) do bar_pos.x -= bar_speed * frame_time
		if rl.IsKeyDown(rl.KeyboardKey.RIGHT) do bar_pos.x += bar_speed * frame_time
        bar_pos.x = rl.Clamp(bar_pos.x, -180, 180)

		rl.BeginDrawing()
		rl.BeginMode2D(camera)

		rl.ClearBackground(rl.RAYWHITE)

		rl.DrawCircleV(ball_pos, 5, rl.RED)
		rl.DrawRectangleV(bar_pos - bar_size / 2, bar_size, rl.RED)

		rl.EndMode2D()
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
