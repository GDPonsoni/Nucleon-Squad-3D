class_name BodyFx
extends PoolItem
## Efeito do corpo que sai de cena (pooled): EXIT = troca voluntária (sobe, afina e dissolve);
## BREAK = corpo perdido (parte-se em pedaços triangulares que giram, caem e somem).
## O delta já vem escalado pelo time scale, então acompanha a câmera lenta.

enum Kind { EXIT, BREAK }

var _kind: Kind = Kind.EXIT
var _age: float = 0.0
var _duration: float = 1.0
var _color: Color = Color.WHITE
var _points := PackedVector2Array()  # contorno já em pixels
# Pedaços (BREAK): triângulo local em volta do centroide + movimento
var _pieces: Array[PackedVector2Array] = []
var _centers := PackedVector2Array()
var _vel := PackedVector2Array()
var _spin := PackedFloat32Array()


func activate_exit(pos: Vector2, data: BodyData) -> void:
	_start(Kind.EXIT, pos, data, Params.exit_seconds)
	queue_redraw()
	_set_active()


func activate_break(pos: Vector2, data: BodyData) -> void:
	_start(Kind.BREAK, pos, data, Params.break_seconds)
	_pieces.clear()
	_centers.resize(0)
	_vel.resize(0)
	_spin.resize(0)
	var n: int = _points.size()
	var k: float = Params.anim_intensity
	for i in n:
		var a: Vector2 = _points[i]
		var b: Vector2 = _points[(i + 1) % n]
		var center: Vector2 = (a + b) / 3.0  # centroide do triângulo (origem, a, b)
		var dir: Vector2 = center.normalized() if center.length() > 0.001 else Vector2.from_angle(randf() * TAU)
		_pieces.append(PackedVector2Array([-center, a - center, b - center]))
		_centers.append(center)
		_vel.append((dir * randf_range(Params.break_speed_min, Params.break_speed_max) + Vector2(randf_range(-60.0, 60.0), 0.0)) * k)
		_spin.append(randf_range(-Params.break_spin_max, Params.break_spin_max) * k)
	queue_redraw()
	_set_active()


func _start(kind: Kind, pos: Vector2, data: BodyData, duration: float) -> void:
	_kind = kind
	position = pos
	_age = 0.0
	_duration = maxf(duration, 0.05)
	_color = data.color
	_points.resize(data.shape.size())
	for i in data.shape.size():
		_points[i] = data.shape[i] * Params.ship_size


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		expire()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / _duration
	if _kind == Kind.EXIT:
		_draw_exit(t)
	else:
		_draw_break(t)


func _draw_exit(t: float) -> void:
	var k: float = Params.anim_intensity
	var e: float = ease(t, -2.0)  # começa devagar e acelera para dentro do núcleo
	draw_set_transform(Vector2.ZERO, Params.exit_spin * k * e, Vector2.ONE * (1.0 - e))
	var fade: float = 1.0 - t * t
	draw_colored_polygon(_points, Color(_color.lightened(0.3 * t), fade))
	draw_colored_polygon(_points, Color(1.0, 1.0, 1.0, sin(t * PI) * 0.6 * minf(k, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Anel que converge para o núcleo
	var ring: float = Params.ship_size.y * lerpf(0.9, 0.2, e)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32, Color(_color.lightened(0.4), (1.0 - t) * 0.7 * minf(k, 1.0)), 4.0)


func _draw_break(t: float) -> void:
	var fade: float = 1.0 - t * t
	# Clarão curto na hora da quebra
	if t < 0.25:
		var flash: float = 1.0 - t / 0.25
		draw_colored_polygon(_points, Color(1.0, 1.0, 1.0, flash * 0.9 * minf(Params.anim_intensity, 1.0)))
	for i in _pieces.size():
		# Velocidade cai com o tempo e a gravidade puxa os pedaços para baixo
		var travel: float = _age * (1.0 - t * 0.5)
		var pos: Vector2 = _centers[i] + _vel[i] * travel + Vector2(0.0, Params.break_gravity * _age * _age * 0.5)
		draw_set_transform(pos, _spin[i] * _age, Vector2.ONE * (1.0 - t * 0.35))
		draw_colored_polygon(_pieces[i], Color(_color.lightened(0.2 * (1.0 - t)), fade))
		# Borda quente que esfria
		var edge: PackedVector2Array = _pieces[i].duplicate()
		edge.append(edge[0])
		draw_polyline(edge, Color(1.0, 0.9, 0.7, fade * (1.0 - t)), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
