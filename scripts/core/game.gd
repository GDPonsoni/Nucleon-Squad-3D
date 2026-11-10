extends Node2D
## Cena da partida: monta os nós por código. Joga a fase escolhida em Session,
## com os bônus da evolução do núcleo e a nave auxiliar escolhida no esquadrão.
## Outros modos (RunGame) estendem esta cena e trocam só os ganchos "Modo" no fim do arquivo.

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
var tip_spotlight: TipSpotlight
var _revive_used: bool = false  # uma vez por partida
var hud: Hud
var slow_overlay: SlowMotionOverlay
var companion: Companion  # null = sem nave auxiliar
var renderer: Renderer3D  # visão 3D (null com Params.render_3d desligado)
var _special_was_ready: bool = false
var _special_moment: bool = false
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
	state = MatchState.new(_formation(), boosts)
	_configure_state()
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

	# Faíscas de acerto, acima dos inimigos
	var impacts := NodePool.new(HitSpark.new, Params.impact_pool_size)
	impacts.name = "Impacts"
	add_child(impacts)
	context.impacts = impacts

	# Números de dano, acima dos inimigos
	var numbers := DamageNumbers.new()
	numbers.name = "DamageNumbers"
	add_child(numbers)
	context.damage_numbers = numbers

	# Corpos que saem de cena (troca e quebra), atrás da nave
	body_fx = NodePool.new(BodyFx.new, Params.body_fx_pool_size)
	body_fx.name = "BodyFx"
	add_child(body_fx)

	power_ups = NodePool.new(PowerUp.new, Params.powerup_pool_size)
	power_ups.name = "PowerUps"
	context.power_ups = power_ups
	dropper.setup(power_ups, boosts, _stage().duration_seconds, _weapon_powerups())
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
	var companion_body: BodyData = _companion_body()
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

	var reserved_bottom: float = Params.no_switcher_bottom_margin
	if _uses_switcher():
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
		reserved_bottom = get_viewport_rect().end.y - switcher.top()
	player.bind_input(touch_input)
	# A nave fica sempre acima da barra de troca (ou da margem de baixo, sem barra)
	player.bottom_limit = get_viewport_rect().end.y - reserved_bottom

	spawner = EnemySpawner.new()
	spawner.name = "EnemySpawner"
	add_child(spawner)
	spawner.setup(_stage(), enemies)
	spawner.finished.connect(_on_spawning_finished)

	time_controller = TimeController.new()
	time_controller.name = "TimeController"
	add_child(time_controller)
	time_controller.bind_input(touch_input)
	time_controller.voluntary_slow_changed.connect(func(slow: bool) -> void:
		context.weapons_hold = slow and Params.slowmo_holds_fire)

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

	# Visão 3D: depois de toda a lógica, para desenhar o quadro já simulado
	if Params.render_3d:
		renderer = Renderer3D.new()
		renderer.name = "Renderer3D"
		add_child(renderer)
		renderer.setup(self, reserved_bottom)

	slow_overlay = SlowMotionOverlay.new()
	slow_overlay.name = "SlowMotionOverlay"
	slow_overlay.time_controller = time_controller
	add_child(slow_overlay)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.place_special(reserved_bottom)
	hud.special_pressed.connect(_on_special_pressed)
	hud.setup(state, spawner, _hud_label())

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
	_setup_tutorial()
	_on_mode_ready()


## Dicas do tutorial: na primeira vez que algo acontece, o jogo pausa e destaca o elemento.
func _setup_tutorial() -> void:
	tip_spotlight = TipSpotlight.new()
	tip_spotlight.name = "TipSpotlight"
	tip_spotlight.can_pause = func() -> bool:
		return not _match_over and not get_tree().paused and not Dialog.is_open() and player.body != null
	tip_spotlight.highlight_rect = _tip_highlight_rect
	if renderer != null:
		tip_spotlight.world_rect = renderer.project_rect
	add_child(tip_spotlight)
	Tutorial.attach(Tutorial.MATCH, tip_spotlight)
	var held_since := [-1]
	touch_input.touch_started.connect(func(_pos: Vector2) -> void: held_since[0] = Time.get_ticks_msec())
	touch_input.touch_ended.connect(func() -> void:
		var held: float = (Time.get_ticks_msec() - held_since[0]) / 1000.0 if held_since[0] >= 0 else 0.0
		held_since[0] = -1
		# A pausa também solta o dedo: só conta o soltar de verdade, depois de mover a nave
		if not get_tree().paused and held >= Params.tip_slowmo_after_hold_seconds:
			Tutorial.notify(&"touch_released", "", player))
	Tutorial.notify(&"match_start", String(_stage().id), player)
	if companion != null:
		Tutorial.notify(&"companion_active", "", companion)


