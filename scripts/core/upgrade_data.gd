class_name UpgradeData
extends Resource
## Um nó da árvore de evolução do núcleo: efeito por nível, custo e pré-requisitos.
## Valores em data/upgrades/*.tres; a árvore fica em data/upgrade_tree.tres.

enum Stat {
	DAMAGE,  ## dano de todas as armas e especiais (+% por nível)
	FIRE_RATE,  ## cadência de todas as armas (+%)
	SPECIAL,  ## dano do especial (+%) e recarga mais rápida (metade disso, em %)
	BOSS_DAMAGE,  ## dano em chefes (+%)
	MAX_HITS,  ## hits a mais em cada corpo
	INVULNERABILITY,  ## segundos a mais de invulnerabilidade após levar hit
	SHIELD,  ## escudos por fase (cada um absorve um hit)
	MEDKIT,  ## intervalo entre kits médicos (-% por nível)
	COLLECT,  ## quarks (+%) e alcance de coleta (+1,5x isso)
	POWERUP,  ## intervalo entre power-ups de arma (-% por nível)
	COMPANION,  ## dano da nave auxiliar (+%)
	START_LEVEL,  ## níveis a mais nas armas ao começar a fase
	OVERDRIVE,  ## dano geral (+%), sem limite de níveis
}

@export var id: StringName
@export var name_key: String  # chave da tabela de tradução
@export var description_key: String  # texto com %s para o valor do efeito
@export var stat: Stat = Stat.DAMAGE
@export var per_level: float = 0.1  # efeito somado a cada nível
@export var max_level: int = 5  # 0 = sem limite
@export var base_cost: int = 50  # custo do 1º nível, em quarks
@export var cost_growth: float = 1.35  # cada nível custa isso vezes o anterior
@export var cost_step: int = 0  # e mais isso por nível (custo linear)
@export var requires: Array[UpgradeData] = []  # precisa de nível 1 em todos para liberar
@export var requires_companion: bool = false  # só libera com o espaço da nave auxiliar
@export var column: int = 0  # coluna na tela da árvore (0 a 2)
@export var row: int = 0  # linha na tela da árvore (0 = topo)
@export var color: Color = Color.WHITE


func is_infinite() -> bool:
	return max_level <= 0


func is_maxed(level: int) -> bool:
	return not is_infinite() and level >= max_level


## Custo em quarks para chegar ao nível next_level (1 = primeiro), arredondado de 5 em 5.
func cost(next_level: int) -> int:
	var raw: float = (base_cost + cost_step * (next_level - 1)) * pow(cost_growth, next_level - 1)
	return maxi(int(roundf(raw / 5.0)) * 5, 5)


## Valor do efeito com level níveis, já formatado (ex.: "+24%", "+1", "+0,4 s").
func value_text(level: int) -> String:
	var total: float = per_level * level
	match stat:
		Stat.MAX_HITS, Stat.SHIELD, Stat.START_LEVEL:
			return "+%d" % roundi(total)
		Stat.MEDKIT, Stat.POWERUP:
			return "-%d%%" % roundi(total * 100.0)
		Stat.INVULNERABILITY:
			return "+%s s" % _decimal(total)
		_:
			return "+%d%%" % roundi(total * 100.0)


## Segundo valor do efeito, para os nós com dois efeitos (vazio nos outros).
func second_value_text(level: int) -> String:
	var total: float = per_level * level
	match stat:
		Stat.SPECIAL:
			return "-%d%%" % roundi(total * 50.0)
		Stat.COLLECT:
			return "+%d%%" % roundi(total * 150.0)
	return ""


## Número com uma casa decimal e vírgula em português.
static func _decimal(value: float) -> String:
	var text := "%.1f" % value
	if TranslationServer.get_locale().begins_with("pt"):
		text = text.replace(".", ",")
	return text
