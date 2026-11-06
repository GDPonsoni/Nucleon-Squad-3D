class_name IconButton
extends Button
## Botão redondo com ícone desenhado por código e legenda pequena opcional.
## Usos: ação (continuar, reiniciar), interruptor (toggle = true: aceso quando ligado) e
## ícone de linha de configuração (sem legenda, pequeno).

signal toggled_value(on: bool)

enum Icon { PLAY, RESTART, GEAR, HOME, SPEAKER, NOTE, BURST, SPARKLE, VIBRATE, CHART, GLOBE, MAP, UPGRADE, DAMAGE }

var kind: Icon = Icon.PLAY
var caption: String = ""
## Preenchido na cor de destaque (ação principal).
var primary: bool = false
## Interruptor: alterna a cada toque e acende quando ligado.
var toggle: bool = false
var on: bool = false:
	set(value):
		on = value
		queue_redraw()
## Risco diagonal sobre o ícone (ex.: som mudo).
var slashed: bool = false:
	set(value):
		slashed = value
		queue_redraw()
var diameter: float = 150.0


func setup(icon_kind: Icon, diameter_px: float, caption_text: String = "") -> IconButton:
	kind = icon_kind
	diameter = diameter_px
	caption = caption_text
	return self


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var caption_h: float = Params.icon_caption_font_size * 1.5 if not caption.is_empty() else 0.0
	custom_minimum_size = Vector2(maxf(diameter, Params.icon_caption_min_width if not caption.is_empty() else 0.0), diameter + caption_h)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	button_down.connect(func() -> void:
		if not disabled:
			create_tween().set_ignore_time_scale(true).tween_property(self, "scale", Vector2.ONE * Params.button_press_scale, Params.button_press_seconds))
	button_up.connect(func() -> void:
		create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(self, "scale", Vector2.ONE, Params.button_press_seconds * 2.0))
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	Audio.play(&"ui_confirm" if primary else &"ui_click")
	if toggle:
		on = not on
		Haptics.play(&"tick")
		toggled_value.emit(on)


func _draw() -> void:
	var c := Vector2(size.x * 0.5, diameter * 0.5)
	var r: float = diameter * 0.5 - 4.0
	var filled: bool = primary or (toggle and on)
	var ink: Color = Color(0.05, 0.07, 0.12) if filled else (Params.ui_text_color if (not toggle or on) else Params.ui_muted_text_color)
	if filled:
		draw_circle(c, r, Params.ui_accent_color if not (toggle and on) else Params.toggle_on_color)
	else:
		draw_circle(c, r, Color(0.11, 0.14, 0.23, 0.95))
		draw_arc(c, r, 0.0, TAU, 48, Color(Params.ui_text_color, 0.25), 3.0)
	var s: float = r * 0.5
	_draw_icon(c, s, ink)
	if slashed:
		draw_line(c + Vector2(-s, -s) * 1.1, c + Vector2(s, s) * 1.1, Params.hud_warning_color, maxf(s * 0.16, 4.0))
	if not caption.is_empty():
		var font: Font = get_theme_default_font()
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Params.icon_caption_font_size).x
		draw_string(font, Vector2((size.x - width) * 0.5, diameter + Params.icon_caption_font_size * 1.1), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Params.icon_caption_font_size, Params.ui_muted_text_color)


