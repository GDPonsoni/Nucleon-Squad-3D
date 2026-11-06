extends Node
## Ferramenta de balanceamento: joga fases com um piloto automático que desvia dos tiros
## e mede dificuldade (hits que levaria), densidade de tiros, abates e duração dos chefes.
##
## Rodado por simulate_stages.gd (o script -s só o carrega depois dos autoloads).
## Uso (dentro do repo):
##   godot --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_stages.gd -- \
##       --stages p1_s1,p4_s4 --level 3 --mode count
##
## Opções:
##   --stages a,b,c   ids das fases (padrão: todas da campanha)
##   --chapter N      só as fases do capítulo N (1 = primeiro)
##   --level N        nível inicial das armas (padrão 1; os power-ups continuam valendo)
##   --mode count     invulnerável: conta os hits que levaria (padrão)
##   --mode survival  regras normais: mede se o piloto passa da fase
##   --seed N         semente do sorteio (padrão 1)
##   --squad a,b,c,d  ids dos corpos do esquadrão (padrão: o salvo / inicial)
##   --companion id   nave auxiliar (padrão: nenhuma)
##   --upgrades a=3,b=1  níveis da evolução do núcleo (padrão: nenhum)
##   --boss-only      pula direto para o chefe (fases com chefe)
## Não grava o save do aparelho.

const LOOKAHEAD := [0.0, 0.12, 0.24, 0.38]
const NEAR_BULLETS: float = 650.0
const VIRTUAL_INVULNERABILITY: float = 1.0
const SAFETY_SECONDS: float = 1000.0

var _queue: Array[Vector2i] = []
var _level: int = 1
var _survival: bool = false
var _game: Node
var _stage_id: String = ""
var _clock: float = 0.0
var _stats: Dictionary = {}
var _virtual_invulnerable: float = 0.0
var _boss_started: float = -1.0
var _candidates := PackedVector2Array()
var _results: Array[Dictionary] = []
var _waiting_free: int = 0
var _boss_only: bool = false


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	seed(int(args.get("seed", "1")))
	_level = int(args.get("level", "1"))
	_survival = args.get("mode", "count") == "survival"
	SaveGame.persistent = false
	SaveGame.unlock_everything = true  # libera naves e o espaço auxiliar para testar
	Params.debug_start_weapon_level = _level
	if args.has("squad"):
		SaveGame.squad = (args["squad"] as String).split(",")
	SaveGame.companion = args.get("companion", "")
	SaveGame.upgrades = {}
	if args.has("upgrades"):
		for pair in (args["upgrades"] as String).split(","):
			var parts: PackedStringArray = pair.split("=")
			SaveGame.upgrades[parts[0]] = int(parts[1])
	_boss_only = args.has("boss-only")

	var campaign: CampaignData = Session.campaign
	var wanted: PackedStringArray = PackedStringArray()
	if args.has("stages"):
		wanted = (args["stages"] as String).split(",")
	for p in campaign.planets.size():
		if args.has("chapter") and int(args["chapter"]) != p + 1:
			continue
		for s in campaign.planets[p].stages.size():
			var id := String(campaign.planets[p].stages[s].id)
			if wanted.is_empty() or id in wanted:
				_queue.append(Vector2i(p, s))

	_candidates.append(Vector2.ZERO)
	for ring in [70.0, 150.0]:
		for i in 16:
			_candidates.append(Vector2.from_angle(TAU * i / 16.0) * ring)
	print("stage | result | time | boss_s | hits | hits/min | kills | score | bullets avg/max | enemies max | pool_full | levels")
	_start_next()


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result := {}
	var i: int = 0
	while i < raw.size():
		var key: String = raw[i]
		if key.begins_with("--") and i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
			result[key.substr(2)] = raw[i + 1]
			i += 2
		elif key.begins_with("--"):
			result[key.substr(2)] = "true"
			i += 1
		else:
			i += 1
	return result


