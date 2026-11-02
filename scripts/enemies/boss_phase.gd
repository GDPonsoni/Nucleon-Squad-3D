class_name BossPhase
extends Resource
## Fase de ataque do chefe: começa quando a vida cai até hp_ratio.

@export var hp_ratio: float = 1.0  # 1 = desde o início; 0.5 = a partir de metade da vida
@export var attacks: Array[BossAttack] = []
@export var sway_speed_scale: float = 1.0  # balança mais rápido nas fases finais
