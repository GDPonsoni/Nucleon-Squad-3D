class_name SettingsPanel
extends VBoxContainer
## Configurações do jogo: volumes (geral, música, efeitos sonoros), vibração, efeitos
## visuais reduzidos e idioma. Salva na hora (SaveGame.settings) e é usado na tela
## de configurações do menu e na pausa.

signal back_pressed


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
	_add_toggle("SETTINGS_VIBRATION", "vibration", "SETTINGS_ON", "SETTINGS_OFF")
	_add_toggle("SETTINGS_EFFECTS", "reduced_effects", "SETTINGS_EFFECTS_REDUCED", "SETTINGS_EFFECTS_FULL")
	_add_language()
	var back := UiFactory.make_button("MENU_BACK")
	back.pressed.connect(back_pressed.emit)
	add_child(back)


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


## Botão que alterna entre dois estados (valor booleano).
func _add_toggle(label_key: String, setting: String, on_key: String, off_key: String) -> void:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var refresh := func() -> void:
		button.text = "%s: %s" % [tr(label_key), tr(on_key if bool(SaveGame.setting(setting)) else off_key)]
	refresh.call()
	button.pressed.connect(func() -> void:
		SaveGame.set_setting(setting, not bool(SaveGame.setting(setting)))
		refresh.call())
	add_child(button)


## Botão que passa pelos idiomas: automático, português, inglês.
func _add_language() -> void:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var current: String = String(SaveGame.setting("language"))
	button.text = "%s: %s" % [tr("SETTINGS_LANGUAGE"), tr("LANGUAGE_" + current.to_upper())]
	button.pressed.connect(func() -> void:
		var index: int = Params.languages.find(current)
		SaveGame.set_setting("language", Params.languages[(index + 1) % Params.languages.size()])
		# set_setting aplica o idioma novo; refaz os textos
		_build())
	add_child(button)
