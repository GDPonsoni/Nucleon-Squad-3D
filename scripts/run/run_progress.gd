class_name RunProgress
extends RefCounted
## Progresso de uma partida do modo roguelike: XP, nível, armas escolhidas e seus níveis.
## Sem nós nem tela: a RunGame liga os sinais e os testes usam direto.

signal xp_changed(xp: float, needed: float)
signal leveled_up(level: int)
signal loadout_changed

var mode: RunModeData
var level: int = 1  # nível do jogador (sobe com XP)
var xp: float = 0.0  # XP acumulado rumo ao próximo nível
var pending: int = 0  # níveis ganhos ainda sem escolha feita
var xp_scale: float = 1.0  # multiplicador de XP (evolução do núcleo)
var quarks_from_levels: int = 0  # quarks ganhos nas opções de recompensa
var owned: Array[BodyData] = []  # armas escolhidas, na ordem dos espaços
var _levels: Dictionary = {}  # id do corpo -> nível da arma


func _init(run_mode: RunModeData) -> void:
	mode = run_mode


## XP para passar do nível atual ao próximo.
func xp_needed() -> float:
	return mode.xp_first_level * pow(mode.xp_growth, level - 1)


func add_xp(amount: float) -> void:
	xp += amount * xp_scale
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_needed())


func weapon_level(ship: BodyData) -> int:
	return int(_levels.get(String(ship.id), 0))


func slots_used() -> int:
	return owned.size()


func is_full() -> bool:
	return owned.size() >= mode.weapon_slots


func is_maxed(ship: BodyData) -> bool:
	return weapon_level(ship) >= ship.weapon.max_level()


## Arma de maior nível (o especial é o dela); empate fica com a escolhida primeiro.
func best_weapon() -> BodyData:
	var best: BodyData = null
	for ship in owned:
		if best == null or weapon_level(ship) > weapon_level(best):
			best = ship
	return best


## Sorteia as opções do próximo nível entre as armas disponíveis (as liberadas na campanha).
## Com espaço livre: armas novas e as que ainda sobem. Cheio: só as que já tem e ainda sobem.
## Faltando opções, completa com uma recompensa em quarks.
func roll_choices(rng: RandomNumberGenerator, available: Array[BodyData], allow_reward: bool = true) -> Array[RunChoice]:
	var pool: Array[RunChoice] = []
	for ship in owned:
		if not is_maxed(ship):
			pool.append(RunChoice.weapon(ship, weapon_level(ship) + 1))
	if not is_full():
		for ship in available:
			if not owned.has(ship):
				pool.append(RunChoice.weapon(ship, 1))
	# Embaralha com a semente da partida
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: RunChoice = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var result: Array[RunChoice] = pool.slice(0, mini(pool.size(), mode.choices_per_level))
	if allow_reward and result.size() < mode.choices_per_level:
		result.append(RunChoice.reward(mode.quarks_per_extra_level))
	return result


## Aplica a opção escolhida e consome um nível pendente (se houver).
func apply(choice: RunChoice) -> void:
	pending = maxi(pending - 1, 0)
	match choice.kind:
		RunChoice.Kind.QUARKS:
			quarks_from_levels += choice.quarks
			return
		_:
			if not owned.has(choice.body):
				owned.append(choice.body)
			_levels[String(choice.body.id)] = mini(choice.to_level, choice.body.weapon.max_level())
	loadout_changed.emit()
