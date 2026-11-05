class_name PowerUp
extends PoolItem
## Item que desce devagar e é coletado ao encostar na nave.
## WEAPON sobe o nível da arma do corpo ativo; HEAL (medkit) recupera 1 hit;
## COMPANION (raro) sobe o nível da nave auxiliar.

enum Kind { WEAPON, HEAL, COMPANION }

var kind: Kind = Kind.WEAPON

var _clock: float = 0.0


func activate(pos: Vector2, item_kind: Kind = Kind.WEAPON) -> void:
	position = pos
	kind = item_kind
	_clock = 0.0
	queue_redraw()
	_set_active()


func _process(delta: float) -> void:
	position.y += Params.powerup_fall_speed * delta
	if position.y - Params.powerup_radius > get_viewport_rect().end.y:
		expire()
		return
	# Power-up gira; ambos pulsam para chamar atenção
	_clock += delta
	rotation = _clock * Params.powerup_spin_speed if kind != Kind.HEAL else 0.0
	scale = Vector2.ONE * (1.0 + Params.powerup_pulse * sin(_clock * Params.powerup_pulse_speed))


func _draw() -> void:
	if kind == Kind.HEAL:
		_draw_medkit()
		return
	var radius: float = Params.powerup_radius
	# Auxiliar: lilás, maior e com anel extra (é raro e precisa se destacar)
	var companion: bool = kind == Kind.COMPANION
	var color: Color = Params.companion_powerup_color if companion else Params.powerup_color
	draw_circle(Vector2.ZERO, radius, Color(color, 0.25))
	if companion:
		draw_arc(Vector2.ZERO, radius * 1.3, 0.0, TAU, 32, Color(color, 0.8), 4.0)
	var r: float = radius * 0.75
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0),
	]), color)
	# Sinal de "+"
	var arm: float = radius * 0.4
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), Color.WHITE, 5.0)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), Color.WHITE, 5.0)


## Medkit: caixa branca arredondada com cruz verde.
func _draw_medkit() -> void:
	var radius: float = Params.powerup_radius
	draw_circle(Vector2.ZERO, radius, Color(Params.medkit_color, 0.25))
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(int(radius * 0.3))
	var half: float = radius * 0.72
	draw_style_box(box, Rect2(-half, -half, half * 2.0, half * 2.0))
	var arm: float = radius * 0.48
	var thick: float = radius * 0.3
	draw_rect(Rect2(-arm, -thick * 0.5, arm * 2.0, thick), Params.medkit_color)
	draw_rect(Rect2(-thick * 0.5, -arm, thick, arm * 2.0), Params.medkit_color)
