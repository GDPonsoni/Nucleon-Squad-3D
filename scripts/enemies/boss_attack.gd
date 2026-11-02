class_name BossAttack
extends Resource
## Um ataque do chefe, repetido em intervalos enquanto a fase dele estiver ativa.

enum Pattern {
	FAN,  ## leque de tiros (mirado na nave ou para baixo)
	RING,  ## anel em 360°; com giro e poucos tiros vira espiral
	SUMMON,  ## chama uma onda de inimigos
}

@export var pattern: Pattern = Pattern.FAN
@export var interval: float = 1.5
@export var first_delay: float = 1.0  # ao começar a fase
@export var count: int = 5  # FAN/RING: tiros por disparo
@export var spread_degrees: float = 40.0  # FAN: abertura total
@export var aimed: bool = true  # FAN: mira na nave (senão, para baixo)
@export var turn_degrees: float = 0.0  # RING: giro a cada disparo (espiral)
@export var burst: int = 1  # FAN: disparos seguidos
@export var burst_gap: float = 0.12  # FAN: segundos entre disparos da rajada
@export var bullet_speed: float = 500.0
@export var bullet_radius: float = 14.0
@export var bullet_color: Color = Color(1.0, 0.35, 0.75)
@export var wave: WaveData  # SUMMON: onda chamada (time_seconds é ignorado)

@export_group("Tiros especiais")
@export var split_time: float = 0.0  # > 0: os tiros se dividem após esse tempo
@export var split_count: int = 6
@export var split_speed: float = 420.0
@export var split_radius: float = 11.0
@export var homing_time: float = 0.0  # > 0: os tiros perseguem a nave por esse tempo
@export var homing_turn_degrees: float = 140.0
