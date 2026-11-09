extends "res://scripts/core/game.gd"
## Modo roguelike (nome provisório): nave branca única com ataque frontal e até 3 armas
## escolhidas ao subir de nível com o XP dos orbes. Estende a partida da campanha pelos
## ganchos de modo. Regras em data/run/run_mode.tres (RunModeData).
## Começa só com o ataque frontal; a 1ª arma vem no 1º nível.
## Etapa (a): ondas provisórias (uma fase da campanha em laço), sem chefes nem escala.

var mode: RunModeData
var progress: RunProgress
var orbs: NodePool
var run_hud: RunHud
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _choosing: bool = false
var _equipped: Dictionary = {}  # id do corpo -> Weapon montada na nave


func _ready() -> void:
	mode = load(Params.run_mode_path) as RunModeData
	_rng.randomize()
	# Inimigos usam a escala do capítulo 1 enquanto o modo não tem a própria (etapa c)
	Session.planet_index = 0
	Session.stage_index = 0
	super()


# --- Ganchos de modo ---

func _formation() -> FormationData:
	var formation := FormationData.new()
	var bodies: Array[BodyData] = [mode.ship]
	formation.bodies = bodies
	return formation


func _configure_state() -> void:
	state.max_hits = mode.max_hits + state.boosts.extra_hits
	state.hits_left.fill(state.max_hits)
	progress = RunProgress.new(mode)
	progress.xp_scale = state.boosts.quarks  # Coleta: mais XP também
	progress.loadout_changed.connect(_refresh_weapons)


func _stage() -> StageData:
	return mode.placeholder_stage


func _uses_switcher() -> bool:
	return false


func _companion_body() -> BodyData:
	return null


func _weapon_powerups() -> bool:
	return false


func _special_weapon() -> WeaponData:
	var best: BodyData = progress.best_weapon()
	return best.weapon if best != null else mode.ship.weapon


func _hud_label() -> String:
	return tr("RUN_MODE_NAME")


func _setup_tutorial() -> void:
	super()
	Tutorial.detach(Tutorial.MATCH, tip_balloon)  # dicas da campanha não valem aqui


func _on_mode_ready() -> void:
	orbs = NodePool.new(_create_orb, Params.xp_orb_pool_size)
	orbs.name = "XpOrbs"
	add_child(orbs)
	move_child(orbs, power_ups.get_index())
	run_hud = RunHud.new()
	run_hud.name = "RunHud"
	run_hud.progress = progress
	run_hud.clock = func() -> float: return _clock
	add_child(run_hud)
	hud.progress_ratio = func() -> float: return clampf(_clock / mode.duration_seconds, 0.0, 1.0)
	pause_menu.title_text = tr("RUN_MODE_NAME")
	pause_menu.restart_path = ScenePaths.RUN
	pause_menu.extra_content = func() -> Control: return RunLoadoutView.build(progress)
	results_menu.title_text = tr("RUN_MODE_NAME")
	results_menu.restart_path = ScenePaths.RUN
	results_menu.back_path = ScenePaths.MENU
	run_hud.time_controller = time_controller


func _on_enemy_killed(killed: Enemy) -> void:
	_drop_orb(killed.position, killed.points() * mode.xp_per_point)


func _switch_to(index: int, invulnerable_seconds: float) -> void:
	super(index, invulnerable_seconds)
	# set_body limpa o suporte: remonta as armas escolhidas (revive)
	_equipped.clear()
	if progress != null:
		_refresh_weapons()


func _elapsed_seconds() -> float:
	return _clock


func _result_summary(summary: Dictionary) -> Dictionary:
	summary["level"] = progress.level
	return summary


## Fim das ondas provisórias: recomeça a mesma fase (a partida só acaba ao perder ou sair).
func _on_spawning_finished() -> void:
	spawner.restart(_stage())


# --- Partida ---

func _process(delta: float) -> void:
	super(delta)
	if _match_over:
		return
	_clock += delta
	if progress.pending > 0 and not _choosing:
		_open_choices()


## Até o 1º nível só o ataque frontal; a partir dele, 4 opções por nível.
func _open_choices() -> void:
	if _match_over:
		return
	var first: bool = progress.owned.is_empty()
	var options: Array[RunChoice] = progress.roll_choices(_rng, _available())
	if options.is_empty():
		progress.pending = 0
		return
	_choosing = true
	get_tree().paused = true
	pause_menu.disable()
	var menu := LevelUpMenu.open_choices(self, progress, options, first)
	Audio.play(&"weapon_levelup")
	Haptics.play(&"nivel_arma")
	var choice: RunChoice = await menu.chosen
	progress.apply(choice)
	if choice.kind == RunChoice.Kind.QUARKS:
		state.quarks += choice.quarks
	_choosing = false
	pause_menu.enable()
	get_tree().paused = false
	player.pulse_level_up()


## Armas que podem aparecer: as das naves liberadas na campanha.
func _available() -> Array[BodyData]:
	var result: Array[BodyData] = []
	for body in (load(Params.roster_path) as FormationData).bodies:
		if SaveGame.is_ship_unlocked(body):
			result.append(body)
	return result


## Monta na nave as armas escolhidas, cada uma no seu nível (o ataque frontal fica sempre).
func _refresh_weapons() -> void:
	if player.body == null:
		return
	for ship in progress.owned:
		var level: int = progress.weapon_level(ship)
		var id: String = String(ship.id)
		if _equipped.has(id):
			(_equipped[id] as Weapon).set_level(level)
		else:
			_equipped[id] = player.mount.equip(ship.weapon, level)
	state.special_weapon = _special_weapon()


func _create_orb() -> PoolItem:
	var orb := XpOrb.new()
	orb.mode = mode
	orb.player = player
	orb.magnet_scale = state.boosts.pickup_radius
	orb.collected.connect(func(value: float) -> void:
		Audio.play(&"powerup_pickup", -8.0, 1.6)
		progress.add_xp(value))
	return orb


func _drop_orb(pos: Vector2, value: float) -> void:
	if value <= 0.0:
		return
	var orb := orbs.acquire() as XpOrb
	if orb != null:
		orb.activate(pos, value)
		return
	# Pool cheio: o XP não se perde
	progress.add_xp(value)