func _draw_icon(c: Vector2, s: float, ink: Color) -> void:
	var w: float = maxf(s * 0.2, 4.0)
	match kind:
		Icon.PLAY:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(s, 0.0), c + Vector2(-s * 0.6, s)]), ink)
		Icon.RESTART:
			draw_arc(c, s * 0.9, deg_to_rad(-60.0), deg_to_rad(240.0), 32, ink, w)
			var tip: Vector2 = c + Vector2.from_angle(deg_to_rad(-60.0)) * s * 0.9
			draw_colored_polygon(PackedVector2Array([tip + Vector2(s * 0.55, -s * 0.1), tip + Vector2(-s * 0.1, -s * 0.5), tip + Vector2(-s * 0.25, s * 0.45)]), ink)
		Icon.GEAR:
			draw_arc(c, s * 0.62, 0.0, TAU, 32, ink, w)
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8.0)
				draw_line(c + dir * s * 0.78, c + dir * s * 1.12, ink, w * 1.25)
		Icon.HOME:
			draw_polyline(PackedVector2Array([c + Vector2(-s * 1.05, -s * 0.05), c + Vector2(0.0, -s * 1.0), c + Vector2(s * 1.05, -s * 0.05)]), ink, w)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, 0.0), c + Vector2(-s * 0.7, s * 0.95), c + Vector2(s * 0.7, s * 0.95), c + Vector2(s * 0.7, 0.0)]), ink, w)
		Icon.SPEAKER:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 1.0, -s * 0.35), c + Vector2(-s * 0.45, -s * 0.35), c + Vector2(s * 0.15, -s * 0.9),
				c + Vector2(s * 0.15, s * 0.9), c + Vector2(-s * 0.45, s * 0.35), c + Vector2(-s * 1.0, s * 0.35)]), ink)
			draw_arc(c + Vector2(s * 0.1, 0.0), s * 0.55, deg_to_rad(-45.0), deg_to_rad(45.0), 10, ink, w)
			draw_arc(c + Vector2(s * 0.1, 0.0), s * 0.95, deg_to_rad(-45.0), deg_to_rad(45.0), 10, ink, w)
		Icon.NOTE:
			draw_circle(c + Vector2(-s * 0.45, s * 0.65), s * 0.38, ink)
			draw_line(c + Vector2(-s * 0.1, s * 0.6), c + Vector2(-s * 0.1, -s * 0.9), ink, w)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.9), c + Vector2(s * 0.75, -s * 0.5), c + Vector2(s * 0.5, -s * 0.05)]), ink, w)
		Icon.BURST:
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8.0)
				draw_line(c + dir * s * (0.35 if i % 2 == 0 else 0.5), c + dir * s * (1.05 if i % 2 == 0 else 0.8), ink, w)
		Icon.SPARKLE:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -s * 1.1), c + Vector2(s * 0.25, -s * 0.25), c + Vector2(s * 1.1, 0.0), c + Vector2(s * 0.25, s * 0.25),
				c + Vector2(0.0, s * 1.1), c + Vector2(-s * 0.25, s * 0.25), c + Vector2(-s * 1.1, 0.0), c + Vector2(-s * 0.25, -s * 0.25)]), ink)
		Icon.VIBRATE:
			draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.85), Vector2(s * 0.8, s * 1.7)), ink, false, w)
			for side in [-1.0, 1.0]:
				draw_line(c + Vector2(side * s * 0.75, -s * 0.45), c + Vector2(side * s * 0.75, s * 0.45), ink, w)
				draw_line(c + Vector2(side * s * 1.05, -s * 0.25), c + Vector2(side * s * 1.05, s * 0.25), ink, w)
		Icon.CHART:
			for i in 3:
				var h: float = s * (0.7 + 0.55 * i)
				draw_rect(Rect2(c + Vector2(-s * 0.95 + i * s * 0.7, s * 0.9 - h), Vector2(s * 0.5, h)), ink)
		Icon.GLOBE:
			draw_arc(c, s, 0.0, TAU, 32, ink, w)
			draw_line(c + Vector2(-s, 0.0), c + Vector2(s, 0.0), ink, w * 0.7)
			draw_arc(c, s, 0.0, TAU, 32, ink, 1.0)
			var pts := PackedVector2Array()
			for k in 25:
				var a: float = k / 24.0 * TAU
				pts.append(c + Vector2(cos(a) * s * 0.45, sin(a) * s))
			draw_polyline(pts, ink, w * 0.7)
		Icon.MAP:
			# Três nós ligados por linha (como o mapa de fases)
			var a: Vector2 = c + Vector2(-s * 0.8, s * 0.7)
			var b: Vector2 = c + Vector2(s * 0.3, s * 0.1)
			var d: Vector2 = c + Vector2(s * 0.7, -s * 0.8)
			draw_polyline(PackedVector2Array([a, b, d]), ink, w * 0.8)
			for point in [a, b, d]:
				draw_circle(point, s * 0.3, ink)
		Icon.DAMAGE:
			# Estrela de impacto: ponta longa e curta alternadas
			var star := PackedVector2Array()
			for i in 16:
				var r: float = s * (1.15 if i % 2 == 0 else 0.55)
				star.append(c + Vector2.from_angle(TAU * i / 16.0) * r)
			draw_colored_polygon(star, ink)
		Icon.UPGRADE:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s * 1.1), c + Vector2(s * 0.95, -s * 0.05), c + Vector2(-s * 0.95, -s * 0.05)]), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.1), Vector2(s * 0.7, s * 1.05)), ink)
