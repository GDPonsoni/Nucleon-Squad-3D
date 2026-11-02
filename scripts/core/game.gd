extends Node2D
## Cena da partida: monta os nós por código. Joga a fase escolhida em Session.

var touch_input: TouchInput
var player: Player
var player_bullets: NodePool
var enemy_bullets: NodePool
var enemies: NodePool
var context: CombatContext
var state: MatchState
var time_controller: TimeController
var switcher: BodySwitcher
var spawner: EnemySpawner
var combat: CombatSystem
var power_ups: NodePool
var dropper: PowerUpDropper
var explosions: NodePool
var pause_menu: PauseMenu
var results_menu: ResultsMenu
var revive_offer: ReviveOffer
var _revive_used: bool = false  # uma vez por partida
var hud: Hud

var _spawning_done: bool = false  # fase pode terminar (tempo acabou e não há chefe vivo)
var boss: Boss
var _clear_wait: float = 0.0
var _match_over: bool = false


func _ready() -> void:
	var planet: PlanetData = Session.planet()
	RenderingServer.set_default_clear_color(planet.background_color)
	state = MatchState.new(SaveGame.squad_formation())
	state.body_destroyed.connect(_on_body_destroyed)
	state.game_over.connect(_on_game_over)

	touch_input = TouchInput.new()
	touch_input.name = "TouchInput"
	add_child(touch_input)

	var starfield := Starfield.new()
	starfield.name = "Starfield"
	starfield.star_color = planet.star_color
	add_child(starfield)

	# Pool antes da nave para os projéteis ficarem atrás dela
	player_bullets = NodePool.new(Bullet.new, Params.player_bullet_pool_size)
	player_bullets.name = "PlayerBullets"
	add_child(player_bullets)

	context = CombatContext.new()
	context.player_bullets = player_bullets

	enemy_bullets = NodePool.new(Bullet.new, Params.enemy_bullet_pool_size)
	enemy_bullets.name = "EnemyBullets"
	context.enemy_bullets = enemy_bullets

	# O dropper existe antes do pool de inimigos: cada inimigo se conecta a ele
	dropper = PowerUpDropper.new()
	dropper.name = "PowerUpDropper"

	enemies = NodePool.new(_create_enemy, Params.enemy_pool_size)
	enemies.name = "Enemies"
	add_child(enemies)
	context.enemies = enemies

	# Explosões acima dos inimigos e atrás da nave
	explosions = NodePool.new(Explosion.new, Params.explosion_pool_size)
	explosions.name = "Explosions"
	add_child(explosions)

	power_ups = NodePool.new(PowerUp.new, Params.powerup_pool_size)
	power_ups.name = "PowerUps"
	context.power_ups = power_ups
	dropper.setup(power_ups)
	add_child(dropper)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(context)
	context.player = player

	# Power-ups e tiros inimigos por cima da nave e do raio, para ficarem sempre visíveis
	add_child(power_ups)
	add_child(enemy_bullets)

	# Faixa de troca numa camada própria: acima da moldura da câmera lenta, abaixo do HUD
	var switcher_layer := CanvasLayer.new()
	switcher_layer.name = "SwitcherLayer"
	switcher_layer.layer = 8
	add_child(switcher_layer)
	switcher = BodySwitcher.new()
	switcher.name = "BodySwitcher"
	switcher_layer.add_child(switcher)
	# O switcher trata o toque antes da nave e da câmera lenta (ordem das conexões)
	switcher.setup(state, touch_input)
	switcher.body_chosen.connect(_on_body_chosen)
	player.bind_input(touch_input)

	spawner = EnemySpawner.new()
	spawner.name = "EnemySpawner"
	add_child(spawner)
	spawner.setup(Session.stage(), enemies)
	spawner.finished.connect(_on_spawning_finished)

	time_controller = TimeController.new()
	time_controller.name = "TimeController"
	add_child(time_controller)
	time_controller.bind_input(touch_input)

	# Por último entre os nós de lógica: roda depois dos movimentos
	combat = CombatSystem.new()
	combat.name = "CombatSystem"
	add_child(combat)
	combat.setup(context, player)
	combat.player_hit.connect(_on_player_hit)
	combat.powerup_collected.connect(_on_powerup_collected)
	combat.splashed.connect(func(pos: Vector2, radius: float, color: Color) -> void: _explode(pos, radius * 0.5, color))

	var slow_overlay := SlowMotionOverlay.new()
	slow_overlay.name = "SlowMotionOverlay"
	add_child(slow_overlay)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.special_pressed.connect(_on_special_pressed)
	hud.setup(state, spawner, "%s  %s" % [tr(planet.name_key), Session.stage_label(Session.planet_index, Session.stage_index)])

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	results_menu = ResultsMenu.new()
	results_menu.name = "ResultsMenu"
	add_child(results_menu)

	revive_offer = ReviveOffer.new()
	revive_offer.name = "ReviveOffer"
	add_child(revive_offer)

	if Params.debug_overlay_enabled and OS.is_debug_build():
		var overlay := DebugOverlay.new()
		overlay.name = "DebugOverlay"
		overlay.stats = _debug_stats
		add_child(overlay)

	_switch_to(0, 0.0)


## Fase concluída quando o tempo acaba e não sobram inimigos (ou após um limite de espera).
func _process(delta: float) -> void:
	hud.hide_bottom_panels = switcher.visible
	if not _match_over and player.body != null:
		state.charge_special(delta)
	if not _spawning_done or _match_over:
		return
	_clear_wait += delta
	if enemies.active.is_empty() or _clear_wait >= Params.stage_clear_timeout:
		_match_over = true
		pause_menu.disable()
		var record: bool = SaveGame.complete_stage(Session.stage().id, state.score)
		results_menu.show_stage_clear(state, spawner.elapsed(), record)


