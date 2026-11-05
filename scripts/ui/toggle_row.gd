class_name ToggleRow
extends Button
## Linha de configuração com interruptor (estilo do celular): nome à esquerda e chave à
## direita, verde quando ligada. A linha inteira é tocável.

signal toggled_value(on: bool)

var value: bool = false:
	set(v):
		value = v
		_target = 1.0 if v else 0.0
		set_process(true)

var _label: Label
var _knob: float = 0.0  # 0 = desligado, 1 = ligado (animado)
var _target: float = 0.0


func setup(text_key: String, on: bool) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(Params.settings_slider_width, Params.toggle_row_height)
	_label = Label.new()
	_label.text = text_key
	_label.add_theme_font_size_override("font_size", Params.settings_label_font_size)
	_label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.offset_right = Params.settings_slider_width - Params.toggle_size.x - 20.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	value = on
	_knob = _target
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	value = not value
	Audio.play(&"ui_click")
	Haptics.play(&"tick")
	toggled_value.emit(value)


func _process(delta: float) -> void:
	_knob = move_toward(_knob, _target, delta / Params.toggle_seconds)
	queue_redraw()
	if is_equal_approx(_knob, _target):
		set_process(false)


func _draw() -> void:
	var track_size: Vector2 = Params.toggle_size
	var track := Rect2(Vector2(size.x - track_size.x, (size.y - track_size.y) * 0.5), track_size)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(track_size.y * 0.5))
	box.bg_color = Params.hud_dead_color.lerp(Params.toggle_on_color, _knob)
	draw_style_box(box, track)
	var radius: float = track_size.y * 0.5 - 6.0
	var x: float = lerpf(track.position.x + track_size.y * 0.5, track.end.x - track_size.y * 0.5, _knob)
	draw_circle(Vector2(x, track.get_center().y), radius, Color.WHITE)
	# Linha separadora discreta embaixo
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(Params.ui_muted_text_color, 0.2), 2.0)
