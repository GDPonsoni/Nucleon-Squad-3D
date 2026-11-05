extends Control
## Montar o esquadrão: no topo, 4 vagas do esquadrão (a 1ª começa a fase) e 1 vaga de
## auxiliar, de outro formato. Toque numa vaga e depois numa nave da lista para colocá-la
## ali; se a nave já estava em outra vaga, as duas trocam de lugar. Cada cartão mostra o
## que a nave faz como principal e como auxiliar. A auxiliar é opcional e tem botão de
## remover. Salvar grava tudo; Voltar sai sem salvar.

const AUX_SLOT: int = -1  # índice da vaga da auxiliar em _selected

var _roster: Array[BodyData] = []
var _chosen: Array[BodyData] = []  # 4 vagas do esquadrão (pode ter null enquanto monta)
var _companion: BodyData
var _selected: int = 0  # vaga escolhida: 0..3 ou AUX_SLOT
var _slot_icons: Array[ShipIcon] = []
var _aux_icon: ShipIcon
var _aux_clear: Button
var _slot_info: Label
var _cards: Array[Button] = []
var _card_icons: Array[ShipIcon] = []
var _save_button: Button


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())

	_roster = (load(Params.roster_path) as FormationData).bodies
	_chosen = SaveGame.squad_formation().bodies.duplicate()
	_companion = SaveGame.companion_body()

	# Rolável: cabe todas as naves mesmo em telas mais baixas
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0.0, get_viewport_rect().size.y)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.squad_spacing)
	center.add_child(column)
	UiFactory.add_top_space(column, Params.back_top_space_squad)
	column.add_child(UiFactory.make_title("SQUAD_TITLE"))
	var hint := UiFactory.make_subtitle("SQUAD_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = Params.squad_hint_width
	hint.add_theme_font_size_override("font_size", Params.squad_hint_font_size)
	column.add_child(hint)

	column.add_child(_build_slots())
	_slot_info = UiFactory.make_subtitle("")
	_slot_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_slot_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_info.custom_minimum_size.x = Params.squad_hint_width
	_slot_info.add_theme_font_size_override("font_size", Params.squad_description_font_size)
	column.add_child(_slot_info)

	var grid := GridContainer.new()
	grid.columns = Params.squad_columns
	grid.add_theme_constant_override("h_separation", Params.squad_spacing)
	grid.add_theme_constant_override("v_separation", Params.squad_spacing)
	column.add_child(grid)
	for body in _roster:
		grid.add_child(_make_card(body))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", Params.squad_spacing)
	column.add_child(buttons)
	UiFactory.add_corner_back(self, _go_back)
	_save_button = UiFactory.make_primary_button("SQUAD_SAVE")
	_save_button.custom_minimum_size = Params.squad_button_size
	_save_button.pressed.connect(_on_save_pressed)
	buttons.add_child(_save_button)

	UiFactory.animate_in(center)
	_refresh()


## Fileira de vagas: 4 do esquadrão, um separador e a vaga da auxiliar (com rótulos embaixo).
func _build_slots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Params.squad_spacing)
	for i in Params.squad_size:
		var cell := _slot_cell(str(i + 1), Params.ui_muted_text_color)
		var button := cell.get_child(0) as Button
		button.pressed.connect(_on_slot_pressed.bind(i))
		_slot_icons.append(button.get_child(0) as ShipIcon)
		row.add_child(cell)
	var divider := ColorRect.new()
	divider.color = Color(Params.companion_powerup_color, 0.5)
	divider.custom_minimum_size = Vector2(3.0, Params.squad_slot_size * 0.8)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(divider)
	var aux_cell := _slot_cell(tr("SQUAD_AUX_LABEL"), Params.companion_powerup_color)
	var aux_button := aux_cell.get_child(0) as Button
	aux_button.pressed.connect(_on_slot_pressed.bind(AUX_SLOT))
	_aux_icon = aux_button.get_child(0) as ShipIcon
	_aux_icon.auxiliary = true
	_aux_icon.locked = not SaveGame.is_companion_unlocked()
	# Remover a auxiliar (ela é opcional)
	_aux_clear = Button.new()
	_aux_clear.flat = true
	_aux_clear.focus_mode = Control.FOCUS_NONE
	_aux_clear.text = tr("SQUAD_AUX_CLEAR")
	_aux_clear.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_aux_clear.add_theme_font_size_override("font_size", Params.squad_slot_label_font_size)
	_aux_clear.add_theme_color_override("font_color", Params.ui_muted_text_color)
	_aux_clear.custom_minimum_size.y = Params.squad_aux_clear_height
	_aux_clear.pressed.connect(_on_aux_clear_pressed)
	aux_cell.add_child(_aux_clear)
	row.add_child(aux_cell)
	return row


## Vaga: ícone tocável e rótulo embaixo.
func _slot_cell(label_text: String, label_color: Color) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_BEGIN
	cell.add_theme_constant_override("separation", 4)
	cell.add_child(_icon_button(Params.squad_slot_size))
	var label := Label.new()
	label.text = label_text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_font_size_override("font_size", UiFactory.fit_font_size(label_text, Params.squad_slot_size, Params.squad_slot_label_font_size))
	cell.add_child(label)
	return cell


## Botão quadrado e sem fundo com um ícone de nave dentro.
func _icon_button(side: float) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2.ONE * side
	button.pressed.connect(Audio.play.bind(&"ui_click"))
	var icon := ShipIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	return button


