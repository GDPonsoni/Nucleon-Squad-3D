class_name Enemy
extends PoolItem
## Inimigo reutilizável: movimento e padrão de tiro vêm do EnemyData.

## Destruído pelo jogador (não emite ao sair da tela).
signal killed(enemy: Enemy)

var data: EnemyData
var hp: float = 0.0
var radius: float = 0.0
var bullets: NodePool  # projéteis inimigos
var context: CombatContext  # para mirar na nave

var _velocity: Vector2
var _age: float = 0.0
var _entered: bool = false  # já apareceu na tela (antes disso não sai por "sair da tela")
var _fire_cooldown: float = 0.0
var _ring_angle: float = 0.0
var _flash_left: float = 0.0
var _hover_left: float = -1.0  # HOVER: < 0 = ainda descendo até a altura de parada
# Movimento da onda (WaveData): balanço lateral, curva e velocidade
var _speed_scale: float = 1.0
var _fire_scale: float = 1.0  # cadência de tiro da fase (StageData.enemy_fire_scale)
var _sway_amplitude: float = 0.0
var _sway_omega: float = 0.0
var _sway_phase: float = 0.0
var _curve_rate: float = 0.0  # rad/s
var _curve_delay: float = 0.0
var _curve_left: float = 0.0


## extra_delay atrasa o comportamento por tempo (ex.: mergulhos em sequência numa onda).
func activate(enemy_data: EnemyData, pos: Vector2, velocity: Vector2, extra_delay: float = 0.0) -> void:
	data = enemy_data
	hp = data.max_hp
	radius = data.radius
	position = pos
	_velocity = velocity
	_age = -extra_delay
	_entered = false
	_fire_cooldown = data.first_shot_delay
	_ring_angle = 0.0
	_flash_left = 0.0
	_hover_left = -1.0
	_speed_scale = 1.0
	_fire_scale = 1.0
	_sway_amplitude = 0.0
	_curve_left = 0.0
	rotation = 0.0
	queue_redraw()
	_set_active()


## Movimento comum da onda (chamar depois de activate). member = posição na onda.
func set_motion(wave: WaveData, member: int) -> void:
	_speed_scale = wave.speed_scale
	_velocity *= wave.speed_scale
	if wave.sway_amplitude > 0.0 and wave.sway_period > 0.0:
		_sway_amplitude = wave.sway_amplitude
		_sway_omega = TAU / wave.sway_period
		_sway_phase = wave.sway_phase_step * member
	if not is_zero_approx(wave.curve_degrees) and wave.curve_seconds > 0.0:
		_curve_rate = deg_to_rad(wave.curve_degrees) / wave.curve_seconds
		_curve_delay = wave.curve_delay
		_curve_left = wave.curve_seconds


## Escalas da fase: vida e cadência de tiro dos inimigos (capítulos finais).
func apply_stage(stage: StageData) -> void:
	hp *= stage.enemy_hp_scale
	_fire_scale = stage.enemy_fire_scale


func is_on_screen() -> bool:
	return get_viewport_rect().grow(-radius * 0.5).has_point(position)


func contact_damage() -> int:
	return data.contact_damage


func points() -> int:
	return data.score


func tint() -> Color:
	return data.color


## Encostou na nave: inimigos comuns são destruídos (o chefe sobrescreve).
func on_player_contact() -> void:
	take_damage(hp)


func take_damage(amount: float) -> void:
	if not visible:
		return
	hp -= amount
	_flash_left = Params.enemy_hit_flash_seconds
	queue_redraw()
	if hp <= 0:
		killed.emit(self)
		expire()



