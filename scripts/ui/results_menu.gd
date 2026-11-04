class_name ResultsMenu
extends CanvasLayer
## Tela de resultado (fase concluída ou fim de jogo) com resumo da partida:
## pontos, inimigos destruídos, power-ups, medkits, tempo e quarks ganhos, mais as
## recompensas de capítulo (naves, espaço auxiliar) e os próximos passos.
## summary: {"quarks_kills": int, "quarks_bonus": int, "rewards": PackedStringArray}

var _overlay: ColorRect


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_overlay = UiFactory.make_overlay()
	_overlay.visible = false
	add_child(_overlay)


func show_stage_clear(state: MatchState, seconds: float, record: bool, summary: Dictionary) -> void:
	var buttons: Array[Button] = []
	if Session.has_next():
		var next := _button("STAGE_NEXT", _on_next_pressed)
		next.theme_type_variation = &"PrimaryButton"
		buttons.append(next)
	buttons.append(_upgrades_button())
	buttons.append(_button("RESULT_STAGE_SELECT", _go.bind(ScenePaths.STAGE_SELECT)))
	buttons.append(_button("PAUSE_EXIT_TO_MENU", _go.bind(ScenePaths.MENU)))
	_open("STAGE_CLEAR_TITLE", state, seconds, record, summary, buttons)


func show_game_over(state: MatchState, seconds: float, summary: Dictionary) -> void:
	var buttons: Array[Button] = [
		_button("GAMEOVER_RETRY", _go.bind(ScenePaths.GAME)),
		_upgrades_button(),
		_button("RESULT_STAGE_SELECT", _go.bind(ScenePaths.STAGE_SELECT)),
		_button("PAUSE_EXIT_TO_MENU", _go.bind(ScenePaths.MENU)),
	]
	_open("GAMEOVER_TITLE", state, seconds, false, summary, buttons)


func _open(title_key: String, state: MatchState, seconds: float, record: bool, summary: Dictionary, buttons: Array[Button]) -> void:
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.results_spacing)
	column.add_child(UiFactory.make_title(title_key))
	var stage_name := UiFactory.make_subtitle("")
	stage_name.text = "%s  %s" % [tr(Session.planet().name_key), Session.stage_label(Session.planet_index, Session.stage_index)]
	column.add_child(stage_name)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", Params.results_column_gap)
	column.add_child(stats)
	_add_stat(stats, "RESULT_SCORE", str(state.score))
	_add_stat(stats, "RESULT_KILLS", str(state.kills))
	_add_stat(stats, "RESULT_POWERUPS", str(state.powerups_collected))
	_add_stat(stats, "RESULT_MEDKITS", str(state.medkits_collected))
	_add_stat(stats, "RESULT_TIME", "%d:%02d" % [int(seconds) / 60, int(seconds) % 60])
	var kills_quarks: int = int(summary.get("quarks_kills", 0))
	var bonus: int = int(summary.get("quarks_bonus", 0))
	_add_stat(stats, "RESULT_QUARKS", "+%d" % (kills_quarks + bonus), Params.quark_color)
	if bonus > 0:
		var detail := UiFactory.make_subtitle("")
		detail.text = tr("RESULT_QUARKS_DETAIL") % [kills_quarks, bonus]
		detail.add_theme_font_size_override("font_size", Params.results_detail_font_size)
		column.add_child(detail)

	if record:
		var record_label := UiFactory.make_subtitle("RESULT_NEW_RECORD")
		record_label.add_theme_color_override("font_color", Params.powerup_color)
		column.add_child(record_label)

	var rewards: PackedStringArray = summary.get("rewards", PackedStringArray())
	if not rewards.is_empty():
		var chapter := UiFactory.make_subtitle("RESULT_CHAPTER_CLEAR")
		chapter.add_theme_color_override("font_color", Params.powerup_color)
		column.add_child(chapter)
		for text in rewards:
			var reward := Label.new()
			reward.text = text
			reward.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reward.add_theme_font_size_override("font_size", Params.subtitle_font_size)
			column.add_child(reward)

	for button in buttons:
		button.custom_minimum_size.y = Params.results_button_height
		column.add_child(button)

	var center := UiFactory.make_centered(UiFactory.make_panel(column))
	_overlay.add_child(center)
	get_tree().paused = true
	_overlay.visible = true
	UiFactory.animate_in(center)


func _add_stat(grid: GridContainer, key: String, value: String, color: Color = Params.ui_text_color) -> void:
	var name_label := UiFactory.make_subtitle(key)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", Params.subtitle_font_size)
	value_label.add_theme_color_override("font_color", color)
	grid.add_child(value_label)


func _button(key: String, action: Callable) -> Button:
	var button := UiFactory.make_button(key)
	button.pressed.connect(action)
	return button


## Evoluir o núcleo com o saldo de quarks; volta para o seletor de fases.
func _upgrades_button() -> Button:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = tr("RESULT_UPGRADES") % SaveGame.quarks
	button.pressed.connect(func() -> void:
		Session.upgrades_return_path = ScenePaths.STAGE_SELECT
		_go(ScenePaths.UPGRADES))
	return button


func _on_next_pressed() -> void:
	Session.select_next()
	_go(ScenePaths.GAME)


func _go(path: String) -> void:
	SceneTransition.go_to(path)


func _notification(what: int) -> void:
	# Botão Voltar do Android no resultado vai para o seletor de fases
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _overlay.visible:
		_go(ScenePaths.STAGE_SELECT)
