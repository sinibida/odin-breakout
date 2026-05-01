package phys

import rl "vendor:raylib"

// LATER: interpolate physics (capsulecast?)

Ball_Rectangle_Collision :: struct {
	normal:           rl.Vector2,
	center_reflected: rl.Vector2,
}

handle_ball_collision :: proc(
	ball_pos: ^rl.Vector2,
	ball_dir: ^rl.Vector2,
	col: Ball_Rectangle_Collision,
) {
	ball_pos^ = col.center_reflected
	proj := col.normal * rl.Vector2DotProduct(col.normal, ball_dir^)
	ball_dir^ = -(ball_dir^ - (ball_dir^ - proj) * 2)
}

@(private = "file")
handle_corner :: proc(
	corner: rl.Vector2,
	center: rl.Vector2,
	radius: f32,
) -> (
	col: Ball_Rectangle_Collision,
	ok: bool,
) {
	dist := rl.Vector2Distance(center, corner)
	if dist > radius {
		ok = false
		return
	}
	normal := (center - corner) / dist
	center_reflected := center + normal * (radius - dist) * 2

	col = Ball_Rectangle_Collision {
		normal           = normal,
		center_reflected = center_reflected,
	}
	ok = true
	return
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
			corner := rl.Vector2{center.x, y_max}
			col, _ = handle_corner(corner, center, radius)
			ok = true
			return
		}; if y_rmin <= center.y && center.y <= y_mid {
			corner := rl.Vector2{center.x, y_min}
			col, _ = handle_corner(corner, center, radius)
			ok = true
			return
		}
	} else if y_min <= center.y && center.y <= y_max {
		// LR Edge
		if x_mid <= center.x && center.x <= x_rmax {
			corner := rl.Vector2{x_max, center.y}
			col_temp, _ := handle_corner(corner, center, radius)
			col = col_temp
			ok = true
			return
		}; if x_rmin <= center.x && center.x <= x_mid {
			corner := rl.Vector2{x_min, center.y}
			col, _ = handle_corner(corner, center, radius)
			ok = true
			return
		}
	} else {
		// Corners
		corners := [4]rl.Vector2{{x_min, y_min}, {x_min, y_max}, {x_max, y_min}, {x_max, y_max}}
		for corner in corners {
			col_temp, ok_temp := handle_corner(corner, center, radius)
			if ok_temp {
				col = col_temp
				ok = true
				return
			}
		}
	}


	return
}
