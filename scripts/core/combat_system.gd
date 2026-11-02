class_name CombatSystem
extends Node
## Colisões por círculos, sem física: tiros do jogador x inimigos e
## tiros/inimigos x núcleo da nave (a hitbox é o núcleo, menor que o corpo).
## Fica por último na árvore para rodar depois dos movimentos.

signal player_hit(damage: int)

var _context: CombatContext
var _player: Player


func setup(context: CombatContext, player: Player) -> void:
	_context = context
	_player = player


func _process(_delta: float) -> void:
	_player_bullets_vs_enemies()
	if _player.is_vulnerable():
		_hazards_vs_player()


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


## No máximo um hit por frame; a invulnerabilidade evita hits em sequência.
func _hazards_vs_player() -> void:
	var center: Vector2 = _player.position
	var bullets: Array[PoolItem] = _context.enemy_bullets.active
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i] as Bullet
		var reach: float = bullet.radius + Params.nucleus_radius
		if bullet.position.distance_squared_to(center) <= reach * reach:
			_context.enemy_bullets.release(bullet)
			player_hit.emit(bullet.damage)
			return

	for item in _context.enemies.active:
		var enemy := item as Enemy
		var reach: float = enemy.radius + Params.nucleus_radius
		if enemy.position.distance_squared_to(center) <= reach * reach:
			# A colisão destrói o inimigo
			enemy.take_damage(enemy.hp)
			player_hit.emit(Params.enemy_contact_damage)
			return
