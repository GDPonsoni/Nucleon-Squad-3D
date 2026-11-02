class_name PowerUpDropper
extends Node
## Solta um power-up a cada N inimigos destruídos, na posição do último.

var _pool: NodePool
var _kills: int = 0


func setup(pool: NodePool) -> void:
	_pool = pool


func on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	if _kills < Params.powerup_every_kills:
		return
	_kills = 0
	var power_up := _pool.acquire() as PowerUp
	if power_up != null:
		power_up.activate(enemy.position)
