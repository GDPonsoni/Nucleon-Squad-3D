class_name BeamWeapon
extends Weapon
## Raios contínuos saindo da ponta da nave, cada um com deslocamento, ângulo e largura
## próprios (vindos do nível). Cada raio para no primeiro inimigo e causa dano em intervalos.

const MAX_LENGTH: float = 4000.0  # passa da tela em qualquer ângulo

var _lengths := PackedFloat32Array()
var _ticks := PackedFloat32Array()


func apply_stats(values: WeaponLevel) -> void:
	super(values)
	var count: int = stats.beam_angles.size()
	_lengths.resize(count)
	_lengths.fill(0.0)
	_ticks.resize(count)
	_ticks.fill(0.0)


func _process(delta: float) -> void:
	_tick_spawn(delta)
	var tip: Vector2 = muzzle()
	for k in stats.beam_angles.size():
		var origin := Vector2(tip.x + stats.beam_offsets[k], tip.y)
		var dir: Vector2 = _direction(k)
		var half_width: float = stats.beam_widths[k] * 0.5
		var target: Enemy = null
		var hit: float = MAX_LENGTH
		for item in context.hostiles():
			var enemy := item as Enemy
			if not enemy.visible or not enemy.is_on_screen():
				continue
			var rel: Vector2 = enemy.position - origin
			var along: float = rel.dot(dir)
			# Atrás da ponta ou longe da linha do raio
			if along <= 0.0 or absf(rel.cross(dir)) > half_width + enemy.radius:
				continue
			# O raio termina no meio do inimigo mais próximo
			var stop: float = maxf(along - enemy.radius * 0.5, 0.0)
			if stop < hit:
				hit = stop
				target = enemy
		_lengths[k] = hit
		_ticks[k] = maxf(_ticks[k] - delta, 0.0)
		if target != null and _ticks[k] == 0.0 and not is_spawning():
			_ticks[k] = stats.beam_tick_seconds / rate()
			target.take_damage(damage())
			Audio.shot(data.kind, sound_db)
	queue_redraw()


## Ângulo 0 = para cima; positivo abre para a direita.
func _direction(index: int) -> Vector2:
	return Vector2.from_angle(-PI * 0.5 + deg_to_rad(stats.beam_angles[index]))


func _draw() -> void:
	var tip := Vector2(0.0, -muzzle_offset)
	var glow := Color(data.color, 0.35)
	var core: Color = data.color.lightened(0.6)
	for k in stats.beam_angles.size():
		# Surgimento: o raio abre de uma linha fina até a largura cheia, depois do orbe de carga
		var grow: float = ease(clampf((spawn_progress() - 0.3) / 0.7, 0.0, 1.0), 0.5)
		var width: float = stats.beam_widths[k] * grow
		var length: float = _lengths[k]
		# Desenha em pé e gira para o ângulo do raio
		draw_set_transform(tip + Vector2(stats.beam_offsets[k], 0.0), deg_to_rad(stats.beam_angles[k]))
		draw_rect(Rect2(-width * 0.5, -length, width, length), glow)
		draw_rect(Rect2(-width * 0.2, -length, width * 0.4, length), core)
	draw_set_transform(Vector2.ZERO)
	_draw_charge()
