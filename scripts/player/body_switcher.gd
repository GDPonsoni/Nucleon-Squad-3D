class_name BodySwitcher
extends Node2D
## Barra fixa na base da tela com todos os corpos da formação, sempre no mesmo lugar.
## Com o dedo na tela (jogando), fica translúcida e só mostra o estado: hits, nível da
## arma e corpos abatidos. Na câmera lenta (dedo solto), fica nítida e aceita a troca.
## A troca é um toque curto: o dedo encosta num corpo vivo e sai logo. Se o dedo andar
## ou demorar, vira arraste normal da nave e nada troca (evita trocas sem querer).
## Com o corpo destruído (forced), é preciso escolher um corpo vivo para continuar.
## Fica numa CanvasLayer própria: coordenadas de tela, acima da moldura da câmera lenta.

signal body_chosen(index: int)

## Corpo destruído: a barra fica nítida e pede a escolha mesmo com o dedo na tela.
var forced: bool = false

var _state: MatchState
var _touch: TouchInput
var _positions := PackedVector2Array()
var _radius: float = 0.0
var _strip := Rect2()
var _strip_style: StyleBoxFlat
var _focus: float = 0.0  # 0 = translúcida (jogando), 1 = nítida (câmera lenta)
var _pressed_slot: int = -1  # corpo sob um toque curto ainda pendente
var _last_usec: int = 0


func setup(state: MatchState, touch: TouchInput) -> void:
	_state = state
	_touch = touch
	touch.tap_filter = _accepts_tap
	touch.tapped.connect(_on_tapped)
	touch.tap_pending_changed.connect(_on_tap_pending_changed)
	_strip_style = StyleBoxFlat.new()
	_strip_style.bg_color = Params.switch_strip_color
	_strip_style.border_color = Color(Params.ui_accent_color, Params.switch_bar_border_alpha)
	_strip_style.set_border_width_all(Params.ui_border_width)
	_strip_style.set_corner_radius_all(Params.ui_corner_radius)
	_last_usec = Time.get_ticks_usec()
	_layout()


## Topo da barra em coordenadas de tela: a nave não desce além disso.
func top() -> float:
	return _strip.position.y


## Nítida e aceitando a troca: dedo solto (câmera lenta) ou corpo destruído.
func is_interactive() -> bool:
	return forced or not _touch.is_touching()


func _process(_delta: float) -> void:
	# Transição em tempo real: não fica lenta junto com a câmera lenta
	var now: int = Time.get_ticks_usec()
	var real_delta: float = (now - _last_usec) / 1_000_000.0
	_last_usec = now
	var target: float = 1.0 if is_interactive() else 0.0
	_focus = move_toward(_focus, target, real_delta / Params.switch_bar_fade_seconds)
	modulate.a = lerpf(Params.switch_bar_idle_alpha, 1.0, _focus)
	_layout()
	queue_redraw()


## Ícones lado a lado, centralizados e sempre na mesma altura da tela.
func _layout() -> void:
	var count: int = _state.bodies.size()
	var rect: Rect2 = get_viewport_rect()
	var spacing: float = minf(Params.switch_strip_spacing, (rect.size.x - Params.switch_strip_side_margin * 2.0) / count)
	_radius = minf(Params.switch_icon_radius, spacing * Params.switch_icon_max_spacing_ratio)
	var y: float = rect.end.y - Params.switch_strip_bottom
	_positions.resize(count)
	for i in count:
		_positions[i] = Vector2(rect.get_center().x + (i - (count - 1) * 0.5) * spacing, y)
	var pad: float = Params.switch_strip_padding + Params.switch_level_ring_offset + Params.switch_level_ring_width
	var left: float = _positions[0].x - _radius - pad
	var right: float = _positions[count - 1].x + _radius + pad
	_strip = Rect2(left, y - _radius - pad, right - left, (_radius + pad) * 2.0)


## Corpo cujo ícone (com folga de toque) contém o ponto; -1 se nenhum.
func slot_at(pos: Vector2) -> int:
	var reach: float = _radius * Params.switch_icon_touch_scale
	for i in _positions.size():
		if pos.distance_to(_positions[i]) <= reach:
			return i
	return -1


