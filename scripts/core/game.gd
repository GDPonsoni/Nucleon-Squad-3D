extends Node2D
## Cena da partida: monta os nós por código. Joga a fase escolhida em Session,
## com os bônus da evolução do núcleo e a nave auxiliar escolhida no esquadrão.

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
var body_fx: NodePool
var pause_menu: PauseMenu
var results_menu: ResultsMenu
var revive_offer: ReviveOffer
var _revive_used: bool = false  # uma vez por partida
var hud: Hud
var companion: Companion  # null = sem nave auxiliar
var _special_was_ready: bool = false
var _quarks_banked: bool = false

var _spawning_done: bool = false  # fase pode terminar (tempo acabou e não há chefe vivo)
var boss: Boss
var _clear_wait: float = 0.0
var _match_over: bool = false


func _ready() -> void:
	var planet: PlanetData = Session.planet()
	RenderingServer.set_default_clear_color(planet.background_color)
	Audio.play_chapter_music(Session.planet_index)
	var boosts: PlayerBoosts = Session.boosts()
	state = MatchState.new(SaveGame.squad_formation(), boosts)
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
	context.boosts = boosts

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

	# Corpos que saem de cena (troca e quebra), atrás da nave
	body_fx = NodePool.new(BodyFx.new, Params.body_fx_pool_size)
	body_fx.name = "BodyFx"
	add_child(body_fx)

	power_ups = NodePool.new(PowerUp.new, Params.powerup_pool_size)
	power_ups.name = "PowerUps"
	context.power_ups = power_ups
	dropper.setup(power_ups, boosts)
	add_child(dropper)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(context)
	context.player = player
	player.shield_charges = state.shields
	player.max_health = state.max_hits
	state.hits_changed.connect(func(index: int, left: int) -> void:
		if index == state.current:
			player.health = left)
	state.body_changed.connect(func(index: int) -> void: player.set("health", state.hits_left[index]))
	state.shields_changed.connect(func(count: int) -> void: player.shield_charges = count)

	# Nave auxiliar (opcional): desenhada atrás da nave principal
	var companion_body: BodyData = SaveGame.companion_body()
	if companion_body != null:
		companion = Companion.new()
		companion.name = "Companion"
		add_child(companion)
		move_child(companion, player.get_index())
		companion.setup(companion_body, context)
		state.companion = companion_body
		dropper.companion_can_level = state.companion_can_level

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
	# A nave fica sempre acima da barra de troca
	player.bottom_limit = switcher.top()

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
	combat.splashed.connect(func(pos: Vector2, radius: float, color: Color) -> void:
		Audio.play(&"missile_explode")
		_explode(pos, radius * 0.5, color))

	var slow_overlay := SlowMotionOverlay.new()
	slow_overlay.name = "SlowMotionOverlay"
	add_child(slow_overlay)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.place_special(get_viewport_rect().end.y - switcher.top())
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
	if not _match_over and player.body != null:
		state.charge_special(delta)
		# Tempo de jogo: na câmera lenta a recarga da troca também desacelera
		state.tick_switch_cooldown(delta)
	var special_ready: bool = player.body != null and state.special_ready()
	if special_ready and not _special_was_ready:
		Audio.play(&"special_ready")
	_special_was_ready = special_ready
	if not _spawning_done or _match_over:
		return
	_clear_wait += delta
	if enemies.active.is_empty() or _clear_wait >= Params.stage_clear_timeout:
		_finish_stage_clear()


## Saiu da partida (menu, reiniciar, próxima fase): os quarks ganhos não se perdem.
func _exit_tree() -> void:
	_bank_quarks(0)


