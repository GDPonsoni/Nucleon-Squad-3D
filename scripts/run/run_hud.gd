class_name RunHud
extends CanvasLayer
## HUD extra do modo roguelike: barra de XP com o nível à esquerda e o tempo de partida à direita.

var progress: RunProgress
var clock: Callable  # devolve os segundos de partida
var _canvas: Control
var _level_label: Label
var _time_label: Label


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFactory.apply_theme(_canvas)
	_canvas.draw.connect(_draw_bar)
	add_child(_canvas)
	_level_label = _label(HORIZONTAL_ALIGNMENT_LEFT)
	_level_label.add_theme_color_override("font_color", Params.run_xp_color)
	_time_label = _label(HORIZONTAL_ALIGNMENT_RIGHT)


func _label(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", Params.run_hud_font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(label)
	return label


func _process(_delta: float) -> void:
	if progress == null:
		return
	var width: float = _canvas.size.x - Params.hud_margin.x * 2.0
	var y: float = Params.run_xp_bar_top + Params.run_xp_bar_height + 6.0
	_level_label.text = tr("RUN_LEVEL") % progress.level
	_level_label.position = Vector2(Params.hud_margin.x, y)
	_level_label.size.x = width
	var seconds: int = int(clock.call()) if clock.is_valid() else 0
	_time_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_time_label.position = Vector2(Params.hud_margin.x, y)
	_time_label.size.x = width
	_canvas.queue_redraw()


func _draw_bar() -> void:
	if progress == null:
		return
	var rect := Rect2(Params.hud_margin.x, Params.run_xp_bar_top, _canvas.size.x - Params.hud_margin.x * 2.0, Params.run_xp_bar_height)
	_canvas.draw_rect(rect, Params.hud_panel_color)
	var ratio: float = clampf(progress.xp / maxf(progress.xp_needed(), 0.001), 0.0, 1.0)
	_canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), Params.run_xp_color)
