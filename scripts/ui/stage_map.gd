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


## Posições dos nós como numa constelação: sobem da primeira ao chefe, mas espalhadas
## de forma irregular (sorteio fixo por capítulo) e afastadas o bastante para não se tocarem.
func _constellation() -> PackedVector2Array:
	var count: int = _nodes.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + planet_index * 31
	var top: float = Params.stage_map_margin_top
	var bottom: float = size.y - Params.stage_map_margin_bottom
	var step: float = (bottom - top) / maxf(count - 1, 1)
	var margin: float = Params.stage_node_size * 0.75
	var points := PackedVector2Array()
	var side: float = rng.randf_range(-1.0, 1.0)
	for i in count:
		# Sobe em ziguezague irregular: o lado muda quase sempre, com amplitude sorteada
		side = -signf(side) if rng.randf() < 0.8 else signf(side)
		var x: float = size.x * (0.5 + side * rng.randf_range(0.12, Params.stage_map_sway))
		var y: float = bottom - i * step + rng.randf_range(-0.22, 0.22) * step
		if i == count - 1:
			x = size.x * rng.randf_range(0.42, 0.58)
			y = top
		points.append(Vector2(clampf(x, margin, size.x - margin), y))
	# Relaxamento: afasta nós que ficaram perto demais
	var min_dist: float = Params.stage_node_size * 1.25
	for _pass in 12:
		for i in count:
			for j in range(i + 1, count):
				var delta: Vector2 = points[j] - points[i]
				var dist: float = delta.length()
				if dist < min_dist and dist > 0.01:
					var push: Vector2 = delta / dist * (min_dist - dist) * 0.5
					points[i] -= push
					points[j] += push
		for i in count:
			points[i].x = clampf(points[i].x, margin, size.x - margin)
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
