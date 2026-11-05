class_name ProjectileWeapon
extends Weapon
## Dispara projéteis retos do pool: um ou vários em leque, que podem atravessar
## inimigos (Lança), explodir em área (Artilharia) ou ricochetear (Ricochete).
## Versões auxiliares podem atirar em ângulos fixos (fire_angles) ou mirar no grupo mais denso.

var _cooldown: float = 0.0
var _flash_left: float = 0.0


func _process(delta: float) -> void:
	# delta escalado: a cadência também desacelera na câmera lenta
	if _tick_spawn(delta):
		_cooldown = 0.0  # carrega e atira assim que o carregamento termina
		return
	_cooldown -= delta
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()
	if _cooldown > 0.0:
		return
	_cooldown += 1.0 / (stats.fire_rate * rate())
	_fire()


func _draw() -> void:
	_draw_charge()
	_draw_muzzle_flash(_flash_left)


func _fire() -> void:
	Audio.shot(data.kind, sound_db)
	_flash_left = Params.muzzle_flash_seconds
	var origin: Vector2 = muzzle()
	var base: float = -PI * 0.5
	# Auxiliar de área: mira o grupo mais denso (sem inimigos, atira para cima)
	if stats.aim_at_cluster:
		var target: Enemy = context.densest_enemy(stats.cluster_radius)
		if target != null:
			base = (target.position - origin).angle()
	var fixed: bool = not stats.fire_angles.is_empty()
	var count: int = stats.fire_angles.size() if fixed else maxi(stats.projectile_count, 1)
	for i in count:
		var angle: float
		if fixed:
			angle = base + deg_to_rad(stats.fire_angles[i])
		else:
			# -0.5..0.5 ao longo do leque (0 com um projétil só)
			var t: float = 0.0 if count == 1 else float(i) / (count - 1) - 0.5
			angle = base + deg_to_rad(stats.spread_degrees) * t
		var bullet := context.player_bullets.acquire() as Bullet
		if bullet == null:
			return
		bullet.activate(origin, Vector2.from_angle(angle) * stats.projectile_speed, damage(),
			stats.projectile_size, data.color, stats.projectile_shape)
		bullet.life_left = stats.projectile_lifetime
		bullet.pierce_left = stats.pierce
		bullet.splash_radius = stats.splash_radius
		bullet.bounce_left = stats.bounces
		bullet.wall_bounce_left = stats.wall_bounces
		bullet.bounce_range = stats.bounce_range
