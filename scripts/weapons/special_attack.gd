class_name SpecialAttack
## Dispara o especial da arma (um por tipo, valores no grupo "Especial" da WeaponData):
## Raio: raio gigante + anel que limpa em volta. Leque: rajada de 360° que limpa os tiros.
## Mísseis: chuva de mísseis atrás de todos os inimigos na tela. Órbita: anel de energia
## que se expande pela tela, limpa os tiros e causa dano.


static func trigger(data: WeaponData, player: Player, context: CombatContext, world: Node) -> void:
	match data.kind:
		WeaponData.Kind.BEAM:
			var beam := GiantBeam.new()
			beam.setup(context, data)
			player.add_child(beam)
			_shockwave(context, world, player.position, data.special_radius, 0.4, 0, data.color)
		WeaponData.Kind.SPREAD:
			_burst(data, player, context)
			_shockwave(context, world, player.position, data.special_radius, data.special_duration, 0, data.color)
		WeaponData.Kind.HOMING:
			_missile_rain(data, player, context)
		WeaponData.Kind.ORBIT:
			_shockwave(context, world, player.position, data.special_radius, data.special_duration, data.special_damage, data.color)


static func _shockwave(context: CombatContext, world: Node, center: Vector2, radius: float, duration: float, damage: int, color: Color) -> void:
	var wave := Shockwave.new()
	wave.setup(context, center, radius, duration, damage, color)
	world.add_child(wave)


## Anéis de projéteis em 360°, um pouco defasados entre si.
static func _burst(data: WeaponData, player: Player, context: CombatContext) -> void:
	var per_ring: int = maxi(data.special_count / Params.special_burst_rings, 1)
	for ring in Params.special_burst_rings:
		var offset: float = TAU / per_ring * ring / Params.special_burst_rings
		for i in per_ring:
			var bullet := context.player_bullets.acquire() as Bullet
			if bullet == null:
				return
			var dir := Vector2.from_angle(offset + TAU * i / per_ring)
			var speed: float = Params.special_burst_speed * (1.0 - ring * 0.15)
			bullet.activate(player.position, dir * speed, data.special_damage, Params.special_burst_size, data.color, Bullet.Shape.CIRCLE)


## Dois mísseis por inimigo na tela (até special_count), cada um preso ao seu alvo.
static func _missile_rain(data: WeaponData, player: Player, context: CombatContext) -> void:
	var targets: Array[Enemy] = []
	for item in context.hostiles():
		var enemy := item as Enemy
		if enemy.visible and enemy.is_on_screen():
			targets.append(enemy)
	var count: int = data.special_count if targets.is_empty() else mini(targets.size() * 2, data.special_count)
	for i in count:
		var bullet := context.player_bullets.acquire() as Bullet
		if bullet == null:
			return
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / count)
		bullet.activate(player.position + dir * Params.ship_size.y, dir * Params.special_missile_speed,
			data.special_damage, Params.special_missile_size, data.color, Bullet.Shape.TRIANGLE)
		bullet.life_left = Params.special_missile_lifetime
		bullet.homing_turn_rate = deg_to_rad(Params.special_missile_turn_degrees)
		bullet.homing_turn_growth = deg_to_rad(Params.special_missile_turn_degrees)
		if targets.is_empty():
			bullet.target_finder = context.nearest_enemy
		else:
			var target: Enemy = targets[i % targets.size()]
			# Persegue o alvo dele; se ele morrer, o inimigo mais próximo
			bullet.target_finder = func(from: Vector2) -> Enemy:
				return target if target.visible else context.nearest_enemy(from)
