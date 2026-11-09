class_name ModeCard
extends Button
## Card grande da escolha de modo: ilustração desenhada por código, nome e descrição curta.
## Travado: escurece, mostra um cadeado e o que falta para liberar.

enum Art { CAMPAIGN, RUN }

var art: Art = Art.CAMPAIGN
var title_key: String = ""
var description: String = ""  # já traduzida
var locked: bool = false
var accent: Color = Params.ui_accent_color
var _clock: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, Params.mode_card_height)
	focus_mode = Control.FOCUS_NONE
	flat = true
	clip_contents = true
	UiFactory._add_press_feedback(self)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var box := StyleBoxFlat.new()
	box.bg_color = Params.ui_panel_color
	box.border_color = Color(accent, 0.35 if locked else 0.9)
	box.set_border_width_all(4)
	box.set_corner_radius_all(int(Params.mode_card_radius))
	draw_style_box(box, rect)
	var art_rect := Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, rect.size.y * 0.62))
	match art:
		Art.CAMPAIGN:
			_draw_campaign(art_rect)
		Art.RUN:
			_draw_run(art_rect)
	var font: Font = get_theme_default_font()
	var title: String = tr(title_key)
	var title_y: float = art_rect.end.y + Params.mode_card_title_size * 1.1
	draw_string(font, Vector2(Params.ui_panel_padding * 0.6, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Params.mode_card_title_size, Params.ui_muted_text_color if locked else Params.ui_text_color)
	draw_multiline_string(font, Vector2(Params.ui_panel_padding * 0.6, title_y + Params.mode_card_text_size * 1.3), description,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - Params.ui_panel_padding * 1.2, Params.mode_card_text_size, 2,
		Params.ui_muted_text_color)
	if locked:
		draw_rect(rect, Color(0, 0, 0, 0.45))
		_draw_lock(art_rect.get_center(), art_rect.size.y * 0.16)


## Campanha: planeta com anel, estrelas e um esquadrão em V subindo.
func _draw_campaign(r: Rect2) -> void:
	draw_rect(r, Color(0.03, 0.04, 0.09))
	for i in 40:
		var p := Vector2(fmod(i * 97.3, r.size.x), fmod(i * 53.1 + _clock * (20.0 + i % 3 * 25.0), r.size.y))
		draw_circle(r.position + p, 1.5 + i % 2, Color(1, 1, 1, 0.5))
	var planet_c := r.position + Vector2(r.size.x * 0.76, r.size.y * 0.52)
	var pr: float = r.size.y * 0.3
	draw_circle(planet_c, pr, Color(0.35, 0.25, 0.75))
	draw_circle(planet_c + Vector2(-pr * 0.18, -pr * 0.18), pr * 0.78, Color(0.5, 0.38, 0.95))
	# Anel inclinado: elipse achatada passando na frente do planeta
	var ring := PackedVector2Array()
	for k in 33:
		var a: float = TAU * k / 32.0
		ring.append(planet_c + Vector2(cos(a) * pr * 1.6, sin(a) * pr * 0.35).rotated(-0.35))
	draw_polyline(ring, Color(1.0, 0.85, 0.5, 0.85), 5.0)
	var colors: Array[Color] = [Color(0.45, 0.9, 1.0), Color(1.0, 0.6, 0.3), Color(0.6, 1.0, 0.5), Color(1.0, 0.45, 0.8)]
	var lead := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.3 + sin(_clock * 2.0) * 8.0)
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(-110, 95), Vector2(110, 95), Vector2(0, 190)]
	for i in offsets.size():
		_draw_ship(lead + offsets[i], 46.0, colors[i])


## Incursão: nave branca com três armas em órbita, orbes de XP e uma onda de inimigos.
func _draw_run(r: Rect2) -> void:
	draw_rect(r, Color(0.06, 0.02, 0.08))
	var center := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.62)
	for i in 3:
		var a: float = _clock * 1.5 + TAU * i / 3.0
		var colors: Array[Color] = [Color(0.45, 0.9, 1.0), Color(0.72, 0.55, 1.0), Color(1.0, 0.6, 0.3)]
		draw_circle(center + Vector2.from_angle(a) * 95.0, 16.0, colors[i])
	draw_arc(center, 95.0, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 3.0)
	_draw_ship(center, 46.0, Color(0.95, 0.97, 1.0))
	for i in 7:
		var x: float = r.position.x + r.size.x * (0.12 + i * 0.125)
		var y: float = r.position.y + r.size.y * 0.16 + sin(_clock * 3.0 + i) * 10.0
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(Vector2(x, y) + Vector2.from_angle(PI * 0.5 + TAU * k / 6.0) * 22.0)
		draw_colored_polygon(pts, Color(1.0, 0.3, 0.4))
	for i in 10:
		var p := center + Vector2(cos(i * 2.4) * (150.0 + i * 12.0), sin(i * 1.7) * 60.0 - 20.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(6, 0), p + Vector2(0, 9), p + Vector2(-6, 0)]), Params.xp_orb_color)


func _draw_ship(c: Vector2, s: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, s * 0.8), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.7, s * 0.8)]), color)
	draw_circle(c + Vector2(0, s * 0.1), s * 0.18, Color.WHITE)


func _draw_lock(c: Vector2, s: float) -> void:
	draw_arc(c + Vector2(0, -s * 0.5), s * 0.6, PI, TAU, 16, Color.WHITE, s * 0.22)
	draw_rect(Rect2(c + Vector2(-s, -s * 0.4), Vector2(s * 2.0, s * 1.6)), Color.WHITE)
