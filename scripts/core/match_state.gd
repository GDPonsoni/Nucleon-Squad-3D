class_name MatchState
extends RefCounted
## Estado da partida: corpos da formação, hits restantes de cada um e corpo ativo.
## Não assume quantidade fixa de corpos. Os bônus da evolução do núcleo (vida, nível
## inicial, escudos, recarga do especial e quarks) são aplicados aqui.

signal body_changed(index: int)
signal hits_changed(index: int, hits_left: int)
signal body_destroyed(index: int)
signal game_over
signal weapon_level_changed(index: int, level: int)
signal score_changed(score: int)
signal shields_changed(shields: int)
signal companion_level_changed(level: int)

var bodies: Array[BodyData] = []
var hits_left: PackedInt32Array = PackedInt32Array()
var weapon_levels: PackedInt32Array = PackedInt32Array()  # nível da arma de cada corpo
var special_charge: PackedFloat32Array = PackedFloat32Array()  # segundos de carga do especial por corpo
var lost_levels: PackedInt32Array = PackedInt32Array()  # nível da arma de cada corpo ao ser destruído (revive)
var current: int = 0
var boosts: PlayerBoosts
var max_hits: int = 0  # hits de cada corpo (com a evolução do núcleo)
var start_level: int = 1  # nível das armas ao começar (e ao perder o corpo)
var shields: int = 0  # hits absorvidos antes de tirar vida (evolução do núcleo)
var companion: BodyData  # nave auxiliar (null = sem auxiliar)
var companion_level: int = 1  # sobe com o power-up raro; não se perde durante a partida
var companion_powerups: int = 0
var switch_cooldown_left: float = 0.0  # segundos (de jogo) até poder trocar de corpo de novo

# Estatísticas da partida (HUD e telas de resultado)
var score: int = 0
var kills: int = 0
var powerups_collected: int = 0
var medkits_collected: int = 0
var shields_used: int = 0
var quarks: float = 0.0  # quarks ganhos com os inimigos nesta partida (ainda não guardados)


func _init(formation: FormationData, player_boosts: PlayerBoosts = PlayerBoosts.new()) -> void:
	boosts = player_boosts
	bodies = formation.bodies.duplicate()
	max_hits = Params.body_max_hits + boosts.extra_hits
	start_level = Params.debug_start_weapon_level + boosts.start_level_bonus
	shields = boosts.shields
	hits_left.resize(bodies.size())
	hits_left.fill(max_hits)
	weapon_levels.resize(bodies.size())
	special_charge.resize(bodies.size())
	special_charge.fill(0.0)
	lost_levels.resize(bodies.size())
	for i in bodies.size():
		weapon_levels[i] = _clamp_level(i, start_level)
		lost_levels[i] = weapon_levels[i]


func current_body() -> BodyData:
	return bodies[current]


func is_alive(index: int) -> bool:
	return hits_left[index] > 0


func alive_indices() -> Array[int]:
	var result: Array[int] = []
	for i in bodies.size():
		if is_alive(i):
			result.append(i)
	return result


func dead_count() -> int:
	return bodies.size() - alive_indices().size()


func select(index: int) -> void:
	current = index
	body_changed.emit(index)


## Troca voluntária: começa a recarga. A escolha após um corpo destruído não passa por aqui.
func start_switch_cooldown() -> void:
	switch_cooldown_left = Params.switch_cooldown_seconds


func tick_switch_cooldown(delta: float) -> void:
	switch_cooldown_left = maxf(switch_cooldown_left - delta, 0.0)


func can_switch() -> bool:
	return switch_cooldown_left <= 0.0


## 0 a 1: quanto ainda falta da recarga da troca (1 = acabou de trocar).
func switch_cooldown_ratio() -> float:
	return switch_cooldown_left / Params.switch_cooldown_seconds if Params.switch_cooldown_seconds > 0.0 else 0.0


