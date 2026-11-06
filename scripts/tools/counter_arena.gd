extends Node
## Mede quanto cada arma rende contra cada inimigo: uma onda típica do inimigo desce e a
## nave (sem levar dano) segue embaixo do inimigo mais próximo atirando. Resultado: % da
## onda destruída (vida total tirada, contando pedaços) e tempo até a onda acabar.
## Serve para conferir a tabela de counters (forte/fraco) depois de mudar dados.

const TIME_LIMIT: float = 30.0
const WEAPONS: PackedStringArray = ["beam", "spread", "homing", "orbit", "lance", "artillery", "tesla", "ricochet"]

var _levels: PackedInt32Array = [1, 3, 5]
var _level: int = 1
var _cases: Array[Dictionary] = []  # {name, wave}
var _queue: Array[Vector3i] = []  # (caso, arma, nível)
var _results: Dictionary = {}  # "caso|arma|nível" -> [fração, tempo]
var _world: Node2D
var _context: CombatContext
var _player: Player
var _spawner: EnemySpawner
var _clock: float = 0.0
var _hp_total: float = 0.0
var _hp_done: float = 0.0  # vida tirada dos que já saíram de cena
var _current: Vector3i


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only_weapon: String = ""
	for i in args.size():
		if args[i] == "--levels" and i + 1 < args.size():
			_levels = PackedInt32Array(Array(args[i + 1].split(",")).map(func(x: String) -> int: return int(x)))
		if args[i] == "--weapon" and i + 1 < args.size():
			only_weapon = args[i + 1]
	seed(7)
	SaveGame.persistent = false
	_case("drone (base)", "drone", WaveData.Formation.LINE, 5, {"spacing": 165.0})
	_case("faísca", "spark", WaveData.Formation.SIDE, 6, {"interval": 0.35, "side": WaveData.EntrySide.BOTH, "y_ratio": 0.22})
	_case("enxame", "swarm", WaveData.Formation.SWARM, 18, {"spacing": 110.0, "sway_amplitude": 60.0, "sway_period": 2.0, "sway_phase_step": 0.9})
	_case("colosso", "colossus", WaveData.Formation.LINE, 1, {})
	_case("escudeiro", "shielder", WaveData.Formation.LINE, 2, {"spacing": 480.0}, "drone", 4, 200.0)
	_case("serpente", "serpent", WaveData.Formation.COLUMN, 8, {"interval": 0.36, "sway_amplitude": 140.0, "sway_period": 2.6, "sway_phase_step": 0.35})
	_case("rocha grande", "rock_large", WaveData.Formation.LINE, 2, {"spacing": 400.0})
	for c in _cases.size():
		for w in WEAPONS.size():
			if only_weapon.is_empty() or WEAPONS[w] == only_weapon:
				for level in _levels:
					_queue.append(Vector3i(c, w, level))
	_next()


## escort: onda de apoio junto (como na campanha).
func _case(name: String, enemy: String, formation: WaveData.Formation, count: int, props: Dictionary,
		escort: String = "", escort_count: int = 0, escort_spacing: float = 0.0) -> void:
	var wave := WaveData.new()
	wave.time_seconds = 0.5
	wave.enemy = load("res://data/enemies/%s.tres" % enemy)
	wave.formation = formation
	wave.count = count
	for key: String in props:
		wave.set(key, props[key])
	var waves: Array[WaveData] = [wave]
	if not escort.is_empty():
		var extra := WaveData.new()
		extra.time_seconds = 0.9
		extra.enemy = load("res://data/enemies/%s.tres" % escort)
		extra.formation = WaveData.Formation.LINE
		extra.count = escort_count
		extra.spacing = escort_spacing
		waves.append(extra)
	_cases.append({"name": name, "waves": waves})


func _next() -> void:
	if _queue.is_empty():
		_print()
		get_tree().quit()
		return
	_current = _queue.pop_front()
	_level = _current.z
	_world = Node2D.new()
	add_child(_world)
	_context = CombatContext.new()
	_context.player_bullets = _pool(Bullet.new, 400)
	_context.enemies = _pool(_make_enemy, 48)
	_context.enemy_bullets = _pool(Bullet.new, 300)
	_context.power_ups = _pool(PowerUp.new, 1)
	_player = Player.new()
	_world.add_child(_player)
	_player.setup(_context)
	_context.player = _player
	_player.place_at(Vector2(540.0, 1900.0))
	var body := load("res://data/bodies/%s_body.tres" % WEAPONS[_current.y]) as BodyData
	_player.set_body(body, _level, 0.0)
	_player.start_invulnerability(1.0e6)  # mede só a arma: quem passa pela nave foge
	var combat := CombatSystem.new()
	_world.add_child(combat)
	combat.setup(_context, _player)
	var stage := StageData.new()
	stage.duration_seconds = 0.1
	stage.waves.assign(_cases[_current.x]["waves"])
	_spawner = EnemySpawner.new()
	_world.add_child(_spawner)
	_spawner.setup(stage, _context.enemies)
	_clock = 0.0
	_hp_total = 0.0
	_hp_done = 0.0


func _pool(factory: Callable, size: int) -> NodePool:
	var pool := NodePool.new(factory, size)
	_world.add_child(pool)
	return pool


## Inimigo da arena: conta a vida inicial ao surgir e quanto perdeu ao morrer ou fugir.
## (Fase com escala 1: a vida inicial é a do EnemyData.)
func _make_enemy() -> PoolItem:
	var enemy := Enemy.new()
	enemy.context = _context
	enemy.killed.connect(func(killed: Enemy) -> void:
		killed.set_meta("dead", true)
		var data: EnemyData = killed.data
		if data.death_spawn != null and data.death_spawn_count > 0:
			_spawner.spawn_burst(data.death_spawn, killed.position, data.death_spawn_count, data.death_spawn_spread_degrees))
	enemy.expired.connect(func(item: PoolItem) -> void:
		var e := item as Enemy
		_hp_done += float(e.data.max_hp) if e.has_meta("dead") else float(e.data.max_hp) - maxf(e.hp, 0.0)
		e.remove_meta("dead")
		e.remove_meta("counted"))
	return enemy


