class_name StageData
extends Resource
## Definição de uma fase: quais inimigos aparecem e com que frequência.
## Valores em data/stages/*.tres.

@export var id: StringName
@export var duration_seconds: float = 120.0  # depois disso param de surgir inimigos
@export var enemies: Array[EnemyData] = []
@export var spawn_weights: PackedFloat32Array = []  # chance relativa de cada inimigo (mesma ordem)
@export var waves: Array[WaveData] = []  # ondas em formação em momentos fixos
@export var start_delay: float = 1.5
@export var spawn_interval_min: float = 0.9
@export var spawn_interval_max: float = 1.8
@export var spawn_margin_x: float = 80.0  # distância mínima das bordas laterais
