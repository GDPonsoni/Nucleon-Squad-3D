class_name Hud
extends CanvasLayer
## HUD da partida.
## Topo: progresso da fase, pontuação e nome da fase.
## Base esquerda: nível da arma e hits do corpo ativo. Base direita: formação.
## Flash vermelho na tela ao levar hit. Com chefe: barra de vida dele no topo.
## Botão do especial acima do painel da base esquerda.

signal special_pressed

var _state: MatchState
var _spawner: EnemySpawner
var _canvas: Control
var _score_label: Label
var _stage_label: Label
var _flash: ColorRect
var _panel_style: StyleBoxFlat
var _boss: Boss
var _boss_label: Label
var _warning: Label
var _special: SpecialButton
## Faixa de troca visível: esconde os painéis da base (ela já mostra hits e níveis).
var hide_bottom_panels: bool = false


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

	_boss_label = UiFactory.make_subtitle("")
	_boss_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_boss_label.add_theme_font_size_override("font_size", Params.hud_boss_name_font_size)
	_boss_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_label.offset_top = Params.hud_progress_y + Params.hud_boss_bar_height + 6.0
	_boss_label.visible = false
	_canvas.add_child(_boss_label)

	_warning = UiFactory.make_title("")
	_warning.set_anchors_preset(Control.PRESET_CENTER)
	_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	_warning.add_theme_color_override("font_color", Params.hud_warning_color)
	_warning.add_theme_font_size_override("font_size", Params.hud_score_font_size)
	_warning.visible = false
	_canvas.add_child(_warning)

	# Especial: canto inferior esquerdo, logo acima do painel de nível e hits
	_special = SpecialButton.new()
	_special.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var panel_height: float = Params.hud_pip_size.y + Params.hud_gap + Params.hud_level_size + Params.hud_panel_padding * 2.0
	var bottom: float = Params.hud_margin.y + panel_height + Params.special_button_gap
	_special.offset_left = Params.hud_margin.x - Params.hud_panel_padding
	_special.offset_right = _special.offset_left + Params.special_button_size
	_special.offset_bottom = -bottom
	_special.offset_top = -bottom - Params.special_button_size
	_special.pressed.connect(special_pressed.emit)
	_canvas.add_child(_special)

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


## Mostra a barra de vida do chefe (null esconde).
func set_boss(boss: Boss, boss_name: String) -> void:
	_boss = boss
	_boss_label.text = boss_name
	_boss_label.visible = boss != null


## Aviso piscando no centro da tela.
func show_warning(text_key: String) -> void:
	_warning.text = text_key
	_warning.visible = true
	_warning.modulate.a = 0.0
	var tween := create_tween()
	for i in Params.hud_warning_blinks:
		tween.tween_property(_warning, "modulate:a", 1.0, Params.boss_warning_seconds / Params.hud_warning_blinks * 0.5)
		tween.tween_property(_warning, "modulate:a", 0.15, Params.boss_warning_seconds / Params.hud_warning_blinks * 0.5)
	tween.tween_callback(_warning.hide)


## Flash vermelho rápido (em tempo real, mesmo na câmera lenta).
func flash_hit() -> void:
	_flash.color.a = Params.hud_hit_flash_alpha
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_flash, "color:a", 0.0, Params.hud_hit_flash_seconds)


func _process(_delta: float) -> void:
	# Progresso muda a cada frame; o resto é barato de redesenhar junto
	_canvas.queue_redraw()
	if _state != null:
		var alive: bool = _state.is_alive(_state.current)
		_special.body = _state.current_body() if alive else null
		_special.charge = _state.special_ratio() if alive else 0.0


func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)


func _draw_hud() -> void:
	if _state == null:
		return
	if _boss != null and is_instance_valid(_boss):
		_draw_boss_bar()
	else:
		_draw_progress()
	var bottom: float = _canvas.size.y - Params.hud_margin.y
	if not hide_bottom_panels:
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


## Barra de vida do chefe no lugar do progresso da fase.
func _draw_boss_bar() -> void:
	var left: float = Params.hud_margin.x
	var right: float = _canvas.size.x - Params.hud_margin.x
	var rect := Rect2(left, Params.hud_progress_y, right - left, Params.hud_boss_bar_height)
	var radius: float = Params.hud_boss_bar_height * 0.5
	_draw_round_rect(rect, Params.hud_panel_color, radius)
	var filled := Rect2(rect.position, Vector2(rect.size.x * _boss.health_ratio(), rect.size.y))
	if filled.size.x > 0.0:
		_draw_round_rect(filled, _boss.tint(), radius)


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
