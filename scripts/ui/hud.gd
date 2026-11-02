class_name Hud
extends CanvasLayer
## HUD da partida.
## Topo: progresso da fase, pontuação e nome da fase.
## Base esquerda: nível da arma e hits do corpo ativo. Base direita: formação.
## Flash vermelho na tela ao levar hit.

var _state: MatchState
var _spawner: EnemySpawner
var _canvas: Control
var _score_label: Label
var _stage_label: Label
var _flash: ColorRect
var _panel_style: StyleBoxFlat


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFactory.apply_theme(_canvas)
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)

	_score_label = Label.new()
	_score_label.position = Params.hud_score_position
	_score_label.add_theme_font_size_override("font_size", Params.hud_score_font_size)
	_score_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_canvas.add_child(_score_label)

	_stage_label = UiFactory.make_subtitle("")
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stage_label.position = Params.hud_score_position + Vector2(0.0, Params.hud_score_font_size * 1.25)
	_stage_label.add_theme_font_size_override("font_size", Params.hud_stage_font_size)
	_stage_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_canvas.add_child(_stage_label)

	_flash = ColorRect.new()
	_flash.color = Color(Params.hud_hit_flash_color, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Params.hud_panel_color
	_panel_style.set_corner_radius_all(Params.ui_corner_radius)


func setup(state: MatchState, spawner: EnemySpawner, stage_text: String) -> void:
	_state = state
	_spawner = spawner
	_stage_label.text = stage_text
	state.score_changed.connect(_on_score_changed)
	_on_score_changed(state.score)


## Flash vermelho rápido (em tempo real, mesmo na câmera lenta).
func flash_hit() -> void:
	_flash.color.a = Params.hud_hit_flash_alpha
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_flash, "color:a", 0.0, Params.hud_hit_flash_seconds)


func _process(_delta: float) -> void:
	# Progresso muda a cada frame; o resto é barato de redesenhar junto
	_canvas.queue_redraw()


func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)


func _draw_hud() -> void:
	if _state == null:
		return
	_draw_progress()
	var bottom: float = _canvas.size.y - Params.hud_margin.y
	_draw_hits_and_level(bottom)
	_draw_formation(bottom)


## Barra fina no topo, entre a margem e o botão de pausa.
func _draw_progress() -> void:
	var left: float = Params.hud_margin.x
	var right: float = _canvas.size.x - Params.hud_margin.x
	var rect := Rect2(left, Params.hud_progress_y, right - left, Params.hud_progress_height)
	var radius: float = Params.hud_progress_height * 0.5
	_draw_round_rect(rect, Params.hud_panel_color, radius)
	var filled := Rect2(rect.position, Vector2(rect.size.x * _spawner.progress(), rect.size.y))
	if filled.size.x > 0.0:
		_draw_round_rect(filled, Params.ui_accent_color, radius)


## Losangos do nível da arma em cima e quadrados dos hits embaixo, sobre um painel.
func _draw_hits_and_level(bottom: float) -> void:
	var body: BodyData = _state.current_body()
	var hits: int = _state.hits_left[_state.current]
	var level: int = _state.weapon_levels[_state.current]
	var pip: Vector2 = Params.hud_pip_size
	var diamond: float = Params.hud_level_size
	var left: float = Params.hud_margin.x
	var width: float = maxf(Params.body_max_hits * (pip.x + Params.hud_gap), body.weapon.max_level() * (diamond + Params.hud_level_gap))
	var top: float = bottom - pip.y - Params.hud_gap - diamond
	var pad: float = Params.hud_panel_padding
	_canvas.draw_style_box(_panel_style, Rect2(left - pad, top - pad, width + pad * 2.0, bottom - top + pad * 2.0))

	for i in body.weapon.max_level():
		var center := Vector2(left + diamond * 0.5 + i * (diamond + Params.hud_level_gap), top + diamond * 0.5)
		var half: float = diamond * 0.5
		var points := PackedVector2Array([
			center + Vector2(0.0, -half), center + Vector2(half, 0.0),
			center + Vector2(0.0, half), center + Vector2(-half, 0.0),
		])
		if i < level:
			_canvas.draw_colored_polygon(points, Params.powerup_color)
		else:
			points.append(points[0])
			_canvas.draw_polyline(points, Params.hud_dead_color, 2.0)

	var color: Color = body.color if hits > 0 else Params.hud_dead_color
	for i in Params.body_max_hits:
		var rect := Rect2(Vector2(left + i * (pip.x + Params.hud_gap), bottom - pip.y), pip)
		if i < hits:
			_draw_round_rect(rect, color, Params.hud_pip_radius)
		else:
			_canvas.draw_rect(rect, color, false, 3.0)


func _draw_formation(bottom: float) -> void:
	var radius: float = Params.hud_icon_radius
	var count: int = _state.bodies.size()
	var right: float = _canvas.size.x - Params.hud_margin.x
	var width: float = count * radius * 2.0 + (count - 1) * Params.hud_gap
	var pad: float = Params.hud_panel_padding
	_canvas.draw_style_box(_panel_style, Rect2(right - width - pad, bottom - radius * 2.0 - pad, width + pad * 2.0, radius * 2.0 + pad * 2.0))
	for i in count:
		var center := Vector2(right - radius - (count - 1 - i) * (radius * 2.0 + Params.hud_gap), bottom - radius)
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


func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	_canvas.draw_style_box(box, rect)
