class_name CombatSystem
extends Node
## Colisões por círculos, sem física: tiros do jogador x inimigos e
## tiros/inimigos x núcleo da nave (a hitbox é o núcleo, menor que o corpo)
## e coleta de power-ups.
## Fica por último na árvore para rodar depois dos movimentos.

signal player_hit(damage: int)
signal powerup_collected(kind: PowerUp.Kind)

var _context: CombatContext
var _player: Player


func setup(context: CombatContext, player: Player) -> void:
	_context = context
	_player = player


func _process(_delta: float) -> void:
	_player_bullets_vs_enemies()
	if _player.body != null:
		_collect_powerups()
	if _player.is_vulnerable():
		_hazards_vs_player()


func _player_bullets_vs_enemies() -> void:
	var bullets: Array[PoolItem] = _context.player_bullets.active
	var enemies: Array[PoolItem] = _context.hostiles()
	# De trás para frente: o projétil atual pode ser devolvido ao pool
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i] as Bullet
		for item in enemies:
			var enemy := item as Enemy
			if not enemy.visible:
				continue
			var reach: float = bullet.radius + enemy.radius
			if bullet.position.distance_squared_to(enemy.position) <= reach * reach:
				_context.player_bullets.release(bullet)
				enemy.take_damage(bullet.damage)
				break


## Área de coleta generosa (maior que a hitbox), centrada na nave.
func _collect_powerups() -> void:
	var power_ups: Array[PoolItem] = _context.power_ups.active
	var reach: float = Params.powerup_pickup_radius + Params.powerup_radius
	for i in range(power_ups.size() - 1, -1, -1):
		var power_up := power_ups[i] as PowerUp
		if power_up.position.distance_squared_to(_player.position) <= reach * reach:
			var kind: PowerUp.Kind = power_up.kind
			_context.power_ups.release(power_up)
			powerup_collected.emit(kind)


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

	for item in _context.hostiles():
		var enemy := item as Enemy
		var reach: float = enemy.radius + Params.nucleus_radius
		if enemy.visible and enemy.position.distance_squared_to(center) <= reach * reach:
			var damage: int = enemy.contact_damage()
			enemy.on_player_contact()
			player_hit.emit(damage)
			return
