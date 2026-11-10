class_name Explosion
extends PoolItem
## Efeito de destruição reutilizável: clarão, anel que se expande e estilhaços.
## O tamanho e a duração crescem com o raio de quem explodiu.

var _age: float = 0.0
var _duration: float = 0.0
var _radius: float = 0.0
var _color: Color
var _dirs := PackedVector2Array()
var _speeds := PackedFloat32Array()


func activate(pos: Vector2, radius: float, color: Color) -> void:
	position = pos
	_radius = radius
	_color = color
	_age = 0.0
	var size_factor: float = radius / Params.explosion_reference_radius
	_duration = Params.explosion_seconds * clampf(size_factor, 0.8, 1.6)
	var shards: int = Params.reduced_explosion_shards if SaveGame.setting("reduced_effects") else Params.explosion_shards
	_dirs.resize(shards)
	_speeds.resize(shards)
	for i in shards:
		_dirs[i] = Vector2.from_angle(randf() * TAU)
		_speeds[i] = randf_range(Params.explosion_shard_speed_min, Params.explosion_shard_speed_max) * size_factor
	queue_redraw()
	_set_active()


func _process(delta: float) -> void:
	# delta escalado: a explosão também desacelera na câmera lenta
	_age += delta
	if _age >= _duration:
		expire()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / _duration  # 0 -> 1
	# Some devagar no começo e rápido no fim
	var fade: float = 1.0 - t * t

	# Bola de fogo na cor do inimigo, que se dissolve na primeira metade
	if t < 0.5:
		draw_circle(Vector2.ZERO, _radius * (1.0 + t), Color(_color.lightened(0.25), (1.0 - t * 2.0) * 0.85))

	# Clarão branco no começo
	if t < Params.explosion_flash_part:
		var flash: float = 1.0 - t / Params.explosion_flash_part
		draw_circle(Vector2.ZERO, _radius * (0.7 + t), Color(1.0, 1.0, 1.0, flash))

	# Anel que se expande
	var ring_radius: float = _radius * (0.5 + ease(t, 0.4) * Params.explosion_ring_growth)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(_color.lightened(0.15), fade), maxf(2.0, Params.explosion_ring_width * fade))

	# Estilhaços voando para fora, desacelerando (na visão 3D são partículas: ParticleView)
	if Renderer3D.particles:
		return
	var shard_color := Color(_color.lightened(0.35), fade)
	var travel: float = _age * (1.0 - t * 0.5)
	var length: float = _radius * Params.explosion_shard_length * (0.4 + 0.6 * fade)
	for i in _dirs.size():
		var start: Vector2 = _dirs[i] * _speeds[i] * travel
		draw_line(start, start + _dirs[i] * length, shard_color, Params.explosion_shard_width)


# --- Leitura para a visão 3D ---

## Segundos desde que explodiu (volta a 0 quando o item é reaproveitado).
func age() -> float:
	return _age


func blast_radius() -> float:
	return _radius


func tint() -> Color:
	return _color
