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

@export_group("Drops (1 a cada N inimigos; maior = mais raro)")
@export_range(1, 200) var medkit_every_kills: int = 30
## Chance por inimigo abatido do power-up raro da auxiliar.
@export_range(0.0, 1.0, 0.001) var companion_powerup_chance: float = 0.012
## Multiplica todos os "a cada N" acima (2 = metade dos drops). Chance da auxiliar divide.
@export_range(0.1, 10.0, 0.05) var drop_rarity_multiplier: float = 1.0

@export_group("Power-ups de arma (por tempo de fase)")
## Quantos power-ups de arma a fase solta ao longo de `powerup_span` da duração. 15 permite
## 3 armas no nível 5 (4 power-ups cada = 12) com folga para os que o jogador perde.
@export_range(1, 60) var powerups_per_stage: int = 15
## Fração da duração da fase em que esses power-ups são soltos (0,75 = até 75% da fase).
@export_range(0.2, 1.0, 0.05) var powerup_span: float = 0.75
## Cada bônus da evolução do núcleo ("power-up N inimigos antes") encurta o intervalo nesta fração.
@export_range(0.0, 0.2, 0.005) var powerup_bonus_step: float = 0.04

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


## Segundos de jogo entre power-ups de arma numa fase de `stage_seconds`.
func powerup_interval(stage_seconds: float, kills_bonus: int = 0) -> float:
	var base: float = stage_seconds * powerup_span / maxf(powerups_per_stage, 1) * drop_rarity_multiplier
	return base * maxf(1.0 - powerup_bonus_step * kills_bonus, 0.4)


func medkit_kills(bonus: int = 0) -> int:
	return maxi(roundi(medkit_every_kills * drop_rarity_multiplier) - bonus, 1)


func companion_chance() -> float:
	return companion_powerup_chance / drop_rarity_multiplier


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
