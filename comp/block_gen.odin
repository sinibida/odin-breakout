package comp

import rl "vendor:raylib"
import "core:math/rand"

Block_Gen :: struct {
	prob:    f32,
	width:   f32,
	height:  f32,
	gap:     f32,
	col_cnt: i32,
	y_min:   f32,
}

block_gen_push :: proc(block_gen: ^Block_Gen, blocks: ^[dynamic]Block) {
	block_gen_y_push := block_gen.height + block_gen.gap
	for &block, idx in blocks {
		block.rect.y += block_gen_y_push
	}
}

block_gen_append_row :: proc(block_gen: ^Block_Gen, blocks: ^[dynamic]Block, enemy: ^Enemy) {
	block_gen_full_width :=
		block_gen.width * f32(block_gen.col_cnt) + block_gen.gap * f32(block_gen.col_cnt - 1)
	block_gen_x_min := -block_gen_full_width * 0.5
	block_gen_x_interval := block_gen.width + block_gen.gap
	for i in 0 ..< block_gen.col_cnt {
		rect := rl.Rectangle {
			block_gen_x_min + block_gen_x_interval * f32(i),
			block_gen.y_min,
			block_gen.width,
			block_gen.height,
		}
		health := rand.int32_range(1, 3 + enemy.level)
		if rand.float32() < block_gen.prob {
			append(blocks, Block{rect = rect, health = health, max_health = health})
		}
	}
}