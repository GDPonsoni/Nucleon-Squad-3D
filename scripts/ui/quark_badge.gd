class_name QuarkBadge
extends PanelContainer
## Selo com o saldo de quarks: painel arredondado, ícone do quark e o número.
## set_amount(valor, true) conta até o valor novo e dá um pulo (ganho de quarks).
## Tocável (interactive): mostra um "+" e emite pressed (abre a janela de ganhar quarks).

signal pressed

var interactive: bool = true
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
	if interactive:
		var plus := Control.new()
		plus.custom_minimum_size = Vector2.ONE * Params.quark_badge_height * 0.55
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.draw.connect(func() -> void:
			var c: Vector2 = plus.size * 0.5
			var r: float = plus.size.x * 0.5
			plus.draw_circle(c, r, Params.ui_accent_color)
			plus.draw_line(c + Vector2(-r * 0.5, 0.0), c + Vector2(r * 0.5, 0.0), Params.background_color, 5.0)
			plus.draw_line(c + Vector2(0.0, -r * 0.5), c + Vector2(0.0, r * 0.5), Params.background_color, 5.0))
		row.add_child(plus)
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in row.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	set_amount(SaveGame.quarks, false)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if interactive and click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		Audio.play(&"ui_click")
		pressed.emit()
		accept_event()


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
