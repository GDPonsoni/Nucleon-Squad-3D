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
	var tween := node.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 1.0, Params.ui_enter_seconds)
	tween.tween_property(node, "position:y", node.position.y - Params.ui_enter_offset, Params.ui_enter_seconds)