## Tira hits do corpo ativo. Emite body_destroyed e, se acabaram os corpos, game_over.
func damage_current(amount: int) -> void:
	if not is_alive(current):
		return
	hits_left[current] = maxi(hits_left[current] - amount, 0)
	hits_changed.emit(current, hits_left[current])
	if is_alive(current):
		return
	# Corpo perdido leva junto os power-ups da arma e a carga do especial
	lost_levels[current] = weapon_levels[current]
	weapon_levels[current] = _clamp_level(current, start_level)
	special_charge[current] = 0.0
	body_destroyed.emit(current)
	if alive_indices().is_empty():
		game_over.emit()


## Escudo da evolução do núcleo: absorve um hit inteiro. Retorna false se não havia escudo.
func absorb_with_shield() -> bool:
	if shields <= 0:
		return false
	shields -= 1
	shields_used += 1
	shields_changed.emit(shields)
	return true


## Recupera hits do corpo ativo, até o máximo. Retorna false se já estava cheio.
func heal_current(amount: int) -> bool:
	if not is_alive(current) or hits_left[current] >= max_hits:
		return false
	hits_left[current] = mini(hits_left[current] + amount, max_hits)
	hits_changed.emit(current, hits_left[current])
	return true


## Sobe o nível da arma do corpo ativo. Retorna false se já estiver no máximo.
func level_up_current() -> bool:
	if weapon_levels[current] >= current_body().weapon.max_level():
		return false
	weapon_levels[current] += 1
	weapon_level_changed.emit(current, weapon_levels[current])
	return true


## A auxiliar ainda pode subir de nível (existe e não está no máximo).
func companion_can_level() -> bool:
	return companion != null and companion_level < companion.weapon.companion_max_level()


## Sobe o nível da auxiliar. Retorna false se não há auxiliar ou já está no máximo.
func level_up_companion() -> bool:
	if not companion_can_level():
		return false
	companion_level += 1
	companion_powerups += 1
	companion_level_changed.emit(companion_level)
	return true


## Inimigo destruído: soma pontos e os quarks correspondentes.
func add_kill(points: int) -> void:
	kills += 1
	score += points
	quarks += points * Params.quarks_per_point * boosts.quarks
	score_changed.emit(score)


## Segundos para encher o especial do corpo ativo (com a evolução do núcleo).
func special_seconds() -> float:
	return current_body().weapon.special_charge_seconds * Params.special_charge_multiplier * boosts.special_charge


## O especial do corpo ativo carrega com o tempo (de jogo) enquanto ele está ativo.
func charge_special(delta: float) -> void:
	if is_alive(current):
		special_charge[current] = minf(special_charge[current] + delta, special_seconds())


## 0 a 1: quanto o especial do corpo ativo já carregou.
## A carga fica num PackedFloat32Array (32 bits) e o tempo total é float de 64 bits: um tempo
## que não cabe exato em 32 bits (ex.: 24,3 s) deixava a carga em 0,9999999 e o especial
## nunca ficava pronto. Por isso a comparação tem folga.
func special_ratio() -> float:
	var seconds: float = special_seconds()
	if special_charge[current] >= seconds - Params.special_ready_epsilon:
		return 1.0
	return clampf(special_charge[current] / seconds, 0.0, 1.0)


func special_ready() -> bool:
	return is_alive(current) and special_ratio() >= 1.0


## Momento de especial: a carga do corpo ativo enche na hora.
func fill_special() -> void:
	if is_alive(current):
		special_charge[current] = special_seconds()


func use_special() -> void:
	special_charge[current] = 0.0


## Revive (após anúncio): o corpo volta com a vida cheia e o nível de arma que tinha.
func revive(index: int) -> void:
	hits_left[index] = max_hits
	weapon_levels[index] = lost_levels[index]
	hits_changed.emit(index, hits_left[index])
	select(index)


func _clamp_level(index: int, level: int) -> int:
	return clampi(level, 1, bodies[index].weapon.max_level())
