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
var hud: Hud

var _spawning_done: bool = false
var _clear_wait: float = 0.0
var _match_over: bool = false


func _ready() -> void:
	var planet: PlanetData = Session.planet()
	RenderingServer.set_default_clear_color(planet.background_color)
	state = MatchState.new(load(Params.formation_path) as FormationData)
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

	switcher = BodySwitcher.new()
	switcher.name = "BodySwitcher"
	add_child(switcher)
	# O switcher trata o toque antes da nave e da câmera lenta (ordem das conexões)
	switcher.setup(state, player, touch_input)
	switcher.body_chosen.connect(_on_body_chosen)
	player.bind_input(touch_input)

	spawner = EnemySpawner.new()
	spawner.name = "EnemySpawner"
	add_child(spawner)
	spawner.setup(Session.stage(), enemies)
	spawner.finished.connect(func() -> void: _spawning_done = true)

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

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(state, spawner, "%s  %s" % [tr(planet.name_key), Session.stage_label(Session.planet_index, Session.stage_index)])

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	results_menu = ResultsMenu.new()
	results_menu.name = "ResultsMenu"
	add_child(results_menu)

	if Params.debug_overlay_enabled and OS.is_debug_build():
		var overlay := DebugOverlay.new()
		overlay.name = "DebugOverlay"
		overlay.stats = _debug_stats
		add_child(overlay)

	_switch_to(0, 0.0)


## Fase concluída quando o tempo acaba e não sobram inimigos (ou após um limite de espera).
func _process(delta: float) -> void:
	if not _spawning_done or _match_over:
		return
	_clear_wait += delta
	if enemies.active.is_empty() or _clear_wait >= Params.stage_clear_timeout:
		_match_over = true
		pause_menu.disable()
		var record: bool = SaveGame.complete_stage(Session.linear_index(), Session.stage().id, state.score)
		results_menu.show_stage_clear(state, spawner.elapsed(), record)


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


func _on_powerup_collected() -> void:
	state.powerups_collected += 1
	if state.level_up_current() and player.weapon != null:
		player.weapon.set_level(state.weapon_levels[state.current])


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


func _on_game_over() -> void:
	_match_over = true
	pause_menu.disable()
	await get_tree().create_timer(Params.game_over_delay_seconds, false).timeout
	results_menu.show_game_over(state, spawner.elapsed())


func _explode(pos: Vector2, radius: float, color: Color) -> void:
	var explosion := explosions.acquire() as Explosion
	if explosion != null:
		explosion.activate(pos, radius, color)


func _create_enemy() -> PoolItem:
	var enemy := Enemy.new()
	enemy.bullets = enemy_bullets
	enemy.context = context
	enemy.killed.connect(dropper.on_enemy_killed)
	enemy.killed.connect(func(killed: Enemy) -> void: state.add_kill(killed.data.score))
	enemy.killed.connect(func(killed: Enemy) -> void: _explode(killed.position, killed.radius, killed.data.color))
	return enemy


func _debug_stats() -> String:
	return "tiros %d | inimigos %d | tiros inimigos %d | nível %d" % [
		player_bullets.active.size(), enemies.active.size(), enemy_bullets.active.size(),
		state.weapon_levels[state.current]]
