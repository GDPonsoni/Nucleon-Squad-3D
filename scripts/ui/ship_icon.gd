class_name ShipIcon
extends Control
## Ícone redondo com o formato de um corpo. Sem corpo, mostra um espaço vazio tracejado.
## Opcionalmente mostra um número (posição no esquadrão).

var body: BodyData:
	set(value):
		body = value
		queue_redraw()
var number: int = 0:  # 0 = sem número
	set(value):
		number = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	if body == null:
		# Espaço vazio: círculo tracejado
		var dashes: int = 16
		for i in dashes:
			var start: float = TAU * i / dashes
			draw_arc(center, radius, start, start + TAU / dashes * 0.55, 6, Params.ui_muted_text_color, 3.0)
		return
	draw_circle(center, radius, Params.switch_icon_bg_color)
	draw_arc(center, radius, 0.0, TAU, 48, body.color, 4.0)
	var points := PackedVector2Array()
	for point in body.shape:
		points.append(center + point * radius * Params.switch_icon_shape_scale)
	draw_colored_polygon(points, body.color)
	if number > 0:
		var badge := center + Vector2(radius * 0.72, -radius * 0.72)
		var badge_radius: float = radius * 0.32
		draw_circle(badge, badge_radius, Params.ui_accent_color)
		var font: Font = get_theme_default_font()
		var font_size: int = int(badge_radius * 1.3)
		var text := str(number)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, badge + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Params.background_color)
