class_name RunHud
extends CanvasLayer
## HUD extra do modo roguelike: tempo de partida embaixo do botão de pausa. A barra de XP é a
## barra fina do topo do Hud e o nível fica embaixo da pontuação (RunGame liga os dois).
## Na câmera lenta voluntária, mostra os espaços de arma (compactos) acima da barra de energia.

var progress: RunProgress
var clock: Callable  # devolve os segundos de partida
var time_controller: TimeController
var _loadout_box: Control
var _loadout_alpha: float = 0.0
var _last_usec: int = 0
var _canvas: Control
var _time_label: Label


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFactory.apply_theme(_canvas)
	add_child(_canvas)
	_time_label = _label(HORIZONTAL_ALIGNMENT_RIGHT)
	_loadout_box = CenterContainer.new()
	_loadout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loadout_box.modulate.a = 0.0
	_canvas.add_child(_loadout_box)
	_last_usec = Time.get_ticks_usec()
	if progress != null:
		progress.loadout_changed.connect(_rebuild_loadout)
		progress.leveled_up.connect(func(_level: int) -> void: _rebuild_loadout())
		_rebuild_loadout()


func _rebuild_loadout() -> void:
	for child in _loadout_box.get_children():
		child.queue_free()
	_loadout_box.add_child(RunLoadoutView.build(progress, true))


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
	var y: float = Params.run_time_top
	var seconds: int = int(clock.call()) if clock.is_valid() else 0
	_time_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_time_label.position = Vector2(Params.hud_margin.x, y)
	_time_label.size.x = width
	# Espaços de arma aparecem suavemente na câmera lenta (tempo real)
	var now: int = Time.get_ticks_usec()
	var real_delta: float = (now - _last_usec) / 1_000_000.0
	_last_usec = now
	var wanted: bool = time_controller != null and time_controller.is_voluntary_slow()
	_loadout_alpha = move_toward(_loadout_alpha, 1.0 if wanted else 0.0, real_delta / Params.run_slow_loadout_fade_seconds)
	_loadout_box.modulate.a = _loadout_alpha
	_loadout_box.size = Vector2(_canvas.size.x, 0.0)
	_loadout_box.position = Vector2(0.0, _canvas.size.y - Params.no_switcher_bottom_margin - Params.run_slow_loadout_bottom)
