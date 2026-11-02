class_name Enemy
extends PoolItem
## Inimigo reutilizável: movimento e padrão de tiro vêm do EnemyData.

## Destruído pelo jogador (não emite ao sair da tela).
signal killed(enemy: Enemy)

var data: EnemyData
var hp: int = 0
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
	rotation = 0.0
	queue_redraw()
	_set_active()


func is_on_screen() -> bool:
	return get_viewport_rect().grow(-radius * 0.5).has_point(position)


func take_damage(amount: int) -> void:
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
	position += _velocity * delta

	var on_screen: bool = is_on_screen()
	_entered = _entered or on_screen
	if _entered and not get_viewport_rect().grow(radius * 2.0).has_point(position):
		expire()
		return

	if on_screen and data.fire_pattern != EnemyData.FirePattern.NONE:
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown += data.fire_interval
			_shoot()

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
			_velocity = Vector2(0.0, data.speed)


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
