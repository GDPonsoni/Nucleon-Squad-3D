class_name Enemy
extends PoolItem
## Inimigo reutilizável: desce em linha reta e atira reto para baixo.

var data: EnemyData
var hp: int = 0
var radius: float = 0.0
var bullets: NodePool  # projéteis inimigos

var _fire_cooldown: float = 0.0
var _flash_left: float = 0.0


func activate(enemy_data: EnemyData, pos: Vector2) -> void:
	data = enemy_data
	hp = data.max_hp
	radius = data.radius
	position = pos
	_fire_cooldown = data.first_shot_delay
	_flash_left = 0.0
	queue_redraw()
	_set_active()


func is_on_screen() -> bool:
	return position.y > get_viewport_rect().position.y + radius


func take_damage(amount: int) -> void:
	if not visible:
		return
	hp -= amount
	_flash_left = Params.enemy_hit_flash_seconds
	queue_redraw()
	if hp <= 0:
		expire()


func _process(delta: float) -> void:
	position.y += data.speed * delta
	if position.y - radius > get_viewport_rect().end.y:
		expire()
		return

	if is_on_screen():
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown += data.fire_interval
			_shoot()

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			queue_redraw()


func _shoot() -> void:
	var bullet := bullets.acquire() as Bullet
	if bullet == null:
		return
	var size := Vector2.ONE * data.bullet_radius * 2.0
	bullet.activate(position + Vector2(0.0, radius), Vector2(0.0, data.bullet_speed),
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
