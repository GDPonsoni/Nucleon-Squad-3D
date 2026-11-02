class_name Hud
extends CanvasLayer
## HUD da partida: hits do corpo ativo (canto inferior esquerdo) e
## formação com corpos vivos, destruídos e o ativo (canto inferior direito).

var _state: MatchState
var _canvas: Control


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func setup(state: MatchState) -> void:
	_state = state
	state.body_changed.connect(_refresh.unbind(1))
	state.hits_changed.connect(_refresh.unbind(2))
	state.body_destroyed.connect(_refresh.unbind(1))


func _refresh() -> void:
	_canvas.queue_redraw()


func _draw_hud() -> void:
	if _state == null:
		return
	var bottom: float = _canvas.size.y - Params.hud_margin.y
	_draw_hits(bottom)
	_draw_formation(bottom)


func _draw_hits(bottom: float) -> void:
	var hits: int = _state.hits_left[_state.current]
	var color: Color = _state.current_body().color if hits > 0 else Params.hud_dead_color
	var pip: Vector2 = Params.hud_pip_size
	for i in Params.body_max_hits:
		var rect := Rect2(Vector2(Params.hud_margin.x + i * (pip.x + Params.hud_gap), bottom - pip.y), pip)
		if i < hits:
			_canvas.draw_rect(rect, color)
		else:
			_canvas.draw_rect(rect, color, false, 3.0)


func _draw_formation(bottom: float) -> void:
	var radius: float = Params.hud_icon_radius
	var count: int = _state.bodies.size()
	for i in count:
		var center := Vector2(
			_canvas.size.x - Params.hud_margin.x - radius - (count - 1 - i) * (radius * 2.0 + Params.hud_gap),
			bottom - radius)
		var body: BodyData = _state.bodies[i]
		var alive: bool = _state.is_alive(i)
		var color: Color = body.color if alive else Params.hud_dead_color
		_canvas.draw_circle(center, radius, Params.switch_icon_bg_color)
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(center + point * radius * Params.switch_icon_shape_scale)
		_canvas.draw_colored_polygon(points, color)
		if not alive:
			var d: float = radius * 0.6
			_canvas.draw_line(center + Vector2(-d, -d), center + Vector2(d, d), Params.hud_dead_mark_color, 4.0)
			_canvas.draw_line(center + Vector2(d, -d), center + Vector2(-d, d), Params.hud_dead_mark_color, 4.0)
		elif i == _state.current:
			_canvas.draw_arc(center, radius, 0.0, TAU, 40, Color.WHITE, 4.0)
