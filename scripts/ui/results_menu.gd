class_name ResultsMenu
extends CanvasLayer
## Tela de resultado (fase concluída ou fim de jogo) com resumo da partida:
## pontos, inimigos destruídos, power-ups, medkits, tempo e quarks ganhos, mais as
## recompensas de capítulo (naves, espaço auxiliar) e os próximos passos.
## summary: {"quarks_kills": int, "quarks_bonus": int, "rewards": PackedStringArray}

var _dialog: Dialog


var title_text: String = ""  # vazio = fase atual da campanha
var restart_path: String = ScenePaths.GAME
var back_path: String = ScenePaths.STAGE_SELECT  # Voltar do Android e botão do mapa


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60


func show_stage_clear(state: MatchState, seconds: float, record: bool, summary: Dictionary) -> void:
	var main: IconButton
	if Session.has_next():
		main = _icon(IconButton.Icon.PLAY, Params.results_main_size, "RESULT_CAPTION_NEXT", _on_next_pressed, true)
	else:
		main = _icon(IconButton.Icon.RESTART, Params.results_main_size, "PAUSE_CAPTION_RESTART", _go.bind(restart_path), true)
	_open("STAGE_CLEAR_TITLE", state, seconds, record, summary, main)


func show_game_over(state: MatchState, seconds: float, summary: Dictionary, title_key: String = "GAMEOVER_TITLE") -> void:
	var main := _icon(IconButton.Icon.RESTART, Params.results_main_size, "PAUSE_CAPTION_RESTART", _go.bind(restart_path), true)
	_open(title_key, state, seconds, false, summary, main)


func _open(title_key: String, state: MatchState, seconds: float, record: bool, summary: Dictionary, main: IconButton) -> void:
	get_tree().paused = true
	# Sem X: o resultado já foi salvo, e o Voltar do Android leva ao seletor de fases
	_dialog = Dialog.open(self, title_key, false, layer)
	_dialog.back_handler = _go.bind(back_path)
	var column: VBoxContainer = _dialog.body
	column.add_theme_constant_override("separation", Params.results_spacing)
	var stage_name := UiFactory.make_subtitle("")
	stage_name.text = title_text if not title_text.is_empty() else "%s  %s" % [tr(Session.planet().name_key), Session.stage_label(Session.planet_index, Session.stage_index)]
	column.add_child(stage_name)
	if summary.has("stars"):
		var stars_row := HBoxContainer.new()
		stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_row.add_child(StarRow.new().setup(int(summary["stars"]), Params.stage_sheet_star_size))
		column.add_child(stars_row)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", Params.results_column_gap)
	column.add_child(stats)
	_add_stat(stats, "RESULT_SCORE", str(state.score))
	_add_stat(stats, "RESULT_KILLS", str(state.kills))
	if summary.has("level"):
		_add_stat(stats, "RESULT_LEVEL", str(summary["level"]))
	else:
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

	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_child(main)
	column.add_child(main_row)
	var row := HBoxContainer.new()
	if back_path == ScenePaths.STAGE_SELECT:
		row.add_child(_icon(IconButton.Icon.MAP, Params.results_action_size, "RESULT_CAPTION_STAGES", _go.bind(ScenePaths.STAGE_SELECT)))
		row.add_child(_expander())
	row.add_child(_icon(IconButton.Icon.UPGRADE, Params.results_action_size, "RESULT_CAPTION_UPGRADE", func() -> void:
		Session.upgrades_return_path = back_path
		_go(ScenePaths.UPGRADES)))
	row.add_child(_expander())
	row.add_child(_icon(IconButton.Icon.HOME, Params.results_action_size, "PAUSE_CAPTION_EXIT", _go.bind(ScenePaths.MENU)))
	column.add_child(row)


func _add_stat(grid: GridContainer, key: String, value: String, color: Color = Params.ui_text_color) -> void:
	var name_label := UiFactory.make_subtitle(key)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", Params.results_stats_font_size)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", Params.results_stats_font_size)
	value_label.add_theme_color_override("font_color", color)
	grid.add_child(value_label)


func _icon(kind: IconButton.Icon, diameter: float, caption_key: String, action: Callable, primary: bool = false) -> IconButton:
	var button := IconButton.new().setup(kind, diameter, tr(caption_key))
	button.primary = primary
	button.pressed.connect(action)
	return button


func _expander() -> Control:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return space


func _on_next_pressed() -> void:
	Session.select_next()
	_go(ScenePaths.GAME)


func _go(path: String) -> void:
	SceneTransition.go_to(path)
