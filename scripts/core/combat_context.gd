class_name CombatContext
extends RefCounted
## Referências compartilhadas entre armas, inimigos e colisão.

var player_bullets: NodePool
var enemy_bullets: NodePool
var enemies: NodePool


## Inimigo visível mais próximo de um ponto (null se não houver).
func nearest_enemy(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for item in enemies.active:
		var enemy := item as Enemy
		if not enemy.is_on_screen():
			continue
		var distance: float = from.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