## Toques que começam na barra (com folga) podem ser toque curto enquanto ela está nítida.
func _accepts_tap(pos: Vector2) -> bool:
	return is_interactive() and _strip.grow(Params.switch_strip_touch_margin).has_point(pos)


func _on_tap_pending_changed(pos: Vector2, pending: bool) -> void:
	_pressed_slot = slot_at(pos) if pending else -1


func _on_tapped(pos: Vector2) -> void:
	var index: int = slot_at(pos)
	if index < 0 or not _state.is_alive(index) or index == _state.current:
		return
	# Em recarga: recusa (a escolha forçada após perder um corpo ignora a recarga)
	if not forced and not _state.can_switch():
		Audio.play(&"ui_back")
		return
	body_chosen.emit(index)


func _draw() -> void:
	draw_style_box(_strip_style, _strip)
	for i in _positions.size():
		var body: BodyData = _state.bodies[i]
		var center: Vector2 = _positions[i]
		if not _state.is_alive(i):
			_draw_dead(center, _radius, body)
			continue
		var current: bool = i == _state.current and not forced
		var radius: float = _radius * (Params.switch_current_scale if current else 1.0)
		if i == _pressed_slot:
			draw_circle(center, radius * Params.switch_icon_touch_scale, Color(Params.ui_accent_color, 0.25))
		draw_circle(center, radius, Params.switch_icon_bg_color)
		var ring_color: Color = Color.WHITE if current else body.color
		if forced:
			# Pede a escolha: os vivos pulsam
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			ring_color = ring_color.lerp(Color.WHITE, pulse)
		draw_arc(center, radius, 0.0, TAU, 48, ring_color, 7.0 if current else 4.0)
		_draw_level_ring(center, radius + Params.switch_level_ring_offset, i, body)
		_draw_shape(center, radius, body, body.color)
		_draw_hits(center, radius, i)
		if not current and not forced and not _state.can_switch():
			_draw_cooldown(center, radius)
	if forced:
		_draw_choose_hint()


## Recarga da troca: setor escuro que esvazia no sentido horário a partir do topo.
func _draw_cooldown(center: Vector2, radius: float) -> void:
	var ratio: float = _state.switch_cooldown_ratio()
	var start: float = -PI * 0.5 + TAU * (1.0 - ratio)
	var points := PackedVector2Array([center])
	var steps: int = maxi(int(ceil(48.0 * ratio)), 2)
	for k in steps + 1:
		points.append(center + Vector2.from_angle(lerpf(start, -PI * 0.5 + TAU, float(k) / steps)) * radius)
	draw_colored_polygon(points, Params.switch_cooldown_color)


## Hits restantes em bolinhas embaixo do formato da nave (cheias e vazias).
func _draw_hits(center: Vector2, radius: float, index: int) -> void:
	var total: int = _state.max_hits
	var left: int = _state.hits_left[index]
	var step: float = minf(radius * 0.24, radius * 1.3 / maxf(total, 1.0))
	var dot: float = minf(radius * 0.08, step * 0.38)
	for h in total:
		var offset := Vector2((h - (total - 1) * 0.5) * step, radius * 0.74)
		if h < left:
			draw_circle(center + offset, dot, Color.WHITE)
		else:
			draw_arc(center + offset, dot, 0.0, TAU, 12, Color(Color.WHITE, 0.45), 2.0)


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
		points.append(center + Vector2(point.x, point.y - 0.08) * radius * Params.switch_icon_shape_scale)
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


## Corpo destruído: aviso acima da barra pedindo a próxima nave.
func _draw_choose_hint() -> void:
	var font: Font = ThemeDB.fallback_font
	var text: String = tr("SWITCH_CHOOSE")
	var size: int = Params.switch_hint_font_size
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	var pos := Vector2(_strip.get_center().x - width * 0.5, _strip.position.y - Params.switch_hint_gap)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Params.nucleus_outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
