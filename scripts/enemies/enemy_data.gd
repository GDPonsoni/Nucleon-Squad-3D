class_name EnemyData
extends Resource
## Definição de um tipo de inimigo: corpo, movimento e padrão de tiro.
## Valores em data/enemies/*.tres.

enum Movement {
	DESCEND,  ## desce em linha reta
	CROSS,  ## entra por uma lateral e atravessa a tela
	DIVE,  ## desce um pouco e depois mergulha na nave
	HOVER,  ## desce até uma altura, para por um tempo e depois segue descendo
}
enum FirePattern {
	NONE,
	STRAIGHT,  ## para baixo
	AIMED,  ## na direção da nave
	RING,  ## anel de tiros em 360°
	FAN,  ## leque de tiros mirado na nave
}

@export var id: StringName
@export var max_hp: int = 6
@export var score: int = 10
@export var contact_damage: int = 1  # hits ao encostar na nave
@export var radius: float = 48.0  # colisão e desenho
@export var sides: int = 6  # polígono do placeholder
@export var color: Color = Color(0.95, 0.2, 0.35)

@export_group("Movimento")
@export var movement: Movement = Movement.DESCEND
@export var speed: float = 220.0  # px/s
@export var cross_drift: float = 0.15  # CROSS: descida em relação à velocidade lateral
@export var dive_delay: float = 0.6  # DIVE: segundos descendo antes de mergulhar
@export var dive_speed: float = 900.0
@export var dive_turn_degrees: float = 200.0  # giro por segundo ao perseguir a nave
@export var hover_y_ratio: float = 0.22  # HOVER: altura onde para (0 = topo, 1 = base)
@export var hover_seconds: float = 4.0  # HOVER: tempo parado

@export_group("Tiro")
@export var fire_pattern: FirePattern = FirePattern.STRAIGHT
@export var fire_interval: float = 1.4
@export var first_shot_delay: float = 0.4  # após entrar na tela
@export var bullet_speed: float = 700.0
@export var bullet_radius: float = 14.0
@export var bullet_damage: int = 1
@export var bullet_color: Color = Color(1.0, 0.35, 0.75)
@export var ring_count: int = 12  # RING: tiros por anel
@export var ring_turn_degrees: float = 15.0  # RING: giro do anel a cada disparo
@export var fan_count: int = 5  # FAN: tiros por leque
@export var fan_degrees: float = 50.0  # FAN: abertura total
