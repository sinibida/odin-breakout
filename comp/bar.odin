package comp

import rl "vendor:raylib"

Bar :: struct {
	pos:         rl.Vector2,
	size:        rl.Vector2,
	max_width:   f32,
	vel_x:       f32,
	acc_x:       f32,
	speed:       f32,
	drain_speed: f32,
	active:      bool,
}
INITIAL_BAR_MAX_WIDTH :: 100

bar_get_rectangle :: proc(bar: ^Bar) -> rl.Rectangle {
	return rl.Rectangle {
		bar.pos.x - bar.size.x / 2,
		bar.pos.y - bar.size.y / 2,
		bar.size.x,
		bar.size.y,
	}
}

bar_move :: proc(bar: ^Bar, x_min, x_max: f32) {
	frame_time := rl.GetFrameTime()
	bar_min := x_min + bar.size.x / 2
	bar_max := x_max - bar.size.x / 2
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
	bar.pos.x = rl.Clamp(bar.pos.x, bar_min, bar_max)
	// Vel = 0 if the bar is clamped
	if bar.pos.x == bar_max do bar.vel_x = bar.vel_x > 0 ? 0 : bar.vel_x
	if bar.pos.x == bar_min do bar.vel_x = bar.vel_x < 0 ? 0 : bar.vel_x
}

bar_drain :: proc(bar: ^Bar) {
	frame_time := rl.GetFrameTime()
	if bar.size.x > 0 do bar.size.x -= bar.drain_speed * frame_time
	if bar.size.x <= 0 {
		bar.size.x = 0
		bar.active = false
	}
}

bar_heal :: proc(bar: ^Bar, amount: f32) {
	bar.size.x = min(bar.size.x + amount, bar.max_width)
}
