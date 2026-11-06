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
		node.color = _planet.star_color
		node.label = str(s + 1)
		node.unlocked = SaveGame.is_unlocked(index, s)
		node.completed = SaveGame.is_completed(stage.id)
		node.is_next = s == next_index
		node.stars = SaveGame.stage_stars(stage)
		node.kind = StageNode.Kind.NORMAL if stage.boss == null else (StageNode.Kind.BOSS if s == last else StageNode.Kind.MIDBOSS)
		node.pressed.connect(_on_node_pressed.bind(s, node))
		add_child(node)
		_nodes.append(node)
	resized.connect(_layout)
	_layout()


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
	var count: int = _nodes.size()
	var top: float = Params.stage_map_margin_top
	var span: float = maxf(size.y - top - Params.stage_map_margin_bottom, 1.0)
	_points.clear()
	for i in count:
		var t: float = float(i) / maxf(count - 1, 1)
		# Zigue-zague: lados alternados, com amplitude variando um pouco para não ficar mecânico
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = size.x * (0.5 + side * Params.stage_map_sway * (0.85 + 0.15 * sin(i * Params.stage_map_wave)))
		if i == count - 1:
			x = size.x * 0.5
		var point := Vector2(x, size.y - Params.stage_map_margin_bottom - t * span)
		_points.append(point)
		_nodes[i].position = point - _nodes[i].size * 0.5
	queue_redraw()


func _draw() -> void:
	var tint: Color = _planet.star_color
	for i in range(_points.size() - 1):
		var done: bool = SaveGame.is_completed(_planet.stages[i].id)
		var color: Color = Color(tint, 0.85) if done else Color(Params.ui_muted_text_color, 0.3)
		var a: Vector2 = _points[i]
		var b: Vector2 = _points[i + 1]
		var lift: float = (a.y - b.y) * 0.5
		var curve := PackedVector2Array()
		for k in 17:
			var u: float = k / 16.0
			var p0: Vector2 = a
			var p1: Vector2 = a + Vector2(0.0, -lift)
			var p2: Vector2 = b + Vector2(0.0, lift)
			curve.append(p0.bezier_interpolate(p1, p2, b, u))
		draw_polyline(curve, color, 8.0 if done else 5.0, true)
