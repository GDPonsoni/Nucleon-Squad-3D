class_name Player
extends Node2D
## Nave placeholder: triângulo desenhado por código.
## Controle relativo: a nave segue o deslocamento do dedo desde o toque inicial.

var _touch_origin: Vector2
var _ship_origin: Vector2
var _target: Vector2


func _ready() -> void:
	var rect: Rect2 = get_viewport_rect()
	position = Vector2(rect.get_center().x, rect.end.y - Params.ship_start_bottom_offset)
	_target = position


func bind_input(touch: TouchInput) -> void:
	touch.touch_started.connect(_on_touch_started)
	touch.touch_moved.connect(_on_touch_moved)


func _process(delta: float) -> void:
	# delta já vem escalado pelo time scale: a nave reflete a câmera lenta
	position = position.move_toward(_target, Params.ship_speed * delta)


func _draw() -> void:
	var half: Vector2 = Params.ship_size * 0.5
	var points := PackedVector2Array([
		Vector2(0.0, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	draw_colored_polygon(points, Params.ship_color)


func _on_touch_started(pos: Vector2) -> void:
	_touch_origin = pos
	_ship_origin = position
	_target = position


func _on_touch_moved(pos: Vector2) -> void:
	var raw: Vector2 = _ship_origin + (pos - _touch_origin) * Params.drag_sensitivity
	_target = _clamp_to_screen(raw)
	# Na borda, reancora para a nave responder assim que o dedo voltar
	_ship_origin += _target - raw


func _clamp_to_screen(point: Vector2) -> Vector2:
	var rect: Rect2 = get_viewport_rect()
	var half: Vector2 = Params.ship_size * 0.5
	return point.clamp(rect.position + half, rect.end - half)
