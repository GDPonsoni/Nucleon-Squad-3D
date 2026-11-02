class_name StageData
extends Resource
## Definição de uma fase: quais inimigos aparecem e com que frequência.
## Valores em data/stages/*.tres.

@export var id: StringName
@export var enemies: Array[EnemyData] = []
@export var start_delay: float = 1.5
@export var spawn_interval_min: float = 0.9
@export var spawn_interval_max: float = 1.8
@export var spawn_margin_x: float = 80.0  # distância mínima das bordas laterais
