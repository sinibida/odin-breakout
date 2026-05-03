package main

import rl "vendor:raylib"
import "comp"
import "lib"

main :: proc() {
	rl.InitWindow(lib.WINDOW_WIDTH, lib.WINDOW_HEIGHT, "Breakout")

    gp_st := comp.gp_st_init()
    defer comp.gp_st_free(&gp_st)

	for !rl.WindowShouldClose() {
        comp.gp_st_update(&gp_st)
        comp.gp_st_draw(&gp_st)
	}

	rl.CloseWindow()
}