## Tempo da fase acabou: sem chefe, a fase termina; com chefe, ele entra após o aviso.
func _on_spawning_finished() -> void:
	var boss_data: BossData = Session.stage().boss
	if boss_data == null:
		_spawning_done = true
		return
	hud.show_warning("BOSS_WARNING")
	await get_tree().create_timer(Params.boss_warning_seconds, false).timeout
	if _match_over:
		return
	boss = Boss.new()
	boss.name = "Boss"
	add_child(boss)
	# Desenhado junto dos inimigos, abaixo da nave e dos tiros
	move_child(boss, enemies.get_index() + 1)
	boss.setup(boss_data, enemy_bullets, context, spawner.spawn_wave)
	boss.killed.connect(_on_boss_killed)
	context.boss = boss
	hud.set_boss(boss, tr(boss_data.name_key))


## Chefe destruído: explosões em sequência, tiros inimigos somem e a fase termina.
func _on_boss_killed(killed: Enemy) -> void:
	state.add_kill(killed.points())
	context.boss = null
	hud.set_boss(null, "")
	for item in enemy_bullets.active.duplicate():
		enemy_bullets.release(item)
	var center: Vector2 = killed.position
	var radius: float = killed.radius
	var color: Color = killed.tint()
	killed.queue_free()
	boss = null
	for i in Params.boss_explosions:
		_explode(center + Vector2.from_angle(randf() * TAU) * randf() * radius, radius * randf_range(0.5, 1.2), color)
		await get_tree().create_timer(Params.boss_explosion_gap, false).timeout
	_spawning_done = true


func _switch_to(index: int, invulnerable_seconds: float) -> void:
	state.select(index)
	player.set_body(state.current_body(), state.weapon_levels[index], invulnerable_seconds)


func _on_body_chosen(index: int) -> void:
	switcher.forced = false
	time_controller.forced_slow = false
	_switch_to(index, Params.switch_invulnerability_seconds)


func _on_player_hit(damage: int) -> void:
	hud.flash_hit()
	state.damage_current(damage)
	if state.is_alive(state.current):
		player.start_invulnerability(Params.hit_invulnerability_seconds)


func _on_special_pressed() -> void:
	if _match_over or player.body == null or not state.special_ready():
		return
	state.use_special()
	SpecialAttack.trigger(player.body.weapon, player, context, self)


func _on_powerup_collected(kind: PowerUp.Kind) -> void:
	if kind == PowerUp.Kind.HEAL:
		state.medkits_collected += 1
		if state.heal_current(Params.medkit_heal):
			player.pulse(Params.medkit_color)
		return
	state.powerups_collected += 1
	if state.level_up_current() and player.weapon != null:
		player.weapon.set_level(state.weapon_levels[state.current])
		player.pulse_level_up()


## Corpo destruído: explode, o núcleo racha e o jogador escolhe outro corpo vivo.
func _on_body_destroyed(index: int) -> void:
	_explode(player.position, Params.ship_size.y * 0.5, state.bodies[index].color)
	player.clear_body()
	player.cracks = state.dead_count()
	var alive: Array[int] = state.alive_indices()
	if alive.size() == 1:
		_switch_to(alive[0], Params.switch_invulnerability_seconds)
	elif alive.size() > 1:
		switcher.forced = true
		time_controller.forced_slow = true


## Sem corpos vivos: oferece continuar com anúncio (uma vez por partida); senão, fim de jogo.
func _on_game_over() -> void:
	_match_over = true
	pause_menu.disable()
	# Tempo real: na câmera lenta o atraso não se estende
	await get_tree().create_timer(Params.game_over_delay_seconds, false, false, true).timeout
	if not _revive_used and AdService.is_rewarded_available():
		revive_offer.open()
		var accepted: bool = await revive_offer.closed
		if accepted:
			AdService.show_rewarded()
			var granted: bool = await AdService.rewarded_finished
			if granted:
				_revive()
				return
	results_menu.show_game_over(state, spawner.elapsed())


## O último corpo usado volta com vida cheia, de onde parou, com os tiros inimigos limpos.
func _revive() -> void:
	_revive_used = true
	var index: int = state.current
	state.revive(index)
	player.cracks = state.dead_count()
	_switch_to(index, Params.revive_invulnerability_seconds)
	SpecialAttack._shockwave(context, self, player.position, Params.revive_clear_radius, 0.6, 0, Params.medkit_color)
	_match_over = false
	pause_menu.enable()
	get_tree().paused = false

func _explode(pos: Vector2, radius: float, color: Color) -> void:
	var explosion := explosions.acquire() as Explosion
	if explosion != null:
		explosion.activate(pos, radius, color)


func _create_enemy() -> PoolItem:
	var enemy := Enemy.new()
	enemy.bullets = enemy_bullets
	enemy.context = context
	enemy.killed.connect(dropper.on_enemy_killed)
	enemy.killed.connect(func(killed: Enemy) -> void: state.add_kill(killed.points()))
	enemy.killed.connect(func(killed: Enemy) -> void: _explode(killed.position, killed.radius, killed.tint()))
	return enemy


func _debug_stats() -> String:
	return "tiros %d | inimigos %d | tiros inimigos %d | nível %d" % [
		player_bullets.active.size(), enemies.active.size(), enemy_bullets.active.size(),
		state.weapon_levels[state.current]]
