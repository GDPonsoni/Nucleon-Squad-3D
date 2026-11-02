class_name BodySwitcher
extends Node2D
## Faixa fixa na parte de baixo da tela com todos os corpos da formação, durante a
## câmera lenta. Tocar num corpo vivo troca para ele; o atual aparece destacado e os
## destruídos aparecem apagados com um X. Tocar fora (ou no atual) só retoma o jogo.
## Com o corpo destruído (forced), é preciso escolher um corpo vivo para continuar.
## Fica numa CanvasLayer própria: coordenadas de tela, acima da moldura da câmera lenta.

signal body_chosen(index: int)

## Corpo destruído: mostra a faixa mesmo com o dedo na tela até escolher.
var forced: bool = false

var _state: MatchState
var _touch: TouchInput
var _positions := PackedVector2Array()
var _strip := Rect2()
var _strip_style: StyleBoxFlat


func setup(state: MatchState, touch: TouchInput) -> void:
	_state = state
	_touch = touch
	# Conectar antes da nave e da câmera lenta: o toque no ícone é tratado primeiro
	touch.touch_started.connect(_on_touch_started)
	_strip_style = StyleBoxFlat.new()
	_strip_style.bg_color = Params.switch_strip_color
	_strip_style.set_corner_radius_all(Params.ui_corner_radius)


func _process(_delta: float) -> void:
	visible = forced or not _touch.is_touching()
	if visible:
		_layout()
		queue_redraw()


## Ícones lado a lado, centralizados, sempre na mesma altura da tela.
func _layout() -> void:
	var count: int = _state.bodies.size()
	var rect: Rect2 = get_viewport_rect()
	var radius: float = Params.switch_icon_radius
	var spacing: float = minf(Params.switch_strip_spacing, (rect.size.x - Params.switch_strip_side_margin * 2.0) / count)
	var y: float = rect.end.y - Params.switch_strip_bottom
	_positions.resize(count)
	for i in count:
		_positions[i] = Vector2(rect.get_center().x + (i - (count - 1) * 0.5) * spacing, y)
	var pad: float = Params.switch_strip_padding + Params.switch_level_ring_offset
	var left: float = _positions[0].x - radius - pad
	var right: float = _positions[count - 1].x + radius + pad
	_strip = Rect2(left, y - radius - pad, right - left, (radius + pad) * 2.0)


func _on_touch_started(pos: Vector2) -> void:
	if not visible:
		return
	var reach: float = Params.switch_icon_radius * Params.switch_icon_touch_scale
	for i in _positions.size():
		if pos.distance_to(_positions[i]) <= reach and _state.is_alive(i) and i != _state.current:
			body_chosen.emit(i)
			return


func _draw() -> void:
	draw_style_box(_strip_style, _strip)
	var radius: float = Params.switch_icon_radius
	for i in _positions.size():
		var body: BodyData = _state.bodies[i]
		var center: Vector2 = _positions[i]
		if not _state.is_alive(i):
			_draw_dead(center, radius, body)
			continue
		var current: bool = i == _state.current and not forced
		draw_circle(center, radius, Params.switch_icon_bg_color)
		draw_arc(center, radius, 0.0, TAU, 48, Color.WHITE if current else body.color, 7.0 if current else 4.0)
		_draw_level_ring(center, radius + Params.switch_level_ring_offset, i, body)
		_draw_shape(center, radius, body, body.color)
		# Hits restantes do corpo
		var hits: int = _state.hits_left[i]
		for h in hits:
			var offset := Vector2((h - (hits - 1) * 0.5) * radius * 0.22, radius * 0.75)
			draw_circle(center + offset, radius * 0.07, Color.WHITE)


## Corpo abatido: apagado, sem anel de nível e com um X vermelho.
func _draw_dead(center: Vector2, radius: float, body: BodyData) -> void:
	draw_circle(center, radius, Color(Params.switch_icon_bg_color, Params.switch_dead_alpha))
	draw_arc(center, radius, 0.0, TAU, 48, Color(Params.hud_dead_color, Params.switch_dead_alpha), 3.0)
	_draw_shape(center, radius, body, Color(Params.hud_dead_color, Params.switch_dead_alpha))
	var d: float = radius * 0.55
	draw_line(center + Vector2(-d, -d), center + Vector2(d, d), Params.hud_dead_mark_color, 7.0)
	draw_line(center + Vector2(d, -d), center + Vector2(-d, d), Params.hud_dead_mark_color, 7.0)


func _draw_shape(center: Vector2, radius: float, body: BodyData, color: Color) -> void:
	var points := PackedVector2Array()
	for point in body.shape:
		points.append(center + point * radius * Params.switch_icon_shape_scale)
	draw_colored_polygon(points, color)


## Segmentos dourados em volta do ícone: quantos níveis a arma do corpo já tem.
func _draw_level_ring(center: Vector2, ring_radius: float, index: int, body: BodyData) -> void:
	var levels: int = body.weapon.max_level()
	var level: int = _state.weapon_levels[index]
	var gap: float = deg_to_rad(Params.switch_level_ring_gap_degrees)
	var segment: float = TAU / levels
	for i in levels:
		# Começa no topo e segue no sentido horário
		var start: float = -PI * 0.5 + i * segment + gap * 0.5
		var color: Color = Params.powerup_color if i < level else Params.hud_dead_color
		draw_arc(center, ring_radius, start, start + segment - gap, 12, color, Params.switch_level_ring_width)
