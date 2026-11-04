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
	var accent: Color = Params.ui_accent_color

	# Botões: painel com relevo (borda de baixo mais grossa), sombra e cantos redondos
	theme.set_stylebox("normal", "Button", _button_box(Params.ui_panel_color, accent, false))
	theme.set_stylebox("hover", "Button", _button_box(Params.ui_panel_color.lightened(0.06), accent.lightened(0.2), false))
	theme.set_stylebox("pressed", "Button", _button_box(accent.darkened(0.55), accent.lightened(0.3), true))
	theme.set_stylebox("disabled", "Button", _button_box(Params.ui_panel_color.darkened(0.35), Params.ui_muted_text_color.darkened(0.45), false))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Params.ui_text_color)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Params.ui_muted_text_color.darkened(0.3))
	theme.set_font_size("font_size", "Button", Params.ui_font_size)

	# Ação principal (Jogar, Salvar, Evoluir, Próxima fase): preenchida na cor de destaque
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _button_box(accent.darkened(0.25), accent.lightened(0.35), false))
	theme.set_stylebox("hover", "PrimaryButton", _button_box(accent.darkened(0.15), Color.WHITE, false))
	theme.set_stylebox("pressed", "PrimaryButton", _button_box(accent.darkened(0.45), Color.WHITE, true))
	theme.set_color("font_color", "PrimaryButton", Params.background_color.darkened(0.3))
	theme.set_color("font_hover_color", "PrimaryButton", Params.background_color.darkened(0.3))
	theme.set_color("font_pressed_color", "PrimaryButton", Color.WHITE)

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
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel.shadow_size = 18
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme


static func _box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(Params.ui_border_width)
	box.set_corner_radius_all(Params.ui_corner_radius)
	box.set_content_margin_all(Params.ui_button_padding)
	box.anti_aliasing = true
	return box


## Botão com relevo: a borda de baixo é mais grossa; pressionado, o relevo some e o texto desce.
static func _button_box(background: Color, border: Color, pressed: bool) -> StyleBoxFlat:
	var box := _box(background, border)
	box.border_width_bottom = Params.ui_border_width if pressed else Params.ui_button_depth
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.0 if pressed else 0.3)
	box.shadow_size = 0 if pressed else 8
	box.shadow_offset = Vector2(0.0, 4.0)
	if pressed:
		box.content_margin_top += Params.ui_button_depth - Params.ui_border_width
	return box
