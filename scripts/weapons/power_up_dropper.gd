class_name PowerUpDropper
extends Node
## Solta itens na posição do último inimigo destruído: um power-up a cada
## powerup_every_kills e um medkit (mais raro) a cada medkit_every_kills.

var _pool: NodePool
var _kills: int = 0
var _heal_kills: int = 0
var _powerup_every: int = 1
var _medkit_every: int = 1


## Os bônus da evolução do núcleo adiantam os drops.
func setup(pool: NodePool, boosts: PlayerBoosts) -> void:
	_pool = pool
	_powerup_every = maxi(Params.powerup_every_kills - boosts.powerup_kills_bonus, 1)
	_medkit_every = maxi(Params.medkit_every_kills - boosts.medkit_kills_bonus, 1)


func on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	_heal_kills += 1
	if _kills >= _powerup_every:
		_kills = 0
		_drop(enemy.position, PowerUp.Kind.WEAPON)
	if _heal_kills >= _medkit_every:
		_heal_kills = 0
		# Se cair junto com um power-up, sai um pouco ao lado
		_drop(enemy.position + Vector2(Params.powerup_radius * 2.5, 0.0), PowerUp.Kind.HEAL)


func _drop(pos: Vector2, kind: PowerUp.Kind) -> void:
	var item := _pool.acquire() as PowerUp
	if item != null:
		item.activate(pos, kind)
