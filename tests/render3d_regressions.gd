extends Node
## Ver render3d_regressions_run.gd. Sai com código 1 se algum caso falhar.
## Em headless não há imagem: os casos provam a estrutura (o que é desenhado por quem), não o visual.

var _failures: int = 0
var _player: Player  # mantida invulnerável durante as esperas (a partida pausaria ao morrer)


func _ready() -> void:
	SaveGame.persistent = false
	SaveGame.settings["tips_enabled"] = false
	SaveGame.unlock_everything = true
	var main: Viewport = get_viewport()
	var mask_before: int = main.canvas_cull_mask
	_check(not Renderer3D.active, "sem partida não há visão 3D ativa")

	Session.select(0, 0)
	var game: Node2D = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	_hold_finger(game)
	var state: MatchState = game.get("state")
	var player: Player = game.get("player")
	_player = player
	var renderer: Renderer3D = game.get("renderer")
	_check(renderer != null and Renderer3D.active, "a partida monta a visão 3D")
	if renderer == null:
		_finish()
		return

	# Camada 2D no plano de jogo (GroundFx): a tela não desenha o mundo 2D, o SubViewport sim
	_check(main.canvas_cull_mask & GroundFx.WORLD_LAYER == 0, "a tela principal não desenha a camada do jogo")
	_check(renderer.ground_fx.viewport.world_2d == main.world_2d, "o plano de jogo mostra o mesmo mundo 2D")
	_check(renderer.ground_fx.viewport.canvas_cull_mask == GroundFx.WORLD_LAYER, "o plano de jogo só desenha a camada do jogo")
	_check(Vector2(renderer.ground_fx.viewport.size_2d_override) == game.get_viewport_rect().size, "a textura do plano cobre a arena inteira")
	_check(_wrong_layer(game) == 0, "todo nó 2D do jogo está na camada do plano (%d fora)" % _wrong_layer(game))
	var hud_items: int = _count_layer(game.get("hud"), GroundFx.WORLD_LAYER)
	_check(hud_items == 0, "o HUD continua na tela, fora do plano (%d dentro)" % hud_items)

	# Câmera: a nave fica dentro da tela e o seguimento respeita o limite
	await _wait(game, 0.4)
	var view: Rect2 = game.get_viewport_rect()
	_check(view.has_point(renderer.project_to_screen(player.position)), "a nave aparece dentro da tela")
	player.place_at(Vector2(view.size.x - 60.0, 400.0))
	await _wait(game, 1.5)
	var offset: Vector2 = renderer.follow_offset()
	_check(offset.x > 1.0 and offset.y < -1.0, "a câmera acompanha a nave (deslocamento %s)" % offset)
	_check(absf(offset.x) <= Params.camera_follow_max_px + 0.01 and absf(offset.y) <= Params.camera_follow_max_px + 0.01, "seguimento dentro do máximo")
	for corner: Vector2 in [Vector2.ZERO, Vector2(view.size.x, 0.0), Vector2(0.0, player.bottom_limit), Vector2(view.size.x, player.bottom_limit)]:
		_check(view.grow(1.0).has_point(renderer.project_to_screen(corner)), "canto %s da área jogável na tela com a câmera deslocada" % corner)
	_check(renderer.camera.global_transform.is_equal_approx(renderer.rig.camera_transform(offset)), "a Camera3D usa a conta do CameraRig")
	player.place_at(Vector2(view.size.x * 0.5, player.bottom_limit - 200.0))

	# Jogador e auxiliar
	var views: EntityViews = renderer.entities
	var hull: MeshInstance3D = views.get("_hull")
	var nucleus: MeshInstance3D = views.get("_nucleus")
	await _wait(game, Params.body_rebuild_seconds + 0.3)
	_check(hull.visible and hull.mesh == ModelLibrary.ship(player.body), "casco da nave ativa visível")
	_check(nucleus.visible, "núcleo visível")
	_check(hull.position.is_equal_approx(renderer.rig.to_world(player.position)), "casco na posição da nave")

	# Troca voluntária: o corpo que sai recolhe em 3D; o novo usa a malha do corpo novo
	if state.bodies.size() > 1:
		var old_body: BodyData = player.body
		game.call("_on_body_chosen", 1)
		await _frames(3)
		_check(_visible_count(views.get("_fx_hulls")) == 1, "o corpo que sai da troca recolhe em 3D")
		_check(player.body != old_body and hull.mesh == ModelLibrary.ship(player.body), "casco troca para o corpo novo")
		await _wait(game, Params.exit_seconds + 0.3)
		_check(_visible_count(views.get("_fx_hulls")) == 0, "o efeito da troca termina")

	# Inimigos e projéteis: um modelo por inimigo ativo, uma instância por tiro
	await _wait(game, 9.0)
	var enemies: NodePool = game.get("enemies")
	_check(not enemies.active.is_empty(), "há inimigos na fase")
	_check(_visible_count(views.get("_enemy_views")) == _visible_items(enemies), "um modelo por inimigo ativo (%d x %d)" % [_visible_count(views.get("_enemy_views")), _visible_items(enemies)])
	for item in enemies.active:
		var enemy := item as Enemy
		var view_3d: MeshInstance3D = (views.get("_enemy_views") as Dictionary).get(enemy)
		_check(view_3d != null and view_3d.mesh != null and view_3d.position.is_equal_approx(renderer.rig.to_world(enemy.position)), "modelo do inimigo na posição dele")
	var player_bullets: NodePool = game.get("player_bullets")
	var enemy_bullets: NodePool = game.get("enemy_bullets")
	var shot: Bullet = enemy_bullets.acquire() as Bullet
	shot.activate(Vector2(200.0, 300.0), Vector2(0.0, 10.0), 1.0, Vector2(24.0, 24.0), Color.RED, Bullet.Shape.CIRCLE)
	await _frames(2)
	_check(renderer.bullets.visible_count() == player_bullets.active.size() + enemy_bullets.active.size(),
		"uma instância por projétil (%d x %d)" % [renderer.bullets.visible_count(), player_bullets.active.size() + enemy_bullets.active.size()])

	# Itens
	var power_ups: NodePool = game.get("power_ups")
	var item_up := power_ups.acquire() as PowerUp
	item_up.activate(Vector2(300.0, 500.0), PowerUp.Kind.HEAL)
	await _frames(2)
	_check(_visible_count(views.get("_item_views")) == power_ups.active.size(), "um modelo por item ativo")

	# Chefe: peças montadas ao entrar, na camada do plano (avisos e feixes), desmontadas ao morrer
	var boss_data := load("res://data/bosses/boss_2.tres") as BossData
	game.call("_spawn_boss", boss_data)
	await _wait(game, Params.boss_warning_seconds + 0.3)
	var boss: Boss = game.get("boss")
	_check(boss != null, "chefe entrou")
	if boss != null:
		var root: Node3D = views.get("_boss_root")
		var expected: int = 4 + boss_data.spikes + boss_data.plates + boss_data.turrets + 6
		_check(root != null and root.get_child_count() == expected, "chefe com %d peças" % expected)
		_check(boss.visibility_layer == GroundFx.WORLD_LAYER, "avisos e feixes do chefe vão para o plano de jogo")
		await _wait(game, 5.0)
		_check(root.position.is_equal_approx(renderer.rig.to_world(boss.position)), "modelo do chefe na posição dele")
		boss.hp = boss.boss_data.max_hp * 0.3
		await _frames(2)
		var lit: int = 0
		for crack in (views.get("_boss_parts") as Dictionary)["cracks"]:
			if (crack as Node3D).visible:
				lit += 1
		_check(boss.crack_count() >= 4 and lit == boss.crack_count(), "rachaduras acendem conforme a vida cai (%d x %d)" % [lit, boss.crack_count()])
		# Especial: os nós criados na hora (raio gigante, onda de choque) também vão para o plano
		state.fill_special()
		game.call("_on_special_pressed")
		await _frames(3)
		_check(_wrong_layer(game) == 0, "efeitos criados durante a partida entram na camada do plano (%d fora)" % _wrong_layer(game))
		await _frames(600)
		_check(_wrong_layer(game) == 0, "nada escapa da camada do plano durante a luta (%d fora)" % _wrong_layer(game))
		if is_instance_valid(boss):
			boss.take_damage(1e9, Enemy.SOURCE_SPECIAL)
		await _frames(3)
		_check(views.get("_boss_root") == null or not is_instance_valid(views.get("_boss_root")) or (views.get("_boss_root") as Node).is_queued_for_deletion(), "modelo do chefe sai junto com ele")

	# Corpo destruído: quebra em pedaços 3D
	_player = null
	state.hits_left.fill(1)
	var shape_size: int = player.body.shape.size() if player.body != null else 0
	if shape_size > 0:
		state.damage_current(1)
		await _frames(3)
		_check(_visible_pieces(views.get("_fx_pieces")) == shape_size, "a nave destruída quebra em %d pedaços" % shape_size)
		_check(not hull.visible and nucleus.visible, "sem corpo, só o núcleo aparece")

	_player = null
	get_tree().paused = false
	game.queue_free()
	await _frames(3)
	_check(not Renderer3D.active, "saiu da partida: visão 3D desligada")
	_check(main.canvas_cull_mask == mask_before, "saiu da partida: a tela volta a desenhar tudo")

	# Modo Incursão: mesma visão, mais os orbes de XP
	Engine.time_scale = 1.0
	var run: Node2D = (load(ScenePaths.RUN) as PackedScene).instantiate()
	get_tree().root.add_child(run)
	await _frames(5)
	_hold_finger(run)
	var run_renderer: Renderer3D = run.get("renderer")
	_check(run_renderer != null, "a Incursão também monta a visão 3D")
	if run_renderer != null:
		run.call("_drop_orb", Vector2(400.0, 400.0), 1.0)
		await _frames(3)
		_check(_visible_count(run_renderer.entities.get("_orb_views")) == (run.get("orbs") as NodePool).active.size(), "um modelo por orbe de XP")
		_check(_wrong_layer(run) == 0, "Incursão: nós 2D na camada do plano (%d fora)" % _wrong_layer(run))
	get_tree().paused = false
	run.queue_free()
	await _frames(3)

	# Desligada pelo parâmetro: a partida volta ao desenho 2D, sem tocar na tela
	Params.render_3d = false
	var flat: Node2D = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(flat)
	await _frames(5)
	_check(flat.get("renderer") == null and not Renderer3D.active, "render_3d desligado: sem visão 3D")
	_check(main.canvas_cull_mask == mask_before and _count_layer(flat, GroundFx.WORLD_LAYER) == 0, "render_3d desligado: desenho 2D normal")
	flat.queue_free()
	Params.render_3d = true
	await _frames(3)
	_finish()


