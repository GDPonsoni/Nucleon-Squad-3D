extends Control
## Tela de configurações do menu inicial (o painel em si é o SettingsPanel).


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())
	var panel := SettingsPanel.new()
	panel.back_pressed.connect(_go_back)
	var center := UiFactory.make_centered(panel)
	add_child(center)
	UiFactory.animate_in(center)


func _go_back() -> void:
	SceneTransition.go_to(ScenePaths.MENU)


func _notification(what: int) -> void:
	# Botão Voltar do Android volta ao menu
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
