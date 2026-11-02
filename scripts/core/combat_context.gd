class_name CombatContext
extends RefCounted
## Referências compartilhadas entre armas, inimigos e colisão.

var player_bullets: NodePool
var enemy_bullets: NodePool
var enemies: NodePool
var power_ups: NodePool
var player: Player
var boss: Boss  # fora do pool; null quando não há chefe


## Alvos atingíveis: inimigos ativos e, se houver, o chefe.
## Sem chefe, devolve a própria lista do pool (sem cópia).
func hostiles() -> Array[PoolItem]:
	if boss == null or not boss.visible:
		return enemies.active
	var list: Array[PoolItem] = enemies.active.duplicate()
	list.append(boss)
	return list


## Inimigo visível mais próximo de um ponto (null se não houver).
func nearest_enemy(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for item in hostiles():
		var enemy := item as Enemy
		if not enemy.visible or not enemy.is_on_screen():
			continue
		var distance: float = from.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