func _finish() -> void:
	print("render3d_regressions: %d falhas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Dedo na tela e velocidade normal (sem dedo a partida ficaria em câmera lenta).
func _hold_finger(game: Node) -> void:
	(game.get("touch_input") as TouchInput).set("_index", 0)
	(game.get("time_controller") as Node).set_process(false)
	Engine.time_scale = 1.0
	if game.get("director") != null:
		(game.get("director") as Node).set_process(false)


## Nós 2D do jogo (fora de CanvasLayer) que não estão na camada do plano.
func _wrong_layer(node: Node) -> int:
	if node is CanvasLayer or node is Viewport:
		return 0
	var wrong: int = 0
	if node is CanvasItem and (node as CanvasItem).visibility_layer != GroundFx.WORLD_LAYER:
		wrong += 1
	for child in node.get_children():
		wrong += _wrong_layer(child)
	return wrong


## Nós 2D em node (e filhos) cuja camada inclui layer.
func _count_layer(node: Node, layer: int) -> int:
	var count: int = 0
	if node is CanvasItem and (node as CanvasItem).visibility_layer & layer != 0:
		count += 1
	for child in node.get_children():
		count += _count_layer(child, layer)
	return count


func _visible_count(views: Dictionary) -> int:
	var count: int = 0
	for view in views.values():
		if (view as Node3D).visible:
			count += 1
	return count


func _visible_pieces(views: Dictionary) -> int:
	var count: int = 0
	for list in views.values():
		for piece in list:
			if (piece as Node3D).visible:
				count += 1
	return count


func _visible_items(pool: NodePool) -> int:
	var count: int = 0
	for item in pool.active:
		if item.visible:
			count += 1
	return count


## Espera em tempo real com a partida rodando.
func _wait(_game: Node, seconds: float) -> void:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while true:
		if _player != null and is_instance_valid(_player):
			_player.start_invulnerability(10.0)
		await get_tree().process_frame
		if Time.get_ticks_msec() >= end:
			return


func _frames(count: int) -> void:
	for i in count:
		if _player != null and is_instance_valid(_player):
			_player.start_invulnerability(10.0)
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("FALHOU: " + label)
