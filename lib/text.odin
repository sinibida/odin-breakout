package lib

import rl "vendor:raylib"

// origin.x: 0~1
// origin.y: 0~1
get_text_pos_rect_origin :: proc(
	text: cstring,
	rect: rl.Rectangle,
	origin: rl.Vector2,
	font_size: i32,
) -> (
	x: i32,
	y: i32,
) {
	text_width := rl.MeasureText(text, font_size)
	x = i32(rect.x + rect.width * origin.x - f32(text_width) * origin.x)
	y = i32(rect.y + rect.height * origin.y - f32(font_size) * origin.y)
	return
}
