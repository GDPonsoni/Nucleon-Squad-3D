class_name BalanceData
extends Resource
## Ritmo e economia da partida num só lugar (data/balance.tres, carregado em Params.balance).
## Só ordens de grandeza: ajuste aqui, a lógica não muda. Um painel de debug pode ler
## tunables() e escrever direto nas propriedades.

@export_group("Vida dos inimigos")
## Multiplicador global sobre a vida de todo inimigo (soma-se a StageData.enemy_hp_scale).
@export_range(0.1, 10.0, 0.05) var enemy_hp_multiplier: float = 1.0
## Multiplicador por capítulo (índice 0 = capítulo 1). O jogador evolui com o avanço, então a
## vida sobe junto; o capítulo 1 fica em 1 para quem começa do zero. Passa do fim = repete o último.
@export var enemy_hp_by_chapter: PackedFloat32Array = [1.0, 1.4, 1.9, 2.4, 3.0]
## Curva por fase: cada fase do capítulo (0 a 8) soma esta fração à vida (1 + n x passo).
@export_range(0.0, 0.5, 0.01) var enemy_hp_per_stage: float = 0.05

@export_group("Drops por tempo de fase")
## Todos os drops seguem o relógio da fase (independem de quantos inimigos ela tem): ficam
## "devidos" e caem no próximo abate. Cada tipo solta `N` itens ao longo de `span` da duração.
## Power-ups de arma: 15 permite 3 armas no nível 5 (4 power-ups cada = 12) com folga.
@export_range(1, 60) var powerups_per_stage: int = 15
@export_range(0.2, 1.0, 0.05) var powerup_span: float = 0.75
## Kits médicos: poucos, para a vida dos corpos importar (o nó Reparo aumenta a frequência).
@export_range(0, 20) var medkits_per_stage: int = 2
@export_range(0.2, 1.0, 0.05) var medkit_span: float = 0.9
## Power-up da auxiliar (raro): só conta enquanto ela pode subir de nível.
@export_range(0, 10) var companion_powerups_per_stage: int = 2
@export_range(0.2, 1.0, 0.05) var companion_powerup_span: float = 0.7
## Multiplica todos os intervalos (2 = metade dos drops).
@export_range(0.1, 10.0, 0.05) var drop_rarity_multiplier: float = 1.0
## Menor fração do intervalo que os bônus da evolução podem deixar (0,4 = no máximo 2,5x mais drops).
@export_range(0.1, 1.0, 0.05) var drop_interval_floor: float = 0.4

@export_group("Chefes")
## Multiplicador da vida do chefe de capítulo e do intermediário (sobre BossData.max_hp).
@export_range(0.5, 6.0, 0.05) var boss_hp_multiplier: float = 1.6
@export_range(0.5, 6.0, 0.05) var miniboss_hp_multiplier: float = 1.5
## Ataques com intervalo >= 1 s ficam mais rápidos por capítulo (índice 0 = capítulo 1): intervalo x fator.
@export var boss_interval_by_chapter: PackedFloat32Array = [0.95, 0.9, 0.85, 0.8, 0.75]
## Fase final extra de fúria: começa com esta fração da vida (0 desliga). Copia a última fase.
@export_range(0.0, 0.6, 0.01) var boss_enrage_ratio: float = 0.25
@export_range(0.3, 1.0, 0.05) var boss_enrage_interval_scale: float = 0.7
@export_range(1.0, 2.0, 0.05) var boss_enrage_bullet_speed_scale: float = 1.12
@export_range(1.0, 2.0, 0.05) var boss_enrage_sway_scale: float = 1.2

@export_group("Fase")
## Escala o tempo da fase (ondas e duração). Ondas extras que preencham o tempo dependem da
## estrutura aprovada; até lá, deixe em 1.
@export_range(0.5, 4.0, 0.05) var stage_duration_scale: float = 1.0

@export_group("Especial")
## Multiplica o tempo de carga de todos os especiais (1,5 = +50%).
@export_range(0.1, 10.0, 0.05) var special_charge_multiplier: float = 1.5


## Fator final de vida para a fase `stage_index` (0 a 8) do capítulo `chapter_index` (0 a 4).
func enemy_hp_factor(chapter_index: int, stage_index: int) -> float:
	var chapter: float = 1.0
	if not enemy_hp_by_chapter.is_empty():
		chapter = enemy_hp_by_chapter[clampi(chapter_index, 0, enemy_hp_by_chapter.size() - 1)]
	return enemy_hp_multiplier * chapter * (1.0 + enemy_hp_per_stage * stage_index)


## Segundos de jogo entre drops de um tipo: `count` itens em `span` da fase de `stage_seconds`.
## `cut` = fração encurtada pela evolução do núcleo (0,2 = intervalo 20% menor), com piso.
func drop_interval(stage_seconds: float, count: int, span: float, cut: float = 0.0) -> float:
	if count <= 0:
		return INF
	var base: float = stage_seconds * span / count * drop_rarity_multiplier
	return base * maxf(1.0 - cut, drop_interval_floor)


func powerup_interval(stage_seconds: float, cut: float = 0.0) -> float:
	return drop_interval(stage_seconds, powerups_per_stage, powerup_span, cut)


func medkit_interval(stage_seconds: float, cut: float = 0.0) -> float:
	return drop_interval(stage_seconds, medkits_per_stage, medkit_span, cut)


func companion_powerup_interval(stage_seconds: float) -> float:
	return drop_interval(stage_seconds, companion_powerups_per_stage, companion_powerup_span)


## Lista de ajustes para um painel: {name, value, group, hint}. Só propriedades @export.
func tunables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group: String = ""
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_GROUP:
			group = p["name"]
		elif p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and p["usage"] & PROPERTY_USAGE_EDITOR:
			out.append({"name": p["name"], "value": get(p["name"]), "group": group, "hint": p["hint_string"]})
	return out
