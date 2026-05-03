package comp

import rl "vendor:raylib"

Board :: struct {
	x_min: f32,
	x_max: f32,
	y_min: f32,
	y_max: f32,
}

board_get_draw_rectangle :: proc(board: ^Board) -> rl.Rectangle {
	return rl.Rectangle {
		board.x_min,
		board.y_min,
		board.x_max - board.x_min,
		board.y_max - board.y_min,
	}
}
board_get_collider_rectangle :: proc(board: ^Board) -> rl.Rectangle {
	return rl.Rectangle{board.x_min, board.y_min, board.x_max - board.x_min, 100000}
}
