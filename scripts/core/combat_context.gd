class_name CombatContext
extends RefCounted
## Referências compartilhadas entre armas, inimigos e colisão.

var player_bullets: NodePool
var enemy_bullets: NodePool
var enemies: NodePool
var power_ups: NodePool
var impacts: NodePool  # faíscas de acerto (pode ser null em testes)
var player: Player
var boss: Boss  # fora do pool; null quando não há chefe
var boosts: PlayerBoosts = PlayerBoosts.new()  # evolução do núcleo (neutro em testes)


## Faísca de acerto no ponto (ignora se o contexto não tem o pool).
func spark(pos: Vector2, color: Color, size: float = 1.0) -> void:
	if impacts == null:
		return
	var item := impacts.acquire() as HitSpark
	if item != null:
		item.activate(pos, color, size)


## Alvos atingíveis: inimigos ativos e, se houver, o chefe.
## Sem chefe, devolve a própria lista do pool (sem cópia).
func hostiles() -> Array[PoolItem]:
	if boss == null or not boss.visible:
		return enemies.active
	var list: Array[PoolItem] = enemies.active.duplicate()
	list.append(boss)
	return list


## Inimigo visível mais próximo de um ponto (null se não houver).
func nearest_enemy(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for item in hostiles():
		var enemy := item as Enemy
		if not enemy.visible or not enemy.is_on_screen():
			continue
		var distance: float = from.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Inimigo visível com mais vida (null se não houver). Mesma assinatura de nearest_enemy.
func strongest_enemy(_from: Vector2 = Vector2.ZERO) -> Enemy:
	var best: Enemy = null
	for item in hostiles():
		var enemy := item as Enemy
		if not enemy.visible or not enemy.is_on_screen():
			continue
		if best == null or enemy.hp > best.hp:
			best = enemy
	return best


## Centro do grupo mais denso: o inimigo com mais vizinhos dentro do raio (null se não houver).
func densest_enemy(radius: float) -> Enemy:
	var list: Array[PoolItem] = hostiles()
	var best: Enemy = null
	var best_count: int = -1
	var reach: float = radius * radius
	for item in list:
		var enemy := item as Enemy
		if not enemy.visible or not enemy.is_on_screen():
			continue
		var count: int = 0
		for other_item in list:
			var other := other_item as Enemy
			if other.visible and enemy.position.distance_squared_to(other.position) <= reach:
				count += 1
		if count > best_count:
			best_count = count
			best = enemy
	return best