## Fase concluída: guarda o progresso, os quarks (com bônus) e mostra as recompensas.
func _finish_stage_clear() -> void:
	_match_over = true
	pause_menu.disable()
	Audio.play(&"stage_clear")
	Audio.vibrate(Params.haptic_stage_clear_ms)
	var stage: StageData = Session.stage()
	var first_time: bool = not SaveGame.is_completed(stage.id)
	var chapter_cleared_before: bool = SaveGame.is_chapter_cleared(Session.planet_index)
	var record: bool = SaveGame.complete_stage(stage.id, state.score)
	var kills_quarks: int = int(state.quarks)
	var bonus: int = _clear_bonus(first_time)
	_bank_quarks(bonus)
	var rewards := PackedStringArray()
	if not chapter_cleared_before and SaveGame.is_chapter_cleared(Session.planet_index):
		rewards = _chapter_rewards(Session.planet_index)
	results_menu.show_stage_clear(state, spawner.elapsed(), record, {
		"quarks_kills": kills_quarks, "quarks_bonus": bonus, "rewards": rewards,
	})


## Bônus em quarks por concluir a fase (dobra na primeira vez).
func _clear_bonus(first_time: bool) -> int:
	var table: PackedInt32Array = Params.quarks_stage_clear
	var base: float = table[mini(Session.planet_index, table.size() - 1)]
	if first_time:
		base *= Params.quarks_first_clear_multiplier
	return int(base * state.boosts.quarks)


## Guarda os quarks da partida (uma vez só). Retorna quanto foi guardado.
func _bank_quarks(bonus: int) -> int:
	if _quarks_banked or state == null:
		return 0
	_quarks_banked = true
	var total: int = int(state.quarks) + bonus
	SaveGame.add_quarks(total)
	return total


## Textos do que o capítulo libera: naves com unlock_chapter dele e o espaço auxiliar.
func _chapter_rewards(planet_index: int) -> PackedStringArray:
	var chapter: int = planet_index + 1
	var rewards := PackedStringArray()
	if Params.companion_unlock_chapter == chapter:
		rewards.append(tr("REWARD_COMPANION_SLOT"))
	var roster := load(Params.roster_path) as FormationData
	for body in roster.bodies:
		if body.unlock_chapter == chapter:
			rewards.append(tr("REWARD_SHIP") % tr(body.name_key))
	return rewards


## Tempo da fase acabou: sem chefe, a fase termina; com chefe, ele entra após o aviso.
func _on_spawning_finished() -> void:
	var boss_data: BossData = Session.stage().boss
	if boss_data == null:
		_spawning_done = true
		return
	Audio.play(&"boss_warning")
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
	Audio.play(&"boss_explode")
	Audio.vibrate(Params.haptic_boss_kill_ms)
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
	Audio.play(&"ship_switch")
	Audio.vibrate(Params.haptic_tick_ms)
	# Troca voluntária começa a recarga; a escolha forçada (corpo destruído) não
	if not switcher.forced:
		state.start_switch_cooldown()
	# Troca voluntária: o corpo que sai se dissolve (a perda usa a quebra)
	if player.body != null and player.body != state.bodies[index]:
		_body_fx(player.body, false)
	switcher.forced = false
	time_controller.forced_slow = false
	_switch_to(index, Params.switch_invulnerability_seconds)


func _on_player_hit(damage: int) -> void:
	var invulnerability: float = Params.hit_invulnerability_seconds + state.boosts.extra_invulnerability
	# Escudo da evolução do núcleo absorve o hit inteiro
	if state.absorb_with_shield():
		Audio.play(&"hit_player", -8.0, 1.4)
		hud.flash_hit(Params.shield_color)
		player.pulse(Params.shield_color)
		player.start_invulnerability(invulnerability)
		return
	Audio.play(&"hit_player")
	Audio.vibrate()
	hud.flash_hit()
	state.damage_current(damage)
	if state.is_alive(state.current):
		player.start_invulnerability(invulnerability)


func _on_special_pressed() -> void:
	if _match_over or player.body == null or not state.special_ready():
		return
	state.use_special()
	Audio.play(&"special_fire")
	Audio.vibrate(Params.haptic_special_ms)
	SpecialAttack.trigger(player.body.weapon, player, context, self)