func _tip_highlight_rect(name: String) -> Rect2:
	match name:
		"special":
			return hud.special_rect()
		"energy":
			return slow_overlay.bar_rect()
		"player":
			var r: float = Params.ship_size.y * 0.9
			if renderer != null:
				return renderer.project_rect(player.position, r)
			return Rect2(player.position - Vector2.ONE * r, Vector2.ONE * r * 2.0)
		"switcher" when switcher != null:
			var view: Vector2 = get_viewport_rect().size
			return Rect2(0.0, switcher.top(), view.x, view.y - switcher.top())
	return Rect2()


## Fase concluída quando o tempo acaba e não sobram inimigos (ou após um limite de espera).
func _process(delta: float) -> void:
	if not _match_over and player.body != null:
		state.charge_special(delta)
		# Tempo de jogo: na câmera lenta a recarga da troca também desacelera
		state.tick_switch_cooldown(delta)
	var special_ready: bool = player.body != null and state.special_ready()
	if special_ready and not _special_was_ready:
		Audio.play(&"special_ready")
		Tutorial.notify(&"special_ready")
	_special_was_ready = special_ready
	_update_special_moment()
	if not _spawning_done or _match_over:
		return
	_clear_wait += delta
	if enemies.active.is_empty() or _clear_wait >= Params.stage_clear_timeout:
		_finish_stage_clear()


## Momento de especial: há alvo blindado na tela. Ao começar, a carga enche e a tela avisa.
func _update_special_moment() -> void:
	var active: bool = boss != null and is_instance_valid(boss) and boss.armored and not boss.is_entering()
	if not active:
		for item in enemies.active:
			var enemy := item as Enemy
			if enemy.armored and enemy.is_on_screen():
				active = true
				break
	if active == _special_moment:
		return
	_special_moment = active
	hud.set_special_moment(active)
	if active:
		Tutorial.notify(&"special_moment")
		state.fill_special()
		hud.show_warning("SPECIAL_MOMENT")
		Audio.play(&"special_ready", 2.0)
		Haptics.play(&"momento_especial")


## Saiu da partida (menu, reiniciar, próxima fase): os quarks ganhos não se perdem.
func _exit_tree() -> void:
	Tutorial.detach(Tutorial.MATCH, tip_spotlight)
	_bank_quarks(0)


## Fase concluída: guarda o progresso, os quarks (com bônus) e mostra as recompensas.
func _finish_stage_clear() -> void:
	_match_over = true
	pause_menu.disable()
	tip_spotlight.cancel()
	Audio.play(&"stage_clear")
	Haptics.play(&"fase_completa")
	var stage: StageData = Session.stage()
	var first_time: bool = not SaveGame.is_completed(stage.id)
	var stars_before: int = SaveGame.stage_stars(stage)
	var chapter_cleared_before: bool = SaveGame.is_chapter_cleared(Session.planet_index)
	var record: bool = SaveGame.complete_stage(stage.id, state.score, {
		"time": spawner.elapsed(), "kills": state.kills, "hits": state.hits_taken, "medkits": state.medkits_collected,
	})
	var kills_quarks: int = int(state.quarks)
	var bonus: int = _clear_bonus(first_time, SaveGame.stage_stars(stage) - stars_before)
	_bank_quarks(bonus)
	var rewards := PackedStringArray()
	var chapter_just_cleared: bool = not chapter_cleared_before and SaveGame.is_chapter_cleared(Session.planet_index)
	if chapter_just_cleared:
		rewards = _chapter_rewards(Session.planet_index)
	Tutorial.notify(&"stage_clear", String(stage.id))
	var summary := {"quarks_kills": kills_quarks, "quarks_bonus": bonus, "rewards": rewards, "stars": stage.stars_for(state.score)}
	await _play_clear_sequence()
	# Avisos só aqui, com a partida já encerrada: nunca no meio de um desvio
	if chapter_just_cleared:
		await Tutorial.show_unlocks(self, Session.planet_index)
	await Tutorial.show_end_tips(self)
	results_menu.show_stage_clear(state, spawner.elapsed(), record, summary)


