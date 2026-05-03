package lib

import "core:strings"
import rl "vendor:raylib"

// origin.x: 0-1
// origin.y: 0-1
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

/*
An unecessarily complex function for drawing number in monospace

Returns width of the text
*/
draw_score_text :: proc(
	score: i32,
	digit_count: i32,
	font_size: i32,
	ch_gap: i32,
	#any_int pos_x, pos_y: i32,
	origin: rl.Vector2,
) -> (
	text_width: i32,
) {
	text := rl.TextFormat(rl.TextFormat("%%0%dd", digit_count), score)
	ch_width: i32 = rl.MeasureText("0", font_size)
	return draw_mono_text_ch_width(text, ch_width, font_size, ch_gap, pos_x, pos_y, origin)
}

draw_mono_text:: proc(
    text: cstring,
	font_size: i32,
	ch_gap: i32,
	#any_int pos_x, pos_y: i32,
	origin: rl.Vector2,
) -> (
	text_width: i32,
) {
	ch_width: i32 = rl.MeasureText("W", font_size)
	return draw_mono_text_ch_width(text, ch_width, font_size, ch_gap, pos_x, pos_y, origin)
}

draw_mono_text_ch_width :: proc(
    text: cstring,
    ch_width: i32,
	font_size: i32,
	ch_gap: i32,
	#any_int pos_x, pos_y: i32,
	origin: rl.Vector2,
) -> (
	text_width: i32,
) {
	text_width = (ch_width + ch_gap) * i32(len(text)) - ch_gap
	x_min: i32 = pos_x - i32(f32(text_width) * origin.x)
	ty: i32 = pos_y - i32(f32(font_size) * origin.y)

    text_str := string(text)
	for idx in 0 ..< len(text_str) {
		tx: i32 = x_min + (ch_width + ch_gap) * i32(idx)
		ch_str := text_str[idx:][:1]
        ch_cstring := strings.clone_to_cstring(ch_str)
        defer delete(ch_cstring)
		ttx, tty := get_text_pos_rect_origin(
			ch_cstring,
			{f32(tx), f32(ty), f32(ch_width), f32(font_size)},
			{0.5, 0.5},
			font_size,
		)
		rl.DrawText(ch_cstring, ttx, tty, font_size, MYBLACK)
	}

	return
}