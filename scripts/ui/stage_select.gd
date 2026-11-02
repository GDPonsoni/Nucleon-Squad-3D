extends Control
## Seletor de fases por planeta. Fases travadas aparecem desativadas com cadeado.
## Em build de debug, tocar várias vezes no título libera todas as fases.

var _content: VBoxContainer
var _title_taps: int = 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	_build()


func _build() -> void:
	if _content != null:
		_content.get_parent().queue_free()
	_content = UiFactory.make_column()
	add_child(UiFactory.make_centered(_content))

	var title := UiFactory.make_title("STAGE_SELECT_TITLE")
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_on_title_input)
	_content.add_child(title)

	var campaign: CampaignData = Session.campaign
	for p in campaign.planets.size():
		_content.add_child(_planet_panel(p, campaign.planets[p]))

	var back_button := UiFactory.make_button("MENU_BACK")
	back_button.pressed.connect(_go_back)
	_content.add_child(back_button)


func _planet_panel(planet_index: int, planet: PlanetData) -> PanelContainer:
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.stage_select_spacing)
	var name_label := UiFactory.make_subtitle(planet.name_key)
	name_label.add_theme_color_override("font_color", planet.star_color)
	column.add_child(name_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Params.stage_select_spacing)
	column.add_child(row)
	for s in planet.stages.size():
		row.add_child(_stage_button(planet_index, s, planet.stages[s]))

	var panel := UiFactory.make_panel(column)
	# Borda na cor do planeta
	var style := (UiTheme.get_theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.border_color = Color(planet.star_color, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _stage_button(planet_index: int, stage_index: int, stage: StageData) -> Button:
	var unlocked: bool = SaveGame.is_unlocked(Session.campaign.linear_index(planet_index, stage_index))
	var button := UiFactory.make_button("")
	button.custom_minimum_size = Params.stage_button_size
	button.disabled = not unlocked

	# Número da fase grande e recorde menor embaixo
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var number := Label.new()
	number.text = Session.stage_label(planet_index, stage_index)
	number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var best: int = SaveGame.best_score(stage.id)
	if unlocked and best > 0:
		var record := UiFactory.make_subtitle("")
		record.text = tr("STAGE_BEST") % best
		record.add_theme_font_size_override("font_size", Params.stage_record_font_size)
		column.add_child(record)
	if not unlocked:
		number.add_theme_color_override("font_color", Params.ui_muted_text_color.darkened(0.3))
	if unlocked:
		button.pressed.connect(_on_stage_pressed.bind(planet_index, stage_index))
	else:
		button.draw.connect(_draw_lock.bind(button))
	return button


## Cadeado simples no canto do botão travado.
func _draw_lock(button: Button) -> void:
	var size: float = Params.stage_lock_size
	var origin := Vector2(button.size.x - size * 1.4, size * 0.6)
	var color: Color = Params.ui_muted_text_color
	button.draw_arc(origin + Vector2(size * 0.5, size * 0.45), size * 0.3, PI, TAU, 16, color, 4.0)
	button.draw_rect(Rect2(origin + Vector2(0.0, size * 0.45), Vector2(size, size * 0.65)), color)


func _on_stage_pressed(planet_index: int, stage_index: int) -> void:
	Session.select(planet_index, stage_index)
	SceneTransition.go_to(ScenePaths.GAME)


func _on_title_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventScreenTouch and event.pressed):
		return
	_title_taps += 1
	if _title_taps == Params.debug_unlock_taps:
		SaveGame.unlock_all()
		_build()


func _go_back() -> void:
	SceneTransition.go_to(ScenePaths.MENU)


func _notification(what: int) -> void:
	# Botão Voltar do Android volta ao menu inicial
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
