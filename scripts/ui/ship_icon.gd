class_name ShipIcon
extends Control
## Ícone redondo com o formato de um corpo. Sem corpo, mostra um espaço vazio tracejado.
## Opcionalmente mostra um número (posição no esquadrão), a marca de nave auxiliar,
## um destaque (espaço sendo escolhido) ou um cadeado (nave ou espaço bloqueado).

var body: BodyData:
	set(value):
		body = value
		queue_redraw()
var number: int = 0:  # 0 = sem número
	set(value):
		number = value
		queue_redraw()
var auxiliary: bool = false:  # marca "A" de nave auxiliar
	set(value):
		auxiliary = value
		queue_redraw()
var highlighted: bool = false:  # anel pulsando (espaço sendo escolhido)
	set(value):
		highlighted = value
		set_process(value)
		queue_redraw()
var locked: bool = false:
	set(value):
		locked = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(highlighted)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	if highlighted:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(center, radius + 2.0, 0.0, TAU, 48, Color(Params.quark_color, 0.5 + 0.5 * pulse), 6.0)
	if body == null:
		# Espaço vazio: círculo tracejado
		var dashes: int = 16
		var dash_color: Color = Params.quark_color if auxiliary else Params.ui_muted_text_color
		for i in dashes:
			var start: float = TAU * i / dashes
			draw_arc(center, radius, start, start + TAU / dashes * 0.55, 6, dash_color, 3.0)
		if locked:
			_draw_lock(center, radius * 0.4)
		return
	var color: Color = Params.hud_dead_color if locked else body.color
	draw_circle(center, radius, Params.switch_icon_bg_color)
	draw_arc(center, radius, 0.0, TAU, 48, color, 4.0)
	var points := PackedVector2Array()
	for point in body.shape:
		points.append(center + point * radius * Params.switch_icon_shape_scale)
	draw_colored_polygon(points, Color(color, 0.5) if locked else color)
	if locked:
		_draw_lock(center + Vector2(radius * 0.62, -radius * 0.62), radius * 0.3)
	if number > 0:
		# Mesmo canto da marca "A" da auxiliar (o canto direito é do ⓘ na grade)
		_draw_badge(center + Vector2(-radius * 0.72, -radius * 0.72), radius * 0.32, str(number), Params.ui_accent_color)
	if auxiliary:
		_draw_badge(center + Vector2(-radius * 0.72, -radius * 0.72), radius * 0.32, "A", Params.quark_color)


func _draw_badge(badge: Vector2, badge_radius: float, text: String, color: Color) -> void:
	draw_circle(badge, badge_radius, color)
	var font: Font = get_theme_default_font()
	var font_size: int = int(badge_radius * 1.3)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, badge + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Params.background_color)


func _draw_lock(center: Vector2, size_px: float) -> void:
	var color: Color = Params.ui_muted_text_color
	draw_circle(center, size_px * 1.2, Params.switch_icon_bg_color)
	draw_arc(center + Vector2(0.0, -size_px * 0.2), size_px * 0.45, PI, TAU, 12, color, 4.0)
	draw_rect(Rect2(center + Vector2(-size_px * 0.6, -size_px * 0.2), Vector2(size_px * 1.2, size_px * 0.85)), color)