func _process(delta: float) -> void:
	if _world == null:
		return
	_clock += delta
	for item in _context.enemies.active:
		var enemy := item as Enemy
		if enemy.bullets == null:
			enemy.bullets = _context.enemy_bullets
		if not enemy.has_meta("counted"):
			enemy.set_meta("counted", true)
			_hp_total += enemy.data.max_hp
	_follow()
	var pending: bool = _clock < 2.0 or not (_spawner.get("_pending") as Array).is_empty()
	if (not pending and _context.enemies.active.is_empty()) or _clock >= TIME_LIMIT:
		_finish()


## Fica embaixo do inimigo mais próximo (qualquer um, rochas incluídas), na parte baixa da tela.
func _follow() -> void:
	var best: Enemy = null
	var best_d: float = INF
	for item in _context.enemies.active:
		var enemy := item as Enemy
		if not enemy.is_on_screen():
			continue
		var d: float = absf(enemy.position.x - _player.position.x) + (2340.0 - enemy.position.y) * 0.2
		if d < best_d:
			best_d = d
			best = enemy
	var goal := Vector2(540.0, 1900.0)
	if best != null:
		goal.x = best.position.x
		# Órbita joga de perto: fica logo abaixo do alvo, dentro do raio da órbita
		# Armas de curto alcance jogam de perto: Órbita dentro do raio, Tesla dentro do alcance
		if WEAPONS[_current.y] == "orbit":
			goal.y = clampf(best.position.y + best.radius + 150.0, 900.0, 1900.0)
		elif WEAPONS[_current.y] == "tesla":
			goal.y = clampf(best.position.y + 700.0, 900.0, 1900.0)
	_player.place_at(_player.position.move_toward(goal, Params.ship_speed * get_process_delta_time()))


func _finish() -> void:
	var done: float = _hp_done
	for item in _context.enemies.active:
		var e := item as Enemy
		if e.has_meta("counted"):
			done += float(e.data.max_hp) - maxf(e.hp, 0.0)
	_results["%d|%d|%d" % [_current.x, _current.y, _current.z]] = [clampf(done / maxf(_hp_total, 1.0), 0.0, 1.0), _clock]
	set_process(false)
	_world.queue_free()
	_world = null
	await get_tree().process_frame
	set_process(true)
	_next()


func _print() -> void:
	print("níveis: %s (%% tirado / tempo, média dos níveis)" % str(_levels))
	var header := "inimigo".rpad(14)
	for w in WEAPONS:
		header += " | " + w.left(9).rpad(9)
	print(header)
	for c in _cases.size():
		var row: String = String(_cases[c]["name"]).rpad(14)
		for w in WEAPONS.size():
			var frac: float = 0.0
			var time: float = 0.0
			for level in _levels:
				var r: Array = _results.get("%d|%d|%d" % [c, w, level], [0.0, 0.0])
				frac += float(r[0]) / _levels.size()
				time += float(r[1]) / _levels.size()
			row += " | " + ("%3d%% %4.1fs" % [roundi(frac * 100.0), time]).rpad(9)
		print(row)
	_print_relative()


## Eficiência = % tirado por segundo. Índice = eficiência contra o inimigo / contra o Drone
## (tira a força bruta da arma), dividido pela mediana das armas naquele inimigo; média dos níveis.
## > 1,3 = brilha (✔), < 0,7 = sofre (✖).
func _print_relative() -> void:
	print("")
	print("índice relativo (✔ > 1,3 | ✖ < 0,7)")
	var header := "inimigo".rpad(14)
	for w in WEAPONS:
		header += " | " + w.left(9).rpad(9)
	print(header)
	var strong := PackedInt32Array()
	var weak := PackedInt32Array()
	strong.resize(WEAPONS.size())
	weak.resize(WEAPONS.size())
	for c in range(1, _cases.size()):
		var index := PackedFloat32Array()
		index.resize(WEAPONS.size())
		for level in _levels:
			var ratios := PackedFloat32Array()
			for w in WEAPONS.size():
				ratios.append(_efficiency(c, w, level) / maxf(_efficiency(0, w, level), 0.0001))
			var sorted := ratios.duplicate()
			sorted.sort()
			var median: float = (sorted[3] + sorted[4]) * 0.5
			for w in WEAPONS.size():
				index[w] += ratios[w] / maxf(median, 0.0001) / _levels.size()
		var row: String = String(_cases[c]["name"]).rpad(14)
		for w in WEAPONS.size():
			var mark: String = "  "
			if index[w] > 1.3:
				mark = " ✔"
				strong[w] += 1
			elif index[w] < 0.7:
				mark = " ✖"
				weak[w] += 1
			row += " | " + ("%4.2f%s" % [index[w], mark]).rpad(9)
		print(row)
	var missing := PackedStringArray()
	for w in WEAPONS.size():
		if strong[w] == 0 or weak[w] == 0:
			missing.append(WEAPONS[w])
	print("armas sem ✔ e ✖: %s" % (", ".join(missing) if not missing.is_empty() else "nenhuma"))


func _efficiency(c: int, w: int, level: int) -> float:
	var r: Array = _results.get("%d|%d|%d" % [c, w, level], [0.0, 1.0])
	return float(r[0]) / maxf(float(r[1]), 0.5)
