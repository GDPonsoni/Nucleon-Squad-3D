class_name OrbitWeapon
extends Weapon
## Orbitais girando em volta da nave: causam dano ao encostar nos inimigos
## e, se a arma permitir, destroem projéteis inimigos que tocam.

var _angle: float = 0.0
var _cooldowns: Dictionary = {}  # Enemy -> segundos até poder levar dano de novo


func _process(delta: float) -> void:
	_angle = wrapf(_angle + deg_to_rad(stats.orbit_speed_degrees) * delta, 0.0, TAU)

	for enemy: Enemy in _cooldowns.keys():
		_cooldowns[enemy] -= delta
		if _cooldowns[enemy] <= 0.0 or not enemy.visible:
			_cooldowns.erase(enemy)

	var enemies: Array[PoolItem] = context.hostiles()
	var pivot: Vector2 = _pivot()
	for i in stats.orbit_count:
		var center: Vector2 = pivot + _offset(i)
		if stats.clears_projectiles:
			_clear_projectiles(center)
		# De trás para frente: o inimigo pode morrer e sair da lista
		for j in range(enemies.size() - 1, -1, -1):
			var enemy := enemies[j] as Enemy
			if _cooldowns.has(enemy):
				continue
			var reach: float = enemy.radius + stats.orbit_size * 0.5
			if center.distance_squared_to(enemy.position) <= reach * reach:
				_cooldowns[enemy] = stats.orbit_hit_seconds / rate()
				enemy.take_damage(damage())
				Audio.shot(data.kind, sound_db)
	queue_redraw()


func _clear_projectiles(center: Vector2) -> void:
	var bullets: Array[PoolItem] = context.enemy_bullets.active
	for j in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[j] as Bullet
		var reach: float = bullet.radius + stats.orbit_size * 0.5
		if center.distance_squared_to(bullet.position) <= reach * reach:
			context.enemy_bullets.release(bullet)


## Centro da órbita: a própria nave ou (auxiliar escudo) a nave principal.
func _pivot() -> Vector2:
	if stats.orbit_around_player and context.player != null:
		return context.player.global_position
	return global_position


func _offset(index: int) -> Vector2:
	return Vector2.from_angle(_angle + TAU * index / stats.orbit_count) * stats.orbit_radius


func _draw() -> void:
	var pivot: Vector2 = to_local(_pivot())
	draw_arc(pivot, stats.orbit_radius, 0.0, TAU, 64, Color(data.color, 0.15), 3.0)
	for i in stats.orbit_count:
		draw_circle(pivot + _offset(i), stats.orbit_size * 0.5, data.color)
		draw_circle(pivot + _offset(i), stats.orbit_size * 0.2, Color.WHITE)