func _make_card(body: BodyData) -> Button:
	var unlocked: bool = SaveGame.is_ship_unlocked(body)
	var card := UiFactory.make_button("")
	card.custom_minimum_size = Params.squad_card_size
	card.toggle_mode = true
	card.disabled = not unlocked
	card.pressed.connect(_on_card_pressed.bind(body))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = Params.ui_button_padding
	row.offset_right = -Params.ui_button_padding
	row.add_theme_constant_override("separation", Params.ui_button_padding)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := ShipIcon.new()
	icon.body = body
	icon.locked = not unlocked
	icon.custom_minimum_size = Vector2.ONE * Params.squad_card_icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var name_label := Label.new()
	name_label.text = body.name_key
	name_label.add_theme_color_override("font_color", body.color if unlocked else Params.ui_muted_text_color)
	name_label.add_theme_font_size_override("font_size", Params.squad_name_font_size)
	texts.add_child(name_label)
	var lines: Array[Label] = []
	if unlocked:
		lines.append(_card_line("%s: %s" % [tr("SQUAD_MAIN_LABEL"), tr(body.description_key)], Params.ui_muted_text_color))
		lines.append(_card_line("%s: %s" % [tr("SQUAD_AUX_LABEL"), tr(body.companion_description_key)], Params.companion_powerup_color))
	else:
		lines.append(_card_line(tr("SQUAD_LOCKED_SHIP") % body.unlock_chapter, Params.ui_muted_text_color))
	for line in lines:
		texts.add_child(line)

	# O cartão cresce se o texto (que muda com o idioma) não couber na altura mínima
	card.resized.connect(_fit_card_height.bind(card, name_label, lines))
	_cards.append(card)
	_card_icons.append(icon)
	return card


func _card_line(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", Params.squad_description_font_size)
	return label


func _fit_card_height(card: Button, name_label: Label, lines: Array[Label]) -> void:
	var text_width: float = card.size.x - Params.ui_button_padding * 3.0 - Params.squad_card_icon_size
	if text_width <= 0.0:
		return
	var needed: float = name_label.get_theme_font("font").get_height(Params.squad_name_font_size)
	for line in lines:
		needed += line.get_theme_font("font").get_multiline_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, Params.squad_description_font_size).y + 2.0
	needed = maxf(Params.squad_card_size.y, needed + Params.ui_button_padding * 2.0)
	if absf(card.custom_minimum_size.y - needed) > 1.0:
		card.custom_minimum_size.y = needed


func _on_slot_pressed(slot: int) -> void:
	_selected = slot
	_refresh()


## Coloca a nave na vaga escolhida; se ela estava em outra vaga, as duas trocam.
func _on_card_pressed(body: BodyData) -> void:
	if _selected == AUX_SLOT and not SaveGame.is_companion_unlocked():
		_refresh()
		return
	var from: int = _slot_of(body)
	if from == _selected:
		_refresh()
		return
	var previous: BodyData = _get_slot(_selected)
	_set_slot(_selected, body)
	if from != -2:
		# A nave saiu da outra vaga: a que estava aqui vai para lá (a auxiliar pode ficar vazia)
		_set_slot(from, previous)
	Audio.play(&"ui_confirm")
	# Se alguma vaga do esquadrão ficou vazia, ela passa a ser a escolhida
	var empty: int = _chosen.find(null)
	if empty >= 0:
		_selected = empty
	_refresh()


func _on_aux_clear_pressed() -> void:
	_companion = null
	Audio.play(&"ui_back")
	_refresh()


## Vaga onde a nave está: 0..3, AUX_SLOT ou -2 (fora).
func _slot_of(body: BodyData) -> int:
	if body == _companion:
		return AUX_SLOT
	var index: int = _chosen.find(body)
	return index if index >= 0 else -2


func _get_slot(slot: int) -> BodyData:
	if slot == AUX_SLOT:
		return _companion
	return _chosen[slot] if slot < _chosen.size() else null


func _set_slot(slot: int, body: BodyData) -> void:
	if slot == AUX_SLOT:
		_companion = body
		return
	while _chosen.size() <= slot:
		_chosen.append(null)
	_chosen[slot] = body


## Vagas, destaque da vaga escolhida, marcas nos cartões e botão Salvar.
func _refresh() -> void:
	for i in _slot_icons.size():
		_slot_icons[i].body = _get_slot(i)
		_slot_icons[i].highlighted = _selected == i
	_aux_icon.body = _companion
	_aux_icon.highlighted = _selected == AUX_SLOT
	_aux_clear.visible = _companion != null
	_slot_info.text = _slot_text()
	_slot_info.add_theme_color_override("font_color",
		Params.companion_powerup_color if _selected == AUX_SLOT else Params.ui_muted_text_color)
	for i in _roster.size():
		var slot: int = _slot_of(_roster[i])
		_cards[i].set_pressed_no_signal(slot != -2)
		_card_icons[i].number = slot + 1 if slot >= 0 else 0
		_card_icons[i].auxiliary = slot == AUX_SLOT
	_save_button.disabled = _chosen.size() != Params.squad_size or _chosen.has(null)


func _slot_text() -> String:
	if _selected == AUX_SLOT:
		if not SaveGame.is_companion_unlocked():
			return tr("SQUAD_COMPANION_LOCKED") % Params.companion_unlock_chapter
		return tr("SQUAD_SLOT_AUX")
	return tr("SQUAD_SLOT_MAIN") % (_selected + 1)


func _on_save_pressed() -> void:
	SaveGame.set_squad(_chosen)
	SaveGame.set_companion(_companion)
	_go_back()


func _go_back() -> void:
	SceneTransition.go_to(ScenePaths.MENU)


func _notification(what: int) -> void:
	# Botão Voltar do Android volta ao menu sem salvar
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not Dialog.is_open():
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Dialog.is_open():
		_go_back()
