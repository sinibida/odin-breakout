package phys

import rl "vendor:raylib"

// LATER: interpolate physics (capsulecast?)

Ball_Rectangle_Collision_Corner :: struct {
	normal: rl.Vector2,
}
Ball_Rectangle_Collision_Edge :: struct {
	normal:           rl.Vector2,
	center_reflected: rl.Vector2,
}

Ball_Rectangle_Collision :: union {
	Ball_Rectangle_Collision_Corner,
	Ball_Rectangle_Collision_Edge,
}

handle_ball_collision :: proc(
	ball_pos: ^rl.Vector2,
	ball_dir: ^rl.Vector2,
	col: Ball_Rectangle_Collision,
) {
	switch c in col {
	case Ball_Rectangle_Collision_Edge:
		ball_pos^ = c.center_reflected
		if c.normal.x == 0 {
			ball_dir^ *= {1, -1}
		} else {
			ball_dir^ *= {-1, 1}
		}
	case Ball_Rectangle_Collision_Corner:
	// STUB
	}
}

get_collision_ball_rectangle :: proc(
	center: rl.Vector2,
	radius: f32,
	rectangle: rl.Rectangle,
) -> (
	col: Ball_Rectangle_Collision,
	ok: bool = false,
) {
	x_min := rectangle.x
	y_min := rectangle.y
	x_max := rectangle.x + rectangle.width
	y_max := rectangle.y + rectangle.height
	x_mid := (x_min + x_max) / 2
	y_mid := (y_min + y_max) / 2

	x_rmin := x_min - radius
	y_rmin := y_min - radius
	x_rmax := x_max + radius
	y_rmax := y_max + radius

	// Fast Exit (Bounding Box check)
	if center.x < x_rmin || center.x > x_rmax || center.y < y_rmin || center.y > y_rmax {
		return
	}

	if x_min <= center.x && center.x <= x_max {
		// UD Edge
		if y_mid <= center.y && center.y <= y_rmax {
			y_ref := (y_rmax) * 2 - center.y
			col = Ball_Rectangle_Collision_Edge {
				normal           = {0, 1},
				center_reflected = {center.x, y_ref},
			}
			ok = true
		} else if y_rmin <= center.y && center.y <= y_mid {
			y_ref := (y_rmin) * 2 - center.y
			col = Ball_Rectangle_Collision_Edge {
				normal           = {0, -1},
				center_reflected = {center.x, y_ref},
			}
			ok = true
		} else {
			// nothing
		}
	} else if y_min <= center.y && center.y <= y_max {
		// LR Edge
		if x_mid <= center.x && center.x <= x_rmax {
			x_ref := (x_rmax) * 2 - center.x
			col = Ball_Rectangle_Collision_Edge {
				normal           = {0, 1},
				center_reflected = {x_ref, center.y},
			}
			ok = true
		} else if x_rmin <= center.x && center.x <= x_mid {
			x_ref := (x_rmin) * 2 - center.x
			col = Ball_Rectangle_Collision_Edge {
				normal           = {0, -1},
				center_reflected = {x_ref, center.y},
			}
			ok = true
		} else {
			// nothing
		}
	} else {
		// Corners
		if rl.Vector2Distance(center, {x_min, y_min}) <= radius {
			ok = true
		} else if rl.Vector2Distance(center, {x_min, y_max}) <= radius {
			ok = true
		} else if rl.Vector2Distance(center, {x_max, y_min}) <= radius {
			ok = true
		} else if rl.Vector2Distance(center, {x_max, y_max}) <= radius {
			ok = true
		} else {
			// nothing
		}
	}

	return
}
