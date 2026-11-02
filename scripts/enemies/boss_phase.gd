class_name BossPhase
extends Resource
## Fase de ataque do chefe: começa quando a vida cai até hp_ratio.

enum Movement {
	SWAY,  ## balança de um lado para o outro
	FIGURE8,  ## desenha um oito, subindo e descendo
	CHASE,  ## segue a nave na horizontal
}

@export var hp_ratio: float = 1.0  # 1 = desde o início; 0.5 = a partir de metade da vida
@export var attacks: Array[BossAttack] = []
@export var sway_speed_scale: float = 1.0  # balança mais rápido nas fases finais
@export var movement: Movement = Movement.SWAY
@export var chase_speed: float = 220.0  # CHASE: px/s
