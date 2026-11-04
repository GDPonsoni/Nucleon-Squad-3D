class_name Shockwave
extends Node2D
## Anel de energia que se expande a partir de um ponto: destrói os tiros inimigos
## que alcança e, se tiver dano, atinge cada inimigo uma única vez.

var _context: CombatContext
var _max_radius: float = 0.0
var _duration: float = 0.0
var _damage: float = 0.0
var _color: Color
var _age: float = 0.0
var _radius: float = 0.0
var _hit: Dictionary = {}  # inimigos já atingidos


func setup(context: CombatContext, center: Vector2, max_radius: float, duration: float, damage: float, color: Color) -> void:
	_context = context
	position = center
	_max_radius = max_radius
	_duration = duration
	_damage = damage
	_color = color


func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / _duration, 0.0, 1.0)
	_radius = _max_radius * ease(t, 0.5)

	var bullets: Array[PoolItem] = _context.enemy_bullets.active
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i] as Bullet
		if bullet.position.distance_to(position) <= _radius + bullet.radius:
			_context.enemy_bullets.release(bullet)

	if _damage > 0.0:
		for item in _context.hostiles():
			var enemy := item as Enemy
			if _hit.has(enemy) or not enemy.visible:
				continue
			if enemy.position.distance_to(position) <= _radius + enemy.radius:
				_hit[enemy] = true
				enemy.take_damage(_damage)

	queue_redraw()
	if t >= 1.0:
		queue_free()


func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / _duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, _radius, Color(_color, 0.12 * fade))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 96, Color(_color.lightened(0.3), fade), 4.0 + 14.0 * fade)
