extends Control
## Montar o esquadrão. No topo, 4 vagas do esquadrão (a 1ª começa a fase) e a vaga da
## auxiliar. Embaixo, a grade de naves (ícone grande, nome e ⓘ para inspecionar).
## Tocar numa nave a põe na 1ª vaga livre do esquadrão; com o esquadrão cheio, ela vai
## para a vaga da auxiliar. Tocar numa nave escolhida (ou na vaga dela) tira. A nave voa
## animada entre a grade e a vaga. Salvar grava; Voltar sai sem salvar.

const AUX_SLOT: int = -1
const OUTSIDE: int = -2

var _roster: Array[BodyData] = []
var _chosen: Array[BodyData] = []  # vagas do esquadrão (null = livre)
var _companion: BodyData
var _slot_icons: Array[ShipIcon] = []  # 0..3 esquadrão, 4 = auxiliar
var _cell_icons: Array[ShipIcon] = []
var _cell_buttons: Array[Button] = []
var _hint: Label
var _save_button: Button
var _hint_tween: Tween


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())

	_roster = (load(Params.roster_path) as FormationData).bodies
	_chosen = SaveGame.squad_formation().bodies.duplicate()
	while _chosen.size() < Params.squad_size:
		_chosen.append(null)
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

	column.add_child(_build_slots())
	_hint = UiFactory.make_subtitle("SQUAD_HINT")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = Params.squad_hint_width
	_hint.add_theme_font_size_override("font_size", Params.squad_hint_font_size)
	column.add_child(_hint)

	var grid := GridContainer.new()
	grid.columns = Params.squad_columns
	grid.add_theme_constant_override("h_separation", Params.squad_spacing)
	grid.add_theme_constant_override("v_separation", Params.squad_spacing)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	for body in _roster:
		grid.add_child(_make_cell(body))

	UiFactory.add_corner_back(self, _go_back)
	_save_button = UiFactory.make_primary_button("SQUAD_SAVE")
	_save_button.custom_minimum_size = Params.squad_button_size
	_save_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_save_button.pressed.connect(_on_save_pressed)
	column.add_child(_save_button)

	UiFactory.animate_in(center)
	_refresh()
	Tutorial.open_screen(self, &"squad_open")


## Fileira de vagas: 4 do esquadrão, divisória e a vaga da auxiliar (rótulos embaixo).
func _build_slots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Params.squad_spacing)
	for i in Params.squad_size:
		row.add_child(_slot_cell(i, str(i + 1), Params.ui_muted_text_color))
	var divider := ColorRect.new()
	divider.color = Color(Params.companion_powerup_color, 0.5)
	divider.custom_minimum_size = Vector2(3.0, Params.squad_slot_size * 0.8)
	divider.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(divider)
	row.add_child(_slot_cell(AUX_SLOT, tr("SQUAD_AUX_LABEL"), Params.companion_powerup_color))
	_slot_icons[Params.squad_size].auxiliary = true
	_slot_icons[Params.squad_size].locked = not SaveGame.is_companion_unlocked()
	return row


func _slot_cell(slot: int, label_text: String, label_color: Color) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	var button := _icon_button(Params.squad_slot_size)
	button.pressed.connect(_on_slot_pressed.bind(slot))
	cell.add_child(button)
	_slot_icons.append(button.get_child(0) as ShipIcon)
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
	var icon := ShipIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.pivot_offset = Vector2.ONE * side * 0.5
	button.add_child(icon)
	return button


