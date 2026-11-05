class_name SpecialAttack
## Dispara o especial da arma (um por tipo, valores no grupo "Especial" da WeaponData):
## Raio: raio gigante + anel que limpa em volta. Leque: rajada de 360° que limpa os tiros.
## Mísseis: chuva de mísseis atrás de todos os inimigos na tela. Órbita: anel de energia
## que se expande pela tela, limpa os tiros e causa dano. Lança: leque de lanças gigantes
## que atravessam tudo. Artilharia: bombardeio de explosões pela tela. Tesla: tempestade
## de raios em todos os inimigos. Ricochete: orbes que ricocheteiam entre os inimigos.
## O especial pertence à arma (WeaponData) e sai do portador (player: qualquer Node2D).


## Dano do especial com a evolução do núcleo (dano geral e dano de especial).
static func damage_of(data: WeaponData, context: CombatContext) -> float:
	return data.special_damage * context.boosts.damage * context.boosts.special_damage


static func trigger(data: WeaponData, player: Node2D, context: CombatContext, world: Node) -> void:
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
			_shockwave(context, world, player.position, data.special_radius, data.special_duration, damage_of(data, context), data.color)
		WeaponData.Kind.PIERCE:
			_lances(data, player, context)
		WeaponData.Kind.BLAST:
			var bombardment := Bombardment.new()
			bombardment.setup(context, data, world)
			world.add_child(bombardment)
		WeaponData.Kind.CHAIN:
			var storm := Storm.new()
			storm.setup(context, data)
			world.add_child(storm)
			_shockwave(context, world, player.position, data.special_radius, 0.4, 0, data.color)
		WeaponData.Kind.BOUNCE:
			_pinball(data, player, context)


static func _shockwave(context: CombatContext, world: Node, center: Vector2, radius: float, duration: float, damage: float, color: Color) -> void:
	var wave := Shockwave.new()
	wave.setup(context, center, radius, duration, damage, color)
	world.add_child(wave)


## Leque de lanças gigantes que atravessam todos os inimigos.
static func _lances(data: WeaponData, player: Node2D, context: CombatContext) -> void:
	var spread: float = deg_to_rad(Params.special_lance_spread_degrees)
	var size := Vector2(data.special_width, data.special_width * Params.special_lance_length_ratio)
	for i in data.special_count:
		var bullet := context.player_bullets.acquire() as Bullet
		if bullet == null:
			return
		var t: float = 0.0 if data.special_count == 1 else float(i) / (data.special_count - 1) - 0.5
		var dir := Vector2.from_angle(-PI * 0.5 + spread * t)
		bullet.activate(player.position, dir * Params.special_lance_speed, damage_of(data, context), size, data.color, Bullet.Shape.RECT)
		bullet.pierce_left = Params.special_lance_pierce


## Orbes em 360° que ricocheteiam entre os inimigos e nas laterais da tela.
static func _pinball(data: WeaponData, player: Node2D, context: CombatContext) -> void:
	for i in data.special_count:
		var bullet := context.player_bullets.acquire() as Bullet
		if bullet == null:
			return
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / data.special_count)
		bullet.activate(player.position, dir * Params.special_pinball_speed, damage_of(data, context),
			Params.special_pinball_size, data.color, Bullet.Shape.CIRCLE)
		bullet.bounce_left = Params.special_pinball_bounces
		bullet.wall_bounce_left = Params.special_pinball_wall_bounces
		bullet.bounce_range = Params.special_pinball_range
		bullet.life_left = Params.special_pinball_lifetime


## Anéis de projéteis em 360°, um pouco defasados entre si.
static func _burst(data: WeaponData, player: Node2D, context: CombatContext) -> void:
	var per_ring: int = maxi(data.special_count / Params.special_burst_rings, 1)
	for ring in Params.special_burst_rings:
		var offset: float = TAU / per_ring * ring / Params.special_burst_rings
		for i in per_ring:
			var bullet := context.player_bullets.acquire() as Bullet
			if bullet == null:
				return
			var dir := Vector2.from_angle(offset + TAU * i / per_ring)
			var speed: float = Params.special_burst_speed * (1.0 - ring * 0.15)
			bullet.activate(player.position, dir * speed, damage_of(data, context), Params.special_burst_size, data.color, Bullet.Shape.CIRCLE)


## Dois mísseis por inimigo na tela (até special_count), cada um preso ao seu alvo.
static func _missile_rain(data: WeaponData, player: Node2D, context: CombatContext) -> void:
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
			damage_of(data, context), Params.special_missile_size, data.color, Bullet.Shape.TRIANGLE)
		bullet.life_left = Params.special_missile_lifetime
		bullet.homing_turn_rate = deg_to_rad(Params.special_missile_turn_degrees)
		bullet.homing_turn_growth = deg_to_rad(Params.special_missile_turn_degrees)
		if targets.is_empty():
			bullet.target_finder = context.nearest_enemy
		else:
			var target: Enemy = targets[i % targets.size()]
			# Persegue o alvo dele; se ele morrer (o chefe é liberado da memória), o mais próximo
			bullet.target_finder = func(from: Vector2) -> Enemy:
				return target if is_instance_valid(target) and target.visible else context.nearest_enemy(from)