func _process(delta: float) -> void:
	_age += delta
	if data.movement == EnemyData.Movement.DIVE and _age >= data.dive_delay:
		_dive(delta)
	elif data.movement == EnemyData.Movement.HOVER:
		_hover(delta)
	if _curve_left > 0.0 and _age >= _curve_delay:
		var step: float = minf(delta, _curve_left)
		_velocity = _velocity.rotated(_curve_rate * step)
		_curve_left -= step
	var drift := Vector2.ZERO
	if _sway_amplitude > 0.0 and _age > 0.0:
		drift.x = _sway_amplitude * _sway_omega * cos(_sway_omega * _age + _sway_phase)
	position += (_velocity + drift) * delta

	var on_screen: bool = is_on_screen()
	_entered = _entered or on_screen
	if _entered and not get_viewport_rect().grow(radius * 2.0).has_point(position):
		expire()
		return

	if on_screen and data.fire_pattern != EnemyData.FirePattern.NONE:
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown += data.fire_interval / _fire_scale
			_shoot()

	_update_flash(delta)


func _update_flash(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			queue_redraw()


## Acelera e vira na direção da nave; o desenho aponta para onde vai.
func _dive(delta: float) -> void:
	var speed: float = move_toward(_velocity.length(), data.dive_speed, data.dive_speed * delta * 2.0)
	var angle: float = _velocity.angle()
	var player: Player = context.player
	if player != null and player.body != null:
		angle = rotate_toward(angle, (player.position - position).angle(), deg_to_rad(data.dive_turn_degrees) * delta)
	_velocity = Vector2.from_angle(angle) * speed
	rotation = angle - PI * 0.5


## Desce até a altura de parada, fica parado um tempo e depois segue descendo.
func _hover(delta: float) -> void:
	if _hover_left < 0.0:
		var stop_y: float = get_viewport_rect().position.y + get_viewport_rect().size.y * data.hover_y_ratio
		if position.y >= stop_y:
			_hover_left = data.hover_seconds
			_velocity = Vector2.ZERO
	elif _hover_left > 0.0:
		_hover_left -= delta
		if _hover_left <= 0.0:
			_velocity = Vector2(0.0, data.speed * _speed_scale)


func _shoot() -> void:
	match data.fire_pattern:
		EnemyData.FirePattern.STRAIGHT:
			_fire(Vector2.DOWN)
		EnemyData.FirePattern.AIMED:
			var player: Player = context.player
			_fire(Vector2.DOWN if player == null else (player.position - position).normalized())
		EnemyData.FirePattern.FAN:
			var player: Player = context.player
			var aim: float = PI * 0.5 if player == null else (player.position - position).angle()
			var spread: float = deg_to_rad(data.fan_degrees)
			for i in data.fan_count:
				var t: float = 0.0 if data.fan_count == 1 else float(i) / (data.fan_count - 1) - 0.5
				_fire(Vector2.from_angle(aim + spread * t))
		EnemyData.FirePattern.RING:
			for i in data.ring_count:
				_fire(Vector2.from_angle(_ring_angle + TAU * i / data.ring_count))
			_ring_angle += deg_to_rad(data.ring_turn_degrees)


func _fire(direction: Vector2) -> void:
	var bullet := bullets.acquire() as Bullet
	if bullet == null:
		return
	var size := Vector2.ONE * data.bullet_radius * 2.0
	bullet.activate(position + direction * radius, direction * data.bullet_speed,
		data.bullet_damage, size, data.bullet_color, Bullet.Shape.CIRCLE)
	if data.bullet_split_time > 0.0:
		bullet.add_split(data.bullet_split_time, data.bullet_split_count, data.bullet_split_speed, data.bullet_split_radius, bullets)
	if data.bullet_homing_time > 0.0:
		bullet.add_limited_homing(data.bullet_homing_time, data.bullet_homing_turn_degrees, _find_player)


## Alvo dos tiros perseguidores: a nave, se tiver corpo.
func _find_player(_from: Vector2) -> Node2D:
	var player: Player = context.player
	return player if player != null and player.body != null else null


func _draw() -> void:
	var color: Color = Color.WHITE if _flash_left > 0.0 else data.color
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in data.sides:
		# Vértice para baixo, apontando para o jogador
		var dir := Vector2.from_angle(PI * 0.5 + TAU * i / data.sides)
		outer.append(dir * radius)
		inner.append(dir * radius * 0.45)
	draw_colored_polygon(outer, color)
	draw_colored_polygon(inner, color.darkened(0.5))
