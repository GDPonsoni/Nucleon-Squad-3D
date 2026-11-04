extends Control
## Evolução do núcleo: gasta os quarks ganhos nas fases em nós da árvore (data/upgrade_tree.tres).
## Tocar num nó mostra o efeito atual, o do próximo nível e o custo; Evoluir compra o nível.

var _tree: UpgradeTreeData
var _view: UpgradeTreeView
var _scroll: ScrollContainer
var _balance: QuarkBadge
var _name_label: Label
var _level_label: Label
var _now_label: Label
var _next_label: Label
var _buy_button: Button
var _selected: UpgradeData


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	Audio.play_menu_music()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiFactory.apply_theme(self)
	add_child(Starfield.new())
	_tree = Session.upgrade_tree

	# Conteúdo rolável: cabe em telas mais baixas que a do S24
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center := CenterContainer.new()
	center.custom_minimum_size = get_viewport_rect().size
	_scroll.add_child(center)
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.upgrade_spacing)
	center.add_child(column)

	column.add_child(UiFactory.make_title("UPGRADES_TITLE"))
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", Params.upgrade_spacing)
	column.add_child(top)
	_balance = QuarkBadge.new()
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_balance.pressed.connect(_open_ad_offer)
	top.add_child(_balance)

	_view = UpgradeTreeView.new()
	_view.tree = _tree
	_view.node_selected.connect(_select)
	column.add_child(_view)

	column.add_child(_build_detail_panel())

	var back := UiFactory.make_button("MENU_BACK")
	back.pressed.connect(_go_back)
	column.add_child(back)

	UiFactory.animate_in(center)
	# Começa no primeiro nó que dá para evoluir (ou no primeiro da árvore)
	_select(_first_suggestion())


func _build_detail_panel() -> PanelContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = Params.upgrade_detail_width
	box.add_theme_constant_override("separation", Params.upgrade_detail_spacing)

	var header := HBoxContainer.new()
	box.add_child(header)
	_name_label = Label.new()
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.custom_minimum_size.x = Params.upgrade_detail_width * 0.55
	_name_label.add_theme_font_size_override("font_size", Params.upgrade_name_font_size)
	header.add_child(_name_label)
	_level_label = UiFactory.make_subtitle("")
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(_level_label)

	_now_label = _detail_line()
	box.add_child(_now_label)
	_next_label = _detail_line()
	box.add_child(_next_label)

	_buy_button = UiFactory.make_primary_button("")
	_buy_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_buy_button.custom_minimum_size = Vector2(Params.upgrade_detail_width, Params.upgrade_buy_height)
	# Textos longos (requisitos) quebram linha em vez de alargar o botão
	_buy_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy_button.add_theme_font_size_override("font_size", Params.upgrade_buy_font_size)
	_buy_button.pressed.connect(_on_buy_pressed)
	box.add_child(_buy_button)
	return UiFactory.make_panel(box)


func _detail_line() -> Label:
	var label := UiFactory.make_subtitle("")
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = Params.upgrade_detail_width
	label.add_theme_font_size_override("font_size", Params.upgrade_detail_font_size)
	return label


func _first_suggestion() -> UpgradeData:
	for node in _tree.nodes:
		var level: int = SaveGame.upgrade_level(node)
		if _is_available(node) and not node.is_maxed(level) and SaveGame.quarks >= node.cost(level + 1):
			return node
	return _tree.nodes[0]


func _is_available(node: UpgradeData) -> bool:
	return _tree.is_available(node, SaveGame.upgrades, SaveGame.is_companion_unlocked())


func _select(node: UpgradeData) -> void:
	_selected = node
	_view.selected = node
	_refresh()


## Atualiza saldo e painel do nó selecionado.
func _refresh() -> void:
	_balance.set_amount(SaveGame.quarks, false)
	var node: UpgradeData = _selected
	var level: int = SaveGame.upgrade_level(node)
	_name_label.text = tr(node.name_key)
	_name_label.add_theme_font_size_override("font_size", UiFactory.fit_font_size(_name_label.text, Params.upgrade_detail_width * 0.55, Params.upgrade_name_font_size))
	_name_label.add_theme_color_override("font_color", node.color)
	_level_label.text = (tr("UPGRADES_LEVEL_INFINITE") % level) if node.is_infinite() else (tr("UPGRADES_LEVEL") % [level, node.max_level])
	_now_label.text = tr("UPGRADES_NOW") % _effect(node, level) if level > 0 else tr("UPGRADES_NONE")
	_now_label.add_theme_color_override("font_color", Params.ui_text_color if level > 0 else Params.ui_muted_text_color)

	if node.is_maxed(level):
		_next_label.text = tr("UPGRADES_MAXED")
		_next_label.add_theme_color_override("font_color", Params.powerup_color)
		_buy_button.text = tr("UPGRADES_MAXED")
		_buy_button.disabled = true
		return
	_next_label.text = tr("UPGRADES_NEXT") % _effect(node, level + 1)
	_next_label.add_theme_color_override("font_color", node.color.lightened(0.2))
	var price: int = node.cost(level + 1)
	if not _is_available(node):
		_buy_button.text = _requirement_text(node)
		_buy_button.disabled = true
	elif SaveGame.quarks < price:
		# Fica ativo: tocar explica a falta de saldo e oferece ganhar quarks
		_buy_button.text = tr("UPGRADES_NOT_ENOUGH") % [price, price - SaveGame.quarks]
		_buy_button.disabled = false
	else:
		_buy_button.text = tr("UPGRADES_BUY") % price
		_buy_button.disabled = false


## Descrição do nó com o valor do efeito no nível dado.
func _effect(node: UpgradeData, level: int) -> String:
	var second: String = node.second_value_text(level)
	if second.is_empty():
		return tr(node.description_key) % node.value_text(level)
	return tr(node.description_key) % [node.value_text(level), second]


func _requirement_text(node: UpgradeData) -> String:
	if node.requires_companion and not SaveGame.is_companion_unlocked():
		return tr("UPGRADES_REQUIRES_COMPANION") % Params.companion_unlock_chapter
	var missing := PackedStringArray()
	for required in node.requires:
		if SaveGame.upgrade_level(required) < 1:
			missing.append(tr(required.name_key))
	return tr("UPGRADES_REQUIRES") % ", ".join(missing)


func _on_buy_pressed() -> void:
	var level: int = SaveGame.upgrade_level(_selected)
	var price: int = _selected.cost(level + 1)
	if _is_available(_selected) and not _selected.is_maxed(level) and SaveGame.quarks < price:
		Audio.play(&"ui_back")
		_open_ad_offer(tr("UPGRADES_NO_QUARKS") % (price - SaveGame.quarks))
		return
	if SaveGame.buy_upgrade(_selected):
		Audio.play(&"ui_confirm")
		_view.play_pulse(_selected)
		_refresh()


## Janela de ganhar quarks (toque no saldo ou compra sem saldo).
func _open_ad_offer(warning: String = "") -> void:
	var popup := AdOfferPopup.open(self, warning)
	popup.quarks_changed.connect(func() -> void:
		_balance.set_amount(SaveGame.quarks, true)
		_refresh())


func _go_back() -> void:
	var path: String = Session.upgrades_return_path
	Session.upgrades_return_path = ScenePaths.MENU
	SceneTransition.go_to(path)


func _notification(what: int) -> void:
	# Botão Voltar do Android volta para a tela anterior
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
