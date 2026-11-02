class_name PowerUp
extends PoolItem
## Power-up que desce devagar. Ao ser coletado, sobe o nível da arma do corpo ativo.

var _clock: float = 0.0


func activate(pos: Vector2) -> void:
	position = pos
	_clock = 0.0
	_set_active()


func _process(delta: float) -> void:
	position.y += Params.powerup_fall_speed * delta
	if position.y - Params.powerup_radius > get_viewport_rect().end.y:
		expire()
		return
	# Gira e pulsa para chamar atenção
	_clock += delta
	rotation = _clock * Params.powerup_spin_speed
	scale = Vector2.ONE * (1.0 + Params.powerup_pulse * sin(_clock * Params.powerup_pulse_speed))


func _draw() -> void:
	var radius: float = Params.powerup_radius
	draw_circle(Vector2.ZERO, radius, Color(Params.powerup_color, 0.25))
	var r: float = radius * 0.75
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0),
	]), Params.powerup_color)
	# Sinal de "+"
	var arm: float = radius * 0.4
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), Color.WHITE, 5.0)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), Color.WHITE, 5.0)
