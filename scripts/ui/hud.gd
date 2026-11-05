class_name Hud
extends CanvasLayer
## HUD da partida.
## Topo: progresso da fase (ou vida do chefe), pontuação, nome da fase e quarks ganhos.
## Base: botão do especial logo acima da barra de troca (que mostra hits e níveis).
## Flash vermelho na tela ao levar hit e aviso piscando antes do chefe.

signal special_pressed

var _state: MatchState
var _spawner: EnemySpawner
var _canvas: Control
var _score_label: Label
var _stage_label: Label
var _quarks_label: Label
var _flash: ColorRect
var _boss: Boss
var _boss_label: Label
var _warning: Label
var _toast: Label
var _toast_tween: Tween
var _special: SpecialButton
var _shown_quarks: int = -1


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

	# Quarks ganhos na partida, com o ícone desenhado à esquerda
	_quarks_label = UiFactory.make_subtitle("")
	_quarks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_quarks_label.position = _quarks_icon_center() + Vector2(Params.hud_quark_icon_radius * 1.6, -Params.hud_stage_font_size * 0.72)
	_quarks_label.add_theme_font_size_override("font_size", Params.hud_stage_font_size)
	_quarks_label.add_theme_color_override("font_color", Params.quark_color)
	_quarks_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_canvas.add_child(_quarks_label)

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

	# Aviso curto (ex.: auxiliar subiu de nível), acima do meio da tela
	_toast = UiFactory.make_title("")
	_toast.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", Params.hud_toast_font_size)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.add_theme_color_override("font_outline_color", Params.nucleus_outline_color)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_canvas.add_child(_toast)

	# Especial: canto inferior esquerdo, logo acima da barra de troca (place_special)
	_special = SpecialButton.new()
	_special.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_special.pressed.connect(special_pressed.emit)
	_canvas.add_child(_special)
	place_special(Params.switch_strip_bottom * 2.0)

	_flash = ColorRect.new()
	_flash.color = Color(Params.hud_hit_flash_color, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func setup(state: MatchState, spawner: EnemySpawner, stage_text: String) -> void:
	_state = state
	_spawner = spawner
	_stage_label.text = stage_text
	state.score_changed.connect(_on_score_changed)
	_on_score_changed(state.score)


## Coloca o botão do especial acima de uma faixa reservada na base (a barra de troca).
func place_special(reserved_bottom: float) -> void:
	var bottom: float = reserved_bottom + Params.special_button_gap
	_special.offset_left = Params.hud_margin.x
	_special.offset_right = _special.offset_left + Params.special_button_size
	_special.offset_bottom = -bottom
	_special.offset_top = -bottom - Params.special_button_size


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


## Texto curto que aparece, fica um pouco e some (tempo real, mesmo na câmera lenta).
func show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.offset_left = Params.hud_margin.x
	_toast.offset_right = -Params.hud_margin.x
	_toast.offset_top = get_viewport().get_visible_rect().size.y * Params.hud_toast_y
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween().set_ignore_time_scale(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(Params.hud_toast_seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_toast.hide)


## Flash vermelho rápido (em tempo real, mesmo na câmera lenta).
func flash_hit(color: Color = Params.hud_hit_flash_color) -> void:
	if SaveGame.setting("reduced_effects"):
		return
	_flash.color = Color(color, Params.hud_hit_flash_alpha)
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
		var quarks: int = int(_state.quarks)
		if quarks != _shown_quarks:
			_shown_quarks = quarks
			_quarks_label.text = "+%d" % quarks


func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)


func _quarks_icon_center() -> Vector2:
	var y: float = Params.hud_score_position.y + Params.hud_score_font_size * 1.25 + Params.hud_stage_font_size * 2.3
	return Vector2(Params.hud_score_position.x + Params.hud_quark_icon_radius, y)


func _draw_hud() -> void:
	if _state == null:
		return
	if _boss != null and is_instance_valid(_boss):
		_draw_boss_bar()
	else:
		_draw_progress()
	UiFactory.draw_quark_icon(_canvas, _quarks_icon_center(), Params.hud_quark_icon_radius)


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


func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	_canvas.draw_style_box(box, rect)
