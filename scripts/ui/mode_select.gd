extends Control
## Escolha do modo ao tocar em Jogar: Campanha (mapa dos planetas) e Incursão (modo
## roguelike, travado até concluir o capítulo Params.run_unlock_chapter). Cards grandes.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())
	var column := UiFactory.make_column()
	column.custom_minimum_size.x = get_viewport_rect().size.x - Params.mode_card_side_margin * 2.0
	column.add_theme_constant_override("separation", Params.mode_card_gap)
	column.add_child(UiFactory.make_title("MODE_SELECT_TITLE"))
	var campaign := ModeCard.new()
	campaign.art = ModeCard.Art.CAMPAIGN
	campaign.title_key = "MODE_CAMPAIGN"
	campaign.description = tr("MODE_CAMPAIGN_DESC")
	campaign.pressed.connect(_open_campaign)
	column.add_child(campaign)
	var run := ModeCard.new()
	run.art = ModeCard.Art.RUN
	run.title_key = "RUN_MODE_NAME"
	run.locked = not run_unlocked()
	run.accent = Params.xp_orb_color
	run.description = tr("RUN_LOCKED") % Params.run_unlock_chapter if run.locked else tr("MODE_RUN_DESC")
	run.pressed.connect(_open_run.bind(run.locked))
	column.add_child(run)
	var center := UiFactory.make_centered(column)
	add_child(center)
	UiFactory.animate_in(center)
	UiFactory.add_corner_back(self, _go_back)


static func run_unlocked() -> bool:
	return Params.run_unlock_chapter <= 0 or SaveGame.is_chapter_cleared(Params.run_unlock_chapter - 1)


func _open_campaign() -> void:
	Audio.play(&"ui_confirm")
	SceneTransition.go_to(ScenePaths.STAGE_SELECT)


func _open_run(locked: bool) -> void:
	if locked:
		Audio.play(&"ui_back")
		return
	Audio.play(&"ui_confirm")
	SceneTransition.go_to(ScenePaths.RUN)


func _go_back() -> void:
	SceneTransition.go_to(ScenePaths.MENU)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not Dialog.is_open():
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Dialog.is_open():
		_go_back()
