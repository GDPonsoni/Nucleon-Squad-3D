class_name StageNode
extends Button
## Nó de fase no mapa do planeta. Desenhado por código: trancado (cadeado), liberado (anel),
## próxima fase (anel pulsando) e concluído (preenchido com visto). Chefes são maiores:
## losango para o intermediário e coroa para o do capítulo.

enum Kind { NORMAL, MIDBOSS, BOSS }

var color: Color = Color.WHITE
var label: String = ""
var kind: Kind = Kind.NORMAL
var unlocked: bool = false
var completed: bool = false
var stars: int = 0  # 0 a 3, só nas concluídas
var is_next: bool = false  # a fase sugerida (primeira não concluída)
var _clock: float = 0.0


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var side: float = Params.stage_node_size * (Params.stage_node_boss_scale if kind != Kind.NORMAL else 1.0)
	custom_minimum_size = Vector2.ONE * side
	size = custom_minimum_size
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	button_down.connect(func() -> void:
		create_tween().set_ignore_time_scale(true).tween_property(self, "scale", Vector2.ONE * Params.button_press_scale, Params.button_press_seconds))
	button_up.connect(func() -> void:
		create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(self, "scale", Vector2.ONE, Params.button_press_seconds * 2.0))
	set_process(is_next)


func shake() -> void:
	var tween := create_tween().set_ignore_time_scale(true)
	for dx in [-10.0, 10.0, -6.0, 6.0, 0.0]:
		tween.tween_property(self, "rotation", deg_to_rad(dx), 0.04)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 8.0
	var dark := Color(0.05, 0.06, 0.1, 0.92)
	if not unlocked:
		draw_circle(c, r, dark)
		draw_arc(c, r, 0.0, TAU, 48, Color(Params.ui_muted_text_color, 0.35), 4.0)
		_draw_lock(c, r * 0.5)
	elif completed:
		# Só borda: miolo escuro com um véu da cor, anel duplo e número na cor da fase
		draw_circle(c, r, dark)
		draw_circle(c, r, Color(color, 0.14))
		draw_arc(c, r, 0.0, TAU, 48, color.lightened(0.3), 6.0)
		draw_arc(c, r - 14.0, 0.0, TAU, 48, Color(color, 0.45), 2.0)
		_draw_label(c, r, color.lightened(0.5))
		_draw_stars(c, r)
	else:
		draw_circle(c, r, dark)
		draw_arc(c, r, 0.0, TAU, 48, Color(color, 0.8), 4.0)
		_draw_label(c, r)
	if is_next:
		var pulse: float = fmod(_clock * 0.9, 1.0)
		draw_arc(c, r + 6.0 + pulse * 22.0, 0.0, TAU, 48, Color(color, 0.7 * (1.0 - pulse)), 5.0)
	_draw_kind(c, r)


func _draw_label(c: Vector2, r: float, ink: Color = Params.ui_text_color, outlined: bool = false) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = int(r * (0.5 if kind == Kind.NORMAL else 0.45))
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := Vector2(c.x - width * 0.5, c.y + font_size * 0.35)
	if outlined:
		draw_string_outline(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, color.darkened(0.65))
	draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Três estrelas pequenas embaixo do nó concluído (as ganhas, cheias).
func _draw_stars(c: Vector2, r: float) -> void:
	var radius: float = r * 0.2
	for i in 3:
		StarRow.draw_star(self, c + Vector2((i - 1) * radius * 2.4, r + radius * 1.1 - (0.0 if i == 1 else radius * 0.5) + radius * 0.4), radius, i < stars)


func _draw_lock(c: Vector2, s: float) -> void:
	var tint: Color = Color(Params.ui_muted_text_color, 0.6)
	draw_arc(c + Vector2(0.0, -s * 0.15), s * 0.45, PI, TAU, 16, tint, 5.0)
	draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.15), Vector2(s * 1.2, s * 0.95)), tint)


## Marca do chefe sobre o nó: losango (intermediário) ou coroa (chefe do capítulo).
func _draw_kind(c: Vector2, r: float) -> void:
	if kind == Kind.NORMAL:
		return
	var tint: Color = Params.hud_warning_color if kind == Kind.BOSS else Params.powerup_color
	if not unlocked:
		tint = Color(tint, 0.45)
	var top: Vector2 = c + Vector2(0.0, -r - 4.0)
	var s: float = r * 0.28
	if kind == Kind.BOSS:
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(-s * 1.4, s * 0.6), top + Vector2(-s * 1.4, -s * 0.8), top + Vector2(-s * 0.6, -s * 0.1),
			top + Vector2(0.0, -s * 1.1), top + Vector2(s * 0.6, -s * 0.1), top + Vector2(s * 1.4, -s * 0.8), top + Vector2(s * 1.4, s * 0.6),
		]), tint)
	else:
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(0.0, -s), top + Vector2(s * 0.9, 0.0), top + Vector2(0.0, s), top + Vector2(-s * 0.9, 0.0),
		]), tint)
