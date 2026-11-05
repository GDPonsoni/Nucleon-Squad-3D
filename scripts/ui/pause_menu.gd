class_name PauseMenu
extends CanvasLayer
## Botão de pausa sempre visível e menu de pausa (continuar / recomeçar a fase / voltar ao menu).
## O menu é um Dialog: o X e o Voltar do Android continuam a partida.

var _pause_button: Button
var _dialog: Dialog
var _settings_dialog: Dialog
var _enabled: bool = true


func _ready() -> void:
	# Continua recebendo toques com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50

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
	_pause_button.pressed.connect(Audio.play.bind(&"ui_click"))
	add_child(_pause_button)


## Duas barras verticais desenhadas sobre o botão.
func _draw_pause_icon() -> void:
	var size: Vector2 = _pause_button.size
	var bar := Vector2(size.x * 0.13, size.y * 0.42)
	var gap: float = size.x * 0.12
	var top: float = (size.y - bar.y) * 0.5
	for x in [size.x * 0.5 - gap * 0.5 - bar.x, size.x * 0.5 + gap * 0.5]:
		_pause_button.draw_rect(Rect2(Vector2(x, top), bar), Params.ui_text_color)


func _open_settings() -> void:
	if _dialog == null or _settings_dialog != null:
		return
	_settings_dialog = Dialog.open(self, "", true, layer + 1)
	var panel := SettingsPanel.new()
	_settings_dialog.body.add_child(panel)
	# X / Voltar: da lista de idiomas para as configurações; delas, para a pausa
	_settings_dialog.back_handler = panel.go_back
	panel.back_pressed.connect(_settings_dialog.close)
	_settings_dialog.closed.connect(func() -> void:
		_settings_dialog = null
		if _dialog != null:
			_dialog.visible = true)
	_dialog.visible = false


func open() -> void:
	if _dialog != null:
		return
	get_tree().paused = true
	_pause_button.visible = false
	_dialog = Dialog.open(self, "PAUSE_TITLE", true, layer)
	_dialog.closed.connect(_on_dialog_closed)
	_add_action(_dialog, "PAUSE_RESUME", _dialog.close)
	_add_action(_dialog, "PAUSE_RESTART", _restart_stage)
	_add_action(_dialog, "MENU_SETTINGS", _open_settings)
	_add_action(_dialog, "PAUSE_EXIT_TO_MENU", _exit_to_menu)


func _add_action(dialog: Dialog, key: String, action: Callable) -> void:
	var button := UiFactory.make_button(key)
	button.pressed.connect(action)
	dialog.body.add_child(button)


func close() -> void:
	if _settings_dialog != null:
		_settings_dialog.close()
	if _dialog != null:
		_dialog.close()


func _on_dialog_closed() -> void:
	_dialog = null
	get_tree().paused = false
	_pause_button.visible = _enabled


## Desliga a pausa (ex.: no fim de jogo).
func disable() -> void:
	_enabled = false
	_pause_button.visible = false


## Religa a pausa (ex.: depois de continuar com o anúncio).
func enable() -> void:
	_enabled = true
	_pause_button.visible = true


func toggle() -> void:
	if not _enabled:
		return
	if _dialog != null:
		close()
	else:
		open()


func _notification(what: int) -> void:
	# Botão Voltar do Android abre a pausa; com um diálogo aberto, ele é quem trata o Voltar
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not Dialog.is_open():
		toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Dialog.is_open():
		toggle()
		get_viewport().set_input_as_handled()


## Recomeça a fase atual do zero (a fase escolhida continua em Session).
func _restart_stage() -> void:
	SceneTransition.go_to(ScenePaths.GAME)


func _exit_to_menu() -> void:
	SceneTransition.go_to(ScenePaths.MENU)
