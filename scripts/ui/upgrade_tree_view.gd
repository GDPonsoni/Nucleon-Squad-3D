class_name UpgradeTreeView
extends Control
## Desenha a árvore de evolução do núcleo: nós em colunas (Ataque, Defesa, Suporte)
## ligados aos pré-requisitos, anel com o nível, ícone do efeito, cadeado nos travados
## e um selo nos que já dá para comprar. Tocar num nó o seleciona.

signal node_selected(node: UpgradeData)

const BRANCH_KEYS: PackedStringArray = ["UPGRADES_BRANCH_ATTACK", "UPGRADES_BRANCH_DEFENSE", "UPGRADES_BRANCH_SUPPORT"]

var tree: UpgradeTreeData
var selected: UpgradeData:
	set(value):
		selected = value
		queue_redraw()

var _pulse_node: UpgradeData
var _pulse_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: int = 0
	for node in tree.nodes:
		rows = maxi(rows, node.row + 1)
	custom_minimum_size = Vector2(Params.upgrade_tree_width,
		Params.upgrade_tree_header + (rows - 1) * Params.upgrade_row_gap + Params.upgrade_node_radius * 2.0 + Params.upgrade_level_font_size * 1.6)


func node_center(node: UpgradeData) -> Vector2:
	var x: float = size.x * 0.5 + (node.column - 1) * Params.upgrade_column_offset
	var y: float = Params.upgrade_tree_header + Params.upgrade_node_radius + node.row * Params.upgrade_row_gap
	return Vector2(x, y)


## Anel que se expande no nó recém-evoluído.
func play_pulse(node: UpgradeData) -> void:
	_pulse_node = node
	_pulse_left = Params.upgrade_pulse_seconds


func _process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left -= delta
	# Selos de "dá para comprar" e o nó selecionado pulsam devagar
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# No celular, o toque chega aqui como clique (emulação de mouse da interface)
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for node in tree.nodes:
		if click.position.distance_to(node_center(node)) <= Params.upgrade_node_radius * Params.upgrade_touch_scale:
			selected = node
			node_selected.emit(node)
			accept_event()
			return


func _draw() -> void:
	var levels: Dictionary = SaveGame.upgrades
	var companion: bool = SaveGame.is_companion_unlocked()
	_draw_branch_titles()
	# Ligações primeiro, por baixo dos nós
	for node in tree.nodes:
		for required in node.requires:
			var lit: bool = UpgradeTreeData.level_of(required, levels) > 0
			var color: Color = Color(required.color, 0.8) if lit else Color(Params.hud_dead_color, 0.6)
			draw_line(node_center(required), node_center(node), color, Params.upgrade_link_width)
	for node in tree.nodes:
		_draw_node(node, tree.is_available(node, levels, companion), UpgradeTreeData.level_of(node, levels))


func _draw_branch_titles() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = Params.upgrade_branch_font_size
	for column in BRANCH_KEYS.size():
		var color: Color = Params.ui_muted_text_color
		for node in tree.nodes:
			if node.column == column and node.row == 0:
				color = node.color
		var text: String = tr(BRANCH_KEYS[column])
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var x: float = size.x * 0.5 + (column - 1) * Params.upgrade_column_offset
		draw_string(font, Vector2(x - width * 0.5, font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_node(node: UpgradeData, available: bool, level: int) -> void:
	var center: Vector2 = node_center(node)
	var radius: float = Params.upgrade_node_radius
	var color: Color = node.color if available else Params.hud_dead_color
	if node == selected:
		var glow: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		draw_circle(center, radius * 1.22, Color(Color.WHITE, 0.12 * glow))
		draw_arc(center, radius * 1.18, 0.0, TAU, 48, Color(Color.WHITE, glow), 4.0)
	draw_circle(center, radius, Params.upgrade_node_bg_color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.35 if level == 0 else 0.6), Params.upgrade_ring_width)
	# Progresso do nível: arco desde o topo (nós sem limite mostram o anel cheio)
	if level > 0:
		var ratio: float = 1.0 if node.is_infinite() else float(level) / node.max_level
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, color, Params.upgrade_ring_width)
	UpgradeIcon.draw(self, node.stat, center, radius * 0.95, color if level > 0 or available else Color(color, 0.6))

	var font: Font = get_theme_default_font()
	var font_size: int = Params.upgrade_level_font_size
	var text: String = ("%d" % level) if node.is_infinite() else ("%d/%d" % [level, node.max_level])
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var text_color: Color = Params.powerup_color if node.is_maxed(level) else Params.ui_text_color
	draw_string(font, center + Vector2(-width * 0.5, radius + font_size * 1.15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color if available else Params.ui_muted_text_color)

	var badge := center + Vector2(radius * 0.74, -radius * 0.74)
	if not available:
		_draw_lock(badge, radius * 0.32)
	elif not node.is_maxed(level) and SaveGame.quarks >= node.cost(level + 1):
		# Selo de "dá para evoluir"
		var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(badge, radius * 0.24 * pulse, Params.powerup_color)
		draw_circle(badge, radius * 0.24 * pulse, Params.upgrade_node_bg_color, false, 3.0)

	if node == _pulse_node and _pulse_left > 0.0:
		var t: float = 1.0 - _pulse_left / Params.upgrade_pulse_seconds
		draw_arc(center, radius * (1.0 + t * 0.9), 0.0, TAU, 48, Color(node.color, 1.0 - t), 8.0 * (1.0 - t * 0.5))


func _draw_lock(center: Vector2, size: float) -> void:
	draw_circle(center, size * 1.15, Params.upgrade_node_bg_color)
	var color: Color = Params.ui_muted_text_color
	draw_arc(center + Vector2(0.0, -size * 0.2), size * 0.42, PI, TAU, 12, color, 3.0)
	draw_rect(Rect2(center + Vector2(-size * 0.55, -size * 0.2), Vector2(size * 1.1, size * 0.8)), color)
