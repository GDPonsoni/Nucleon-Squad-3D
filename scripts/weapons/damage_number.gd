class_name DamageNumber
extends PoolItem
## Um número de dano (pooled): sobe, encolhe um pouco e some. O delta é escalado (câmera lenta).

var _text: String = ""
var _color: Color = Color.WHITE
var _age: float = 0.0
var _size: int = 36


func activate(pos: Vector2, amount: float, color: Color) -> void:
	position = pos
	_text = str(roundi(amount)) if amount >= 10.0 else str(snappedf(amount, 0.1))
	_color = color
	_age = 0.0
	# Dano grande aparece maior
	_size = Params.damage_number_font_size + mini(int(amount * 0.2), Params.damage_number_font_bonus)
	queue_redraw()
	_set_active()


func _process(delta: float) -> void:
	_age += delta
	if _age >= Params.damage_number_seconds:
		expire()
		return
	position.y -= Params.damage_number_rise_speed * delta
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / Params.damage_number_seconds, 0.0, 1.0)
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var at := Vector2(-width * 0.5, 0.0)
	font.draw_string_outline(get_canvas_item(), at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, 6, Color(0.0, 0.0, 0.0, fade * 0.8))
	font.draw_string(get_canvas_item(), at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(_color, fade))