func _on_powerup_collected(kind: PowerUp.Kind) -> void:
	Audio.play(&"powerup_pickup", 0.0, 1.25 if kind == PowerUp.Kind.HEAL else 1.0)
	if kind == PowerUp.Kind.HEAL:
		state.medkits_collected += 1
		if state.heal_current(Params.medkit_heal):
			player.pulse(Params.medkit_color)
		return
	if kind == PowerUp.Kind.COMPANION:
		_on_companion_powerup()
		return
	state.powerups_collected += 1
	if state.level_up_current() and player.weapon != null:
		player.weapon.set_level(state.weapon_levels[state.current])
		player.pulse_level_up()
		Audio.play(&"weapon_levelup")
		Audio.vibrate(Params.haptic_level_up_ms)


## Power-up raro da auxiliar: sobe o nível dela e avisa na tela qual é o efeito.
func _on_companion_powerup() -> void:
	if companion == null or not state.level_up_companion():
		return
	companion.set_level(state.companion_level)
	Audio.play(&"weapon_levelup", 0.0, 1.2)
	Audio.vibrate(Params.haptic_level_up_ms)
	var level_text: String = tr("COMPANION_LEVEL_MAX") if not state.companion_can_level() else tr("COMPANION_LEVEL") % state.companion_level
	hud.show_toast("%s %s: %s\n%s" % [tr("SQUAD_COMPANION"), tr(companion.body.name_key), level_text, tr(companion.body.companion_upgrade_key)], Params.companion_powerup_color)


## Corpo destruído: explode, o núcleo racha e o jogador escolhe outro corpo vivo.
func _on_body_destroyed(index: int) -> void:
	Audio.play(&"body_break")
	Audio.vibrate(Params.haptic_body_break_ms)
	Audio.play(&"core_crack")
	_explode(player.position, Params.ship_size.y * 0.5, state.bodies[index].color)
	_body_fx(state.bodies[index], true)
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
	Audio.play(&"game_over")
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
	var kills_quarks: int = int(state.quarks)
	_bank_quarks(0)
	results_menu.show_game_over(state, spawner.elapsed(), {
		"quarks_kills": kills_quarks, "quarks_bonus": 0, "rewards": PackedStringArray(),
	})


## O último corpo usado volta com vida cheia, de onde parou, com os tiros inimigos limpos.
func _revive() -> void:
	Audio.play(&"revive")
	_revive_used = true
	var index: int = state.current
	state.revive(index)
	player.cracks = state.dead_count()
	_switch_to(index, Params.revive_invulnerability_seconds)
	SpecialAttack._shockwave(context, self, player.position, Params.revive_clear_radius, 0.6, 0, Params.medkit_color)
	_match_over = false
	pause_menu.enable()
	get_tree().paused = false

## Corpo que se despede: quebra (perdido) ou saída (troca voluntária).
func _body_fx(data: BodyData, broken: bool) -> void:
	var fx := body_fx.acquire() as BodyFx
	if fx == null:
		return
	if broken:
		fx.activate_break(player.position, data)
	else:
		fx.activate_exit(player.position, data)


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
	enemy.killed.connect(func(killed: Enemy) -> void:
		Audio.explosion(killed.radius)
		_explode(killed.position, killed.radius, killed.tint()))
	enemy.killed.connect(_on_enemy_split)
	return enemy


## Inimigos com fissão viram pedaços ao serem destruídos.
func _on_enemy_split(killed: Enemy) -> void:
	var data: EnemyData = killed.data
	if data.death_spawn != null and data.death_spawn_count > 0:
		spawner.spawn_burst(data.death_spawn, killed.position, data.death_spawn_count, data.death_spawn_spread_degrees)


func _debug_stats() -> String:
	return "tiros %d | inimigos %d | tiros inimigos %d | nível %d" % [
		player_bullets.active.size(), enemies.active.size(), enemy_bullets.active.size(),
		state.weapon_levels[state.current]]
