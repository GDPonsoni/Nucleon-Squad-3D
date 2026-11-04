class_name SettingsPanel
extends VBoxContainer
## Configurações do jogo: volumes (geral, música, efeitos sonoros), vibração, efeitos
## visuais reduzidos, estatísticas na tela (FPS e contadores) e idioma. Salva na hora (SaveGame.settings) e é usado na tela
## de configurações do menu e na pausa.

signal back_pressed

var _in_language_list: bool = false


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
	_add_toggle("SETTINGS_VIBRATION", "vibration")
	_add_toggle("SETTINGS_EFFECTS", "reduced_effects", true)
	_add_toggle("SETTINGS_STATS", "show_stats")
	_add_language()
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
func _add_toggle(label_key: String, setting: String, inverted: bool = false) -> void:
	var row := ToggleRow.new()
	row.setup(label_key, bool(SaveGame.setting(setting)) != inverted)
	row.toggled_value.connect(func(on: bool) -> void: SaveGame.set_setting(setting, on != inverted))
	add_child(row)


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
