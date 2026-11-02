extends Node2D
## Cena da partida: monta os nós por código.

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
var pause_menu: PauseMenu
var game_over_menu: GameOverMenu


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	state = MatchState.new(load(Params.formation_path) as FormationData)
	state.body_destroyed.connect(_on_body_destroyed)
	state.game_over.connect(_on_game_over)

	touch_input = TouchInput.new()
	touch_input.name = "TouchInput"
	add_child(touch_input)

	var starfield := Starfield.new()
	starfield.name = "Starfield"
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

	enemies = NodePool.new(_create_enemy, Params.enemy_pool_size)
	enemies.name = "Enemies"
	add_child(enemies)
	context.enemies = enemies

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(context)

	# Tiros inimigos por cima da nave, para ficarem sempre visíveis
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
	spawner.setup(load(Params.stage_path) as StageData, enemies)

	time_controller = TimeController.new()
	time_controller.name = "TimeController"
	add_child(time_controller)
	time_controller.bind_input(touch_input)

	# Por último entre os nós de lógica: roda depois dos movimentos
	var combat := CombatSystem.new()
	combat.name = "CombatSystem"
	add_child(combat)
	combat.setup(context, player)
	combat.player_hit.connect(_on_player_hit)

	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(state)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	game_over_menu = GameOverMenu.new()
	game_over_menu.name = "GameOverMenu"
	add_child(game_over_menu)

	if Params.debug_overlay_enabled and OS.is_debug_build():
		var overlay := DebugOverlay.new()
		overlay.name = "DebugOverlay"
		overlay.stats = _debug_stats
		add_child(overlay)

	_switch_to(0, 0.0)


func _switch_to(index: int, invulnerable_seconds: float) -> void:
	state.select(index)
	player.set_body(state.current_body(), 1, invulnerable_seconds)


func _on_body_chosen(index: int) -> void:
	switcher.forced = false
	time_controller.forced_slow = false
	_switch_to(index, Params.switch_invulnerability_seconds)


func _on_player_hit(damage: int) -> void:
	state.damage_current(damage)
	if state.is_alive(state.current):
		player.start_invulnerability(Params.hit_invulnerability_seconds)


## Corpo destruído: o núcleo racha e o jogador escolhe outro corpo vivo.
func _on_body_destroyed(_index: int) -> void:
	player.clear_body()
	player.cracks = state.dead_count()
	var alive: Array[int] = state.alive_indices()
	if alive.size() == 1:
		_switch_to(alive[0], Params.switch_invulnerability_seconds)
	elif alive.size() > 1:
		switcher.forced = true
		time_controller.forced_slow = true


func _on_game_over() -> void:
	pause_menu.disable()
	await get_tree().create_timer(Params.game_over_delay_seconds, false).timeout
	game_over_menu.open()


func _create_enemy() -> PoolItem:
	var enemy := Enemy.new()
	enemy.bullets = enemy_bullets
	return enemy


func _debug_stats() -> String:
	return "tiros %d | inimigos %d | tiros inimigos %d" % [
		player_bullets.active.size(), enemies.active.size(), enemy_bullets.active.size()]
