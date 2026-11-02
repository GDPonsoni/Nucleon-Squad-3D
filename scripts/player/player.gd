class_name Player
extends Node2D
## Nave placeholder: triângulo desenhado por código.


func _ready() -> void:
	var rect: Rect2 = get_viewport_rect()
	position = Vector2(rect.get_center().x, rect.end.y - Params.ship_start_bottom_offset)


func _draw() -> void:
	var half: Vector2 = Params.ship_size * 0.5
	var points := PackedVector2Array([
		Vector2(0.0, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	draw_colored_polygon(points, Params.ship_color)
