package main

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:strconv"
import "phys"
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

Ball :: struct {
	pos:    rl.Vector2,
	dir:    rl.Vector2,
	speed:  f32,
	radius: f32,
}

Bar :: struct {
	pos:          rl.Vector2,
	size:         rl.Vector2,
	max_width:    f32,
	vel_x:        f32,
	acc_x:        f32,
	speed:        f32,
	drain_speed:  f32,
	no_collision: bool,
}
INITIAL_BAR_MAX_WIDTH :: 100

Block :: struct {
	rect:       rl.Rectangle,
	max_health: i32,
	health:     i32,
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
		pos          = rl.Vector2{0, 150},
		size         = rl.Vector2{INITIAL_BAR_MAX_WIDTH, 10},
		max_width    = INITIAL_BAR_MAX_WIDTH,
		vel_x        = 0,
		acc_x        = 5000,
		speed        = 500,
		drain_speed  = 10,
		no_collision = false,
	}

	board_x_min: f32 = -250
	board_x_max: f32 = 250
	board_y_min: f32 = -200
	board_y_max: f32 = 200

	// LATER: optimization, use Lilnked List instead.
	blocks := [dynamic; 128]Block{}
	blocks_remove_queue := [dynamic; 128]int{}

	block_gen_prob: f32 = 0.5
	block_gen_width: f32 = 40
	block_gen_height: f32 = 20
	block_gen_gap: f32 = 10
	block_gen_col_cnt: i32 = 7
	block_gen_y_min: f32 = -140

	player_health: i32 = 10
	player_max_health: i32 = 10
	player_score: i32 = 0

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
				// Board collision
				if col, ok := phys.get_collision_ball_rectangle_inner(
					ball.pos,
					ball.radius,
					board_rectangle,
				); ok {
					phys.handle_ball_collision(&ball.pos, &ball.dir, col)
					// TODO: No healing when no_collision is on
					// gotta make some procedures...
					// how do I implement class method on Odin??
					bar.size.x = min(bar.size.x + 2, bar.max_width)
				}

				// Bar collision
				if !bar.no_collision {
					if col, ok := phys.get_collision_ball_rectangle(
						ball.pos,
						ball.radius,
						bar_rectangle,
					); ok {
						phys.handle_ball_collision(&ball.pos, &ball.dir, col)
						// TODO: No healing when no_collision is on
						// gotta make some procedures...
						// how do I implement class method on Odin??
						bar.size.x = min(bar.size.x + 2, bar.max_width)
						// TODO: Bar collision score+ <- needs throttling
						player_score += 10
					}
				}

				// Block collision
				for &block, idx in blocks {
					if col, ok := phys.get_collision_ball_rectangle(
						ball.pos,
						ball.radius,
						block.rect,
					); ok {
						phys.handle_ball_collision(&ball.pos, &ball.dir, col)
						block.health -= 1
						player_score += 5
						if block.health == 0 {
							append(&blocks_remove_queue, idx)
							player_score += 15
						}
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
				if bar.size.x <= 0 {
					bar.size.x = 0
					bar.no_collision = true
				}

				// Ball movement
				ball.pos += ball.dir * ball.speed * frame_time

				// STATE CHANGE: On Ball Death
				if ball.pos.y > board_y_max {
					// Reset bar & ball
					ball.pos = rl.Vector2{0, 130}
					bar.pos.x = 0
					bar.vel_x = 0
					bar.size.x = 100
					bar.no_collision = false

					// push a row of blocks
					block_gen_full_width :=
						block_gen_width * f32(block_gen_col_cnt) +
						block_gen_gap * f32(block_gen_col_cnt - 1)
					block_gen_x_min := -block_gen_full_width * 0.5
					block_gen_x_interval := block_gen_width + block_gen_gap
					block_gen_y_push := block_gen_height + block_gen_gap
					for &block, idx in blocks {
						block.rect.y += block_gen_y_push
						// Damages player if block touches bar line
						if block.rect.y + block.rect.height > bar_rectangle.y {
							player_health -= 1
							append(&blocks_remove_queue, idx)
						}
					}
					for i in 0 ..< block_gen_col_cnt {
						rect := rl.Rectangle {
							block_gen_x_min + block_gen_x_interval * f32(i),
							block_gen_y_min,
							block_gen_width,
							block_gen_height,
						}
						health := rand.int32_range(1, 4)
						if rand.float32() < block_gen_prob {
							append(
								&blocks,
								Block{rect = rect, health = health, max_health = health},
							)
						}
					}

					// update state
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

			// Draw Blocks
			for block in blocks {
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
				health_rate := f32(player_health) / f32(player_max_health)
				health_bar_rect := rl.Rectangle {
					board_x_min,
					board_y_min - 20,
					board_x_max - board_x_min,
					10,
				}
				fill_rect := health_bar_rect
				fill_rect.width *= health_rate
				rl.DrawRectangleRec(fill_rect, rl.RED)
				rl.DrawRectangleLinesEx(health_bar_rect, 1, rl.RED)
				rl.DrawText(
					rl.TextFormat("%d/%d", player_health, player_max_health),
					i32(health_bar_rect.x) + 2,
					i32(health_bar_rect.y),
					10,
					rl.RAYWHITE,
				)
			}

			// Ball
			rl.DrawCircleV(ball.pos, ball.radius, rl.RED)

			// Bar
			rl.DrawRectangleRec(bar_rectangle, rl.RED)

			// Board
			rl.DrawRectangleLinesEx(board_draw_rectangle, 1, rl.RED)

			// Aim Line
			if gs, ok := game_state.(Game_State_Aiming); ok {
				sin, cos := math.sincos(gs.aim_angle + math.PI)
				rl.DrawLineV(ball.pos, ball.pos + rl.Vector2{sin, cos} * 200, rl.RED)
			}

			// Score
			rl.DrawText(
				rl.TextFormat("%07d", player_score),
				i32(board_x_min),
				i32(board_y_max) + 5,
				20,
				rl.BLACK,
			)

			rl.EndMode2D()
			rl.EndDrawing()
		}
	}

	rl.CloseWindow()
}
