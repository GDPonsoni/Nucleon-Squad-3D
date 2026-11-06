class_name StarRow
extends Control
## Fileira de estrelas desenhadas por código (cheias = ganhas).

var earned: int = 0:
	set(value):
		earned = value
		queue_redraw()
var total: int = 3
var star_size: float = 40.0


func setup(earned_count: int, star_px: float, total_count: int = 3) -> StarRow:
	earned = earned_count
	star_size = star_px
	total = total_count
	custom_minimum_size = Vector2(star_px * 1.15 * total_count, star_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _draw() -> void:
	var step: float = size.x / maxf(total, 1)
	for i in total:
		draw_star(self, Vector2(step * (i + 0.5), size.y * 0.5), star_size * 0.5, i < earned)


## Estrela de 5 pontas: dourada se ganha, apagada (só contorno) se não.
static func draw_star(canvas: CanvasItem, center: Vector2, radius: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var r: float = radius if k % 2 == 0 else radius * 0.45
		pts.append(center + Vector2.from_angle(-PI * 0.5 + k * PI / 5.0) * r)
	if filled:
		canvas.draw_colored_polygon(pts, Params.powerup_color)
	else:
		pts.append(pts[0])
		canvas.draw_polyline(pts, Color(Params.ui_muted_text_color, 0.5), 3.0)
