class_name MatchState
extends RefCounted
## Estado da partida: corpos da formação, hits restantes de cada um e corpo ativo.
## Não assume quantidade fixa de corpos.

signal body_changed(index: int)
signal hits_changed(index: int, hits_left: int)
signal body_destroyed(index: int)
signal game_over
signal weapon_level_changed(index: int, level: int)
signal score_changed(score: int)

var bodies: Array[BodyData] = []
var hits_left: PackedInt32Array = PackedInt32Array()
var weapon_levels: PackedInt32Array = PackedInt32Array()  # nível da arma de cada corpo
var current: int = 0

# Estatísticas da partida (HUD e telas de resultado)
var score: int = 0
var kills: int = 0
var powerups_collected: int = 0


func _init(formation: FormationData) -> void:
	bodies = formation.bodies.duplicate()
	hits_left.resize(bodies.size())
	hits_left.fill(Params.body_max_hits)
	weapon_levels.resize(bodies.size())
	weapon_levels.fill(1)


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


## Tira hits do corpo ativo. Emite body_destroyed e, se acabaram os corpos, game_over.
func damage_current(amount: int) -> void:
	if not is_alive(current):
		return
	hits_left[current] = maxi(hits_left[current] - amount, 0)
	hits_changed.emit(current, hits_left[current])
	if is_alive(current):
		return
	# Corpo perdido leva junto os power-ups da arma
	weapon_levels[current] = 1
	body_destroyed.emit(current)
	if alive_indices().is_empty():
		game_over.emit()


## Sobe o nível da arma do corpo ativo. Retorna false se já estiver no máximo.
func level_up_current() -> bool:
	if weapon_levels[current] >= current_body().weapon.max_level():
		return false
	weapon_levels[current] += 1
	weapon_level_changed.emit(current, weapon_levels[current])
	return true


func add_kill(points: int) -> void:
	kills += 1
	score += points
	score_changed.emit(score)
