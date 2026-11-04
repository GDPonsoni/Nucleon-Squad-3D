class_name UiFactory
## Cria elementos de interface com o tema do jogo (UiTheme).
## Textos recebem chaves da tabela de tradução (data/i18n/strings.csv).


## Aplica o tema na raiz de uma tela (os filhos herdam).
static func apply_theme(root: Control) -> void:
	root.theme = UiTheme.get_theme()


static func make_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Params.menu_spacing)
	return column


static func make_title(text_key: String) -> Label:
	var label := Label.new()
	label.text = text_key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = &"TitleLabel"
	return label


static func make_subtitle(text_key: String) -> Label:
	var label := Label.new()
	label.text = text_key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = &"SubtitleLabel"
	return label


static func make_button(text_key: String) -> Button:
	var button := Button.new()
	button.text = text_key
	button.custom_minimum_size = Params.button_min_size
	# Sem contorno de foco ao tocar
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(Audio.ui_press.bind(text_key))
	_add_press_feedback(button)
	return button


## Botão afunda um pouco ao ser tocado e volta ao soltar (resposta visual imediata).
static func _add_press_feedback(button: Button) -> void:
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.button_down.connect(func() -> void:
		if not button.disabled:
			button.create_tween().set_ignore_time_scale(true).tween_property(button, "scale", Vector2.ONE * Params.button_press_scale, Params.button_press_seconds))
	button.button_up.connect(func() -> void:
		button.create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(button, "scale", Vector2.ONE, Params.button_press_seconds * 2.0))


## Maior tamanho de fonte (até max_size) em que o texto cabe na largura.
static func fit_font_size(text: String, width: float, max_size: int) -> int:
	var font: Font = UiTheme.get_theme().default_font if UiTheme.get_theme().default_font != null else ThemeDB.fallback_font
	var font_size: int = max_size
	while font_size > 24 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 2
	return font_size


## Espaço vazio no topo de uma coluna, para a seta de voltar não cobrir o conteúdo.
static func add_top_space(column: Control, height: float = Params.back_top_space) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	column.add_child(space)


## Seta de voltar discreta no canto superior esquerdo (não entra no layout da tela).
static func add_corner_back(parent: Control, on_press: Callable) -> Button:
	var button := make_button("MENU_BACK")
	button.text = ""  # só a seta; a chave serve ao som do botão
	button.custom_minimum_size = Params.back_corner_size
	button.draw.connect(func() -> void:
		var c: Vector2 = button.size * 0.5
		var h: float = button.size.y * 0.2
		var color: Color = Params.ui_text_color
		var width: float = maxf(button.size.y * 0.07, 4.0)
		button.draw_line(c + Vector2(h * 0.9, 0.0), c + Vector2(-h * 0.9, 0.0), color, width)
		button.draw_line(c + Vector2(-h * 0.9, 0.0), c + Vector2(0.0, -h * 0.9), color, width)
		button.draw_line(c + Vector2(-h * 0.9, 0.0), c + Vector2(0.0, h * 0.9), color, width))
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = Params.back_corner_margin.x
	button.offset_top = Params.back_corner_margin.y
	button.offset_right = Params.back_corner_margin.x + Params.back_corner_size.x
	button.offset_bottom = Params.back_corner_margin.y + Params.back_corner_size.y
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button


## Botão de ação principal (preenchido na cor de destaque).
static func make_primary_button(text_key: String) -> Button:
	var button := make_button(text_key)
	button.theme_type_variation = &"PrimaryButton"
	return button


## Painel translúcido com cantos arredondados envolvendo o conteúdo.
static func make_panel(child: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_child(child)
	return panel


## Container centralizado ocupando a tela inteira.
static func make_centered(child: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(child)
	return center


## Fundo escurecido de tela cheia que bloqueia toques no jogo (já com o tema).
static func make_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Params.pause_overlay_color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	apply_theme(overlay)
	return overlay


## Ícone do quark (moeda da evolução do núcleo): anel com três pontos nas cores das cargas.
static func draw_quark_icon(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, Color(Params.quark_color, 0.18))
	canvas.draw_arc(center, radius, 0.0, TAU, 32, Params.quark_color, maxf(radius * 0.14, 2.0))
	for i in Params.quark_dot_colors.size():
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / Params.quark_dot_colors.size())
		canvas.draw_circle(center + dir * radius * 0.45, radius * 0.27, Params.quark_dot_colors[i])


## Entrada suave: aparece e sobe um pouco.
static func animate_in(node: Control) -> void:
	node.modulate.a = 0.0
	node.position.y += Params.ui_enter_offset
	# Tempo real: na câmera lenta (ex.: fim de fase sem o dedo na tela) não fica lenta
	var tween := node.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_ignore_time_scale(true)
	tween.tween_property(node, "modulate:a", 1.0, Params.ui_enter_seconds)
	tween.tween_property(node, "position:y", node.position.y - Params.ui_enter_offset, Params.ui_enter_seconds)
