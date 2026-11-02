class_name Bullet
extends PoolItem
## Projétil reutilizável (jogador ou inimigo): reto ou teleguiado.

enum Shape { RECT, CIRCLE, TRIANGLE }

var velocity: Vector2
var damage: int = 1
var radius: float = 0.0  # raio de colisão

## Teleguiado: giro máximo em rad/s (0 = reto) e função (posição) -> alvo ou null.
var homing_turn_rate: float = 0.0
var target_finder: Callable

var _size: Vector2
var _color: Color
var _shape: Shape


func activate(pos: Vector2, vel: Vector2, dmg: int, size: Vector2, color: Color, shape: Shape) -> void:
	position = pos
	velocity = vel
	damage = dmg
	radius = (size.x + size.y) * 0.25
	homing_turn_rate = 0.0
	target_finder = Callable()
	_size = size
	_color = color
	_shape = shape
	# As formas são desenhadas apontando para cima
	rotation = vel.angle() + PI * 0.5
	queue_redraw()
	_set_active()


func _process(delta: float) -> void:
	if homing_turn_rate > 0.0 and target_finder.is_valid():
		var target: Node2D = target_finder.call(position)
		if target != null:
			var angle: float = rotate_toward(velocity.angle(), (target.position - position).angle(), homing_turn_rate * delta)
			velocity = Vector2.from_angle(angle) * velocity.length()
			rotation = angle + PI * 0.5
	position += velocity * delta
	if not get_viewport_rect().grow(_size.length()).has_point(position):
		expire()


func _draw() -> void:
	match _shape:
		Shape.RECT:
			draw_rect(Rect2(-_size * 0.5, _size), _color)
		Shape.CIRCLE:
			# Núcleo claro para leitura em meio a muitos tiros
			draw_circle(Vector2.ZERO, _size.x * 0.5, _color)
			draw_circle(Vector2.ZERO, _size.x * 0.25, Color.WHITE)
		Shape.TRIANGLE:
			var half: Vector2 = _size * 0.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y),
			]), _color)
