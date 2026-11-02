extends Control
## Menu inicial: escolher a fase ou sair do jogo. Fundo de estrelas e nave animada.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())

	var rect: Rect2 = get_viewport_rect()
	var ship := MenuShip.new()
	ship.position = Vector2(rect.get_center().x, rect.position.y + rect.size.y * Params.menu_ship_y_ratio)
	add_child(ship)

	var column := UiFactory.make_column()
	var center := UiFactory.make_centered(column)
	add_child(center)
	UiFactory.animate_in(center)

	column.add_child(UiFactory.make_title("GAME_TITLE"))

	var play_button := UiFactory.make_button("MENU_PLAY")
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)

	var quit_button := UiFactory.make_button("MENU_QUIT")
	quit_button.pressed.connect(_on_quit_pressed)
	column.add_child(quit_button)


func _notification(what: int) -> void:
	# Botão Voltar do Android no menu fecha o jogo
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _on_play_pressed() -> void:
	SceneTransition.go_to(ScenePaths.STAGE_SELECT)


func _on_quit_pressed() -> void:
	get_tree().quit()
