class_name BodySwitcher
extends Node2D
## Ícones dos outros corpos vivos ao redor da nave durante a câmera lenta.
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


## Distribui os ícones num arco acima da nave (abaixo, se ela estiver no topo).
func _layout() -> void:
	var count: int = _indices.size()
	var radius: float = Params.switch_icon_radius
	var bounds: Rect2 = get_viewport_rect().grow(-radius)
	var base_angle: float = -PI * 0.5
	if _player.position.y - Params.switch_icon_distance < bounds.position.y:
		base_angle = PI * 0.5
	var step: float = 0.0 if count == 1 else deg_to_rad(Params.switch_icon_arc_degrees) / (count - 1)
	var start: float = base_angle - step * (count - 1) * 0.5
	_positions.resize(count)
	for k in count:
		var pos: Vector2 = _player.position + Vector2.from_angle(start + step * k) * Params.switch_icon_distance
		_positions[k] = pos.clamp(bounds.position, bounds.end)


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
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(center + point * radius * Params.switch_icon_shape_scale)
		draw_colored_polygon(points, body.color)
		# Hits restantes do corpo
		var hits: int = _state.hits_left[index]
		for h in hits:
			var offset := Vector2((h - (hits - 1) * 0.5) * radius * 0.22, radius * 0.75)
			draw_circle(center + offset, radius * 0.07, Color.WHITE)
