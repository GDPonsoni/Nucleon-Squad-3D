class_name BeamWeapon
extends Weapon
## Raio contínuo para cima: para no primeiro inimigo da coluna e causa dano em intervalos.

var _length: float = 0.0
var _tick: float = 0.0


func _process(delta: float) -> void:
	var origin: Vector2 = muzzle()
	var hit_y: float = get_viewport_rect().position.y
	var target: Enemy = null
	for item in context.enemies.active:
		var enemy := item as Enemy
		if enemy.position.y >= origin.y or not enemy.is_on_screen():
			continue
		if absf(enemy.position.x - origin.x) > data.beam_width * 0.5 + enemy.radius:
			continue
		# O mais próximo da nave bloqueia o feixe
		var y: float = minf(enemy.position.y + enemy.radius * 0.5, origin.y)
		if y > hit_y:
			hit_y = y
			target = enemy
	_length = origin.y - hit_y

	_tick = maxf(_tick - delta, 0.0)
	if target != null and _tick == 0.0:
		_tick = data.beam_tick_seconds
		target.take_damage(data.damage)
	queue_redraw()


func _draw() -> void:
	var tip := Vector2(0.0, -Params.ship_size.y * 0.5)
	var glow := Color(data.color, 0.35)
	draw_rect(Rect2(tip.x - data.beam_width * 0.5, tip.y - _length, data.beam_width, _length), glow)
	var core_width: float = data.beam_width * 0.4
	draw_rect(Rect2(tip.x - core_width * 0.5, tip.y - _length, core_width, _length), data.color.lightened(0.6))
