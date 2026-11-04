class_name Boss
extends Enemy
## Chefe do fim do capítulo: entra pelo topo, balança de um lado para o outro e
## troca de padrão de ataque conforme a vida cai (BossData.phases).
## Não vem de pool: é criado pela partida e entra na colisão por CombatContext.boss.

signal phase_changed(index: int)

var boss_data: BossData
var spawn_wave: Callable  # (WaveData) -> void, para os ataques SUMMON

var _phase: int = -1
var _timers := PackedFloat32Array()
var _bursts := PackedInt32Array()
var _ring_angles := PackedFloat32Array()
var _clock: float = 0.0
var _entering: bool = true
var _center_x: float = 0.0
var _hold_y: float = 0.0


func _ready() -> void:
	# Diferente dos itens de pool, começa ativo após setup()
	pass


func setup(data: BossData, bullet_pool: NodePool, combat_context: CombatContext, wave_spawner: Callable) -> void:
	boss_data = data
	bullets = bullet_pool
	context = combat_context
	spawn_wave = wave_spawner
	hp = data.max_hp
	radius = data.radius
	var rect: Rect2 = get_viewport_rect()
	_center_x = rect.get_center().x
	_hold_y = rect.position.y + rect.size.y * data.hold_y_ratio
	position = Vector2(_center_x, rect.position.y - radius)
	queue_redraw()
	_set_active()


func is_entering() -> bool:
	return _entering


func health_ratio() -> float:
	return clampf(float(hp) / boss_data.max_hp, 0.0, 1.0)


func contact_damage() -> int:
	return boss_data.contact_damage


func points() -> int:
	return boss_data.score


func tint() -> Color:
	return boss_data.color


## Encostar no chefe tira hits da nave, mas não destrói o chefe.
func on_player_contact() -> void:
	pass


func take_damage(amount: float) -> void:
	# Invulnerável enquanto entra na tela
	if _entering:
		return
	super(amount * context.boosts.boss_damage)


func _process(delta: float) -> void:
	_clock += delta
	_update_flash(delta)
	if _entering:
		position.y = move_toward(position.y, _hold_y, boss_data.entry_speed * delta)
		if position.y >= _hold_y:
			_entering = false
			_clock = 0.0
		queue_redraw()
		return

	_update_phase()
	var phase: BossPhase = boss_data.phases[_phase]
	_move(phase, delta)
	for i in phase.attacks.size():
		_timers[i] -= delta
		if _timers[i] > 0.0:
			continue
		var attack: BossAttack = phase.attacks[i]
		_attack(i, attack)
		# Rajada: os próximos disparos vêm logo em seguida
		if _bursts[i] > 1:
			_bursts[i] -= 1
			_timers[i] += attack.burst_gap
		else:
			_bursts[i] = attack.burst
			_timers[i] += attack.interval
	queue_redraw()


func _move(phase: BossPhase, delta: float) -> void:
	var t: float = _clock * boss_data.sway_speed * phase.sway_speed_scale
	match phase.movement:
		BossPhase.Movement.SWAY:
			position.x = move_toward(position.x, _center_x + sin(t) * boss_data.sway_amplitude, phase.chase_speed * 2.0 * delta)
			position.y = move_toward(position.y, _hold_y, phase.chase_speed * delta)
		BossPhase.Movement.FIGURE8:
			var goal := Vector2(_center_x + sin(t) * boss_data.sway_amplitude, _hold_y + sin(t * 2.0) * boss_data.sway_amplitude * 0.3)
			position = position.move_toward(goal, phase.chase_speed * 2.0 * delta)
		BossPhase.Movement.CHASE:
			var player: Player = context.player
			var goal_x: float = player.position.x if player != null else _center_x
			var rect: Rect2 = get_viewport_rect()
			goal_x = clampf(goal_x, rect.position.x + radius, rect.end.x - radius)
			position.x = move_toward(position.x, goal_x, phase.chase_speed * delta)
			position.y = move_toward(position.y, _hold_y, phase.chase_speed * delta)


## A fase ativa é a última cujo hp_ratio ainda está acima da vida atual.
func _update_phase() -> void:
	var ratio: float = health_ratio()
	var index: int = 0
	for i in boss_data.phases.size():
		if ratio <= boss_data.phases[i].hp_ratio:
			index = i
	if index == _phase:
		return
	_phase = index
	var attacks: Array[BossAttack] = boss_data.phases[index].attacks
	_timers.resize(attacks.size())
	_bursts.resize(attacks.size())
	_ring_angles.resize(attacks.size())
	for i in attacks.size():
		_timers[i] = attacks[i].first_delay
		_bursts[i] = attacks[i].burst
		_ring_angles[i] = 0.0
	phase_changed.emit(index)


func _attack(index: int, attack: BossAttack) -> void:
	match attack.pattern:
		BossAttack.Pattern.FAN:
			var aim: float = PI * 0.5
			var player: Player = context.player
			if attack.aimed and player != null:
				aim = (player.position - position).angle()
			var spread: float = deg_to_rad(attack.spread_degrees)
			for i in attack.count:
				var t: float = 0.0 if attack.count == 1 else float(i) / (attack.count - 1) - 0.5
				_shoot_bullet(Vector2.from_angle(aim + spread * t), attack)
		BossAttack.Pattern.RING:
			for i in attack.count:
				_shoot_bullet(Vector2.from_angle(_ring_angles[index] + TAU * i / attack.count), attack)
			_ring_angles[index] += deg_to_rad(attack.turn_degrees)
		BossAttack.Pattern.SUMMON:
			if attack.wave != null and spawn_wave.is_valid():
				spawn_wave.call(attack.wave)


func _shoot_bullet(direction: Vector2, attack: BossAttack) -> void:
	var bullet := bullets.acquire() as Bullet
	if bullet == null:
		return
	var size := Vector2.ONE * attack.bullet_radius * 2.0
	bullet.activate(position + direction * radius * 0.8, direction * attack.bullet_speed,
		1, size, attack.bullet_color, Bullet.Shape.CIRCLE)
	if attack.split_time > 0.0:
		bullet.add_split(attack.split_time, attack.split_count, attack.split_speed, attack.split_radius, bullets)
	if attack.homing_time > 0.0:
		bullet.add_limited_homing(attack.homing_time, attack.homing_turn_degrees, _find_player)


func _draw() -> void:
	var color: Color = Color.WHITE if _flash_left > 0.0 else boss_data.color
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var spin: float = _clock * 0.8
	for i in boss_data.sides:
		var angle: float = PI * 0.5 + TAU * i / boss_data.sides
		outer.append(Vector2.from_angle(angle) * radius)
		inner.append(Vector2.from_angle(angle + spin) * radius * 0.55)
	draw_colored_polygon(outer, color)
	draw_colored_polygon(inner, color.darkened(0.45))
	# Núcleo do chefe pulsa mais rápido nas fases finais
	var pulse: float = 0.5 + 0.5 * sin(_clock * (4.0 + _phase * 3.0))
	draw_circle(Vector2.ZERO, radius * 0.22, color.lightened(0.3 + pulse * 0.4))