func _start_next() -> void:
	if _queue.is_empty():
		_print_summary()
		get_tree().quit()
		return
	var next: Vector2i = _queue.pop_front()
	Session.select(next.x, next.y)
	_stage_id = String(Session.stage().id)
	if _boss_only and Session.stage().boss != null:
		var copy: StageData = Session.stage().duplicate()
		copy.duration_seconds = 2.0
		var no_waves: Array[WaveData] = []
		copy.waves = no_waves
		Session.planet().stages[next.y] = copy
	_clock = 0.0
	_virtual_invulnerable = 0.0
	_boss_started = -1.0
	_stats = {
		"hits": 0, "bullets_sum": 0.0, "bullets_max": 0, "enemies_max": 0, "frames": 0,
		"pool_full": 0, "boss_seconds": -1.0, "result": "timeout",
	}
	get_tree().paused = false
	Engine.time_scale = 1.0
	_game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_game)
	_hold_finger()


## Dedo na tela o tempo todo: sem câmera lenta.
func _hold_finger() -> void:
	var touch: TouchInput = _game.get("touch_input")
	touch.set("_index", 0)
	var controller: TimeController = _game.get("time_controller")
	controller.set_process(false)
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _waiting_free > 0:
		_waiting_free -= 1
		if _waiting_free == 0:
			_start_next()
		return
	if _game == null:
		return
	_clock += delta
	var state: MatchState = _game.get("state")
	var player: Player = _game.get("player")
	var context: CombatContext = _game.get("context")

	if get_tree().paused:
		_finish("clear" if _game.get("_spawning_done") and not state.alive_indices().is_empty() else "game over")
		return
	if _clock > (Session.stage().duration_seconds + SAFETY_SECONDS):
		_finish("timeout")
		return

	Engine.time_scale = 1.0
	if _stats["frames"] % 600 == 0:
		printerr("[sim] %s t=%.1f real=%dms bullets=%d enemies=%d" % [_stage_id, _clock, Time.get_ticks_msec(), context.enemy_bullets.active.size(), context.enemies.active.size()])
	# Corpo destruído: escolhe o próximo vivo
	var switcher: BodySwitcher = _game.get("switcher")
	if switcher.forced:
		var alive: Array[int] = state.alive_indices()
		if not alive.is_empty():
			_game.call("_on_body_chosen", alive[0])
	# Oferta de continuar: recusa (mede a fase sem anúncio)
	var offer: ReviveOffer = _game.get("revive_offer")
	if offer.get("_open"):
		offer.call("_close", false)

	if not _survival:
		player.start_invulnerability(1000.0)
		_count_virtual_hits(player, context, delta)
	if player.body != null and state.special_ready():
		_game.call("_on_special_pressed")

	player.set("_target", _choose_target(player, context))
	_measure(context)


func _measure(context: CombatContext) -> void:
	var bullets: int = context.enemy_bullets.active.size()
	_stats["bullets_sum"] += bullets
	_stats["bullets_max"] = maxi(_stats["bullets_max"], bullets)
	_stats["enemies_max"] = maxi(_stats["enemies_max"], context.enemies.active.size())
	_stats["frames"] += 1
	if context.enemy_bullets.get("_free").is_empty():
		_stats["pool_full"] += 1
	var boss: Node = _game.get("boss")
	if boss != null and _boss_started < 0.0 and not (boss as Boss).is_entering():
		_boss_started = _clock
	if boss == null and _boss_started >= 0.0 and _stats["boss_seconds"] < 0.0:
		_stats["boss_seconds"] = _clock - _boss_started


## Modo contagem: o que teria acertado o núcleo (com 1 s de invulnerabilidade após cada hit).
func _count_virtual_hits(player: Player, context: CombatContext, delta: float) -> void:
	_virtual_invulnerable = maxf(_virtual_invulnerable - delta, 0.0)
	if _virtual_invulnerable > 0.0 or player.body == null:
		return
	var center: Vector2 = player.position
	var bullets: Array[PoolItem] = context.enemy_bullets.active
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i] as Bullet
		var reach: float = bullet.radius + Params.nucleus_radius
		if bullet.position.distance_squared_to(center) <= reach * reach:
			context.enemy_bullets.release(bullet)
			_register_hit()
			return
	if context.boss != null and context.boss.hazard_hits(center, Params.nucleus_radius):
		_register_hit()
		return
	for item in context.hostiles():
		var enemy := item as Enemy
		var reach: float = enemy.radius + Params.nucleus_radius
		if enemy.visible and enemy.position.distance_squared_to(center) <= reach * reach:
			if not enemy is Boss:
				enemy.on_player_contact()
			_register_hit()
			return


