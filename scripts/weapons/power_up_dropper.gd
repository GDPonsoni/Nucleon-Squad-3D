class_name PowerUpDropper
extends Node
## Solta itens na posição do último inimigo destruído. Todos seguem o relógio da fase
## (BalanceData: powerups/medkits/companion_powerups_per_stage ao longo do span de cada um):
## cada item fica "devido" no seu horário e cai no próximo abate (acumula até MAX_OWED).

const MAX_OWED: int = 2
## Evento do tutorial quando cada tipo aparece pela primeira vez.
const SPAWN_EVENTS: Dictionary = {
	PowerUp.Kind.WEAPON: &"powerup_spawned", PowerUp.Kind.HEAL: &"medkit_spawned",
	PowerUp.Kind.COMPANION: &"companion_powerup_spawned", PowerUp.Kind.CHEST: &"chest_spawned",
}

var _pool: NodePool
var _clock: float = 0.0
## Por tipo (PowerUp.Kind): intervalo, próximo horário e quantos estão devidos.
var _interval: Dictionary = {}
var _next_due: Dictionary = {}
var _owed: Dictionary = {}
## Diz se a auxiliar ainda pode subir de nível (sem auxiliar ou no máximo, não cai).
var companion_can_level: Callable = func() -> bool: return false


## Os bônus da evolução do núcleo encurtam os intervalos.
## weapon_powerups = false: só kits e auxiliar (modos em que a arma sobe de outro jeito).
func setup(pool: NodePool, boosts: PlayerBoosts, stage_seconds: float = 120.0, weapon_powerups: bool = true) -> void:
	_pool = pool
	var balance: BalanceData = Params.balance
	# O primeiro power-up vem cedo; o primeiro kit e o da auxiliar, só depois de um intervalo
	if weapon_powerups:
		_add(PowerUp.Kind.WEAPON, balance.powerup_interval(stage_seconds, boosts.powerup_interval_cut), 0.5)
	_add(PowerUp.Kind.HEAL, balance.medkit_interval(stage_seconds, boosts.medkit_interval_cut), 1.0)
	_add(PowerUp.Kind.COMPANION, balance.companion_powerup_interval(stage_seconds), 1.0)


func _add(kind: PowerUp.Kind, interval: float, first_share: float) -> void:
	_interval[kind] = interval
	_next_due[kind] = interval * first_share
	_owed[kind] = 0


func _process(delta: float) -> void:
	# Tempo de jogo (acompanha a câmera lenta, como a linha do tempo da fase)
	_clock += delta
	for kind: PowerUp.Kind in _interval:
		while _clock >= _next_due[kind]:
			_next_due[kind] += _interval[kind]
			# A auxiliar no máximo (ou ausente) não acumula drops
			if kind != PowerUp.Kind.COMPANION or companion_can_level.call():
				_owed[kind] = mini(_owed[kind] + 1, MAX_OWED)


func on_enemy_killed(enemy: Enemy) -> void:
	# Itens do mesmo abate saem lado a lado
	var offsets: Dictionary = {
		PowerUp.Kind.WEAPON: Vector2.ZERO,
		PowerUp.Kind.HEAL: Vector2(Params.powerup_radius * 2.5, 0.0),
		PowerUp.Kind.COMPANION: Vector2(-Params.powerup_radius * 2.5, 0.0),
	}
	for kind: PowerUp.Kind in _owed:
		if _owed[kind] <= 0:
			continue
		if kind == PowerUp.Kind.COMPANION and not companion_can_level.call():
			_owed[kind] = 0
			continue
		_owed[kind] -= 1
		_drop(enemy.position + offsets[kind], kind)


## Troca o intervalo de um tipo (modos com ritmo próprio). 0 ou menos desliga.
func set_interval(kind: PowerUp.Kind, seconds: float) -> void:
	_add(kind, seconds if seconds > 0.0 else INF, 1.0)
	_next_due[kind] = _clock + _interval[kind]


## Solta um item agora, fora do relógio (recompensas de elite e chefe).
func drop_now(pos: Vector2, kind: PowerUp.Kind) -> void:
	_drop(pos, kind)


## Quantos itens de um tipo estão devidos (para testes).
func owed(kind: PowerUp.Kind) -> int:
	return int(_owed.get(kind, 0))


func _drop(pos: Vector2, kind: PowerUp.Kind) -> void:
	var item := _pool.acquire() as PowerUp
	if item != null:
		item.activate(pos, kind)
		Tutorial.notify(SPAWN_EVENTS[kind], "", item)
