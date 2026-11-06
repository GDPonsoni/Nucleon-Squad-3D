class_name SettingsPanel
extends VBoxContainer
## Configurações do jogo: volumes (geral, música, efeitos sonoros), vibração, efeitos
## visuais reduzidos, estatísticas na tela (FPS e contadores) e idioma. Salva na hora (SaveGame.settings) e é usado na tela
## de configurações do menu e na pausa.

signal back_pressed

## Mostra as ferramentas de teste de progresso (só em build de debug). Ligado pela tela de
## configurações do menu; a pausa não mostra.
var debug_tools: bool = false
var _in_language_list: bool = false  # em qualquer subtela (idioma ou progresso de teste)
var _confirm_key: String = ""  # ação destrutiva esperando o segundo toque


func _ready() -> void:
	_build()


## Monta tudo de novo (ao trocar de idioma, para refazer os textos).
func _build() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_constant_override("separation", Params.settings_row_spacing)
	add_child(UiFactory.make_title("SETTINGS_TITLE"))
	_add_slider("SETTINGS_MASTER", "master")
	_add_slider("SETTINGS_MUSIC", "music")
	_add_slider("SETTINGS_SFX", "sfx", func() -> void: Audio.play(&"powerup_pickup"))
	var vibration_row := _add_toggle("SETTINGS_VIBRATION", "vibration")
	_add_haptic_level(vibration_row)
	_add_toggle("SETTINGS_EFFECTS", "reduced_effects", true)
	_add_toggle("SETTINGS_STATS", "show_stats")
	_add_language()
	if debug_tools and OS.is_debug_build():
		var tools := UiFactory.make_button("DEBUG_PROGRESS_TITLE")
		tools.pressed.connect(_show_progress_tools)
		add_child(tools)
	_in_language_list = false


## Voltar: da lista de idiomas para as configurações; das configurações, sai do painel.
func go_back() -> void:
	if _in_language_list:
		_build()
	else:
		back_pressed.emit()


func _add_slider(label_key: String, setting: String, preview: Callable = Callable()) -> void:
	var header := HBoxContainer.new()
	add_child(header)
	var name_label := Label.new()
	name_label.text = label_key
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", Params.settings_label_font_size)
	header.add_child(name_label)
	var percent := Label.new()
	percent.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	percent.add_theme_font_size_override("font_size", Params.settings_label_font_size)
	percent.add_theme_color_override("font_color", Params.ui_accent_color)
	header.add_child(percent)
	var slider := VolumeSlider.new()
	slider.value = float(SaveGame.setting(setting))
	percent.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		percent.text = "%d%%" % roundi(v * 100.0)
		SaveGame.set_setting(setting, v))
	if preview.is_valid():
		slider.released.connect(preview)
	add_child(slider)


## Interruptor (ligado/desligado). inverted: a configuração guarda o contrário do que a
## chave mostra (ex.: "Efeitos visuais" ligado = reduced_effects falso).
func _add_toggle(label_key: String, setting: String, inverted: bool = false) -> ToggleRow:
	var row := ToggleRow.new()
	row.setup(label_key, bool(SaveGame.setting(setting)) != inverted)
	row.toggled_value.connect(func(on: bool) -> void: SaveGame.set_setting(setting, on != inverted))
	add_child(row)
	return row


## Intensidade da vibração (baixa/média/alta): cada toque passa para a próxima e mostra a vibração.
func _add_haptic_level(vibration_row: ToggleRow) -> void:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size.x = Params.settings_slider_width
	var names: Array[String] = ["HAPTIC_LOW", "HAPTIC_MEDIUM", "HAPTIC_HIGH"]
	var refresh := func() -> void:
		var level: int = clampi(int(SaveGame.setting("haptic_level")), 0, names.size() - 1)
		button.text = "%s: %s" % [tr("SETTINGS_HAPTIC_LEVEL"), tr(names[level])]
		button.add_theme_font_size_override("font_size", UiFactory.fit_font_size(button.text,
			Params.settings_slider_width - Params.ui_button_padding * 2.0, Params.ui_font_size))
		button.disabled = not bool(SaveGame.setting("vibration"))
	refresh.call()
	button.pressed.connect(func() -> void:
		SaveGame.set_setting("haptic_level", (int(SaveGame.setting("haptic_level")) + 1) % names.size())
		refresh.call()
		Haptics.play(&"troca_nave"))
	vibration_row.toggled_value.connect(func(_on: bool) -> void: refresh.call())
	add_child(button)


## Botão que abre a lista de idiomas (mostra o atual).
func _add_language() -> void:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var current: String = String(SaveGame.setting("language"))
	button.text = "%s: %s" % [tr("SETTINGS_LANGUAGE"), tr("LANGUAGE_" + current.to_upper())]
	button.custom_minimum_size.x = Params.settings_slider_width
	button.add_theme_font_size_override("font_size", UiFactory.fit_font_size(button.text,
		Params.settings_slider_width - Params.ui_button_padding * 2.0, Params.ui_font_size))
	button.pressed.connect(_show_language_list)
	add_child(button)


## Lista de idiomas no lugar do painel: tocar num aplica e volta para as configurações.
func _show_language_list() -> void:
	_in_language_list = true
	for child in get_children():
		child.queue_free()
	add_child(UiFactory.make_title("SETTINGS_LANGUAGE"))
	var hint := UiFactory.make_subtitle("SETTINGS_PICK_LANGUAGE")
	add_child(hint)
	var current: String = String(SaveGame.setting("language"))
	for language in Params.languages:
		var option := UiFactory.make_button("")
		option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		option.text = tr("LANGUAGE_" + language.to_upper())
		if language == current:
			option.theme_type_variation = &"PrimaryButton"
		option.pressed.connect(func() -> void:
			SaveGame.set_setting("language", language)
			# set_setting aplica o idioma; refaz os textos no idioma novo
			_build())
		add_child(option)


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
