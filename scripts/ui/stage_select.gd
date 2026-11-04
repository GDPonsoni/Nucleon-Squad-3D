extends Control
## Seletor de fases: um capítulo por página, com setas para trocar de capítulo.
## Cada página mostra o nome do capítulo, o progresso, a recompensa por concluí-lo e as
## fases numa grade (chefe intermediário e chefe marcados). Fases travadas aparecem
## desativadas com cadeado; concluídas, com o recorde.
## Deslizar o dedo para o lado também troca de capítulo (com animação e vibração curta).
## Em build de debug, tocar várias vezes no título libera todas as fases.

var _chapter: int = 0
var _page: Control
var _back_corner: Button
var _title_taps: int = 0
var _swipe_start := Vector2.ZERO
var _swipe_usec: int = -1
var _slide_from: int = 0  # direção da animação ao trocar de capítulo


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())
	_chapter = Session.browsed_chapter if Session.browsed_chapter >= 0 else _first_open_chapter()
	_build()
	UiFactory.animate_in(_page)
	_back_corner = UiFactory.add_corner_back(self, _go_back)


## Primeiro capítulo ainda não concluído (ou o último, se todos foram).
func _first_open_chapter() -> int:
	for p in Session.campaign.planets.size():
		if not SaveGame.is_chapter_cleared(p):
			return p
	return Session.campaign.planets.size() - 1


func _build() -> void:
	if _page != null:
		_page.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_page = scroll
	var center := CenterContainer.new()
	center.custom_minimum_size = get_viewport_rect().size
	scroll.add_child(center)
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.stage_select_spacing)
	center.add_child(column)

	var title := UiFactory.make_title("STAGE_SELECT_TITLE")
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_on_title_input)
	column.add_child(title)
	column.add_child(_chapter_header())
	column.add_child(_chapter_dots())
	var art := ChapterArt.new()
	art.chapter = _chapter
	art.planet = Session.campaign.planets[_chapter]
	column.add_child(art)
	column.add_child(_chapter_panel(_chapter, Session.campaign.planets[_chapter]))
	if _back_corner != null:
		_back_corner.move_to_front()


## Setas e nome do capítulo atual.
func _chapter_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Params.stage_select_spacing)
	var previous := _arrow_button(-1)
	row.add_child(previous)
	var planet: PlanetData = Session.campaign.planets[_chapter]
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.custom_minimum_size.x = Params.stage_chapter_name_width
	row.add_child(names)
	var number := UiFactory.make_subtitle("")
	number.text = (tr("STAGE_CHAPTER") % (_chapter + 1)).to_upper()
	number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	names.add_child(number)
	var name_label := Label.new()
	name_label.text = tr(planet.name_key)
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", planet.star_color)
	name_label.add_theme_font_size_override("font_size", UiFactory.fit_font_size(name_label.text,
		Params.stage_chapter_name_width, Params.stage_chapter_font_size))
	names.add_child(name_label)
	row.add_child(_arrow_button(1))
	return row


func _arrow_button(step: int) -> Button:
	var button := UiFactory.make_button("")
	button.custom_minimum_size = Vector2.ONE * Params.stage_arrow_size
	var target: int = _chapter + step
	button.disabled = target < 0 or target >= Session.campaign.planets.size()
	button.pressed.connect(_show_chapter.bind(target))
	button.draw.connect(_draw_arrow.bind(button, step))
	return button


func _draw_arrow(button: Button, step: int) -> void:
	var c: Vector2 = button.size * 0.5
	var s: float = button.size.x * 0.18
	var color: Color = Params.ui_muted_text_color if button.disabled else Params.ui_text_color
	button.draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * step, 0.0), c + Vector2(-s * step * 0.7, -s), c + Vector2(-s * step * 0.7, s),
	]), color)


## Bolinhas: uma por capítulo, cheias nos concluídos e destacada na página atual.
func _chapter_dots() -> Control:
	var dots := Control.new()
	var count: int = Session.campaign.planets.size()
	dots.custom_minimum_size = Vector2(count * Params.stage_dot_spacing, Params.stage_dot_spacing * 0.6)
	dots.draw.connect(func() -> void:
		for p in count:
			var center := Vector2((p + 0.5) * Params.stage_dot_spacing, dots.size.y * 0.5)
			var color: Color = Session.campaign.planets[p].star_color
			if p == _chapter:
				dots.draw_circle(center, Params.stage_dot_radius * 1.5, color)
			elif SaveGame.is_chapter_cleared(p):
				dots.draw_circle(center, Params.stage_dot_radius, Color(color, 0.8))
			else:
				dots.draw_arc(center, Params.stage_dot_radius, 0.0, TAU, 16, Color(color, 0.6), 3.0))
	return dots


func _show_chapter(chapter: int) -> void:
	if chapter < 0 or chapter >= Session.campaign.planets.size():
		return
	if chapter == _chapter:
		return
	_slide_from = 1 if chapter > _chapter else -1
	_chapter = chapter
	Session.browsed_chapter = chapter
	_build()
	Audio.vibrate(Params.haptic_tick_ms)
	# Entra deslizando do lado para onde o dedo foi
	_page.modulate.a = 0.0
	_page.position.x = _slide_from * Params.stage_slide_offset
	var tween := _page.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_page, "position:x", 0.0, Params.stage_slide_seconds)
	tween.tween_property(_page, "modulate:a", 1.0, Params.stage_slide_seconds)


