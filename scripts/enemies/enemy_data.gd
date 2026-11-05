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
enum Look {
	POLYGON,  ## polígono regular (naves)
	ROCK,  ## rocha irregular que gira
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
@export var look: Look = Look.POLYGON
## false = obstáculo (rocha): bloqueia tiros e machuca ao encostar, mas mísseis, Tesla,
## ricochete e mira automática não o escolhem como alvo.
@export var targetable: bool = true
## Dano recebido por arma (WeaponData.Kind -> multiplicador; ausente = 1). Ex.: {0: 1.4} = Raio +40%.
@export var weapon_multipliers: Dictionary = {}

@export_group("Movimento")
@export var movement: Movement = Movement.DESCEND
@export var speed: float = 220.0  # px/s
@export var cross_drift: float = 0.15  # CROSS: descida em relação à velocidade lateral
@export var dive_delay: float = 0.6  # DIVE: segundos descendo antes de mergulhar
@export var dive_speed: float = 900.0
@export var dive_turn_degrees: float = 200.0  # giro por segundo ao perseguir a nave
@export var hover_y_ratio: float = 0.22  # HOVER: altura onde para (0 = topo, 1 = base)
@export var hover_seconds: float = 4.0  # HOVER: tempo parado
@export var spin_degrees: float = 0.0  # giro do desenho por segundo (sorteia o sentido)
@export var drift_x: float = 0.0  # deriva lateral aleatória (px/s, até esse valor para cada lado) ao surgir sozinho

@export_group("Tiro")
@export var fire_pattern: FirePattern = FirePattern.STRAIGHT
@export var fire_interval: float = 1.4
@export var first_shot_delay: float = 0.4  # após entrar na tela
@export var bullet_speed: float = 700.0
@export var bullet_radius: float = 14.0
@export var bullet_damage: int = 1
@export var bullet_color: Color = Color(1.0, 0.35, 0.75)
@export var telegraph_seconds: float = 0.4  # aviso antes de cada disparo (e antes do mergulho, em DIVE)
@export var telegraph_sound: bool = false  # o aviso também toca som (tiros grandes)
@export var ring_count: int = 12  # RING: tiros por anel
@export var ring_turn_degrees: float = 15.0  # RING: giro do anel a cada disparo
@export var fan_count: int = 5  # FAN: tiros por leque
@export var fan_degrees: float = 50.0  # FAN: abertura total

@export_group("Tiros especiais")  # valem para qualquer padrão de tiro
@export var bullet_split_time: float = 0.0  # > 0: o tiro se divide após esse tempo
@export var bullet_split_count: int = 6
@export var bullet_split_speed: float = 420.0
@export var bullet_split_radius: float = 11.0
@export var bullet_homing_time: float = 0.0  # > 0: o tiro persegue a nave por esse tempo
@export var bullet_homing_turn_degrees: float = 140.0

## Multiplicador de dano de uma fonte (WeaponData.Kind; outras fontes = 1).
func multiplier_for(source: int) -> float:
	return float(weapon_multipliers.get(source, 1.0))


@export_group("Ao ser destruído")
@export var death_spawn: EnemyData  # fissão: vira esses inimigos ao ser destruído (vazio = nada)
@export var death_spawn_count: int = 3
@export var death_spawn_spread_degrees: float = 70.0  # leque para baixo onde os pedaços saem
