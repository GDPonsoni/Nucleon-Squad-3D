class_name BossAttack
extends Resource
## Um ataque do chefe, repetido em intervalos enquanto a fase dele estiver ativa.

enum Pattern {
	FAN,  ## leque de tiros (mirado na nave ou para baixo)
	RING,  ## anel em 360°; com giro e poucos tiros vira espiral
	SUMMON,  ## chama uma onda de inimigos
	BIG_SLOW,  ## orbes grandes e lentos (count, spread_degrees, aimed): forçam desvio
	LASER,  ## raio vertical (laser_width) por laser_seconds, na nave (aimed) ou embaixo do chefe
	CURTAIN,  ## fileira de count tiros caindo do topo, com uma brecha de gap_width
	RAIN,  ## count tiros caindo do topo em x sorteados (marcados no aviso)
	MINES,  ## leque de tiros que freiam (mine_drag), param e explodem em anel (split_*)
	CHARGE,  ## investida: avisa a faixa e avança até a altura da nave; no impacto, anel de count tiros
	SWEEP,  ## varredura: raio saindo do chefe que gira sweep_degrees em laser_seconds
	TROOPS,  ## tropas: count inimigos (troop) saem do corpo do chefe com a trajetória troop_path
}

@export var pattern: Pattern = Pattern.FAN
@export var interval: float = 1.5
@export var first_delay: float = 1.0  # ao começar a fase
@export var telegraph_seconds: float = 0.7  # aviso antes do ataque (em rajadas, só antes do primeiro; em fluxo contínuo, só no começo)
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
@export var laser_width: float = 130.0  # LASER
@export var laser_seconds: float = 0.6  # LASER: quanto tempo o raio fica ligado
@export var gap_width: float = 300.0  # CURTAIN: largura da brecha
@export var mine_drag: float = 2.2  # MINES: frenagem (1/s)
@export var charge_speed: float = 1500.0  # CHARGE: px/s
@export var sweep_degrees: float = 120.0  # SWEEP: arco total varrido
@export var troop: EnemyData  # TROOPS
@export var troop_path: Array[MoveStep] = []  # TROOPS: trajetória das tropas (vazia = a do inimigo)

@export_group("Tiros especiais")
@export var split_time: float = 0.0  # > 0: os tiros se dividem após esse tempo
@export var split_count: int = 6
@export var split_speed: float = 420.0
@export var split_radius: float = 11.0
@export var homing_time: float = 0.0  # > 0: os tiros perseguem a nave por esse tempo
@export var homing_turn_degrees: float = 140.0
