class_name RunWaveEntry
extends Resource
## Um tipo de onda que o diretor do modo roguelike pode sortear: inimigo, formação, tamanho
## e a janela de tempo em que aparece. Lista em data/run/run_mode.tres.

@export var enemy: EnemyData
@export var formation: WaveData.Formation = WaveData.Formation.LINE
@export var count: int = 4  # membros no começo (cresce com o tempo: RunModeData.count_growth_per_minute)
@export var max_count: int = 12
@export var spacing: float = 120.0
@export var interval: float = 0.0  # segundos entre membros (0 = todos juntos)
@export var speed_scale: float = 1.0
@export var sway_amplitude: float = 0.0
@export var from_minute: float = 0.0  # começa a aparecer
@export var to_minute: float = 0.0  # para de aparecer (0 = até o fim)
@export var weight: float = 1.0  # chance relativa entre as ondas ativas
@export var horde: bool = false  # inimigo que não atira, em bando: entra nos surtos
