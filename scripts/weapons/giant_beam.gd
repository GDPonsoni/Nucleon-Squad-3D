class_name GiantBeam
extends Node2D
## Especial do Raio: raio gigante para frente por alguns segundos. Fica como filho
## da nave, atinge todo inimigo na coluna e apaga os tiros inimigos dentro dele.

const TICK: float = 0.05  # segundos entre aplicações de dano

var _context: CombatContext
var _data: WeaponData
var _age: float = 0.0
var _tick: float = 0.0
var _width: float = 0.0


func setup(context: CombatContext, data: WeaponData) -> void:
	_context = context
	_data = data
	show_behind_parent = true


func _process(delta: float) -> void:
	_age += delta
	var duration: float = _data.special_duration
	if _age >= duration:
		queue_free()
		return
	# Abre rápido, mantém e fecha no fim
	var open: float = minf(_age / Params.special_beam_open_seconds, 1.0)
	var close: float = minf((duration - _age) / Params.special_beam_open_seconds, 1.0)
	_width = _data.special_width * minf(open, close)

	var tip_y: float = global_position.y - Params.ship_size.y * 0.5
	var half: float = _width * 0.5
	var bullets: Array[PoolItem] = _context.enemy_bullets.active
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i] as Bullet
		if bullet.position.y < tip_y and absf(bullet.position.x - global_position.x) <= half + bullet.radius:
			_context.enemy_bullets.release(bullet)

	_tick -= delta
	if _tick <= 0.0:
		_tick += TICK
		for item in _context.hostiles():
			var enemy := item as Enemy
			if enemy.visible and enemy.position.y < tip_y and absf(enemy.position.x - global_position.x) <= half + enemy.radius:
				enemy.take_damage(_data.special_damage)
	queue_redraw()


func _draw() -> void:
	var tip_y: float = -Params.ship_size.y * 0.5
	var length: float = get_viewport_rect().size.y * 2.0
	var pulse: float = 0.85 + 0.15 * sin(_age * 30.0)
	draw_rect(Rect2(-_width * 0.5, tip_y - length, _width, length), Color(_data.color, 0.35 * pulse))
	draw_rect(Rect2(-_width * 0.3, tip_y - length, _width * 0.6, length), Color(_data.color.lightened(0.4), 0.7 * pulse))
	draw_rect(Rect2(-_width * 0.12, tip_y - length, _width * 0.24, length), Color(1.0, 1.0, 1.0, 0.9))
