class_name ShipInspect
extends Dialog
## Inspeção de uma nave (botão ⓘ na tela de esquadrão): nave grande, demonstração ao
## vivo da arma (principal ou auxiliar, com níveis, e o especial), descrição curta do modo
## escolhido e botões para pôr/tirar do esquadrão ou usar como auxiliar.
## Nave bloqueada: só a nave grande e como liberá-la (sem demonstração).

enum Mode { MAIN, COMPANION }

var ship: BodyData
var unlocked: bool = true
var companion_unlocked: bool = true
## Vaga atual da nave: 0..3 no esquadrão, -1 auxiliar, -2 fora (fornecida pela tela).
var slot_of: Callable
## Chamados pelos botões de ação; a tela devolve se deu certo.
var toggle_squad: Callable
var toggle_companion: Callable

var _mode: Mode = Mode.MAIN
var _level: int = 1
var _mode_buttons: Array[Button] = []
var _level_row: HBoxContainer
var _demo: WeaponDemo
var _description: Label
var _special_button: Button
var _special_wait: float = 0.0
var _squad_button: Button
var _companion_button: Button


static func create(body: BodyData, is_unlocked: bool, aux_unlocked: bool) -> ShipInspect:
	var dialog := ShipInspect.new()
	dialog.ship = body
	dialog.unlocked = is_unlocked
	dialog.companion_unlocked = aux_unlocked
	dialog.title_key = body.name_key
	dialog.dialog_layer = Params.dialog_layer
	return dialog


## Depois de configurar os Callables, adiciona à árvore (monta tudo no _ready).
func show_on(parent: Node) -> void:
	parent.add_child(self)


func _build_body() -> void:
	if not unlocked:
		_build_locked()
		return
	# Nave grande + escolha do modo (principal / auxiliar)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Params.dialog_spacing)
	body.add_child(header)
	var icon := ShipIcon.new()
	icon.body = ship
	icon.locked = not unlocked
	icon.custom_minimum_size = Vector2.ONE * Params.inspect_icon_size
	header.add_child(icon)
	var modes := VBoxContainer.new()
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", Params.dialog_spacing / 2)
	header.add_child(modes)
	for key in ["SQUAD_MAIN_LABEL", "SQUAD_AUX_LABEL"]:
		var button := UiFactory.make_button(key)
		button.custom_minimum_size = Vector2(0.0, Params.inspect_mode_button_height)
		button.pressed.connect(_set_mode.bind(_mode_buttons.size()))
		modes.add_child(button)
		_mode_buttons.append(button)

	_level_row = HBoxContainer.new()
	_level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_row.add_theme_constant_override("separation", Params.dialog_spacing)
	body.add_child(_level_row)

	_demo = WeaponDemo.new(Vector2(content_width, content_width * Params.inspect_demo_height_ratio))
	body.add_child(_demo)

	_description = Label.new()
	_description.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.add_theme_font_size_override("font_size", Params.inspect_text_font_size)
	body.add_child(_description)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Params.dialog_spacing)
	body.add_child(actions)
	_squad_button = _action_button(actions, _on_squad_pressed)
	_companion_button = _action_button(actions, _on_companion_pressed)
	_set_mode(Mode.MAIN)


## Nave bloqueada: nave grande com o cadeado e o capítulo que a libera.
func _build_locked() -> void:
	var center := CenterContainer.new()
	body.add_child(center)
	var icon := ShipIcon.new()
	icon.body = ship
	icon.locked = true
	icon.custom_minimum_size = Vector2.ONE * Params.inspect_icon_size * Params.inspect_locked_icon_scale
	center.add_child(icon)
	var text := UiFactory.make_subtitle("")
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.text = tr("SQUAD_LOCKED_SHIP") % ship.unlock_chapter
	body.add_child(text)


func _process(delta: float) -> void:
	super(delta)
	# Espera entre especiais na demonstração (tempo real), para não acumular efeitos
	if _special_wait > 0.0:
		_special_wait -= delta / maxf(Engine.time_scale, 0.01)
		if _special_wait <= 0.0 and _special_button != null:
			_special_button.disabled = false


func _action_button(row: HBoxContainer, action: Callable) -> Button:
	var button := UiFactory.make_button("")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, Params.inspect_mode_button_height)
	button.pressed.connect(action)
	row.add_child(button)
	return button


func _set_mode(mode: int) -> void:
	_mode = mode as Mode
	for i in _mode_buttons.size():
		_mode_buttons[i].theme_type_variation = &"PrimaryButton" if i == mode else &""
	_build_levels()
	_set_level(1)


## Bolinhas 1..N (5 na principal, 3 na auxiliar) para ver a arma em cada nível.
func _build_levels() -> void:
	for child in _level_row.get_children():
		child.queue_free()
	var count: int = ship.weapon.max_level() if _mode == Mode.MAIN else ship.weapon.companion_max_level()
	for i in count:
		var button := UiFactory.make_button("")
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2.ONE * Params.inspect_level_button_size
		button.pressed.connect(_set_level.bind(i + 1))
		_level_row.add_child(button)
	# Especial: só a arma principal tem
	if _mode == Mode.MAIN:
		_special_button = UiFactory.make_primary_button("INSPECT_SPECIAL")
		_special_button.custom_minimum_size = Vector2(Params.inspect_special_button_width, Params.inspect_level_button_size)
		UiFactory.fit_button_text(_special_button)
		_special_button.disabled = _special_wait > 0.0
		_special_button.pressed.connect(_on_special_pressed)
		_level_row.add_child(_special_button)
	else:
		_special_button = null


func _set_level(level: int) -> void:
	_level = level
	var index: int = 0
	for child in _level_row.get_children():
		if child.is_queued_for_deletion() or child == _special_button:
			continue
		(child as Button).theme_type_variation = &"PrimaryButton" if index == level - 1 else &""
		index += 1
	if _mode == Mode.MAIN:
		_demo.show_main(ship, level)
	else:
		_demo.show_companion(ship, level)
	_refresh_texts()


func _refresh_texts() -> void:
	if not unlocked:
		_description.text = tr("SQUAD_LOCKED_SHIP") % ship.unlock_chapter
	elif _mode == Mode.MAIN:
		_description.text = tr(ship.description_key)
	else:
		_description.text = "%s\n%s" % [tr(ship.companion_description_key), tr("INSPECT_UPGRADE") % tr(ship.companion_upgrade_key)]
	if _squad_button == null:
		return
	var slot: int = slot_of.call(ship)
	_squad_button.text = tr("INSPECT_REMOVE") if slot >= 0 else tr("INSPECT_ADD")
	_companion_button.text = tr("INSPECT_CLEAR_AUX") if slot == -1 else tr("INSPECT_SET_AUX")
	_companion_button.disabled = not companion_unlocked
	var width: float = (content_width - Params.dialog_spacing) * 0.5
	UiFactory.fit_button_text(_squad_button, width)
	UiFactory.fit_button_text(_companion_button, width)


func _on_special_pressed() -> void:
	Audio.play(&"special_fire")
	_demo.trigger_special(ship)
	_special_button.disabled = true
	_special_wait = Params.inspect_special_wait_seconds


func _on_squad_pressed() -> void:
	toggle_squad.call(ship)
	_refresh_texts()


func _on_companion_pressed() -> void:
	toggle_companion.call(ship)
	_refresh_texts()
