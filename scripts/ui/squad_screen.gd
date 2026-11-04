extends Control
## Montar o esquadrão: 4 espaços em ordem (o 1º começa a fase) e cartões com todas as
## naves; tocar num cartão adiciona/remove a nave, tocar num espaço a remove.
## Abaixo, a seção da nave auxiliar (opcional): uma fileira com "Nenhuma" e as naves.
## Um toque escolhe; naves do esquadrão e bloqueadas não podem ser a auxiliar.
## Salvar só fica ativo com o esquadrão completo.

var _roster: Array[BodyData] = []
var _chosen: Array[BodyData] = []
var _companion: BodyData
var _slots: Array[ShipIcon] = []
var _cards: Array[Button] = []
var _card_icons: Array[ShipIcon] = []
var _wingman_buttons: Array[Button] = []  # 0 = "Nenhuma", depois uma por nave do elenco
var _wingman_icons: Array[ShipIcon] = []
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
	center.custom_minimum_size = get_viewport_rect().size
	scroll.add_child(center)
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.squad_spacing)
	center.add_child(column)
	column.add_child(UiFactory.make_title("SQUAD_TITLE"))
	var hint := UiFactory.make_subtitle("SQUAD_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = Params.squad_hint_width
	column.add_child(hint)

	column.add_child(_build_slots())

	var grid := GridContainer.new()
	grid.columns = Params.squad_columns
	grid.add_theme_constant_override("h_separation", Params.squad_spacing)
	grid.add_theme_constant_override("v_separation", Params.squad_spacing)
	column.add_child(grid)
	for body in _roster:
		grid.add_child(_make_card(body))

	column.add_child(_build_wingman())

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


## Espaços do esquadrão, em ordem.
func _build_slots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Params.squad_spacing)
	for i in Params.squad_size:
		var slot := _icon_button(Params.squad_slot_size)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		row.add_child(slot)
		_slots.append(slot.get_child(0) as ShipIcon)
	return row


## Seção da nave auxiliar: título e a fileira de escolha (ou o aviso de bloqueio).
func _build_wingman() -> PanelContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", Params.squad_spacing)
	var title := UiFactory.make_subtitle("SQUAD_COMPANION_TITLE")
	title.add_theme_color_override("font_color", Params.quark_color)
	box.add_child(title)
	var text_width: float = Params.squad_hint_width - Params.ui_panel_padding * 2.0
	if not SaveGame.is_companion_unlocked():
		var locked := UiFactory.make_subtitle("")
		locked.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		locked.text = tr("SQUAD_COMPANION_LOCKED") % Params.companion_unlock_chapter
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.custom_minimum_size.x = text_width
		box.add_child(locked)
		return UiFactory.make_panel(box)
	var hint := UiFactory.make_subtitle("SQUAD_COMPANION_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = text_width
	hint.add_theme_font_size_override("font_size", Params.squad_description_font_size)
	box.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = Params.squad_wingman_columns
	grid.add_theme_constant_override("h_separation", Params.squad_spacing)
	grid.add_theme_constant_override("v_separation", Params.squad_spacing)
	box.add_child(grid)
	var options: Array = [null]
	options.append_array(_roster)
	for body in options:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_child(cell)
		var button := _icon_button(Params.squad_wingman_size)
		button.pressed.connect(_on_wingman_pressed.bind(body))
		cell.add_child(button)
		var icon := button.get_child(0) as ShipIcon
		icon.body = body
		var label := Label.new()
		label.text = tr("SQUAD_COMPANION_NONE") if body == null else tr(body.name_key)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", Params.squad_wingman_font_size)
		label.custom_minimum_size.x = Params.squad_wingman_size
		label.clip_text = true
		cell.add_child(label)
		_wingman_buttons.append(button)
		_wingman_icons.append(icon)
	return UiFactory.make_panel(box)


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
	row.add_child(texts)
	var name_label := Label.new()
	name_label.text = body.name_key
	name_label.add_theme_color_override("font_color", body.color if unlocked else Params.ui_muted_text_color)
	name_label.add_theme_font_size_override("font_size", Params.squad_name_font_size)
	texts.add_child(name_label)
	var description := UiFactory.make_subtitle(body.description_key)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", Params.squad_description_font_size)
	if not unlocked:
		description.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		description.text = tr("SQUAD_LOCKED_SHIP") % body.unlock_chapter
	texts.add_child(description)

	_cards.append(card)
	_card_icons.append(icon)
	return card


func _on_card_pressed(body: BodyData) -> void:
	if body in _chosen:
		_chosen.erase(body)
	elif _chosen.size() < Params.squad_size:
		_chosen.append(body)
		# Uma nave não pode estar no esquadrão e ser a auxiliar ao mesmo tempo
		if body == _companion:
			_companion = null
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if index < _chosen.size():
		_chosen.remove_at(index)
	_refresh()


func _on_wingman_pressed(body: BodyData) -> void:
	if body != null and (body in _chosen or not SaveGame.is_ship_unlocked(body)):
		return
	_companion = body
	_refresh()


## Espaços, número e marca de auxiliar nos cartões, escolha da auxiliar e botão Salvar.
func _refresh() -> void:
	for i in _slots.size():
		_slots[i].body = _chosen[i] if i < _chosen.size() else null
	for i in _roster.size():
		var position_in_squad: int = _chosen.find(_roster[i])
		_cards[i].set_pressed_no_signal(position_in_squad >= 0)
		_card_icons[i].number = position_in_squad + 1
		_card_icons[i].auxiliary = _roster[i] == _companion
	for i in _wingman_buttons.size():
		var body: BodyData = null if i == 0 else _roster[i - 1]
		var blocked: bool = body != null and (body in _chosen or not SaveGame.is_ship_unlocked(body))
		_wingman_buttons[i].disabled = blocked
		_wingman_buttons[i].modulate.a = 0.35 if blocked else 1.0
		_wingman_icons[i].locked = blocked
		_wingman_icons[i].highlighted = body == _companion
	_save_button.disabled = _chosen.size() != Params.squad_size


func _on_save_pressed() -> void:
	SaveGame.set_squad(_chosen)
	SaveGame.set_companion(_companion)
	_go_back()


func _go_back() -> void:
	SceneTransition.go_to(ScenePaths.MENU)


func _notification(what: int) -> void:
	# Botão Voltar do Android volta ao menu sem salvar
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
