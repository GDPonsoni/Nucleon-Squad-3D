class_name QuarkBadge
extends PanelContainer
## Selo com o saldo de quarks: painel arredondado, ícone do quark e o número.
## set_amount(valor, true) conta até o valor novo e dá um pulo (ganho de quarks).

var _label: Label
var _icon: Control
var _shown: int = 0


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Params.ui_panel_color, 0.9)
	style.border_color = Color(Params.quark_color, 0.7)
	style.set_border_width_all(Params.ui_border_width)
	style.set_corner_radius_all(int(Params.quark_badge_height * 0.5))
	style.content_margin_left = Params.quark_badge_height * 0.3
	style.content_margin_right = Params.quark_badge_height * 0.45
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.y = Params.quark_badge_height
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2.ONE * Params.quark_badge_height * 0.75
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.draw.connect(func() -> void:
		UiFactory.draw_quark_icon(_icon, _icon.size * 0.5, _icon.size.x * 0.45))
	row.add_child(_icon)
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.add_theme_font_size_override("font_size", Params.quark_badge_font_size)
	_label.add_theme_color_override("font_color", Params.quark_color.lightened(0.3))
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	set_amount(SaveGame.quarks, false)


func set_amount(value: int, animate: bool) -> void:
	if not animate:
		_set_shown(value)
		return
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_method(func(v: float) -> void: _set_shown(int(v)), float(_shown), float(value), Params.quark_badge_count_seconds)
	var pop := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2.ONE * 1.15, 0.12)
	pop.tween_property(self, "scale", Vector2.ONE, 0.25)


func _set_shown(value: int) -> void:
	_shown = value
	_label.text = str(value)