## Sequência de fim de fase (tempo real): limpa a tela, a nave sobe e sai, só então o resultado.
## A nave fica imune desde o primeiro quadro (Player.scripted) e o dedo não mexe mais nela.
func _play_clear_sequence() -> void:
	spawner.set_process(false)  # ondas agendadas do chefe não entram mais
	time_controller.lock_normal()
	if switcher != null:
		switcher.disabled = true
	player.begin_scripted()
	Audio.play_clear_music()
	_wipe_field()
	var tree := get_tree()
	await tree.create_timer(Params.clear_pause_seconds, false).timeout
	var rect: Rect2 = get_viewport_rect()
	var tween := create_tween()
	tween.tween_property(player, "position", Vector2(rect.get_center().x, player.position.y), Params.clear_ship_center_seconds)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var exit_y: float = rect.position.y - Params.ship_size.y * Params.clear_ship_exit_margin
	tween.tween_property(player, "position:y", exit_y, Params.clear_ship_exit_seconds)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	await tree.create_timer(Params.clear_results_delay, false).timeout


## Tiros, inimigos restantes e itens somem (os inimigos explodem em sequência).
func _wipe_field() -> void:
	for item in enemy_bullets.active.duplicate():
		enemy_bullets.release(item)
	for item in power_ups.active.duplicate():
		power_ups.release(item)
	var wiped: int = 0
	for item in enemies.active.duplicate():
		var enemy := item as Enemy
		if enemy.is_on_screen():
			_explode_later(enemy.position, enemy.radius, enemy.tint(), wiped * Params.clear_wipe_gap)
			wiped += 1
		enemies.release(enemy)


