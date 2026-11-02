class_name MatchState
extends RefCounted
## Estado da partida: corpos da formação, hits restantes de cada um e corpo ativo.
## Não assume quantidade fixa de corpos.

signal body_changed(index: int)
signal hits_changed(index: int, hits_left: int)
signal body_destroyed(index: int)
signal game_over

var bodies: Array[BodyData] = []
var hits_left: PackedInt32Array = PackedInt32Array()
var current: int = 0


func _init(formation: FormationData) -> void:
	bodies = formation.bodies.duplicate()
	hits_left.resize(bodies.size())
	hits_left.fill(Params.body_max_hits)


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
	body_destroyed.emit(current)
	if alive_indices().is_empty():
		game_over.emit()
