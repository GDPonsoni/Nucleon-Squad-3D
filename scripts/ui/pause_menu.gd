class_name PauseMenu
extends CanvasLayer
## Botão de pausa sempre visível e menu de pausa: continuar (grande), reiniciar, ajustes e sair, em ícones.
## O menu é um Dialog: o X e o Voltar do Android continuam a partida.

var _pause_button: Button
var _dialog: Dialog
var _settings_dialog: Dialog
var _enabled: bool = true


var title_text: String = ""  # vazio = fase atual da campanha
var restart_path: String = ScenePaths.GAME
var extra_content: Callable = Callable()  # monta um Control a mais (ex.: armas do modo roguelike)


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
	# A fase atual vai no título; continuar grande no meio, ações menores nos cantos de baixo
	var stage_label: String = title_text if not title_text.is_empty() else Session.stage_label(Session.planet_index, Session.stage_index)
	_dialog = Dialog.open(self, stage_label, true, layer)
	_dialog.closed.connect(_on_dialog_closed)
	var body: VBoxContainer = _dialog.body
	body.add_theme_constant_override("separation", Params.pause_spacing)
	if extra_content.is_valid():
		body.add_child(extra_content.call())
	body.add_child(_centered(_icon(IconButton.Icon.PLAY, Params.pause_resume_size, tr("PAUSE_CAPTION_RESUME"), _dialog.close, true)))
	var row := HBoxContainer.new()
	row.add_child(_icon(IconButton.Icon.RESTART, Params.pause_action_size, tr("PAUSE_CAPTION_RESTART"), _restart_stage))
	row.add_child(_expander())
	row.add_child(_icon(IconButton.Icon.GEAR, Params.pause_action_size, tr("PAUSE_CAPTION_SETTINGS"), _open_settings))
	row.add_child(_expander())
	row.add_child(_icon(IconButton.Icon.HOME, Params.pause_action_size, tr("PAUSE_CAPTION_EXIT"), _exit_to_menu))
	body.add_child(row)


func _expander() -> Control:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return space


func _icon(kind: IconButton.Icon, diameter: float, caption: String, action: Callable, primary: bool = false) -> IconButton:
	var button := IconButton.new().setup(kind, diameter, caption)
	button.primary = primary
	button.pressed.connect(action)
	return button


func _centered(child: Control) -> Control:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(child)
	return box


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
	SceneTransition.go_to(restart_path)


func _exit_to_menu() -> void:
	SceneTransition.go_to(ScenePaths.MENU)
