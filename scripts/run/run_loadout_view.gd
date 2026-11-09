class_name RunLoadoutView
extends VBoxContainer
## Espaços de arma do modo roguelike: "2/3", um ícone por espaço (vazio = tracejado) e o
## nível de cada arma em tracinhos embaixo. Usado na pausa e na tela de subir de nível.

var _progress: RunProgress
var compact: bool = false  # versão menor, sem nomes (câmera lenta)


static func build(progress: RunProgress, is_compact: bool = false) -> RunLoadoutView:
	var view := RunLoadoutView.new()
	view._progress = progress
	view.compact = is_compact
	return view


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := UiFactory.make_subtitle("")
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.text = tr("RUN_SLOTS") % [_progress.slots_used(), _progress.mode.weapon_slots]
	if not compact:  # na câmera lenta só os ícones (o nível já está no HUD)
		add_child(caption)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	add_child(row)
	for i in _progress.mode.weapon_slots:
		var ship: BodyData = _progress.owned[i] if i < _progress.owned.size() else null
		row.add_child(_slot(ship))


func _slot(ship: BodyData) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var slot_size: float = Params.run_slot_compact_size if compact else Params.run_slot_size
	var icon := ShipIcon.new()
	icon.custom_minimum_size = Vector2.ONE * slot_size
	icon.body = ship
	icon.highlighted = ship != null and ship == _progress.special_weapon() and _progress.owned.size() > 1
	icon.set_meta("ship", ship)
	column.add_child(icon)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(slot_size, Params.run_slot_pip_size.y + 4.0)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void: _draw_pips(pips, ship))
	column.add_child(pips)
	if ship != null and not compact:
		var name_label := UiFactory.make_subtitle(ship.name_key)
		name_label.add_theme_font_size_override("font_size", Params.run_card_detail_font_size)
		column.add_child(name_label)
	return column


## Um tracinho por nível possível; os ganhos na cor da arma.
func _draw_pips(canvas: Control, ship: BodyData) -> void:
	if ship == null:
		return
	var total: int = ship.weapon.max_level()
	var level: int = _progress.weapon_level(ship)
	var w: float = Params.run_slot_pip_size.x
	var gap: float = w * 0.5
	var width: float = total * w + (total - 1) * gap
	var x: float = (canvas.size.x - width) * 0.5
	for i in total:
		var color: Color = ship.color if i < level else Params.run_slot_empty_color
		canvas.draw_rect(Rect2(x + i * (w + gap), 2.0, w, Params.run_slot_pip_size.y), color)
