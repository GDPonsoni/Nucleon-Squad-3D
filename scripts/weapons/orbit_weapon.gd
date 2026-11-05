class_name OrbitWeapon
extends Weapon
## Orbitais girando em volta da nave: causam dano ao encostar nos inimigos
## e, se a arma permitir, destroem projéteis inimigos que tocam.

var _angle: float = 0.0
var _cooldowns: Dictionary = {}  # Enemy -> segundos até poder levar dano de novo


func _process(delta: float) -> void:
	var spin: float = 1.0
	if _tick_spawn(delta):
		spin += (Params.weapon_spawn_orbit_spin - 1.0) * (1.0 - spawn_progress())
	_angle = wrapf(_angle + deg_to_rad(stats.orbit_speed_degrees) * spin * delta, 0.0, TAU)

	# Sem tipo no laço: o chefe é liberado da memória ao morrer e a chave fica inválida
	for enemy in _cooldowns.keys():
		if not is_instance_valid(enemy):
			_cooldowns.erase(enemy)
			continue
		_cooldowns[enemy] -= delta
		if _cooldowns[enemy] <= 0.0 or not (enemy as Enemy).visible:
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
			var reach: float = enemy.radius + stats.orbit_size * 0.5 * _grow()
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
	return Vector2.from_angle(_angle + TAU * index / stats.orbit_count) * stats.orbit_radius * _grow()


## Formação: as esferas saem do centro até o raio cheio (com leve excesso) e crescem.
func _grow() -> float:
	if not is_spawning():
		return 1.0
	var x: float = spawn_progress()
	var c1: float = 1.70158
	return clampf(1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0), 0.0, 1.3)


func _draw() -> void:
	var pivot: Vector2 = to_local(_pivot())
	var grow: float = _grow()
	draw_arc(pivot, stats.orbit_radius * grow, 0.0, TAU, 64, Color(data.color, 0.15 + 0.3 * (1.0 - spawn_progress())), 3.0)
	for i in stats.orbit_count:
		draw_circle(pivot + _offset(i), stats.orbit_size * 0.5 * minf(grow, 1.0), data.color)
		draw_circle(pivot + _offset(i), stats.orbit_size * 0.2 * minf(grow, 1.0), Color.WHITE)