## Célula da grade: ícone grande tocável, ⓘ no canto e o nome embaixo.
func _make_cell(body: BodyData) -> VBoxContainer:
	var unlocked: bool = SaveGame.is_ship_unlocked(body)
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = Params.squad_cell_width
	cell.add_theme_constant_override("separation", 2)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(Params.squad_cell_width, Params.squad_cell_icon_size)
	cell.add_child(holder)
	var button := _icon_button(Params.squad_cell_icon_size)
	button.position = Vector2((Params.squad_cell_width - Params.squad_cell_icon_size) * 0.5, 0.0)
	button.pressed.connect(_on_ship_pressed.bind(body))
	holder.add_child(button)
	var icon := button.get_child(0) as ShipIcon
	icon.body = body
	icon.locked = not unlocked
	_cell_icons.append(icon)
	_cell_buttons.append(button)
	# ⓘ: inspecionar (área de toque grande, ícone pequeno no canto)
	var info := Button.new()
	info.flat = true
	info.focus_mode = Control.FOCUS_NONE
	info.size = Vector2.ONE * Params.squad_info_touch_size
	info.position = Vector2(Params.squad_cell_width - Params.squad_info_touch_size, -Params.squad_info_touch_size * 0.25)
	info.draw.connect(_draw_info.bind(info))
	info.pressed.connect(_open_inspect.bind(body))
	info.pressed.connect(Audio.play.bind(&"ui_click"))
	holder.add_child(info)
	var name_label := Label.new()
	name_label.text = tr(body.name_key)
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", body.color if unlocked else Params.ui_muted_text_color)
	name_label.add_theme_font_size_override("font_size", UiFactory.fit_font_size(name_label.text, Params.squad_cell_width, Params.squad_cell_name_font_size))
	cell.add_child(name_label)
	return cell


## Ícone "i" num círculo, no canto superior direito da área de toque.
func _draw_info(button: Button) -> void:
	var radius: float = Params.squad_info_icon_radius
	var c := Vector2(button.size.x - radius - 6.0, radius + Params.squad_info_touch_size * 0.25)
	button.draw_circle(c, radius, Params.switch_icon_bg_color)
	button.draw_arc(c, radius, 0.0, TAU, 32, Params.ui_accent_color, 3.0)
	button.draw_circle(c + Vector2(0.0, -radius * 0.45), radius * 0.13, Params.ui_text_color)
	button.draw_line(c + Vector2(0.0, -radius * 0.15), c + Vector2(0.0, radius * 0.5), Params.ui_text_color, radius * 0.22)


func _open_inspect(body: BodyData) -> void:
	var dialog := ShipInspect.create(body, SaveGame.is_ship_unlocked(body), SaveGame.is_companion_unlocked())
	dialog.slot_of = _slot_of
	dialog.toggle_squad = _toggle_squad
	dialog.toggle_companion = _toggle_companion
	dialog.show_on(self)


## Toque na nave: tira se já está escolhida; senão põe na 1ª vaga livre (ou na auxiliar).
func _on_ship_pressed(body: BodyData) -> void:
	var index: int = _roster.find(body)
	if not SaveGame.is_ship_unlocked(body):
		_reject(index)
		return
	if _slot_of(body) != OUTSIDE:
		_remove(body)
		return
	var free: int = _chosen.find(null)
	if free >= 0:
		_place(body, free)
	elif _companion == null and SaveGame.is_companion_unlocked():
		_place(body, AUX_SLOT)
	else:
		_reject(index, "SQUAD_FULL")


## Toque numa vaga ocupada tira a nave dela.
func _on_slot_pressed(slot: int) -> void:
	var body: BodyData = _get_slot(slot)
	if body != null:
		_remove(body)
	elif slot == AUX_SLOT and not SaveGame.is_companion_unlocked():
		_flash_hint(tr("SQUAD_COMPANION_LOCKED") % Params.companion_unlock_chapter)


## Inspeção: pôr/tirar do esquadrão (com o esquadrão cheio, troca com a última vaga).
func _toggle_squad(body: BodyData) -> void:
	var slot: int = _slot_of(body)
	if slot >= 0:
		_remove(body)
		return
	if slot == AUX_SLOT:
		_companion = null
	if not _chosen.has(null):
		# Esquadrão cheio: a última nave volta para a grade e dá lugar a esta
		_remove(_chosen[Params.squad_size - 1])
	_place(body, _chosen.find(null))


## Inspeção: usar como auxiliar (sai do esquadrão se estava nele) ou deixar de usar.
func _toggle_companion(body: BodyData) -> void:
	if not SaveGame.is_companion_unlocked():
		return
	if _companion == body:
		_remove(body)
		return
	if _companion != null:
		_remove(_companion)
	var slot: int = _slot_of(body)
	if slot >= 0:
		_chosen[slot] = null
	_place(body, AUX_SLOT)


