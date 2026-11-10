class_name HitSpark
extends PoolItem
## Faísca de acerto (pooled): clarão, anel curto e fagulhas. Pequena e barata,
## aparece onde um tiro, raio ou descarga acerta. O delta é escalado (câmera lenta).

var _age: float = 0.0
var _color: Color
var _size: float = 1.0
var _dirs := PackedVector2Array()


func activate(pos: Vector2, color: Color, size: float = 1.0) -> void:
	position = pos
	_color = color
	_size = size
	_age = 0.0
	var count: int = Params.impact_reduced_sparks if SaveGame.setting("reduced_effects") else Params.impact_sparks
	_dirs.resize(count)
	for i in count:
		_dirs[i] = Vector2.from_angle(randf() * TAU)
	queue_redraw()
	_set_active()


func _process(delta: float) -> void:
	_age += delta
	if _age >= Params.impact_seconds:
		expire()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / Params.impact_seconds
	var k: float = minf(Params.anim_intensity, 1.5)
	var fade: float = 1.0 - t
	draw_circle(Vector2.ZERO, 14.0 * _size * (1.0 - t * 0.5) * k, Color(1.0, 1.0, 1.0, fade * 0.8))
	draw_arc(Vector2.ZERO, 10.0 * _size + 30.0 * _size * t, 0.0, TAU, 20, Color(_color.lightened(0.3), fade), 3.0)
	# Fagulhas: na visão 3D são partículas (ParticleView)
	if Renderer3D.particles:
		return
	for dir in _dirs:
		var start: Vector2 = dir * Params.impact_spark_speed * _size * t * 0.4 * k
		draw_line(start, start + dir * Params.impact_spark_length * _size * fade, Color(_color.lightened(0.5), fade), 3.0)


# --- Leitura para a visão 3D ---

## Segundos desde o acerto (volta a 0 quando o item é reaproveitado).
func age() -> float:
	return _age


func tint() -> Color:
	return _color


func spark_size() -> float:
	return _size
