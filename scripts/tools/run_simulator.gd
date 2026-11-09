extends "res://scripts/tools/stage_simulator.gd"
## Simulador do modo roguelike (Incursão): o mesmo piloto automático da campanha joga uma
## partida e escolhe as opções de nível sozinho. Imprime uma linha por minuto.
##
## Uso (dentro do repo):
##   godot --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_run.gd -- --minutes 12
##
## Opções:
##   --minutes N        duração simulada (padrão 10)
##   --seed N           semente (padrão 1)
##   --upgrades a=3,b=1 evolução do núcleo (padrão: nenhuma)
##   --pick focus       sobe sempre a mesma arma até o máximo (padrão)
##   --pick spread      prefere armas novas até encher os espaços
##   --mode survival    regras normais (padrão: invulnerável, conta os hits que levaria)

var _minutes: float = 10.0
var _pick: String = "focus"
var _minute_stats := {}
var _next_report: float = 60.0


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	seed(int(args.get("seed", "1")))
	_minutes = float(args.get("minutes", "10"))
	_pick = args.get("pick", "focus")
	_survival = args.get("mode", "count") == "survival"
	SaveGame.persistent = false
	SaveGame.settings["tips_enabled"] = false
	SaveGame.unlock_everything = true
	SaveGame.upgrades = {}
	if args.has("upgrades"):
		for pair in (args["upgrades"] as String).split(","):
			var parts: PackedStringArray = pair.split("=")
			SaveGame.upgrades[parts[0]] = int(parts[1])
	_candidates.append(Vector2.ZERO)
	for ring in [70.0, 150.0]:
		for i in 16:
			_candidates.append(Vector2.from_angle(TAU * i / 16.0) * ring)
	_stage_id = "run"
	_stats = {
		"hits": 0, "bullets_sum": 0.0, "bullets_max": 0, "enemies_max": 0, "frames": 0,
		"pool_full": 0, "boss_seconds": -1.0, "result": "timeout",
	}
	_reset_minute()
	print("min | nível | xp/min | abates | hits | inimigos máx | tiros méd | chefe | armas")
	_game = (load(ScenePaths.RUN) as PackedScene).instantiate()
	get_tree().root.add_child(_game)
	_hold_finger()


func _reset_minute() -> void:
	_minute_stats = {"hits": _stats["hits"], "kills": 0, "xp": 0.0, "bullets": 0.0, "frames": 0, "enemies": 0}


func _process(delta: float) -> void:
	if _game == null:
		return
	var menu: LevelUpMenu = _open_menu()
	if menu != null:
		_choose(menu)
		return
	var state: MatchState = _game.get("state")
	if get_tree().paused:
		_report(true)
		print("FIM | game over em %.1f min" % (_clock / 60.0))
		get_tree().quit()
		return
	_clock += delta
	var player: Player = _game.get("player")
	var context: CombatContext = _game.get("context")
	var offer: ReviveOffer = _game.get("revive_offer")
	if offer.get("_open"):
		offer.call("_close", false)
	if not _survival:
		player.start_invulnerability(1000.0)
		_count_virtual_hits(player, context, delta)
	if player.body != null and state.special_ready():
		_game.call("_on_special_pressed")
	player.set("_target", _choose_target(player, context))
	_minute_stats["bullets"] += context.enemy_bullets.active.size()
	_minute_stats["frames"] += 1
	_minute_stats["enemies"] = maxi(_minute_stats["enemies"], context.enemies.active.size())
	if _clock >= _next_report:
		_report(false)
		_next_report += 60.0
	if _clock >= _minutes * 60.0:
		print("FIM | %.0f min sem morrer" % _minutes)
		get_tree().quit()


func _open_menu() -> LevelUpMenu:
	var found: Array = _game.find_children("*", "LevelUpMenu", true, false)
	for item in found:
		var menu := item as LevelUpMenu
		if not menu.is_queued_for_deletion():
			return menu
	return null


## Política de escolha: "focus" sobe a arma de maior nível; "spread" prefere armas novas.
func _choose(menu: LevelUpMenu) -> void:
	var best: RunChoice = menu.choices[0]
	var progress: RunProgress = _game.get("progress")
	for choice in menu.choices:
		if _score_choice(choice, progress) > _score_choice(best, progress):
			best = choice
	menu.chosen.emit(best)
	menu.close()


func _score_choice(choice: RunChoice, progress: RunProgress) -> float:
	match choice.kind:
		RunChoice.Kind.QUARKS:
			return 0.0
		RunChoice.Kind.NEW_WEAPON:
			return 3.0 if _pick == "spread" or progress.owned.is_empty() else 1.0
		_:
			return 2.0 + choice.to_level * (0.1 if _pick == "spread" else 1.0)


func _report(partial: bool) -> void:
	var progress: RunProgress = _game.get("progress")
	var state: MatchState = _game.get("state")
	var kills: int = state.kills - int(_minute_stats.get("kills_total", 0))
	var weapons := PackedStringArray()
	for ship in progress.owned:
		weapons.append("%s:%d" % [String(ship.weapon.id), progress.weapon_level(ship)])
	var boss: Node = _game.get("boss")
	print("%d%s | %d | %.0f | %d | %d | %d | %.0f | %s | %s" % [
		int(_clock / 60.0) + (0 if partial else 0), "*" if partial else "", progress.level,
		_xp_this_minute(progress), kills, _stats["hits"] - int(_minute_stats["hits"]),
		_minute_stats["enemies"], _minute_stats["bullets"] / maxf(_minute_stats["frames"], 1.0),
		"sim" if boss != null else "-", ", ".join(weapons)])
	var total_kills: int = state.kills
	_reset_minute()
	_minute_stats["kills_total"] = total_kills
	_minute_stats["xp_total"] = _total_xp(progress)


## XP total já ganho na partida (níveis completos + o que falta).
func _total_xp(progress: RunProgress) -> float:
	var total: float = progress.xp
	for level in range(1, progress.level):
		total += progress.mode.xp_first_level * pow(progress.mode.xp_growth, level - 1)
	return total


func _xp_this_minute(progress: RunProgress) -> float:
	return _total_xp(progress) - float(_minute_stats.get("xp_total", 0.0))