func _place(body: BodyData, slot: int) -> void:
	_set_slot(slot, body)
	Audio.play(&"ui_confirm")
	var target: ShipIcon = _slot_icon(slot)
	_fly(body, _cell_icons[_roster.find(body)], target, func() -> void: _pop(target))
	target.modulate.a = 0.0  # aparece quando a nave chega
	_refresh()


func _remove(body: BodyData) -> void:
	var slot: int = _slot_of(body)
	if slot == OUTSIDE:
		return
	var source: ShipIcon = _slot_icon(slot)
	_set_slot(slot, null)
	Audio.play(&"ui_back")
	var cell: ShipIcon = _cell_icons[_roster.find(body)]
	_fly(body, source, cell, func() -> void: _pop(cell))
	_refresh()


## Nave voando de um ícone a outro (cópia por cima de tudo, em tempo real).
func _fly(body: BodyData, from: Control, to: Control, arrived: Callable) -> void:
	var flyer := ShipIcon.new()
	flyer.body = body
	flyer.top_level = true
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.global_position = from.global_position
	flyer.size = from.size
	add_child(flyer)
	var tween := flyer.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flyer, "global_position", to.global_position, Params.squad_fly_seconds)
	tween.tween_property(flyer, "size", to.size, Params.squad_fly_seconds)
	tween.chain().tween_callback(func() -> void:
		flyer.queue_free()
		arrived.call())


## Ícone "pula" ao receber a nave.
func _pop(icon: ShipIcon) -> void:
	icon.modulate.a = 1.0
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2.ONE * Params.squad_pop_scale
	icon.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(icon, "scale", Vector2.ONE, Params.squad_fly_seconds)


## Recusa: a nave balança e a dica mostra o motivo.
func _reject(index: int, hint_key: String = "") -> void:
	Audio.play(&"ui_back")
	var icon: ShipIcon = _cell_icons[index]
	var tween := icon.create_tween()
	for i in 3:
		tween.tween_property(icon, "position:x", Params.squad_shake_px, 0.04)
		tween.tween_property(icon, "position:x", -Params.squad_shake_px, 0.04)
	tween.tween_property(icon, "position:x", 0.0, 0.04)
	if hint_key.is_empty():
		_flash_hint(tr("SQUAD_LOCKED_SHIP") % _roster[index].unlock_chapter)
	else:
		_flash_hint(tr(hint_key))


## Troca a dica por um aviso por alguns segundos.
func _flash_hint(text: String) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", Params.hud_warning_color)
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(Params.squad_hint_flash_seconds)
	_hint_tween.tween_callback(func() -> void:
		_hint.text = "SQUAD_HINT"
		_hint.remove_theme_color_override("font_color"))


func _slot_of(body: BodyData) -> int:
	if body != null and body == _companion:
		return AUX_SLOT
	var index: int = _chosen.find(body)
	return index if index >= 0 else OUTSIDE


func _get_slot(slot: int) -> BodyData:
	return _companion if slot == AUX_SLOT else _chosen[slot]


func _set_slot(slot: int, body: BodyData) -> void:
	if slot == AUX_SLOT:
		_companion = body
	else:
		_chosen[slot] = body


func _slot_icon(slot: int) -> ShipIcon:
	return _slot_icons[Params.squad_size if slot == AUX_SLOT else slot]


## Vagas, marcas na grade (número/A, apagada se escolhida) e botão Salvar.
func _refresh() -> void:
	for i in Params.squad_size:
		_slot_icons[i].body = _chosen[i]
	_slot_icons[Params.squad_size].body = _companion
	for i in _roster.size():
		var slot: int = _slot_of(_roster[i])
		_cell_icons[i].number = slot + 1 if slot >= 0 else 0
		_cell_icons[i].auxiliary = slot == AUX_SLOT
		_cell_icons[i].self_modulate.a = Params.squad_chosen_alpha if slot != OUTSIDE else 1.0
	# Basta 1 nave no esquadrão (as outras vagas podem ficar livres)
	_save_button.disabled = _chosen.count(null) == _chosen.size()


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