func _explode_later(pos: Vector2, radius: float, color: Color, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	_explode(pos, radius, color)


## Bônus em quarks por concluir a fase: dobra na primeira vez, cresce com vagas vazias no
## esquadrão e soma as estrelas novas.
func _clear_bonus(first_time: bool, new_stars: int) -> int:
	return SaveGame.clear_bonus(Session.planet_index, first_time, new_stars, state.empty_slots(), state.boosts.quarks)


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
	var boss_data: BossData = _stage().boss
	if boss_data == null:
		_spawning_done = true
		return
	_spawn_boss(boss_data)


## Aviso na tela e, depois dele, o chefe entra.
func _spawn_boss(boss_data: BossData) -> void:
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
	boss.spawn_troops = _spawn_troops
	boss.setup(boss_data, enemy_bullets, context, spawner.spawn_wave)
	boss.killed.connect(_on_boss_killed)
	boss.entered.connect(func() -> void: hud.show_boss_title(tr(boss_data.name_key), boss_data.accent_color))
	context.boss = boss
	hud.set_boss(boss, tr(boss_data.name_key))


## Tropas do chefe: saem do corpo dele, metade para cada lado, seguindo a trajetória dada.
func _spawn_troops(data: EnemyData, origin: Vector2, count: int, path: Array[MoveStep]) -> void:
	for i in count:
		var enemy := enemies.acquire() as Enemy
		if enemy == null:
			return
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var rank: int = i / 2 + 1
		var dir := Vector2(side * 0.55, 1.0).normalized()
		enemy.activate(data, origin + Vector2(side * 50.0 * rank, 30.0), dir * data.speed)
		var wave := WaveData.new()
		wave.enemy = data
		wave.path = path
		wave.mirror = side > 0.0
		enemy.set_motion(wave, i)
		enemy.apply_stage(_stage(), spawner.progress())


## Chefe destruído: explosões em sequência, tiros inimigos somem e a fase termina.
func _on_boss_killed(killed: Enemy) -> void:
	state.add_kill(killed.points())
	Audio.play(&"boss_explode")
	Haptics.play(&"explosao_chefe")
	context.boss = null
	hud.set_boss(null, "")
	for item in enemy_bullets.active.duplicate():
		enemy_bullets.release(item)
	var center: Vector2 = killed.position
	var radius: float = killed.radius
	var color: Color = killed.tint()
	killed.queue_free()
	boss = null
	_after_boss_killed(center)
	for i in Params.boss_explosions:
		_explode(center + Vector2.from_angle(randf() * TAU) * randf() * radius, radius * randf_range(0.5, 1.2), color)
		await get_tree().create_timer(Params.boss_explosion_gap, false).timeout
	_on_boss_sequence_done()


func _switch_to(index: int, invulnerable_seconds: float) -> void:
	state.select(index)
	player.set_body(state.current_body(), state.weapon_levels[index], invulnerable_seconds)


func _on_body_chosen(index: int) -> void:
	Audio.play(&"ship_switch")
	Haptics.play(&"troca_nave")
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
	Tutorial.notify(&"player_hit", "", player)
	var invulnerability: float = Params.hit_invulnerability_seconds + state.boosts.extra_invulnerability
	# Escudo da evolução do núcleo absorve o hit inteiro
	if state.absorb_with_shield():
		Audio.play(&"hit_player", -8.0, 1.4)
		hud.flash_hit(Params.shield_color)
		player.pulse(Params.shield_color)
		player.start_invulnerability(invulnerability)
		return
	Audio.play(&"hit_player")
	Haptics.play(&"dano_jogador")
	hud.flash_hit()
	state.damage_current(damage)
	if state.is_alive(state.current):
		player.start_invulnerability(invulnerability)


func _on_special_pressed() -> void:
	if _match_over or player.body == null or not state.special_ready():
		return
	state.use_special()
	Audio.play(&"special_fire")
	Haptics.play(&"especial")
	SpecialAttack.trigger(_special_weapon(), player, context, self)


func _on_powerup_collected(kind: PowerUp.Kind) -> void:
	Audio.play(&"powerup_pickup", 0.0, 1.25 if kind == PowerUp.Kind.HEAL else 1.0)
	Tutorial.notify(&"medkit_collected" if kind == PowerUp.Kind.HEAL else (&"companion_powerup" if kind == PowerUp.Kind.COMPANION else &"powerup_collected"))
	if kind == PowerUp.Kind.HEAL:
		state.medkits_collected += 1
		if state.heal_current(Params.medkit_heal):
			player.pulse(Params.medkit_color)
		else:
			_overflow_points(Params.medkit_overflow_points)
		return
	if kind == PowerUp.Kind.COMPANION:
		_on_companion_powerup()
		return
	state.powerups_collected += 1
	if state.level_up_current() and player.weapon != null:
		player.weapon.set_level(state.weapon_levels[state.current])
		player.pulse_level_up()
		Audio.play(&"weapon_levelup")
		Haptics.play(&"nivel_arma")
	elif player.body != null:
		_overflow_points(Params.powerup_overflow_points)


## Item que não teria efeito (arma no máximo, corpo sem dano) vira pontos, com o número na tela.
func _overflow_points(points: int) -> void:
	state.add_bonus_points(points)
	if context.damage_numbers != null:
		context.damage_numbers.report(player, points, Params.quark_color)


## Power-up raro da auxiliar: sobe o nível dela e avisa na tela qual é o efeito.
func _on_companion_powerup() -> void:
	if companion == null or not state.level_up_companion():
		return
	companion.set_level(state.companion_level)
	Audio.play(&"weapon_levelup", 0.0, 1.2)
	Haptics.play(&"nivel_arma")
	var level_text: String = tr("COMPANION_LEVEL_MAX") if not state.companion_can_level() else tr("COMPANION_LEVEL") % state.companion_level
	hud.show_toast("%s %s: %s\n%s" % [tr("SQUAD_COMPANION"), tr(companion.body.name_key), level_text, tr(companion.body.companion_upgrade_key)], Params.companion_powerup_color)


## Corpo destruído: explode, o núcleo racha e o jogador escolhe outro corpo vivo.
func _on_body_destroyed(index: int) -> void:
	Audio.play(&"body_break")
	Haptics.play(&"perda_nave")
	Audio.play(&"core_crack")
	_explode(player.position, Params.ship_size.y * 0.5, state.bodies[index].color)
	_body_fx(state.bodies[index], true)
	player.clear_body()
	player.cracks = state.dead_count()
	var alive: Array[int] = state.alive_indices()
	if alive.size() == 1:
		_switch_to(alive[0], Params.switch_invulnerability_seconds)
	elif alive.size() > 1 and switcher != null:
		switcher.forced = true
		time_controller.forced_slow = true


## Sem corpos vivos: oferece continuar com anúncio (uma vez por partida); senão, fim de jogo.
func _on_game_over() -> void:
	Audio.play(&"game_over")
	tip_spotlight.cancel()
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
	results_menu.show_game_over(state, _elapsed_seconds(), _result_summary({
		"quarks_kills": kills_quarks, "quarks_bonus": 0, "rewards": PackedStringArray(),
	}))


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
		Haptics.play(&"explosao_grande" if killed.radius >= Params.explosion_reference_radius * 1.4 else &"explosao_pequena")
		_explode(killed.position, killed.radius, killed.tint()))
	enemy.killed.connect(_on_enemy_split)
	enemy.killed.connect(_on_enemy_killed)
	return enemy


