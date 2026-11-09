extends "res://scripts/core/game.gd"
## Modo roguelike (nome provisório): nave branca única com ataque frontal e até 3 armas
## escolhidas ao subir de nível com o XP dos orbes. Estende a partida da campanha pelos
## ganchos de modo. Regras em data/run/run_mode.tres (RunModeData).
## Começa só com o ataque frontal; a 1ª arma vem no 1º nível. O RunDirector solta ondas,
## surtos, elites (soltam baú) e chefes; a vida dos inimigos cresce com o minuto.
## Sobreviver até RunModeData.duration_seconds vence a partida.

var mode: RunModeData
var progress: RunProgress
var orbs: NodePool
var run_hud: RunHud
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _choosing: bool = false
var _equipped: Dictionary = {}  # id do corpo -> Weapon montada na nave
var director: RunDirector
var _run_stage: StageData  # fase "infinita" da partida (o diretor ajusta as escalas)
var _won: bool = false
var _boss_minute: float = 0.0
var _bosses_killed: int = 0
var _record_submitted: bool = false


func _ready() -> void:
	mode = load(Params.run_mode_path) as RunModeData
	_rng.randomize()
	_run_stage = StageData.new()
	_run_stage.id = &"run"
	_run_stage.duration_seconds = mode.duration_seconds * 2.0  # o spawner não termina sozinho
	_run_stage.start_delay = mode.first_wave_delay
	_run_stage.difficulty_ramp = false  # o diretor já escala pelo minuto
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
	return _run_stage


func _uses_switcher() -> bool:
	return false


func _companion_body() -> BodyData:
	return null


func _weapon_powerups() -> bool:
	return false


func _special_weapon() -> WeaponData:
	var ship: BodyData = progress.special_weapon()
	return ship.weapon if ship != null else mode.ship.weapon


func _hud_label() -> String:
	return tr("RUN_MODE_NAME")


## Dicas: as gerais da partida (câmera lenta, especial...) e as do modo (stage "run").
func _tip_highlight_rect(name: String) -> Rect2:
	if name == "run_slots":
		var view: Vector2 = get_viewport_rect().size
		var top: float = view.y - Params.run_slow_loadout_bottom - 12.0
		return Rect2(0.0, top, view.x, view.y - top)
	return super(name)


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
	# Barra fina do topo = XP; nível embaixo da pontuação
	hud.progress_ratio = func() -> float: return clampf(progress.xp / maxf(progress.xp_needed(), 0.001), 0.0, 1.0)
	hud.progress_color = Params.run_xp_color
	_show_level()
	progress.leveled_up.connect(func(_level: int) -> void: _show_level())
	pause_menu.title_text = tr("RUN_MODE_NAME")
	pause_menu.restart_path = ScenePaths.RUN
	pause_menu.extra_content = func() -> Control: return RunLoadoutView.build(progress)
	results_menu.title_text = tr("RUN_MODE_NAME")
	results_menu.restart_path = ScenePaths.RUN
	results_menu.back_path = ScenePaths.MENU
	run_hud.time_controller = time_controller
	slow_overlay.bar_bottom = Params.run_energy_bar_bottom
	# O botão do especial mostra a arma dona dele
	hud.special_body = func() -> BodyData:
		var ship: BodyData = progress.special_weapon()
		return ship if ship != null else mode.ship
	# Na câmera lenta, tocar num espaço de arma escolhe o especial (toque curto, como a troca
	# de nave da campanha): o toque não tira da câmera lenta
	touch_input.tap_filter = func(pos: Vector2) -> bool:
		return time_controller.is_voluntary_slow() and run_hud.ship_at(pos) != null
	touch_input.tapped.connect(_on_slot_tapped)
	progress.special_changed.connect(func() -> void: state.special_weapon = _special_weapon())
	director = RunDirector.new()
	director.name = "RunDirector"
	add_child(director)
	director.setup(mode, _run_stage, spawner, _rng.randi())
	director.elite_due.connect(_spawn_elite)
	director.boss_due.connect(_on_boss_due)
	dropper.set_interval(PowerUp.Kind.HEAL, mode.medkit_every)


