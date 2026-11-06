class_name PowerUpDropper
extends Node
## Solta itens na posição do último inimigo destruído: um power-up a cada
## BalanceData.powerup_every_kills, um medkit a cada medkit_every_kills e, por sorteio,
## o power-up raro da nave auxiliar (companion_powerup_chance). Valores em Params.balance.

var _pool: NodePool
var _kills: int = 0
var _heal_kills: int = 0
var _powerup_every: int = 1
var _medkit_every: int = 1
## Diz se a auxiliar ainda pode subir de nível (sem auxiliar ou no máximo, não cai).
var companion_can_level: Callable = func() -> bool: return false


## Os bônus da evolução do núcleo adiantam os drops.
func setup(pool: NodePool, boosts: PlayerBoosts) -> void:
	_pool = pool
	_powerup_every = Params.balance.powerup_kills(boosts.powerup_kills_bonus)
	_medkit_every = Params.balance.medkit_kills(boosts.medkit_kills_bonus)


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
	if companion_can_level.call() and randf() < Params.balance.companion_chance():
		_drop(enemy.position - Vector2(Params.powerup_radius * 2.5, 0.0), PowerUp.Kind.COMPANION)


func _drop(pos: Vector2, kind: PowerUp.Kind) -> void:
	var item := _pool.acquire() as PowerUp
	if item != null:
		item.activate(pos, kind)
