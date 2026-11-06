class_name SettingsPanel
extends VBoxContainer
## Configurações do jogo: volumes (geral, música, efeitos sonoros), vibração, efeitos
## visuais, estatísticas na tela (FPS e contadores) e idioma. Salva na hora (SaveGame.settings) e é
## usado na tela de configurações do menu e na pausa. Interface de ícones, quase sem texto.

signal back_pressed

## Mostra as ferramentas de teste de progresso (só em build de debug). Ligado pela tela de
## configurações do menu; a pausa não mostra.
var debug_tools: bool = false
var _in_language_list: bool = false  # na subtela de progresso de teste (debug)
var _dropdown: CanvasLayer  # lista aberta do idioma (null = fechada)
var _confirm_key: String = ""  # ação destrutiva esperando o segundo toque


func _ready() -> void:
	_build()


## Monta tudo de novo (ao trocar de idioma, para refazer os textos).
## Sem títulos nem rótulos longos: ícone + controle. Volumes (som, música, efeitos) em
## deslizadores com ícone que silencia; vibração, efeitos visuais e estatísticas em
## interruptores de ícone; idioma num seletor curto.
func _build() -> void:
	_dropdown = null
	for child in get_children():
		child.queue_free()
	add_theme_constant_override("separation", Params.settings_row_spacing * 2)
	custom_minimum_size.x = Params.settings_panel_width
	_add_volume("master", IconButton.Icon.SPEAKER)
	_add_volume("music", IconButton.Icon.NOTE)
	_add_volume("sfx", IconButton.Icon.BURST, func() -> void: Audio.play(&"powerup_pickup"))
	_add_tiles()
	_add_language()
	if debug_tools and OS.is_debug_build():
		var tools := UiFactory.make_button("DEBUG_PROGRESS_TITLE")
		tools.pressed.connect(_show_progress_tools)
		add_child(tools)
	_in_language_list = false


## Voltar: da lista de idiomas para as configurações; das configurações, sai do painel.
func go_back() -> void:
	if _dropdown != null:
		_close_dropdown()
		return
	if _in_language_list:
		_build()
	else:
		back_pressed.emit()


## Linha: ícone (toque silencia/volta) + deslizador. O ícone ganha um risco quando está mudo.
func _add_volume(setting: String, icon: IconButton.Icon, preview: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	var button := IconButton.new().setup(icon, Params.settings_icon_size)
	var slider := VolumeSlider.new()
	slider.custom_minimum_size.x = 200.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = float(SaveGame.setting(setting))
	button.slashed = slider.value <= 0.0
	var before_mute: Array[float] = [slider.value if slider.value > 0.0 else 0.7]
	button.pressed.connect(func() -> void:
		var target: float = before_mute[0] if slider.value <= 0.0 else 0.0
		if slider.value > 0.0:
			before_mute[0] = slider.value
		slider.value = target
		button.slashed = target <= 0.0
		SaveGame.set_setting(setting, target)
		if preview.is_valid() and target > 0.0:
			preview.call())
	slider.value_changed.connect(func(v: float) -> void:
		button.slashed = v <= 0.0
		SaveGame.set_setting(setting, v))
	if preview.is_valid():
		slider.released.connect(preview)
	row.add_child(button)
	row.add_child(slider)


## Três interruptores de ícone com legenda curta; a intensidade da vibração aparece só com ela ligada.
func _add_tiles() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	var size: float = Params.settings_tile_size
	var vibration := _tile(row, IconButton.Icon.VIBRATE, "SETTINGS_SHORT_VIBRATION", bool(SaveGame.setting("vibration")))
	var effects := _tile(row, IconButton.Icon.SPARKLE, "SETTINGS_SHORT_EFFECTS", not bool(SaveGame.setting("reduced_effects")))
	var stats := _tile(row, IconButton.Icon.CHART, "SETTINGS_SHORT_STATS", bool(SaveGame.setting("show_stats")))
	var level := _haptic_level_button()
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 20)
	level_row.add_child(IconButton.new().setup(IconButton.Icon.VIBRATE, Params.settings_icon_size))
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(level)
	level_row.visible = vibration.on
	add_child(level_row)
	vibration.toggled_value.connect(func(value: bool) -> void:
		SaveGame.set_setting("vibration", value)
		level_row.visible = value)
	effects.toggled_value.connect(func(value: bool) -> void: SaveGame.set_setting("reduced_effects", not value))
	stats.toggled_value.connect(func(value: bool) -> void: SaveGame.set_setting("show_stats", value))


func _tile(row: HBoxContainer, icon: IconButton.Icon, caption_key: String, on: bool) -> IconButton:
	var tile := IconButton.new().setup(icon, Params.settings_tile_size, tr(caption_key))
	tile.toggle = true
	tile.on = on
	row.add_child(tile)
	return tile


## Intensidade da vibração (baixa/média/alta): cada toque passa para a próxima e mostra a vibração.
func _haptic_level_button() -> Button:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = Vector2(200.0, Params.settings_icon_size)
	var names: Array[String] = ["HAPTIC_LOW", "HAPTIC_MEDIUM", "HAPTIC_HIGH"]
	var refresh := func() -> void:
		var level: int = clampi(int(SaveGame.setting("haptic_level")), 0, names.size() - 1)
		button.text = tr(names[level])
		button.add_theme_font_size_override("font_size", UiFactory.fit_font_size(button.text,
			Params.settings_panel_width - Params.settings_icon_size - 20.0 - Params.ui_button_padding * 2.0, Params.settings_label_font_size))
	refresh.call()
	button.pressed.connect(func() -> void:
		SaveGame.set_setting("haptic_level", (int(SaveGame.setting("haptic_level")) + 1) % names.size())
		refresh.call()
		Haptics.play(&"troca_nave"))
	return button


