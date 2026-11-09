class_name XpOrb
extends PoolItem
## Orbe de XP: sai do inimigo destruído, cai devagar e é puxado pela nave quando ela chega
## perto (raio do ímã). Encostou no núcleo, vira XP. Saiu por baixo da tela, some.

signal collected(value: float)

var mode: RunModeData
var player: Player
var magnet_scale: float = 1.0  # alcance do ímã (Coleta da evolução)
var value: float = 0.0
var _velocity := Vector2.ZERO
var _pulled: bool = false
var _clock: float = 0.0


func activate(pos: Vector2, amount: float) -> void:
	position = pos
	value = amount
	_pulled = false
	_clock = randf() * TAU
	# Pulinho para cima e para o lado ao nascer
	_velocity = Vector2(randf_range(-1.0, 1.0) * Params.xp_orb_burst_side, -Params.xp_orb_burst_up)
	_set_active()
	queue_redraw()


func _process(delta: float) -> void:
	# Tempo de jogo: acompanha a câmera lenta
	_clock += delta
	var to_player: Vector2 = player.position - position
	var distance: float = to_player.length()
	if player.body != null and distance <= mode.orb_collect_radius:
		collected.emit(value)
		expire()
		return
	if not _pulled and player.body != null and distance <= mode.orb_magnet_radius * magnet_scale:
		_pulled = true
	if _pulled:
		var goal: Vector2 = to_player / maxf(distance, 0.001) * mode.orb_pull_speed
		_velocity = _velocity.move_toward(goal, mode.orb_pull_accel * delta)
	else:
		_velocity = _velocity.move_toward(Vector2(0.0, mode.orb_fall_speed), Params.xp_orb_settle_accel * delta)
	position += _velocity * delta
	if position.y > get_viewport_rect().end.y + Params.xp_orb_radius * 2.0:
		expire()
	queue_redraw()


func _draw() -> void:
	var big: bool = value >= mode.orb_big_value
	var r: float = Params.xp_orb_radius * (1.6 if big else 1.0) * (1.0 + 0.12 * sin(_clock * 6.0))
	var points := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r), Vector2(-r * 0.7, 0)])
	draw_circle(Vector2.ZERO, r * 1.3, Color(Params.xp_orb_color, 0.25))
	draw_colored_polygon(points, Params.xp_orb_color)
	draw_colored_polygon(PackedVector2Array([points[0] * 0.45, points[1] * 0.45, points[2] * 0.45, points[3] * 0.45]), Color(1, 1, 1, 0.85))
