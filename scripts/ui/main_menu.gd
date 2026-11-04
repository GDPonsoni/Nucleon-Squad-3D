extends Control
## Menu inicial: escolher a fase, montar o esquadrão, evoluir o núcleo ou configurar.
## Para sair, o botão Voltar do Android.
## Fundo de estrelas, nave animada, selo com o saldo de quarks no topo e o espaço
## do banner de anúncio no rodapé (só nesta tela).


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
	# O conteúdo não cobre o banner do rodapé
	var banner_height: float = AdService.banner_height(get_viewport_rect().size.x)
	center.offset_bottom = -banner_height
	add_child(center)

	var badge := QuarkBadge.new()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -Params.hud_margin.x
	badge.offset_top = Params.pause_button_margin.y
	badge.pressed.connect(func() -> void:
		var popup := AdOfferPopup.open(self)
		popup.quarks_changed.connect(func() -> void: badge.set_amount(SaveGame.quarks, true)))
	add_child(badge)

	var banner: Control = AdService.make_banner_placeholder()
	banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	banner.offset_top = -banner_height
	add_child(banner)
	UiFactory.animate_in(center)

	column.add_child(UiFactory.make_title("GAME_TITLE"))

	var play_button := UiFactory.make_primary_button("MENU_PLAY")
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)

	var squad_button := UiFactory.make_button("MENU_SQUAD")
	squad_button.pressed.connect(SceneTransition.go_to.bind(ScenePaths.SQUAD))
	column.add_child(squad_button)

	var upgrades_button := UiFactory.make_button("MENU_UPGRADES")
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