## Seletor de idioma em formato de combobox: globo + caixa com o idioma atual e uma seta.
## Tocar abre a lista flutuando logo abaixo da caixa (sem empurrar o resto do painel); tocar fora
## ou numa opção fecha. Fica numa camada própria para não ser cortada pela rolagem do diálogo.
func _add_language() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	var globe := IconButton.new().setup(IconButton.Icon.GLOBE, Params.settings_icon_size)
	row.add_child(globe)
	var current: String = String(SaveGame.setting("language"))
	var box := UiFactory.make_button("")
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.text = tr("LANGUAGE_" + current.to_upper())
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(200.0, Params.settings_icon_size)
	box.add_theme_font_size_override("font_size", Params.settings_label_font_size)
	box.draw.connect(func() -> void:
		# Seta da combobox (aponta para cima com a lista aberta)
		var c := Vector2(box.size.x - 50.0, box.size.y * 0.5)
		var d: float = 12.0 * (-1.0 if _dropdown != null else 1.0)
		box.draw_colored_polygon(PackedVector2Array([c + Vector2(-16.0, -d * 0.6), c + Vector2(16.0, -d * 0.6), c + Vector2(0.0, d)]), Params.ui_text_color))
	var open := func() -> void:
		if _dropdown != null:
			_close_dropdown()
		else:
			_open_dropdown(box, current)
		box.queue_redraw()
	box.pressed.connect(open)
	globe.pressed.connect(open)
	row.add_child(box)


func _open_dropdown(anchor: Control, current: String) -> void:
	_dropdown = CanvasLayer.new()
	_dropdown.layer = 200
	_dropdown.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dropdown)
	# Fundo invisível que pega o toque fora da lista
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		var touch := event as InputEventMouseButton
		if touch != null and touch.pressed:
			_close_dropdown(anchor))
	_dropdown.add_child(catcher)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	UiFactory.apply_theme(list)
	var option_height: float = Params.settings_compact_button_height
	for language in Params.languages:
		var option := UiFactory.make_button("")
		option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		option.text = tr("LANGUAGE_" + language.to_upper())
		option.custom_minimum_size = Vector2(anchor.size.x, option_height)
		option.add_theme_font_size_override("font_size", Params.settings_label_font_size)
		if language == current:
			option.theme_type_variation = &"PrimaryButton"
		option.pressed.connect(func() -> void:
			SaveGame.set_setting("language", language)
			# O idioma novo refaz todos os textos (e fecha a lista)
			_build())
		list.add_child(option)
	_dropdown.add_child(list)
	# Logo abaixo da caixa; se não couber embaixo, abre para cima
	var rect: Rect2 = anchor.get_global_rect()
	var total: float = Params.languages.size() * (option_height + 4.0)
	var view_h: float = get_viewport().get_visible_rect().size.y
	var top: float = rect.end.y + 6.0
	if top + total > view_h - 20.0:
		top = maxf(rect.position.y - total - 6.0, 20.0)
	list.position = Vector2(rect.position.x, top)


func _close_dropdown(anchor: Control = null) -> void:
	if _dropdown != null:
		_dropdown.queue_free()
		_dropdown = null
	if anchor != null:
		anchor.queue_redraw()


## Teste (build de debug): desfazer, recuar e avançar o progresso para validar o que muda
## conforme o avanço (naves, auxiliar, dificuldade, economia).
func _show_progress_tools() -> void:
	_in_language_list = true
	for child in get_children():
		child.queue_free()
	add_child(UiFactory.make_title("DEBUG_PROGRESS_TITLE"))
	var total: int = SaveGame.stage_order().size()
	var status := Label.new()
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status.text = tr("DEBUG_PROGRESS_STATUS") % [SaveGame.progress_count(), total, SaveGame.quarks]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", Params.settings_label_font_size)
	status.add_theme_color_override("font_color", Params.ui_accent_color)
	add_child(status)
	_add_action("DEBUG_STAGE_BACK", func() -> void: SaveGame.set_progress_count(SaveGame.progress_count() - 1))
	_add_action("DEBUG_STAGE_FORWARD", func() -> void: SaveGame.set_progress_count(SaveGame.progress_count() + 1))
	var per_chapter: int = total / maxi(Session.campaign.planets.size(), 1)
	for c in Session.campaign.planets.size():
		var start: int = c * per_chapter
		var button := _add_action("", func() -> void: SaveGame.set_progress_count(start))
		button.text = tr("DEBUG_CHAPTER_START") % (c + 1)
	_add_action("DEBUG_ALL_DONE", func() -> void: SaveGame.set_progress_count(total))
	_add_action("DEBUG_GIVE_QUARKS", func() -> void: SaveGame.add_quarks(Params.debug_quarks_grant))
	_add_action("DEBUG_RESET_UPGRADES", func() -> void: SaveGame.reset_upgrades(), true)
	_add_action("DEBUG_RESET_ALL", func() -> void: SaveGame.reset_all(), true)


## Botão de ação do painel de teste. confirm: pede um segundo toque antes de executar.
func _add_action(text_key: String, action: Callable, confirm: bool = false) -> Button:
	var button := UiFactory.make_button(text_key)
	var key: String = text_key + str(get_child_count())
	if confirm:
		button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(func() -> void:
		if confirm and _confirm_key != key:
			_confirm_key = key
			button.text = tr("DEBUG_CONFIRM")
			return
		_confirm_key = ""
		action.call()
		_show_progress_tools())
	add_child(button)
	return button
