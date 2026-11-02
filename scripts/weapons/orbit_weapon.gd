class_name OrbitWeapon
extends Weapon
## Orbitais girando em volta da nave: causam dano ao encostar nos inimigos.

var _angle: float = 0.0
var _cooldowns: Dictionary = {}  # Enemy -> segundos até poder levar dano de novo


func _process(delta: float) -> void:
	_angle = wrapf(_angle + deg_to_rad(data.orbit_speed_degrees) * delta, 0.0, TAU)

	for enemy: Enemy in _cooldowns.keys():
		_cooldowns[enemy] -= delta
		if _cooldowns[enemy] <= 0.0 or not enemy.visible:
			_cooldowns.erase(enemy)

	var enemies: Array[PoolItem] = context.enemies.active
	for i in data.orbit_count:
		var center: Vector2 = global_position + _offset(i)
		# De trás para frente: o inimigo pode morrer e sair da lista
		for j in range(enemies.size() - 1, -1, -1):
			var enemy := enemies[j] as Enemy
			if _cooldowns.has(enemy):
				continue
			var reach: float = enemy.radius + data.orbit_size * 0.5
			if center.distance_squared_to(enemy.position) <= reach * reach:
				_cooldowns[enemy] = data.orbit_hit_seconds
				enemy.take_damage(data.damage)
	queue_redraw()


func _offset(index: int) -> Vector2:
	return Vector2.from_angle(_angle + TAU * index / data.orbit_count) * data.orbit_radius


func _draw() -> void:
	draw_arc(Vector2.ZERO, data.orbit_radius, 0.0, TAU, 64, Color(data.color, 0.15), 3.0)
	for i in data.orbit_count:
		draw_circle(_offset(i), data.orbit_size * 0.5, data.color)
		draw_circle(_offset(i), data.orbit_size * 0.2, Color.WHITE)
