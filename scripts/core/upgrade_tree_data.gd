class_name UpgradeTreeData
extends Resource
## Árvore de evolução do núcleo: lista de nós e cálculo dos bônus para a partida.
## Valor em data/upgrade_tree.tres.

@export var nodes: Array[UpgradeData] = []


## Nível de um nó num dicionário id -> nível (o do save).
static func level_of(node: UpgradeData, levels: Dictionary) -> int:
	return int(levels.get(String(node.id), 0))


## Liberado quando todos os pré-requisitos têm nível 1 (e o espaço auxiliar, se pedir).
func is_available(node: UpgradeData, levels: Dictionary, companion_unlocked: bool) -> bool:
	if node.requires_companion and not companion_unlocked:
		return false
	for required in node.requires:
		if level_of(required, levels) < 1:
			return false
	return true


## Soma os efeitos de todos os nós nos níveis dados.
func boosts_for(levels: Dictionary) -> PlayerBoosts:
	var boosts := PlayerBoosts.new()
	for node in nodes:
		var level: int = level_of(node, levels)
		if level <= 0:
			continue
		var total: float = node.per_level * level
		match node.stat:
			UpgradeData.Stat.DAMAGE, UpgradeData.Stat.OVERDRIVE:
				boosts.damage += total
			UpgradeData.Stat.FIRE_RATE:
				boosts.fire_rate += total
			UpgradeData.Stat.SPECIAL:
				boosts.special_damage += total
				boosts.special_charge = maxf(boosts.special_charge - total * 0.5, 0.4)
			UpgradeData.Stat.BOSS_DAMAGE:
				boosts.boss_damage += total
			UpgradeData.Stat.MAX_HITS:
				boosts.extra_hits += roundi(total)
			UpgradeData.Stat.INVULNERABILITY:
				boosts.extra_invulnerability += total
			UpgradeData.Stat.SHIELD:
				boosts.shields += roundi(total)
			UpgradeData.Stat.MEDKIT:
				boosts.medkit_kills_bonus += roundi(total)
			UpgradeData.Stat.COLLECT:
				boosts.quarks += total
				boosts.pickup_radius += total * 1.5
			UpgradeData.Stat.POWERUP:
				boosts.powerup_kills_bonus += roundi(total)
			UpgradeData.Stat.COMPANION:
				boosts.companion_damage += total
			UpgradeData.Stat.START_LEVEL:
				boosts.start_level_bonus += roundi(total)
	return boosts


## Soma de todos os custos dos nós com limite (para balanceamento).
func finite_total_cost() -> int:
	var total: int = 0
	for node in nodes:
		if node.is_infinite():
			continue
		for level in range(1, node.max_level + 1):
			total += node.cost(level)
	return total
