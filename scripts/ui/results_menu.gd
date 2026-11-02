class_name ResultsMenu
extends CanvasLayer
## Tela de resultado (fase concluída ou fim de jogo) com resumo da partida:
## pontos, inimigos destruídos, power-ups, medkits e tempo, mais os próximos passos.

var _overlay: ColorRect


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_overlay = UiFactory.make_overlay()
	_overlay.visible = false
	add_child(_overlay)


func show_stage_clear(state: MatchState, seconds: float, record: bool) -> void:
	var buttons: Array[Button] = []
	if Session.has_next():
		buttons.append(_button("STAGE_NEXT", _on_next_pressed))
	buttons.append(_button("RESULT_STAGE_SELECT", _go.bind(ScenePaths.STAGE_SELECT)))
	buttons.append(_button("PAUSE_EXIT_TO_MENU", _go.bind(ScenePaths.MENU)))
	_open("STAGE_CLEAR_TITLE", state, seconds, record, buttons)


func show_game_over(state: MatchState, seconds: float) -> void:
	var buttons: Array[Button] = [
		_button("GAMEOVER_RETRY", _go.bind(ScenePaths.GAME)),
		_button("RESULT_STAGE_SELECT", _go.bind(ScenePaths.STAGE_SELECT)),
		_button("PAUSE_EXIT_TO_MENU", _go.bind(ScenePaths.MENU)),
	]
	_open("GAMEOVER_TITLE", state, seconds, false, buttons)


func _open(title_key: String, state: MatchState, seconds: float, record: bool, buttons: Array[Button]) -> void:
	var column := UiFactory.make_column()
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

	if record:
		var record_label := UiFactory.make_subtitle("RESULT_NEW_RECORD")
		record_label.add_theme_color_override("font_color", Params.powerup_color)
		column.add_child(record_label)

	for button in buttons:
		column.add_child(button)

	var center := UiFactory.make_centered(UiFactory.make_panel(column))
	_overlay.add_child(center)
	get_tree().paused = true
	_overlay.visible = true
	UiFactory.animate_in(center)


func _add_stat(grid: GridContainer, key: String, value: String) -> void:
	var name_label := UiFactory.make_subtitle(key)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", Params.subtitle_font_size)
	grid.add_child(value_label)


func _button(key: String, action: Callable) -> Button:
	var button := UiFactory.make_button(key)
	button.pressed.connect(action)
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
