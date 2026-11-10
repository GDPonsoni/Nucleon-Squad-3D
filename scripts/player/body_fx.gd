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
var _body: BodyData
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
	_body = data
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
	var e: float = exit_ease()  # começa devagar e acelera para dentro do núcleo
	# Na visão 3D o corpo que recolhe é um modelo (EntityViews); o anel segue no plano
	if not Renderer3D.active:
		draw_set_transform(Vector2.ZERO, Params.exit_spin * k * e, Vector2.ONE * (1.0 - e))
		draw_colored_polygon(_points, Color(_color.lightened(0.3 * t), fade_alpha()))
		draw_colored_polygon(_points, Color(1.0, 1.0, 1.0, exit_glow()))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Anel que converge para o núcleo
	var ring: float = Params.ship_size.y * lerpf(0.9, 0.2, e)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32, Color(_color.lightened(0.4), (1.0 - t) * 0.7 * minf(k, 1.0)), 4.0)


func _draw_break(t: float) -> void:
	var fade: float = fade_alpha()
	# Clarão curto na hora da quebra
	if t < 0.25:
		var flash: float = 1.0 - t / 0.25
		draw_colored_polygon(_points, Color(1.0, 1.0, 1.0, flash * 0.9 * minf(Params.anim_intensity, 1.0)))
	# Na visão 3D os pedaços são modelos (EntityViews)
	if Renderer3D.active:
		return
	for i in _pieces.size():
		draw_set_transform(piece_position(i), piece_rotation(i), Vector2.ONE * piece_scale())
		draw_colored_polygon(_pieces[i], Color(_color.lightened(0.2 * (1.0 - t)), fade))
		# Borda quente que esfria
		var edge: PackedVector2Array = _pieces[i].duplicate()
		edge.append(edge[0])
		draw_polyline(edge, Color(1.0, 0.9, 0.7, fade * (1.0 - t)), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Leitura para o desenho (2D e visão 3D usam os mesmos valores) ---

func kind() -> Kind:
	return _kind


func body_data() -> BodyData:
	return _body


## 0 no começo, 1 no fim do efeito.
func progress() -> float:
	return _age / _duration


func fade_alpha() -> float:
	var t: float = progress()
	return 1.0 - t * t


func tint() -> Color:
	return _color


func exit_ease() -> float:
	return ease(progress(), -2.0)


func exit_glow() -> float:
	return sin(progress() * PI) * 0.6 * minf(Params.anim_intensity, 1.0)


func piece_count() -> int:
	return _pieces.size() if _kind == Kind.BREAK else 0


## Posição do pedaço em relação ao efeito: a velocidade cai com o tempo e a gravidade puxa para baixo.
func piece_position(index: int) -> Vector2:
	var travel: float = _age * (1.0 - progress() * 0.5)
	return _centers[index] + _vel[index] * travel + Vector2(0.0, Params.break_gravity * _age * _age * 0.5)


func piece_rotation(index: int) -> float:
	return _spin[index] * _age


func piece_scale() -> float:
	return 1.0 - progress() * 0.35
