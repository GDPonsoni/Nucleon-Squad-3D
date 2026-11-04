extends Control
## Montar o esquadrão: 4 espaços em ordem (o 1º começa a fase), o espaço opcional da
## nave auxiliar e cartões com todas as naves. Tocar num cartão adiciona/remove a nave
## do esquadrão; tocar num espaço a remove. Tocar no espaço auxiliar entra no modo de
## escolha da auxiliar (o próximo cartão tocado vira a auxiliar; tocar de novo esvazia).
## Naves e o espaço auxiliar ainda não liberados aparecem com cadeado.
## Salvar só fica ativo com o esquadrão completo.

var _roster: Array[BodyData] = []
var _chosen: Array[BodyData] = []
var _companion: BodyData
var _picking_companion: bool = false
var _slots: Array[ShipIcon] = []
var _companion_slot: ShipIcon
var _cards: Array[Button] = []
var _card_icons: Array[ShipIcon] = []
var _hint: Label
var _save_button: Button


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
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
	_hint = UiFactory.make_subtitle("SQUAD_HINT")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = Params.squad_hint_width
	column.add_child(_hint)

	column.add_child(_build_slots())

	# Cartões com todas as naves
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
	var back := UiFactory.make_button("MENU_BACK")
	back.custom_minimum_size = Params.squad_button_size
	back.pressed.connect(_go_back)
	buttons.add_child(back)
	_save_button = UiFactory.make_button("SQUAD_SAVE")
	_save_button.custom_minimum_size = Params.squad_button_size
	_save_button.pressed.connect(_on_save_pressed)
	buttons.add_child(_save_button)

	UiFactory.animate_in(center)
	_refresh()


## Espaços do esquadrão em ordem e, separado, o espaço da nave auxiliar.
func _build_slots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Params.squad_spacing)
	for i in Params.squad_size:
		var slot := _slot_button()
		slot.pressed.connect(_on_slot_pressed.bind(i))
		row.add_child(slot)
		_slots.append(slot.get_child(0) as ShipIcon)

	var divider := Control.new()
	divider.custom_minimum_size.x = Params.squad_companion_gap
	row.add_child(divider)

	var aux := VBoxContainer.new()
	aux.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(aux)
	var slot := _slot_button()
	slot.pressed.connect(_on_companion_slot_pressed)
	aux.add_child(slot)
	_companion_slot = slot.get_child(0) as ShipIcon
	_companion_slot.auxiliary = true
	var label := UiFactory.make_subtitle("SQUAD_COMPANION")
	label.add_theme_color_override("font_color", Params.quark_color)
	label.add_theme_font_size_override("font_size", Params.squad_description_font_size)
	aux.add_child(label)
	return row


func _slot_button() -> Button:
	var slot := Button.new()
	slot.flat = true
	slot.focus_mode = Control.FOCUS_NONE
	slot.custom_minimum_size = Vector2.ONE * Params.squad_slot_size
	var icon := ShipIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(icon)
	return slot


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
	if _picking_companion:
		# A auxiliar não pode ser uma nave do esquadrão
		if body in _chosen:
			_hint.text = tr("SQUAD_COMPANION_IN_SQUAD")
			return
		_companion = body
		_picking_companion = false
	elif body in _chosen:
		_chosen.erase(body)
	elif _chosen.size() < Params.squad_size:
		_chosen.append(body)
		# Colocar a auxiliar no esquadrão esvazia o espaço auxiliar
		if body == _companion:
			_companion = null
	_refresh()


func _on_slot_pressed(index: int) -> void:
	_picking_companion = false
	if index < _chosen.size():
		_chosen.remove_at(index)
	_refresh()


## 1º toque: escolher a auxiliar. 2º toque (já escolhendo): deixar o espaço vazio.
func _on_companion_slot_pressed() -> void:
	if not SaveGame.is_companion_unlocked():
		_hint.text = tr("SQUAD_COMPANION_LOCKED") % Params.companion_unlock_chapter
		return
	if _picking_companion:
		_companion = null
		_picking_companion = false
	else:
		_picking_companion = true
	_refresh()


## Espaços, número de cada cartão, dica e estado do botão Salvar.
func _refresh() -> void:
	for i in _slots.size():
		_slots[i].body = _chosen[i] if i < _chosen.size() else null
	var companion_unlocked: bool = SaveGame.is_companion_unlocked()
	_companion_slot.body = _companion
	_companion_slot.locked = not companion_unlocked
	_companion_slot.highlighted = _picking_companion
	for i in _roster.size():
		var position_in_squad: int = _chosen.find(_roster[i])
		# No modo de escolha da auxiliar, todos os cartões liberados ficam "soltos"
		_cards[i].set_pressed_no_signal(position_in_squad >= 0 and not _picking_companion)
		_card_icons[i].number = position_in_squad + 1
		_card_icons[i].auxiliary = _roster[i] == _companion
		# Escolhendo a auxiliar: naves do esquadrão ficam apagadas
		_cards[i].modulate.a = 0.4 if _picking_companion and position_in_squad >= 0 else 1.0
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.text = tr("SQUAD_COMPANION_HINT") if _picking_companion else tr("SQUAD_HINT")
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