func _on_enemy_killed(killed: Enemy) -> void:
	var xp: float = killed.points() * mode.xp_per_point
	if killed.elite:
		xp *= mode.elite_xp_multiplier
		if mode.elite_drops_chest:
			dropper.drop_now(killed.position, PowerUp.Kind.CHEST)
		if _rng.randf() < mode.elite_medkit_chance:
			dropper.drop_now(killed.position + Vector2(Params.powerup_radius * 3.0, 0.0), PowerUp.Kind.HEAL)
	_drop_orb(killed.position, xp)


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
	summary["record"] = _submit_record()
	return summary


## Guarda o recorde da partida (uma vez): ao morrer, vencer ou sair.
func _submit_record() -> bool:
	if _record_submitted or progress == null:
		return false
	_record_submitted = true
	var weapons: Array = []
	for ship in progress.owned:
		weapons.append({"id": String(ship.id), "level": progress.weapon_level(ship)})
	return SaveGame.submit_run({
		"time": _clock, "level": progress.level, "score": state.score, "kills": state.kills,
		"victory": _won, "weapons": weapons,
	})


func _exit_tree() -> void:
	_submit_record()
	super()


## O spawner da partida não termina sozinho (dura o dobro da meta); nada a fazer.
func _on_spawning_finished() -> void:
	pass


func _on_powerup_collected(kind: PowerUp.Kind) -> void:
	if kind == PowerUp.Kind.CHEST:
		# Baú: uma escolha extra, sem gastar XP
		Audio.play(&"powerup_pickup", 0.0, 0.8)
		progress.pending += 1
		return
	super(kind)


## Elite: inimigo que flutua e atira, com muito mais vida e aura; solta muito XP.
func _spawn_elite(data: EnemyData) -> void:
	var enemy := enemies.acquire() as Enemy
	if enemy == null:
		return
	var rect: Rect2 = get_viewport_rect()
	var x: float = randf_range(rect.size.x * 0.25, rect.size.x * 0.75)
	enemy.activate(data, Vector2(x, rect.position.y - data.radius * 2.0), Vector2(0.0, data.speed))
	enemy.apply_stage(_run_stage)
	enemy.make_elite(mode.elite_hp_multiplier, mode.elite_size)


## Chefe na hora marcada, com a vida do minuto. As ondas diminuem até ele cair.
func _on_boss_due(data: BossData, minute: float) -> void:
	var tuned: BossData = data.duplicate()
	tuned.max_hp = maxi(roundi(data.max_hp * director.boss_hp_factor()), 1)
	_spawn_boss(tuned)
	_boss_minute = minute


func _after_boss_killed(center: Vector2) -> void:
	_drop_orb(center, mode.boss_xp * (_boss_minute / 5.0 + 1.0))
	_bosses_killed += 1
	if mode.boss_chest_every > 0 and _bosses_killed % mode.boss_chest_every == 0:
		dropper.drop_now(center, PowerUp.Kind.CHEST)
	for i in mode.boss_medkits:
		dropper.drop_now(center + Vector2((i + 1) * Params.powerup_radius * 3.0 * (1.0 if i % 2 == 0 else -1.0), 0.0), PowerUp.Kind.HEAL)


func _on_boss_sequence_done() -> void:
	director.boss_active = false


## Sobreviveu até o fim: vitória.
func _win() -> void:
	_won = true
	_match_over = true
	pause_menu.disable()
	Audio.play(&"stage_clear")
	Haptics.play(&"fase_completa")
	var kills_quarks: int = int(state.quarks)
	_bank_quarks(0)
	results_menu.show_game_over(state, _clock, _result_summary({
		"quarks_kills": kills_quarks, "quarks_bonus": 0, "rewards": PackedStringArray(),
	}), "RUN_VICTORY")


# --- Partida ---

func _process(delta: float) -> void:
	super(delta)
	if _match_over:
		return
	_clock += delta
	if _clock >= mode.duration_seconds and not _won:
		_win()
		return
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
	var had: int = progress.owned.size()
	progress.apply(choice)
	if had == 1 and progress.owned.size() == 2:
		Tutorial.notify(&"run_second_weapon")
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


func _on_slot_tapped(pos: Vector2) -> void:
	var ship: BodyData = run_hud.ship_at(pos)
	if ship == null or ship == progress.special_weapon():
		return
	progress.choose_special(ship)
	Audio.play(&"ship_switch")
	Haptics.play(&"troca_nave")
	hud.show_toast(tr("RUN_SPECIAL_CHOSEN") % tr(ship.name_key), ship.color)


func _show_level() -> void:
	hud.set_stage_text(tr("RUN_LEVEL") % progress.level, Params.run_xp_color)


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
