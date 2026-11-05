class_name HomingWeapon
extends Weapon
## Mísseis em ondas: a onda surge em anel ao redor da nave, mira por um instante
## e dispara de uma vez; a próxima onda só surge depois de uma pausa.

enum Phase { COOLDOWN, AIMING }

var _phase: Phase = Phase.COOLDOWN
var _timer: float = 0.0
var _aim_angle: float = -PI * 0.5  # direção para onde os mísseis da onda apontam


func apply_stats(values: WeaponLevel) -> void:
	super(values)
	_phase = Phase.COOLDOWN
	_timer = 0.0


## Ao surgir, a primeira onda já nasce em anel e mira (os mísseis crescem saindo da nave).
func _on_spawn() -> void:
	if stats != null:
		_phase = Phase.AIMING
		_timer = maxf(stats.aim_seconds, Params.weapon_spawn_seconds)


func _process(delta: float) -> void:
	_tick_spawn(delta)
	# delta escalado: as ondas também desaceleram na câmera lenta
	_timer -= delta
	if _phase == Phase.COOLDOWN:
		if _timer <= 0.0:
			_phase = Phase.AIMING
			_timer = stats.aim_seconds
	else:
		var target: Enemy = _finder().call(global_position)
		var goal: float = -PI * 0.5 if target == null else (target.position - global_position).angle()
		_aim_angle = rotate_toward(_aim_angle, goal, TAU * delta)
		if _timer <= 0.0:
			_launch_wave()
			_phase = Phase.COOLDOWN
			_timer = stats.wave_cooldown_seconds / rate()
	queue_redraw()


func _launch_wave() -> void:
	Audio.shot(data.kind, sound_db)
	var dir := Vector2.from_angle(_aim_angle)
	for i in stats.projectile_count:
		var bullet := context.player_bullets.acquire() as Bullet
		if bullet == null:
			return
		bullet.activate(global_position + _slot(i), dir * stats.projectile_speed, damage(),
			stats.projectile_size, data.color, stats.projectile_shape)
		bullet.life_left = stats.projectile_lifetime
		bullet.homing_turn_rate = deg_to_rad(stats.homing_turn_degrees)
		bullet.homing_turn_growth = deg_to_rad(stats.homing_turn_growth_degrees)
		bullet.target_finder = _finder()


## Alvo dos mísseis: o mais próximo ou (auxiliar caça-grandões) o com mais vida.
func _finder() -> Callable:
	return context.strongest_enemy if stats.target_strongest else context.nearest_enemy


## Posição de cada míssil no anel, relativa à nave.
func _slot(index: int) -> Vector2:
	return Vector2.from_angle(-PI * 0.5 + TAU * index / stats.projectile_count) * stats.launch_radius


func _draw() -> void:
	if _phase != Phase.AIMING:
		return
	# Os mísseis crescem enquanto miram
	var grow: float = 1.0 - clampf(_timer / stats.aim_seconds, 0.0, 1.0)
	var half: Vector2 = stats.projectile_size * 0.5 * lerpf(0.3, 1.0, grow)
	var out: float = ease(spawn_progress(), 0.5)  # no surgimento os mísseis saem do centro até o anel
	for i in stats.projectile_count:
		draw_set_transform(_slot(i) * out, _aim_angle + PI * 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y),
		]), data.color)
	draw_set_transform(Vector2.ZERO)