## Inimigos com fissão viram pedaços ao serem destruídos.
func _on_enemy_split(killed: Enemy) -> void:
	var data: EnemyData = killed.data
	if data.death_spawn != null and data.death_spawn_count > 0 and not killed.crushed:
		spawner.spawn_burst(data.death_spawn, killed.position, data.death_spawn_count, data.death_spawn_spread_degrees)


func _debug_stats() -> String:
	return "tiros %d | inimigos %d | tiros inimigos %d | nível %d" % [
		player_bullets.active.size(), enemies.active.size(), enemy_bullets.active.size(),
		state.weapon_levels[state.current]]


# --- Modo: ganchos que outros modos sobrescrevem (padrão = campanha) ---

## Corpos da partida.
func _formation() -> FormationData:
	return SaveGame.squad_formation()


## Ajustes no estado logo depois de criado (vida, arma do especial...).
func _configure_state() -> void:
	pass


## Fase jogada (ondas, duração e chefe).
func _stage() -> StageData:
	return Session.stage()


## Barra de troca de nave na base da tela.
func _uses_switcher() -> bool:
	return true


func _companion_body() -> BodyData:
	return SaveGame.companion_body()


## Power-ups de arma caem durante a fase.
func _weapon_powerups() -> bool:
	return true


## Arma cujo especial o botão dispara.
func _special_weapon() -> WeaponData:
	return player.body.weapon


func _hud_label() -> String:
	return "%s  %s" % [tr(Session.planet().name_key), Session.stage_label(Session.planet_index, Session.stage_index)]


## Tempo de partida mostrado no resultado.
func _elapsed_seconds() -> float:
	return spawner.elapsed()


## Dados extras para a tela de resultado.
func _result_summary(summary: Dictionary) -> Dictionary:
	return summary


## Fim da montagem da cena.
func _on_mode_ready() -> void:
	pass


## Chefe destruído (antes das explosões): recompensas na posição dele.
func _after_boss_killed(_center: Vector2) -> void:
	pass


## Explosões do chefe acabaram (campanha: a fase pode terminar).
func _on_boss_sequence_done() -> void:
	_spawning_done = true


## Inimigo comum destruído (depois de pontos e drops).
func _on_enemy_killed(_killed: Enemy) -> void:
	pass
