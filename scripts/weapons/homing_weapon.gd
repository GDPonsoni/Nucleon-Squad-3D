class_name HomingWeapon
extends Weapon
## Mísseis em ondas: cada onda solta N mísseis em volta da nave, um após o outro,
## girando como um relógio. Eles se afastam devagar e só depois perseguem o alvo.

var _cooldown: float = 0.0
var _pending: int = 0  # mísseis que faltam na onda atual
var _next_launch: float = 0.0
var _angle: float = -PI * 0.5  # continua entre ondas (efeito espiral)


func _process(delta: float) -> void:
	# delta escalado: as ondas também desaceleram na câmera lenta
	_cooldown -= delta
	if _cooldown <= 0.0 and _pending == 0:
		_cooldown += 1.0 / stats.fire_rate
		_pending = stats.projectile_count
		_next_launch = 0.0

	_next_launch -= delta
	while _pending > 0 and _next_launch <= 0.0:
		_launch()
		_pending -= 1
		_next_launch += stats.wave_spacing_seconds


func _launch() -> void:
	var dir := Vector2.from_angle(_angle)
	_angle = wrapf(_angle + TAU / stats.projectile_count, 0.0, TAU)
	var bullet := context.player_bullets.acquire() as Bullet
	if bullet == null:
		return
	bullet.activate(global_position + dir * stats.launch_radius, dir * stats.launch_speed, stats.damage,
		stats.projectile_size, data.color, stats.projectile_shape)
	bullet.life_left = stats.projectile_lifetime
	bullet.homing_turn_rate = deg_to_rad(stats.homing_turn_degrees)
	bullet.homing_turn_growth = deg_to_rad(stats.homing_turn_growth_degrees)
	bullet.homing_delay = stats.homing_delay_seconds
	bullet.cruise_speed = stats.projectile_speed
	bullet.target_finder = context.nearest_enemy
