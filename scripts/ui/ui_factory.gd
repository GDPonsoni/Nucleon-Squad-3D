class_name UiFactory
## Cria elementos de interface com o mesmo estilo (placeholders até ter tema próprio).
## Textos recebem chaves da tabela de tradução (data/i18n/strings.csv).


static func make_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Params.menu_spacing)
	return column


static func make_title(text_key: String) -> Label:
	var label := Label.new()
	label.text = text_key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Params.title_font_size)
	return label


static func make_button(text_key: String) -> Button:
	var button := Button.new()
	button.text = text_key
	button.custom_minimum_size = Params.button_min_size
	button.add_theme_font_size_override("font_size", Params.ui_font_size)
	# Sem contorno de foco ao tocar
	button.focus_mode = Control.FOCUS_NONE
	return button


## Container centralizado ocupando a tela inteira.
static func make_centered(child: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(child)
	return center


## Fundo escurecido de tela cheia que bloqueia toques no jogo.
static func make_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Params.pause_overlay_color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	return overlay
