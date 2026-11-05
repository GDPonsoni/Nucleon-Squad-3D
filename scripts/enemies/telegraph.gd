class_name Telegraph
## Desenhos de aviso antes dos ataques inimigos (linhas, anel, orbe, faixa, marcadores).
## t vai de 0 (começo do aviso) a 1 (o ataque sai): tudo fica mais forte perto do disparo.


static func alpha(t: float) -> float:
	return lerpf(Params.telegraph_alpha.x, Params.telegraph_alpha.y, t)


## Linhas tracejadas saindo do inimigo na direção de cada tiro.
static func draw_lines(canvas: CanvasItem, origin: Vector2, dirs: PackedVector2Array, start: float, color: Color, t: float) -> void:
	var length: float = Params.telegraph_line_length * (0.4 + 0.6 * t)
	var c := Color(color, alpha(t))
	for dir in dirs:
		canvas.draw_dashed_line(origin + dir * start, origin + dir * (start + length), c, Params.telegraph_line_width, Params.telegraph_dash)


## Anel que se contrai em volta do inimigo (anéis de tiro, invocação).
static func draw_ring(canvas: CanvasItem, origin: Vector2, radius: float, color: Color, t: float) -> void:
	var r: float = radius * lerpf(Params.telegraph_ring_scale, 1.05, t)
	canvas.draw_arc(origin, r, 0.0, TAU, 40, Color(color, alpha(t)), 5.0)


## Orbe crescendo no ponto de saída (tiros grandes e lentos).
static func draw_orb(canvas: CanvasItem, center: Vector2, radius: float, color: Color, t: float) -> void:
	canvas.draw_circle(center, radius * t, Color(color, 0.35 + 0.4 * t))
	canvas.draw_circle(center, radius * t * 0.45, Color(1.0, 1.0, 1.0, 0.8 * t))


## Faixa vertical translúcida (laser), piscando mais rápido perto do disparo.
static func draw_band(canvas: CanvasItem, x: float, width: float, top: float, bottom: float, color: Color, t: float) -> void:
	var blink: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.001 * (8.0 + 22.0 * t))
	canvas.draw_rect(Rect2(x - width * 0.5, top, width, bottom - top), Color(color, alpha(t) * 0.5 * blink))
	canvas.draw_line(Vector2(x - width * 0.5, top), Vector2(x - width * 0.5, bottom), Color(color, alpha(t)), 3.0)
	canvas.draw_line(Vector2(x + width * 0.5, top), Vector2(x + width * 0.5, bottom), Color(color, alpha(t)), 3.0)


## Marcadores (setas para baixo) nos pontos onde algo vai cair ou sair.
static func draw_markers(canvas: CanvasItem, points: PackedVector2Array, size: float, color: Color, t: float) -> void:
	var c := Color(color, alpha(t))
	var s: float = size * (0.6 + 0.4 * t)
	for p in points:
		canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-s, -s * 0.6), p + Vector2(s, -s * 0.6), p + Vector2(0.0, s * 0.8)]), c)
