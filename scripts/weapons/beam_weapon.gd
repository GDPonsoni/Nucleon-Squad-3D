class_name BeamWeapon
extends Weapon
## Raios contínuos para cima, lado a lado: cada um para no primeiro inimigo
## da sua coluna e causa dano em intervalos.

var _lengths := PackedFloat32Array()
var _ticks := PackedFloat32Array()


func set_level(number: int) -> void:
	super(number)
	_lengths.resize(stats.beam_count)
	_ticks.resize(stats.beam_count)
	_ticks.fill(0.0)


func _process(delta: float) -> void:
	var tip: Vector2 = muzzle()
	for k in stats.beam_count:
		var origin := Vector2(tip.x + _offset_x(k), tip.y)
		var target: Enemy = _first_enemy_above(origin)
		var hit_y: float = get_viewport_rect().position.y
		if target != null:
			# O feixe termina no meio do inimigo, sem passar da nave
			hit_y = minf(target.position.y + target.radius * 0.5, origin.y)
		_lengths[k] = origin.y - hit_y
		_ticks[k] = maxf(_ticks[k] - delta, 0.0)
		if target != null and _ticks[k] == 0.0:
			_ticks[k] = stats.beam_tick_seconds
			target.take_damage(stats.damage)
	queue_redraw()


## Inimigo visível mais próximo da nave na coluna do feixe.
func _first_enemy_above(origin: Vector2) -> Enemy:
	var best: Enemy = null
	for item in context.enemies.active:
		var enemy := item as Enemy
		if enemy.position.y >= origin.y or not enemy.is_on_screen():
			continue
		if absf(enemy.position.x - origin.x) > stats.beam_width * 0.5 + enemy.radius:
			continue
		if best == null or enemy.position.y > best.position.y:
			best = enemy
	return best


func _offset_x(index: int) -> float:
	return (index - (stats.beam_count - 1) * 0.5) * stats.beam_spacing


func _draw() -> void:
	var tip_y: float = -Params.ship_size.y * 0.5
	var glow := Color(data.color, 0.35)
	var core: Color = data.color.lightened(0.6)
	var core_width: float = stats.beam_width * 0.4
	for k in stats.beam_count:
		var x: float = _offset_x(k)
		var length: float = _lengths[k]
		draw_rect(Rect2(x - stats.beam_width * 0.5, tip_y - length, stats.beam_width, length), glow)
		draw_rect(Rect2(x - core_width * 0.5, tip_y - length, core_width, length), core)
