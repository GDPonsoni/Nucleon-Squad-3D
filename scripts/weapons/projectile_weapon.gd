class_name ProjectileWeapon
extends Weapon
## Dispara projéteis do pool: um ou vários em leque, retos ou teleguiados.

var _cooldown: float = 0.0


func _process(delta: float) -> void:
	# delta escalado: a cadência também desacelera na câmera lenta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += 1.0 / data.fire_rate
	_fire()


func _fire() -> void:
	var origin: Vector2 = muzzle()
	var count: int = maxi(data.projectile_count, 1)
	for i in count:
		# -0.5..0.5 ao longo do leque (0 com um projétil só)
		var t: float = 0.0 if count == 1 else float(i) / (count - 1) - 0.5
		var angle: float = -PI * 0.5 + deg_to_rad(data.spread_degrees) * t
		var bullet := context.player_bullets.acquire() as Bullet
		if bullet == null:
			return
		bullet.activate(origin, Vector2.from_angle(angle) * data.projectile_speed, data.damage,
			data.projectile_size, data.color, data.projectile_shape)
		if data.homing_turn_degrees > 0.0:
			bullet.homing_turn_rate = deg_to_rad(data.homing_turn_degrees)
			bullet.target_finder = context.nearest_enemy
