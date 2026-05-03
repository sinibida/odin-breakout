package comp

Enemy_Gen :: struct {
	// TODO: Add Various Enemies!
	// Below is STUB.
	level: i32,
}

enemy_gen_new_enemy :: proc(enemy_gen: ^Enemy_Gen) -> Enemy {
	max_health: i32 = 20 + (enemy_gen.level - 1) * 5
    level := enemy_gen.level
	return {max_health = max_health, health = max_health, level = level}
}