func _chapter_panel(planet_index: int, planet: PlanetData) -> PanelContainer:
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.stage_select_spacing)

	var done: int = 0
	for stage in planet.stages:
		if SaveGame.is_completed(stage.id):
			done += 1
	var progress := UiFactory.make_subtitle("")
	progress.text = tr("STAGE_PROGRESS") % [done, planet.stages.size()]
	column.add_child(progress)

	var reward: String = _reward_text(planet_index)
	if not reward.is_empty():
		var reward_label := UiFactory.make_subtitle("")
		var cleared: bool = SaveGame.is_chapter_cleared(planet_index)
		reward_label.text = (tr("STAGE_REWARD_DONE") if cleared else tr("STAGE_REWARD")) % reward
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reward_label.custom_minimum_size.x = Params.stage_row_max_width
		reward_label.add_theme_color_override("font_color", Params.powerup_color if not cleared else Params.ui_muted_text_color)
		column.add_child(reward_label)

	var grid := GridContainer.new()
	grid.columns = Params.stage_grid_columns
	grid.add_theme_constant_override("h_separation", Params.stage_select_spacing)
	grid.add_theme_constant_override("v_separation", Params.stage_select_spacing)
	column.add_child(grid)
	for s in planet.stages.size():
		grid.add_child(_stage_button(planet_index, s, planet))

	var panel := UiFactory.make_panel(column)
	# Borda na cor do planeta
	var style := (UiTheme.get_theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.border_color = Color(planet.star_color, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## O que concluir o capítulo libera (naves e o espaço da nave auxiliar).
func _reward_text(planet_index: int) -> String:
	var chapter: int = planet_index + 1
	var names := PackedStringArray()
	if Params.companion_unlock_chapter == chapter:
		names.append(tr("STAGE_REWARD_COMPANION"))
	for body in (load(Params.roster_path) as FormationData).bodies:
		if body.unlock_chapter == chapter:
			names.append(tr(body.name_key))
	return ", ".join(names)


func _stage_button(planet_index: int, stage_index: int, planet: PlanetData) -> Button:
	var stage: StageData = planet.stages[stage_index]
	var unlocked: bool = SaveGame.is_unlocked(planet_index, stage_index)
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
	var boss_mark: int = 0
	if stage.boss != null:
		boss_mark = 2 if stage_index == planet.stages.size() - 1 else 1
	button.draw.connect(_draw_marks.bind(button, unlocked, SaveGame.is_completed(stage.id), boss_mark))
	return button


## Cadeado (travada), visto (concluída) e marca de chefe (1 = intermediário, 2 = do capítulo).
func _draw_marks(button: Button, unlocked: bool, completed: bool, boss_mark: int) -> void:
	var size: float = Params.stage_lock_size
	if not unlocked:
		var origin := Vector2(button.size.x - size * 1.4, size * 0.6)
		var color: Color = Params.ui_muted_text_color
		button.draw_arc(origin + Vector2(size * 0.5, size * 0.45), size * 0.3, PI, TAU, 16, color, 4.0)
		button.draw_rect(Rect2(origin + Vector2(0.0, size * 0.45), Vector2(size, size * 0.65)), color)
	elif completed:
		var o := Vector2(button.size.x - size * 1.3, size * 0.9)
		button.draw_polyline(PackedVector2Array([o, o + Vector2(size * 0.35, size * 0.35), o + Vector2(size, -size * 0.4)]),
			Params.medkit_color, 5.0)
	if boss_mark > 0:
		var center := Vector2(size * 1.1, size * 1.0)
		var color: Color = Params.hud_warning_color if boss_mark == 2 else Params.powerup_color
		if not unlocked:
			color = Color(color, 0.4)
		if boss_mark == 2:
			# Coroa: chefe do capítulo
			button.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-size * 0.6, size * 0.35), center + Vector2(-size * 0.6, -size * 0.3),
				center + Vector2(-size * 0.25, 0.0), center + Vector2(0.0, -size * 0.45), center + Vector2(size * 0.25, 0.0),
				center + Vector2(size * 0.6, -size * 0.3), center + Vector2(size * 0.6, size * 0.35),
			]), color)
		else:
			# Losango: chefe intermediário
			button.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -size * 0.45), center + Vector2(size * 0.4, 0.0),
				center + Vector2(0.0, size * 0.45), center + Vector2(-size * 0.4, 0.0),
			]), color)


func _on_stage_pressed(planet_index: int, stage_index: int) -> void:
	Session.select(planet_index, stage_index)
	Session.browsed_chapter = planet_index
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


## Gesto: deslizar rápido na horizontal troca de capítulo (esquerda = próximo).
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_swipe_start = touch.position
		_swipe_usec = Time.get_ticks_usec()
		return
	if _swipe_usec < 0:
		return
	var moved: Vector2 = touch.position - _swipe_start
	var seconds: float = (Time.get_ticks_usec() - _swipe_usec) / 1_000_000.0
	_swipe_usec = -1
	if absf(moved.x) >= Params.swipe_min_distance and absf(moved.x) > absf(moved.y) * 1.5 and seconds <= Params.swipe_max_seconds:
		_show_chapter(_chapter + (1 if moved.x < 0.0 else -1))
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		return
	# Setas do teclado trocam de capítulo (teste no PC)
	if event.is_action_pressed("ui_left"):
		_show_chapter(_chapter - 1)
	elif event.is_action_pressed("ui_right"):
		_show_chapter(_chapter + 1)
