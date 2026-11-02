class_name PauseMenu
extends CanvasLayer
## Botão de pausa sempre visível e menu de pausa (continuar / voltar ao menu).

var _pause_button: Button
var _overlay: ColorRect
var _enabled: bool = true


func _ready() -> void:
	# Continua recebendo toques com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS

	_pause_button = Button.new()
	_pause_button.focus_mode = Control.FOCUS_NONE
	UiFactory.apply_theme(_pause_button)
	_pause_button.draw.connect(_draw_pause_icon)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -Params.pause_button_margin.x - Params.pause_button_size.x
	_pause_button.offset_right = -Params.pause_button_margin.x
	_pause_button.offset_top = Params.pause_button_margin.y
	_pause_button.offset_bottom = Params.pause_button_margin.y + Params.pause_button_size.y
	_pause_button.pressed.connect(open)
	add_child(_pause_button)

	_overlay = UiFactory.make_overlay()
	_overlay.visible = false
	add_child(_overlay)

	var column := UiFactory.make_column()
	_overlay.add_child(UiFactory.make_centered(UiFactory.make_panel(column)))
	column.add_child(UiFactory.make_title("PAUSE_TITLE"))

	var resume_button := UiFactory.make_button("PAUSE_RESUME")
	resume_button.pressed.connect(close)
	column.add_child(resume_button)

	var exit_button := UiFactory.make_button("PAUSE_EXIT_TO_MENU")
	exit_button.pressed.connect(_exit_to_menu)
	column.add_child(exit_button)


## Duas barras verticais desenhadas sobre o botão.
func _draw_pause_icon() -> void:
	var size: Vector2 = _pause_button.size
	var bar := Vector2(size.x * 0.13, size.y * 0.42)
	var gap: float = size.x * 0.12
	var top: float = (size.y - bar.y) * 0.5
	for x in [size.x * 0.5 - gap * 0.5 - bar.x, size.x * 0.5 + gap * 0.5]:
		_pause_button.draw_rect(Rect2(Vector2(x, top), bar), Params.ui_text_color)


func open() -> void:
	get_tree().paused = true
	_overlay.visible = true
	_pause_button.visible = false


func close() -> void:
	get_tree().paused = false
	_overlay.visible = false
	_pause_button.visible = true


## Desliga a pausa (ex.: no fim de jogo).
func disable() -> void:
	_enabled = false
	_pause_button.visible = false


func toggle() -> void:
	if not _enabled:
		return
	if _overlay.visible:
		close()
	else:
		open()


func _notification(what: int) -> void:
	# Botão Voltar do Android abre/fecha a pausa
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func _exit_to_menu() -> void:
	# A pausa persiste entre cenas: despausar antes de trocar
	get_tree().paused = false
	get_tree().change_scene_to_file(ScenePaths.MENU)
