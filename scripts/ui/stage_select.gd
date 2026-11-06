extends Control
## Seletor de fases: um planeta por página, com o caminho das fases como mapa (StageMap).
## Cabeçalho fixo (capítulo, nome, progresso, bolinhas); só o mapa acompanha o dedo (PagedView).
## Tocar numa fase liberada a inicia; a sugerida (a próxima) pulsa.
## Em build de debug, tocar várias vezes no nome do capítulo libera todas as fases.

var _chapter: int = 0
var _pager: PagedView
var _back_corner: Button
var _title_taps: int = 0
var _header_chapter: int = -1
var _number_label: Label
var _name_label: Label
var _progress_label: Label
var _reward_label: Label
var _dots: Control


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())
	_chapter = Session.browsed_chapter if Session.browsed_chapter >= 0 else _first_open_chapter()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_header())
	_pager = PagedView.new()
	_pager.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_pager)
	_pager.setup(Session.campaign.planets.size(), _build_page, _chapter)
	_pager.scrolled.connect(func(position: float) -> void: _refresh_header(roundi(position)))
	_pager.page_changed.connect(func(index: int) -> void:
		_chapter = index
		Session.browsed_chapter = index)
	_refresh_header(_chapter)
	UiFactory.animate_in(root)
	_back_corner = UiFactory.add_corner_back(self, _go_back)


## Primeiro capítulo ainda não concluído (ou o último, se todos foram).
func _first_open_chapter() -> int:
	for p in Session.campaign.planets.size():
		if not SaveGame.is_chapter_cleared(p):
			return p
	return Session.campaign.planets.size() - 1


## Cabeçalho fixo: "CAPÍTULO 2", nome, "4/9", bolinhas e a recompensa (preenchidos em _refresh_header).
func _build_header() -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	UiFactory.add_top_space(column)
	_number_label = UiFactory.make_subtitle("")
	_number_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_number_label)
	_name_label = Label.new()
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_label.gui_input.connect(_on_title_input)
	column.add_child(_name_label)
	_progress_label = UiFactory.make_subtitle("")
	_progress_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_progress_label)
	_dots = _chapter_dots()
	column.add_child(_dots)
	_reward_label = UiFactory.make_subtitle("")
	_reward_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_reward_label)
	return column


func _refresh_header(chapter: int) -> void:
	chapter = clampi(chapter, 0, Session.campaign.planets.size() - 1)
	if chapter == _header_chapter:
		return
	_header_chapter = chapter
	var planet: PlanetData = Session.campaign.planets[chapter]
	_number_label.text = (tr("STAGE_CHAPTER") % (chapter + 1)).to_upper()
	_name_label.text = tr(planet.name_key)
	_name_label.add_theme_color_override("font_color", planet.star_color)
	_name_label.add_theme_font_size_override("font_size", UiFactory.fit_font_size(_name_label.text,
		Params.stage_header_name_width, Params.stage_chapter_font_size))
	var done: int = 0
	for stage in planet.stages:
		if SaveGame.is_completed(stage.id):
			done += 1
	_progress_label.text = "%d/%d" % [done, planet.stages.size()]
	var reward: String = _reward_text(chapter)
	var cleared: bool = SaveGame.is_chapter_cleared(chapter)
	_reward_label.text = "" if reward.is_empty() or cleared else tr("STAGE_REWARD_SHORT") % reward
	_reward_label.add_theme_color_override("font_color", Params.powerup_color)
	_dots.queue_redraw()
	Haptics.play(&"tick")


## Monta o mapa de um planeta (o PagedView chama para o atual e os vizinhos).
func _build_page(chapter: int) -> Control:
	var map := StageMap.new()
	map.setup(chapter)
	map.stage_chosen.connect(_on_stage_chosen)
	return map


## Bolinhas: uma por capítulo, cheias nos concluídos e destacada na página atual.
func _chapter_dots() -> Control:
	var dots := Control.new()
	var count: int = Session.campaign.planets.size()
	dots.custom_minimum_size = Vector2(count * Params.stage_dot_spacing, Params.stage_dot_spacing * 0.6)
	dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dots.draw.connect(func() -> void:
		for p in count:
			var center := Vector2((p + 0.5) * Params.stage_dot_spacing, dots.size.y * 0.5)
			var color: Color = Session.campaign.planets[p].star_color
			if p == _header_chapter:
				dots.draw_circle(center, Params.stage_dot_radius * 1.5, color)
			elif SaveGame.is_chapter_cleared(p):
				dots.draw_circle(center, Params.stage_dot_radius, Color(color, 0.8))
			else:
				dots.draw_arc(center, Params.stage_dot_radius, 0.0, TAU, 16, Color(color, 0.6), 3.0))
	return dots


func _show_chapter(chapter: int) -> void:
	_pager.go_to(chapter)


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


func _on_stage_chosen(planet_index: int, stage_index: int) -> void:
	Session.select(planet_index, stage_index)
	Session.browsed_chapter = planet_index
	Audio.play(&"ui_confirm")
	SceneTransition.go_to(ScenePaths.GAME)


func _on_title_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventScreenTouch and event.pressed):
		return
	_title_taps += 1
	if _title_taps == Params.debug_unlock_taps:
		SaveGame.unlock_all()
		_pager.refresh()


func _go_back() -> void:
	SceneTransition.go_to(ScenePaths.MENU)


func _notification(what: int) -> void:
	# Botão Voltar do Android volta ao menu inicial
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not Dialog.is_open():
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Dialog.is_open():
		_go_back()
		return
	# Setas do teclado trocam de capítulo (teste no PC)
	if event.is_action_pressed("ui_left"):
		_show_chapter(_chapter - 1)
	elif event.is_action_pressed("ui_right"):
		_show_chapter(_chapter + 1)
