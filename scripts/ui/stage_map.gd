class_name StageMap
extends Control
## Página de um planeta no seletor: arte ao fundo e um caminho sinuoso de nós (as fases),
## da primeira, embaixo, ao chefe, no alto. A parte do caminho já percorrida acende.

## Toque numa fase liberada ainda não concluída: começa direto.
signal stage_chosen(planet_index: int, stage_index: int)
## Toque numa fase concluída: abre a ficha (estrelas, recorde, jogar).
signal stage_info_requested(planet_index: int, stage_index: int)

var planet_index: int = 0
var _planet: PlanetData
var _nodes: Array[StageNode] = []
var _art: ChapterArt
var _points := PackedVector2Array()
var _dust := PackedVector2Array()


func setup(index: int) -> void:
	planet_index = index
	_planet = Session.campaign.planets[index]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = ChapterArt.new()
	_art.chapter = index
	_art.planet = _planet
	_art.modulate.a = Params.stage_map_art_alpha
	add_child(_art)
	var next_index: int = _next_stage()
	var last: int = _planet.stages.size() - 1
	for s in _planet.stages.size():
		var stage: StageData = _planet.stages[s]
		var node := StageNode.new()
		node.color = _stage_tone(s, last)
		node.label = str(s + 1)
		node.unlocked = SaveGame.is_unlocked(index, s)
		node.completed = SaveGame.is_completed(stage.id)
		node.is_next = s == next_index
		node.stars = SaveGame.stage_stars(stage)
		node.kind = StageNode.Kind.NORMAL if stage.boss == null else (StageNode.Kind.BOSS if s == last else StageNode.Kind.MIDBOSS)
		node.pressed.connect(_on_node_pressed.bind(s, node))
		add_child(node)
		_nodes.append(node)
	# Altura fixa pelo número de fases: a página rola em vez de apertar os nós
	custom_minimum_size.y = _top_y() + (_nodes.size() - 1) * Params.stage_map_step + Params.stage_map_margin_bottom
	resized.connect(_layout)
	_layout()


## Monta a página rolável de um planeta: mapa dentro de um ScrollContainer só vertical,
## já posicionado na fase sugerida.
static func build_page(index: int, on_chosen: Callable, on_info: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var map := StageMap.new()
	map.setup(index)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.stage_chosen.connect(on_chosen)
	map.stage_info_requested.connect(on_info)
	scroll.add_child(map)
	scroll.resized.connect(func() -> void: map.focus_scroll(scroll), CONNECT_ONE_SHOT)
	return scroll


## Rola até a fase sugerida (ou o chefe, se o capítulo está completo) ficar no meio.
func focus_scroll(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	var target: int = _next_stage()
	if target < 0:
		target = _nodes.size() - 1
	if target < _nodes.size():
		var y: float = _nodes[target].position.y + _nodes[target].size.y * 0.5
		scroll.scroll_vertical = int(maxf(y - scroll.size.y * 0.5, 0.0))


func _top_y() -> float:
	var boss_half: float = Params.stage_node_size * Params.stage_node_boss_scale * 0.5
	return maxf(Params.stage_map_margin_top, Params.stage_map_art_top + Params.chapter_art_size.y + boss_half + Params.stage_map_art_gap)


## Primeira fase liberada e ainda não concluída (a sugerida); -1 se o capítulo está completo.
func _next_stage() -> int:
	for s in _planet.stages.size():
		if SaveGame.is_unlocked(planet_index, s) and not SaveGame.is_completed(_planet.stages[s].id):
			return s
	return -1


func _on_node_pressed(stage_index: int, node: StageNode) -> void:
	if not node.unlocked:
		Audio.play(&"ui_back")
		Haptics.play(&"tick")
		node.shake()
		return
	if node.completed:
		stage_info_requested.emit(planet_index, stage_index)
	else:
		stage_chosen.emit(planet_index, stage_index)


func _layout() -> void:
	if _nodes.is_empty() or size.x <= 0.0:
		return
	_art.size = Params.chapter_art_size
	_art.position = Vector2((size.x - _art.size.x) * 0.5, Params.stage_map_art_top)
	_points = _constellation()
	for i in _nodes.size():
		_nodes[i].position = _points[i] - _nodes[i].size * 0.5
	# Estrelinhas de fundo, fixas por capítulo
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + planet_index
	_dust.clear()
	for k in Params.stage_map_dust:
		_dust.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
	queue_redraw()


## Cor de cada nó: a do planeta com o matiz deslocado aos poucos ao longo do caminho.
func _stage_tone(stage_index: int, last: int) -> Color:
	var base: Color = _planet.star_color
	var t: float = float(stage_index) / maxf(last, 1)
	var hue: float = fposmod(base.h + (t - 0.5) * Params.stage_map_hue_span, 1.0)
	return Color.from_hsv(hue, clampf(base.s, 0.35, 0.65), clampf(base.v, 0.8, 1.0))


## Posições dos nós numa onda suave que sobe da primeira fase ao chefe (alterna os lados
## com ritmo fixo, sem sorteio). O topo fica abaixo da arte do planeta, para o chefe não cobri-la.
func _constellation() -> PackedVector2Array:
	var count: int = _nodes.size()
	var bottom: float = size.y - Params.stage_map_margin_bottom
	var step: float = Params.stage_map_step
	var margin: float = Params.stage_node_size * 0.75
	var points := PackedVector2Array()
	for i in count:
		var wave: float = sin(i * Params.stage_map_wave_speed + planet_index * 1.3)
		var x: float = size.x * (0.5 + wave * Params.stage_map_sway)
		var y: float = bottom - i * step
		if i == count - 1:
			x = size.x * 0.5
		points.append(Vector2(clampf(x, margin, size.x - margin), y))
	return points


func _draw() -> void:
	var tint: Color = _planet.star_color
	for dust in _dust:
		draw_circle(dust, 2.0, Color(tint, 0.25))
	# Ligações extras, bem fracas, só para parecer uma constelação
	for i in range(0, _points.size() - 2, 3):
		draw_line(_points[i], _points[i + 2], Color(Params.ui_muted_text_color, 0.12), 2.0, true)
	# Linhas retas entre fases seguidas; acendem as já percorridas
	for i in range(_points.size() - 1):
		var done: bool = SaveGame.is_completed(_planet.stages[i].id)
		if done:
			draw_line(_points[i], _points[i + 1], Color(tint, 0.25), 14.0, true)
			draw_line(_points[i], _points[i + 1], Color(tint, 0.9), 4.0, true)
		else:
			draw_line(_points[i], _points[i + 1], Color(Params.ui_muted_text_color, 0.3), 3.0, true)
