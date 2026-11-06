class_name StageData
extends Resource
## Definição de uma fase: quais inimigos aparecem e com que frequência.
## Valores em data/stages/*.tres.

@export var id: StringName
@export var duration_seconds: float = 120.0  # depois disso param de surgir inimigos
@export var enemies: Array[EnemyData] = []
@export var spawn_weights: PackedFloat32Array = []  # chance relativa de cada inimigo (mesma ordem)
@export var waves: Array[WaveData] = []  # ondas em formação em momentos fixos
@export var boss: BossData  # chefe que entra quando o tempo acaba (opcional)
@export var start_delay: float = 1.5
@export var spawn_interval_min: float = 0.9
@export var spawn_interval_max: float = 1.8
@export var spawn_margin_x: float = 80.0  # distância mínima das bordas laterais
@export var enemy_hp_scale: float = 1.0  # multiplica a vida dos inimigos da fase (capítulos finais)
@export var enemy_fire_scale: float = 1.0  # multiplica a cadência de tiro dos inimigos da fase

@export_group("Rochas")  # obstáculos que caem durante a fase (vazio = nenhuma)
@export var rocks: Array[EnemyData] = []
@export var rock_weights: PackedFloat32Array = []  # chance relativa de cada rocha (mesma ordem)
@export var rock_interval_min: float = 0.0  # segundos entre rochas (0 = sem rochas)
@export var rock_interval_max: float = 0.0

@export_group("Estrelas")
## Pontos para 2 e 3 estrelas (1 estrela = concluir a fase). Geradas pelo campaign_builder.
@export var star_scores: PackedInt32Array = []


## Estrelas (1 a 3) de uma partida concluída com essa pontuação.
func stars_for(score: int) -> int:
	var stars: int = 1
	for target in star_scores:
		if score >= target:
			stars += 1
	return mini(stars, 3)


## Pontos da próxima estrela depois de `stars` (0 se já tem as 3).
func next_star_score(stars: int) -> int:
	return star_scores[stars - 1] if stars >= 1 and stars - 1 < star_scores.size() else 0
