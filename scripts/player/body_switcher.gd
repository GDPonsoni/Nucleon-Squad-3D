class_name BodySwitcher
extends Node2D
## Ícones dos outros corpos vivos ao lado da nave durante a câmera lenta.
## Tocar num ícone escolhe o corpo; tocar fora só retoma o jogo.
## Com o corpo destruído (forced), é preciso escolher um ícone para continuar.

signal body_chosen(index: int)

## Corpo destruído: mostra os ícones mesmo com o dedo na tela até escolher.
var forced: bool = false

var _state: MatchState
var _player: Player
var _touch: TouchInput
var _indices: Array[int] = []  # corpo de cada ícone visível
var _positions := PackedVector2Array()


func setup(state: MatchState, player: Player, touch: TouchInput) -> void:
	_state = state
	_player = player
	_touch = touch
	# Conectar antes da nave e da câmera lenta: o toque no ícone é tratado primeiro
	touch.touch_started.connect(_on_touch_started)


func _process(_delta: float) -> void:
	_indices.clear()
	if forced or not _touch.is_touching():
		for i in _state.alive_indices():
			if i != _state.current:
				_indices.append(i)
	visible = not _indices.is_empty()
	if visible:
		_layout()
		queue_redraw()


## Ícones em colunas ao lado da nave (fora do caminho dos tiros, que vão para cima).
## Perto de uma borda, as colunas vão todas para o lado livre.
func _layout() -> void:
	var count: int = _indices.size()
	var radius: float = Params.switch_icon_radius
	# Fora das áreas do HUD (topo e base)
	var bounds: Rect2 = get_viewport_rect().grow_individual(
		-radius, -radius - Params.switch_icons_top_margin, -radius, -radius - Params.switch_icons_bottom_margin)
	var side: float = Params.switch_icon_distance
	var gap: float = Params.switch_icon_spacing
	var columns: Array[float] = [-side, side]
	if _player.position.x - side < bounds.position.x:
		columns = [side, side + gap]
	elif _player.position.x + side > bounds.end.x:
		columns = [-side, -side - gap]

	var per_column: int = ceili(float(count) / columns.size())
	_positions.resize(count)
	for c in columns.size():
		var first: int = c * per_column
		var rows: int = mini(per_column, count - first)
		if rows <= 0:
			break
		# Coluna centrada na altura da nave, deslocada inteira se sair da tela
		var top: float = _player.position.y - (rows - 1) * gap * 0.5
		var bottom: float = top + (rows - 1) * gap
		var shift: float = maxf(bounds.position.y - top, 0.0) + minf(bounds.end.y - bottom, 0.0)
		var x: float = clampf(_player.position.x + columns[c], bounds.position.x, bounds.end.x)
		for row in rows:
			_positions[first + row] = Vector2(x, top + shift + row * gap)


func _on_touch_started(pos: Vector2) -> void:
	if not visible:
		return
	var reach: float = Params.switch_icon_radius * Params.switch_icon_touch_scale
	for k in _indices.size():
		if pos.distance_to(_positions[k]) <= reach:
			body_chosen.emit(_indices[k])
			return


func _draw() -> void:
	var radius: float = Params.switch_icon_radius
	for k in _indices.size():
		var index: int = _indices[k]
		var body: BodyData = _state.bodies[index]
		var center: Vector2 = _positions[k]
		draw_circle(center, radius, Params.switch_icon_bg_color)
		draw_arc(center, radius, 0.0, TAU, 48, body.color, 4.0)
		_draw_level_ring(center, radius + Params.switch_level_ring_offset, index, body)
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(center + point * radius * Params.switch_icon_shape_scale)
		draw_colored_polygon(points, body.color)
		# Hits restantes do corpo
		var hits: int = _state.hits_left[index]
		for h in hits:
			var offset := Vector2((h - (hits - 1) * 0.5) * radius * 0.22, radius * 0.75)
			draw_circle(center + offset, radius * 0.07, Color.WHITE)


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
