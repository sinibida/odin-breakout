package lib

import rl "vendor:raylib"

draw_health_bar :: proc(
	value, max_value: i32,
	rect: rl.Rectangle,
	color: rl.Color,
	back_color: rl.Color = MYWHITE,
) {
	rate := rl.Clamp(f32(value) / f32(max_value), 0, 1)
	fill_rect := rect
	fill_rect.width *= rate

	rl.DrawRectangleRec(fill_rect, color)
	rl.DrawRectangleLinesEx(rect, 1, color)

	text := rl.TextFormat("%d/%d", value, max_value)
	tx, ty := get_text_pos_rect_origin(text, rect, {0, 0.5}, 10)
	text_color := value > 0 ? back_color : color
	rl.DrawText(text, tx + 2, ty, 10, text_color)
}