func _register_hit() -> void:
	_stats["hits"] += 1
	_virtual_invulnerable = VIRTUAL_INVULNERABILITY


## Escolhe o ponto mais seguro perto da nave; empata por ficar sob os inimigos e pegar itens.
func _choose_target(player: Player, context: CombatContext) -> Vector2:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var half: Vector2 = Params.ship_size * 0.5
	var low_limit: float = minf(rect.end.y, player.bottom_limit) - half.y
	var origin: Vector2 = player.position
	var threats: Array = []
	for item in context.enemy_bullets.active:
		var bullet := item as Bullet
		if bullet.position.distance_squared_to(origin) < NEAR_BULLETS * NEAR_BULLETS:
			threats.append([bullet.position, bullet.velocity, bullet.radius])
	for item in context.hostiles():
		var enemy := item as Enemy
		if enemy.visible and enemy.position.distance_squared_to(origin) < NEAR_BULLETS * NEAR_BULLETS:
			threats.append([enemy.position, enemy.get("_velocity"), enemy.radius])

	# Alvo preferido: embaixo do inimigo mais próximo do centro, na parte baixa da tela
	var prefer := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.78)
	var target_enemy: Enemy = context.nearest_enemy(Vector2(origin.x, rect.position.y + rect.size.y * 0.3))
	if target_enemy != null:
		prefer.x = target_enemy.position.x
	for item in context.power_ups.active:
		var power_up := item as PowerUp
		if power_up.position.y > rect.position.y + rect.size.y * 0.45:
			prefer = power_up.position
			break

	var best := origin
	var best_cost: float = INF
	for offset in _candidates:
		var c: Vector2 = (origin + offset).clamp(rect.position + half, Vector2(rect.end.x - half.x, low_limit))
		var danger: float = 0.0
		for threat in threats:
			var pos: Vector2 = threat[0]
			var vel: Vector2 = threat[1]
			var reach: float = threat[2] + Params.nucleus_radius + 26.0
			for t: float in LOOKAHEAD:
				var d: float = (pos + vel * t).distance_to(c)
				if d < reach:
					danger += (reach - d) / (1.0 + t * 4.0)
		if context.boss != null:
			for band: Vector2 in context.boss.laser_bands():
				var inside: float = band.y * 0.5 + Params.nucleus_radius + 30.0 - absf(c.x - band.x)
				if inside > 0.0:
					danger += inside * 0.05
		var edge: float = minf(c.x - rect.position.x, rect.end.x - c.x)
		var cost: float = danger * 1000.0 + c.distance_to(prefer) * 0.6 + offset.length() * 0.2
		if edge < 120.0:
			cost += (120.0 - edge) * 3.0
		if cost < best_cost:
			best_cost = cost
			best = c
	return best


func _finish(result: String) -> void:
	var state: MatchState = _game.get("state")
	var minutes: float = maxf(_clock / 60.0, 0.01)
	var row := {
		"stage": _stage_id, "result": result, "time": _clock, "boss_seconds": _stats["boss_seconds"],
		"hits": _stats["hits"], "hits_per_min": _stats["hits"] / minutes, "kills": state.kills,
		"score": state.score, "bullets_avg": _stats["bullets_sum"] / maxf(_stats["frames"], 1.0),
		"bullets_max": _stats["bullets_max"], "enemies_max": _stats["enemies_max"],
		"pool_full": _stats["pool_full"], "levels": Array(state.weapon_levels),
	}
	_results.append(row)
	print("%s | %s | %d | %d | %d | %.1f | %d | %d | %.0f/%d | %d | %d | %s" % [
		row["stage"], row["result"], int(row["time"]), int(row["boss_seconds"]), row["hits"],
		row["hits_per_min"], row["kills"], row["score"], row["bullets_avg"], row["bullets_max"],
		row["enemies_max"], row["pool_full"], str(row["levels"])])
	_game.queue_free()
	_game = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	_waiting_free = 2


func _print_summary() -> void:
	var total_hits: int = 0
	var total_minutes: float = 0.0
	for row in _results:
		total_hits += row["hits"]
		total_minutes += row["time"] / 60.0
	print("TOTAL | %d fases | %.1f min | %d hits | %.2f hits/min" % [_results.size(), total_minutes, total_hits, total_hits / maxf(total_minutes, 0.01)])
