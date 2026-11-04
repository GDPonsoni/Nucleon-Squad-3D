class_name ChapterArt
extends Control
## Ilustração animada de cada capítulo, desenhada por código (placeholder até a arte final):
## Aurora (planeta com auroras), Vulcânia (planeta de lava), Abismo (vórtice violeta),
## Singularidade (buraco negro com disco) e Eclipse (disco escuro com coroa dourada).

var chapter: int = 0
var planet: PlanetData
var _clock: float = 0.0
var _stars := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(Params.chapter_art_size.x, Params.chapter_art_size.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter + 7
	for i in 40:
		_stars.append(Vector2(rng.randf(), rng.randf()))


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.32
	var tint: Color = planet.star_color if planet != null else Color.WHITE
	for i in _stars.size():
		var twinkle: float = 0.35 + 0.35 * sin(_clock * 2.0 + i)
		draw_circle(Vector2(_stars[i].x * size.x, _stars[i].y * size.y), 2.0 + (i % 3), Color(tint, twinkle))
	match chapter:
		0: _aurora(c, r)
		1: _volcanic(c, r)
		2: _abyss(c, r)
		3: _singularity(c, r)
		_: _eclipse(c, r)


func _aurora(c: Vector2, r: float) -> void:
	draw_circle(c, r * 1.08, Color(0.4, 0.7, 1.0, 0.18))
	draw_circle(c, r, Color(0.16, 0.3, 0.62))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.55, Color(0.3, 0.48, 0.85, 0.6))
	for band in 3:
		var points := PackedVector2Array()
		for i in 25:
			var t: float = float(i) / 24.0
			var x: float = c.x - r * 1.5 + t * r * 3.0
			var y: float = c.y - r * (0.85 + band * 0.22) + sin(t * 9.0 + _clock * 1.6 + band) * r * 0.08
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.3, 1.0, 0.75, 0.55 - band * 0.12), r * 0.09, true)


func _volcanic(c: Vector2, r: float) -> void:
	var glow: float = 0.5 + 0.5 * sin(_clock * 2.2)
	draw_circle(c, r * 1.12, Color(1.0, 0.4, 0.2, 0.12 + 0.08 * glow))
	draw_circle(c, r, Color(0.35, 0.08, 0.06))
	for i in 6:
		var a: float = TAU * i / 6.0 + 0.4
		var mid: Vector2 = c + Vector2.from_angle(a) * r * 0.45 + Vector2.from_angle(a + 1.3) * r * 0.15
		draw_polyline(PackedVector2Array([c + Vector2.from_angle(a) * r * 0.1, mid, c + Vector2.from_angle(a + 0.25) * r * 0.92]),
			Color(1.0, 0.55 + 0.2 * glow, 0.15), r * 0.06)
	for i in 5:
		var t: float = fmod(_clock * 0.6 + i * 0.2, 1.0)
		var a: float = -PI * 0.5 + (i - 2) * 0.35
		draw_circle(c + Vector2.from_angle(a) * r * (1.0 + t * 0.5), r * 0.05 * (1.0 - t), Color(1.0, 0.6, 0.2, 1.0 - t))


func _abyss(c: Vector2, r: float) -> void:
	for i in 7:
		var k: float = 1.0 - i / 7.0
		var spin: float = _clock * (0.4 + i * 0.15)
		var points := PackedVector2Array()
		for j in 49:
			var a: float = TAU * j / 48.0
			points.append(c + Vector2(cos(a + spin) * r * 1.4 * k, sin(a + spin) * r * 0.75 * k))
		draw_polyline(points, Color(0.65, 0.4, 1.0, 0.15 + 0.1 * i), 3.0 + i)
	draw_circle(c, r * 0.22, Color(0.02, 0.0, 0.05))


func _singularity(c: Vector2, r: float) -> void:
	draw_circle(c, r * 1.25, Color(0.4, 1.0, 0.9, 0.06))
	var points := PackedVector2Array()
	for j in 65:
		var a: float = TAU * j / 64.0
		points.append(c + Vector2(cos(a) * r * 1.5, sin(a) * r * 0.32))
	var pulse: float = 0.6 + 0.4 * sin(_clock * 3.0)
	draw_polyline(points, Color(0.5, 1.0, 0.9, 0.5 * pulse), r * 0.16)
	draw_polyline(points, Color(1.0, 1.0, 1.0, 0.7 * pulse), r * 0.04)
	draw_circle(c, r * 0.62, Color(0.0, 0.0, 0.0))
	draw_arc(c, r * 0.66, 0.0, TAU, 48, Color(0.6, 1.0, 0.95, 0.8), 3.0)
	# Parte de trás do disco passa por cima do buraco (lente gravitacional)
	draw_arc(c, r * 0.8, PI * 1.08, PI * 1.92, 32, Color(0.5, 1.0, 0.9, 0.45 * pulse), r * 0.08)


func _eclipse(c: Vector2, r: float) -> void:
	for i in 16:
		var a: float = TAU * i / 16.0 + _clock * 0.25
		var length: float = r * (1.25 + 0.2 * sin(_clock * 2.0 + i * 1.7))
		draw_line(c + Vector2.from_angle(a) * r * 0.95, c + Vector2.from_angle(a) * length, Color(1.0, 0.75, 0.3, 0.6), r * 0.07)
	draw_circle(c, r * 1.05, Color(1.0, 0.85, 0.5, 0.9))
	draw_circle(c, r * 0.98, Color(0.04, 0.02, 0.01))
