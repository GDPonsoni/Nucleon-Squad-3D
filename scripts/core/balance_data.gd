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
@export_range(1, 200) var powerup_every_kills: int = 24
@export_range(1, 200) var medkit_every_kills: int = 30
## Chance por inimigo abatido do power-up raro da auxiliar.
@export_range(0.0, 1.0, 0.001) var companion_powerup_chance: float = 0.012
## Multiplica todos os "a cada N" acima (2 = metade dos drops). Chance da auxiliar divide.
@export_range(0.1, 10.0, 0.05) var drop_rarity_multiplier: float = 1.0

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


func powerup_kills(bonus: int = 0) -> int:
	return maxi(roundi(powerup_every_kills * drop_rarity_multiplier) - bonus, 1)


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
