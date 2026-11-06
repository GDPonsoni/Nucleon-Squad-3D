class_name SpecialButton
extends Button
## Botão do especial (canto inferior esquerdo): mostra o formato do corpo ativo e um
## anel que enche com a carga. Cheio, o anel fica dourado e pulsa.

var charge: float = 0.0  # 0 a 1
var body: BodyData  # null = sem corpo (aguardando escolha)
var moment: bool = false  # momento de especial: pulsa forte em dourado


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2.ONE * Params.special_button_size


func _process(_delta: float) -> void:
	disabled = body == null or charge < 1.0
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - Params.special_ring_width
	var ready: bool = body != null and charge >= 1.0
	var color: Color = Params.powerup_color if ready else (body.color if body != null else Params.hud_dead_color)

	draw_circle(center, radius, Params.switch_icon_bg_color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.25), Params.special_ring_width)
	if charge > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, color, Params.special_ring_width)

	if body != null:
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(center + point * radius * 1.1)
		draw_colored_polygon(points, body.color if ready else Color(body.color, 0.45))

	if moment:
		var beat: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * Params.special_moment_blink_hz)
		for k in 2:
			draw_arc(center, radius + Params.special_ring_width * (1.5 + k * 1.5 + beat * 2.0), 0.0, TAU, 48,
				Color(Params.special_moment_color, (0.9 - k * 0.35) * (1.0 - beat * 0.5)), 6.0)
	if ready:
		# Brilho pulsando em volta quando está pronto
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(center, radius + Params.special_ring_width * (1.0 + pulse), 0.0, TAU, 48, Color(color, 0.6 * (1.0 - pulse)), 4.0)
