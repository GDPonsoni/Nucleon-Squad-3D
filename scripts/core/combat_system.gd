class_name CombatSystem
extends Node
## Colisões por círculos, sem física: tiros do jogador x inimigos.
## Fica por último na árvore para rodar depois dos movimentos.

var _context: CombatContext


func setup(context: CombatContext) -> void:
	_context = context


func _process(_delta: float) -> void:
	_player_bullets_vs_enemies()


func _player_bullets_vs_enemies() -> void:
	var bullets: Array[PoolItem] = _context.player_bullets.active
	var enemies: Array[PoolItem] = _context.enemies.active
	# De trás para frente: o projétil atual pode ser devolvido ao pool
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i] as Bullet
		for item in enemies:
			var enemy := item as Enemy
			var reach: float = bullet.radius + enemy.radius
			if bullet.position.distance_squared_to(enemy.position) <= reach * reach:
				_context.player_bullets.release(bullet)
				enemy.take_damage(bullet.damage)
				break
