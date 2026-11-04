class_name Bullet
extends PoolItem
## Projétil reutilizável (jogador ou inimigo): reto ou teleguiado.

enum Shape { RECT, CIRCLE, TRIANGLE }

var velocity: Vector2
var damage: float = 1.0
var radius: float = 0.0  # raio de colisão

## Teleguiado: giro máximo em rad/s (0 = reto) e função (posição) -> alvo ou null.
var homing_turn_rate: float = 0.0
## Aumento do giro por segundo enquanto persegue: fecha a curva e evita circular o alvo.
var homing_turn_growth: float = 0.0
var target_finder: Callable
## Segundos até sumir (0 = só some ao sair da tela). Evita míssil circulando o alvo para sempre.
var life_left: float = 0.0
## Perfuração: quantos inimigos ainda atravessa (0 = some no primeiro acerto).
var pierce_left: int = 0
## Explosão: raio do dano em área ao acertar (0 = sem explosão).
var splash_radius: float = 0.0
## Perseguição limitada: segue o alvo só por esse tempo e depois vai reto (< 0 = sem limite).
var homing_time_left: float = -1.0
## Ricochete: quantas vezes ainda pula para outro inimigo e rebate nas laterais da tela.
var bounce_left: int = 0
var wall_bounce_left: int = 0
var bounce_range: float = 0.0

# Divisão: ao fim do tempo, vira vários tiros em anel (tiros que se multiplicam)
var _split_left: float = 0.0
var _split_count: int = 0
var _split_speed: float = 0.0
var _split_size: Vector2
var _split_pool: NodePool

var _size: Vector2
var _color: Color
var _shape: Shape
var _pierced: Dictionary = {}  # inimigos já atravessados (não acerta duas vezes)


func activate(pos: Vector2, vel: Vector2, dmg: float, size: Vector2, color: Color, shape: Shape) -> void:
	position = pos
	velocity = vel
	damage = dmg
	radius = (size.x + size.y) * 0.25
	homing_turn_rate = 0.0
	homing_turn_growth = 0.0
	target_finder = Callable()
	life_left = 0.0
	pierce_left = 0
	splash_radius = 0.0
	homing_time_left = -1.0
	bounce_left = 0
	wall_bounce_left = 0
	bounce_range = 0.0
	_split_count = 0
	_pierced.clear()
	_size = size
	_color = color
	_shape = shape
	# As formas são desenhadas apontando para cima
	rotation = vel.angle() + PI * 0.5
	queue_redraw()
	_set_active()


## Depois de seconds, o tiro se divide em count tiros em anel (do mesmo pool).
func add_split(seconds: float, count: int, speed: float, child_radius: float, pool: NodePool) -> void:
	_split_left = seconds
	_split_count = count
	_split_speed = speed
	_split_size = Vector2.ONE * child_radius * 2.0
	_split_pool = pool
	queue_redraw()


## Persegue o alvo por pouco tempo (força o jogador a se mover) e depois segue reto.
func add_limited_homing(seconds: float, turn_degrees: float, finder: Callable) -> void:
	homing_time_left = seconds
	homing_turn_rate = deg_to_rad(turn_degrees)
	target_finder = finder


func color() -> Color:
	return _color


func already_pierced(enemy: Node) -> bool:
	return _pierced.has(enemy)


## Atravessou um inimigo: gasta uma perfuração e não o acerta de novo.
func pierce(enemy: Node) -> void:
	_pierced[enemy] = true
	pierce_left -= 1


## Ricochete: depois de acertar, segue para o inimigo mais próximo ainda não atingido.
## Retorna false se não há outro inimigo perto (o tiro some).
func ricochet(hit: Node, hostiles: Array[PoolItem]) -> bool:
	_pierced[hit] = true
	bounce_left -= 1
	var best: Node2D = null
	var best_distance: float = bounce_range * bounce_range
	for item in hostiles:
		if item == hit or not item.visible or _pierced.has(item):
			continue
		var distance: float = position.distance_squared_to(item.position)
		if distance < best_distance:
			best_distance = distance
			best = item
	if best == null:
		return false
	velocity = (best.position - position).normalized() * velocity.length()
	rotation = velocity.angle() + PI * 0.5
	return true


func _process(delta: float) -> void:
	if life_left > 0.0:
		life_left -= delta
		if life_left <= 0.0:
			expire()
			return
	if _split_count > 0:
		_split_left -= delta
		if _split_left <= 0.0:
			_split()
			return
	if homing_time_left > 0.0:
		homing_time_left -= delta
		if homing_time_left <= 0.0:
			homing_turn_rate = 0.0
	if homing_turn_rate > 0.0 and target_finder.is_valid():
		homing_turn_rate += homing_turn_growth * delta
		var target: Node2D = target_finder.call(position)
		if target != null:
			var angle: float = rotate_toward(velocity.angle(), (target.position - position).angle(), homing_turn_rate * delta)
			velocity = Vector2.from_angle(angle) * velocity.length()
			rotation = angle + PI * 0.5
	position += velocity * delta
	if wall_bounce_left > 0:
		_bounce_on_walls()
	# Com tempo de vida, pode sair um pouco da tela (míssil fazendo a curva de volta)
	if life_left <= 0.0 and not get_viewport_rect().grow(_size.length()).has_point(position):
		expire()


## Rebate nas laterais da tela (Ricochete).
func _bounce_on_walls() -> void:
	var rect: Rect2 = get_viewport_rect()
	if (position.x < rect.position.x and velocity.x < 0.0) or (position.x > rect.end.x and velocity.x > 0.0):
		velocity.x = -velocity.x
		wall_bounce_left -= 1
		rotation = velocity.angle() + PI * 0.5


func _split() -> void:
	var base: float = velocity.angle()
	for i in _split_count:
		var child := _split_pool.acquire() as Bullet
		if child == null:
			break
		child.activate(position, Vector2.from_angle(base + TAU * i / _split_count) * _split_speed,
			damage, _split_size, _color, Shape.CIRCLE)
	expire()


func _draw() -> void:
	match _shape:
		Shape.RECT:
			draw_rect(Rect2(-_size * 0.5, _size), _color)
		Shape.CIRCLE:
			# Núcleo claro para leitura em meio a muitos tiros
			draw_circle(Vector2.ZERO, _size.x * 0.5, _color)
			draw_circle(Vector2.ZERO, _size.x * 0.25, Color.WHITE)
			if _split_count > 0:
				# Orbe que vai se dividir: anel externo
				draw_arc(Vector2.ZERO, _size.x * 0.75, 0.0, TAU, 24, Color(_color, 0.8), 3.0)
		Shape.TRIANGLE:
			var half: Vector2 = _size * 0.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y),
			]), _color)
