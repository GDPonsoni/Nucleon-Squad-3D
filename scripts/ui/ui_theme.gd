class_name UiTheme
## Tema visual da interface, criado por código e compartilhado por todas as telas.
## Cores e tamanhos vêm de Params (seção Interface).

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = Params.ui_font_size

	# Botões: painel arredondado com borda na cor de destaque
	var accent: Color = Params.ui_accent_color
	theme.set_stylebox("normal", "Button", _box(Params.ui_panel_color, accent))
	theme.set_stylebox("hover", "Button", _box(Params.ui_panel_color.lightened(0.08), accent))
	theme.set_stylebox("pressed", "Button", _box(accent.darkened(0.55), accent.lightened(0.3)))
	theme.set_stylebox("disabled", "Button", _box(Params.ui_panel_color.darkened(0.3), Params.ui_muted_text_color.darkened(0.4)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Params.ui_text_color)
	theme.set_color("font_hover_color", "Button", Params.ui_text_color)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Params.ui_muted_text_color.darkened(0.3))
	theme.set_font_size("font_size", "Button", Params.ui_font_size)

	theme.set_color("font_color", "Label", Params.ui_text_color)
	theme.set_font_size("font_size", "Label", Params.ui_font_size)

	# Título com brilho na cor de destaque
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", Params.title_font_size)
	theme.set_color("font_color", "TitleLabel", Color.WHITE)
	theme.set_color("font_outline_color", "TitleLabel", Color(accent, 0.45))
	theme.set_constant("outline_size", "TitleLabel", Params.title_outline_size)

	theme.set_type_variation("SubtitleLabel", "Label")
	theme.set_font_size("font_size", "SubtitleLabel", Params.subtitle_font_size)
	theme.set_color("font_color", "SubtitleLabel", Params.ui_muted_text_color)

	# Painéis translúcidos atrás dos menus
	var panel := _box(Color(Params.ui_panel_color, Params.ui_panel_alpha), Color(accent, 0.25))
	panel.set_content_margin_all(Params.ui_panel_padding)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme


static func _box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(Params.ui_border_width)
	box.set_corner_radius_all(Params.ui_corner_radius)
	box.set_content_margin_all(Params.ui_button_padding)
	return box
