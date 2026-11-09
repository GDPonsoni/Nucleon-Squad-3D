extends Node
## Ver boss_regressions_run.gd. Sai com código 1 se algum caso falhar.

var _failures: int = 0


func _ready() -> void:
	SaveGame.persistent = false
	SaveGame.settings["tips_enabled"] = false
	var game: Node = (load(ScenePaths.RUN) as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	(game.get("director") as RunDirector).set_process(false)
	# Velocidade normal (sem dedo na tela a partida ficaria em câmera lenta)
	(game.get("touch_input") as TouchInput).set("_index", 0)
	(game.get("time_controller") as Node).set_process(false)
	Engine.time_scale = 1.0
	var player: Player = game.get("player")
	# A nave não morre durante o teste (a partida pausaria)
	var state: MatchState = game.get("state")
	state.max_hits = 100000
	state.hits_left.fill(100000)
	for path in ["mini_1", "boss_1", "mini_2", "boss_2", "mini_3", "boss_3", "mini_4", "boss_4", "mini_5", "boss_5"]:
		var data := load("res://data/bosses/%s.tres" % path) as BossData
		game.call("_spawn_boss", data)
		await _wait(game, Params.boss_warning_seconds + 0.2)
		var boss: Boss = game.get("boss")
		_check(boss != null, "%s entrou" % path)
		if boss == null:
			continue
		var entered := [false]
		boss.entered.connect(func() -> void: entered[0] = true)
		await _wait(game, 4.0)
		_check(entered[0] or not boss.is_entering(), "%s terminou a entrada" % path)
		# Fase final (com os ataques únicos): vida baixa
		boss.hp = boss.boss_data.max_hp * 0.2
		var enemies_before: int = (game.get("enemies") as NodePool).active.size()
		var saw_sweep := false
		var saw_charge := false
		var troops := 0
		for i in 60 * 14:
			player.start_invulnerability(10.0)
			await _wait(game, 0.0)
			if not is_instance_valid(boss):
				break
			saw_sweep = saw_sweep or not (boss.get("_sweeps") as Array).is_empty()
			saw_charge = saw_charge or not (boss.get("_charge") as Dictionary).is_empty()
			troops = maxi(troops, (game.get("enemies") as NodePool).active.size() - enemies_before)
		var kinds := {}
		for attack in data.signature:
			kinds[attack.pattern] = true
		if kinds.has(BossAttack.Pattern.SWEEP):
			_check(saw_sweep, "%s usou a varredura" % path)
		if kinds.has(BossAttack.Pattern.CHARGE):
			_check(saw_charge, "%s fez a investida" % path)
		if kinds.has(BossAttack.Pattern.TROOPS):
			_check(troops > 0, "%s soltou tropas" % path)
		if is_instance_valid(boss):
			boss.take_damage(1e9)
		await _wait(game, Params.boss_explosions * Params.boss_explosion_gap + 0.5)
		for item in (game.get("enemies") as NodePool).active.duplicate():
			(game.get("enemies") as NodePool).release(item)
	game.queue_free()
	await _frames(2)
	print("boss_regressions: %d falhas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Espera em tempo real (com a partida rodando), fechando a tela de nível se ela abrir.
func _wait(game: Node, seconds: float) -> void:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while true:
		for menu in game.find_children("*", "LevelUpMenu", true, false):
			if not menu.is_queued_for_deletion():
				(menu as LevelUpMenu).chosen.emit((menu as LevelUpMenu).choices[0])
				(menu as LevelUpMenu).close()
		await get_tree().process_frame
		if Time.get_ticks_msec() >= end:
			return


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("FALHOU: " + label)
