extends Control
## Menu inicial: escolher a fase, montar o esquadrão, evoluir o núcleo ou configurar.
## Para sair, o botão Voltar do Android.
## Fundo de estrelas, nave animada e saldo de quarks.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
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

	var play_button := UiFactory.make_primary_button("MENU_PLAY")
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)

	var squad_button := UiFactory.make_button("MENU_SQUAD")
	squad_button.pressed.connect(SceneTransition.go_to.bind(ScenePaths.SQUAD))
	column.add_child(squad_button)

	var upgrades_button := UiFactory.make_button("")
	upgrades_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	upgrades_button.text = tr("MENU_UPGRADES") % SaveGame.quarks
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	column.add_child(upgrades_button)

	var settings_button := UiFactory.make_button("MENU_SETTINGS")
	settings_button.pressed.connect(SceneTransition.go_to.bind(ScenePaths.SETTINGS))
	column.add_child(settings_button)


func _notification(what: int) -> void:
	# Botão Voltar do Android no menu fecha o jogo
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _on_play_pressed() -> void:
	SceneTransition.go_to(ScenePaths.STAGE_SELECT)


func _on_upgrades_pressed() -> void:
	Session.upgrades_return_path = ScenePaths.MENU
	SceneTransition.go_to(ScenePaths.UPGRADES)
