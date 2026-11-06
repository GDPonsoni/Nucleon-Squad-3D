class_name PowerUpDropper
extends Node
## Solta itens na posição do último inimigo destruído. Power-ups de arma seguem o relógio da fase:
## BalanceData.powerups_per_stage ao longo de powerup_span da duração (independe de quantos
## inimigos a fase tem); ficam "devidos" e caem no próximo abate. Medkit: um a cada
## medkit_every_kills; auxiliar: sorteio (companion_powerup_chance). Valores em Params.balance.

var _pool: NodePool
var _heal_kills: int = 0
var _powerup_interval: float = 30.0  # segundos de jogo entre power-ups devidos
var _clock: float = 0.0
var _next_due: float = 0.0
var _owed: int = 0  # power-ups devidos que ainda não caíram (no máximo 2)
var _medkit_every: int = 1
## Diz se a auxiliar ainda pode subir de nível (sem auxiliar ou no máximo, não cai).
var companion_can_level: Callable = func() -> bool: return false


## Os bônus da evolução do núcleo adiantam os drops.
func setup(pool: NodePool, boosts: PlayerBoosts, stage_seconds: float = 120.0) -> void:
	_pool = pool
	_powerup_interval = Params.balance.powerup_interval(stage_seconds, boosts.powerup_kills_bonus)
	_next_due = _powerup_interval * 0.5  # o primeiro vem cedo
	_medkit_every = Params.balance.medkit_kills(boosts.medkit_kills_bonus)


func _process(delta: float) -> void:
	# Tempo de jogo (acompanha a câmera lenta, como a linha do tempo da fase)
	_clock += delta
	while _clock >= _next_due:
		_next_due += _powerup_interval
		_owed = mini(_owed + 1, 2)


func on_enemy_killed(enemy: Enemy) -> void:
	_heal_kills += 1
	if _owed > 0:
		_owed -= 1
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
