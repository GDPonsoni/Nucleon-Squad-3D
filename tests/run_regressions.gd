extends Node
## Ver run_regressions_run.gd. Sai com código 1 se algum caso falhar.

var _failures: int = 0


func _ready() -> void:
	SaveGame.persistent = false
	SaveGame.settings["tips_enabled"] = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game: Node = (load(ScenePaths.RUN) as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	var progress: RunProgress = game.get("progress")
	var player: Player = game.get("player")
	# Começo: jogo pausado com a escolha da 1ª arma
	var menu: LevelUpMenu = _menu(game)
	_check(menu != null and get_tree().paused, "escolha inicial abre pausada")
	_check(menu != null and menu.choices.size() == 4, "4 opções no começo")
	var first: RunChoice = menu.choices[0]
	menu.chosen.emit(first)
	menu.close()
	await _frames(3)
	_check(not get_tree().paused and progress.slots_used() == 1, "arma escolhida, jogo segue")
	await get_tree().create_timer(0.6).timeout  # a nave termina de se montar
	_check(player.mount.weapons().size() == 2, "ataque frontal + 1 arma montados (%d)" % player.mount.weapons().size())
	# XP: sobe de nível e a escolha abre
	progress.add_xp(progress.xp_needed() + 0.1)
	await _frames(3)
	menu = _menu(game)
	_check(menu != null and get_tree().paused, "subir de nível abre a escolha")
	var upgrade: RunChoice = null
	for choice in menu.choices:
		if choice.body == first.body:
			upgrade = choice
	if upgrade == null:
		upgrade = RunChoice.weapon(first.body, 2)
	menu.chosen.emit(upgrade)
	menu.close()
	await _frames(3)
	_check(progress.weapon_level(first.body) == 2, "repetir a arma sobe o nível")
	var mounted: Weapon = null
	for weapon in player.mount.weapons():
		if weapon.data == first.body.weapon:
			mounted = weapon
	_check(mounted != null and mounted.level == 2, "arma montada no nível novo")
	_check(player.mount.weapons().size() == 2, "subir não monta arma repetida")
	# Orbe: inimigo destruído vira XP ao chegar na nave
	var before: float = progress.xp
	var orbs: NodePool = game.get("orbs")
	game.call("_drop_orb", player.position, 1.0)
	await get_tree().create_timer(0.8).timeout
	_check(progress.xp > before or progress.level > 2, "orbe perto da nave vira XP")
	# Pausa mostra os espaços de arma
	var pause: PauseMenu = game.get("pause_menu")
	pause.open()
	await _frames(3)
	var views: Array = get_tree().root.find_children("*", "RunLoadoutView", true, false)
	_check(not views.is_empty(), "pausa mostra as armas")
	pause.close()
	await _frames(2)
	get_tree().paused = false
	game.queue_free()
	await _frames(2)
	print("run_regressions: %d falhas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _menu(game: Node) -> LevelUpMenu:
	var found: Array = game.find_children("*", "LevelUpMenu", true, false)
	return found[found.size() - 1] if not found.is_empty() else null


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("FALHOU: " + label)
