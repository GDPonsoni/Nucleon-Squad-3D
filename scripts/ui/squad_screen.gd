extends Control
## Montar o esquadrão: 4 espaços em ordem (o 1º começa a fase) e cartões com todas
## as naves. Tocar num cartão adiciona/remove a nave; tocar num espaço a remove.
## Salvar só fica ativo com o esquadrão completo.

var _roster: Array[BodyData] = []
var _chosen: Array[BodyData] = []
var _slots: Array[ShipIcon] = []
var _cards: Array[Button] = []
var _card_icons: Array[ShipIcon] = []
var _save_button: Button


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())

	_roster = (load(Params.roster_path) as FormationData).bodies
	_chosen = SaveGame.squad_formation().bodies.duplicate()

	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.squad_spacing)
	var center := UiFactory.make_centered(column)
	add_child(center)
	column.add_child(UiFactory.make_title("SQUAD_TITLE"))
	var hint := UiFactory.make_subtitle("SQUAD_HINT")
	column.add_child(hint)

	# Espaços do esquadrão, em ordem
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", Params.squad_spacing)
	column.add_child(slot_row)
	for i in Params.squad_size:
		var slot := Button.new()
		slot.flat = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2.ONE * Params.squad_slot_size
		slot.pressed.connect(_on_slot_pressed.bind(i))
		var icon := ShipIcon.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(icon)
		slot_row.add_child(slot)
		_slots.append(icon)

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


func _make_card(body: BodyData) -> Button:
	var card := UiFactory.make_button("")
	card.custom_minimum_size = Params.squad_card_size
	card.toggle_mode = true
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
	name_label.add_theme_color_override("font_color", body.color)
	name_label.add_theme_font_size_override("font_size", Params.squad_name_font_size)
	texts.add_child(name_label)
	var description := UiFactory.make_subtitle(body.description_key)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", Params.squad_description_font_size)
	texts.add_child(description)

	_cards.append(card)
	_card_icons.append(icon)
	return card


func _on_card_pressed(body: BodyData) -> void:
	if body in _chosen:
		_chosen.erase(body)
	elif _chosen.size() < Params.squad_size:
		_chosen.append(body)
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if index < _chosen.size():
		_chosen.remove_at(index)
		_refresh()


## Espaços, número de cada cartão e estado do botão Salvar.
func _refresh() -> void:
	for i in _slots.size():
		_slots[i].body = _chosen[i] if i < _chosen.size() else null
	for i in _roster.size():
		var position_in_squad: int = _chosen.find(_roster[i])
		_cards[i].set_pressed_no_signal(position_in_squad >= 0)
		_card_icons[i].number = position_in_squad + 1
	_save_button.disabled = _chosen.size() != Params.squad_size


func _on_save_pressed() -> void:
	SaveGame.set_squad(_chosen)
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
