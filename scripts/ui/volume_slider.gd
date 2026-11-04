class_name VolumeSlider
extends Control
## Controle deslizante grande para toque (0 a 1): trilho arredondado, preenchimento e botão.

signal value_changed(value: float)
## O dedo soltou o controle (bom momento para tocar um som de exemplo).
signal released

var value: float = 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

var _dragging: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(Params.settings_slider_width, Params.settings_slider_height)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		if button.pressed:
			_set_from_x(button.position.x)
		else:
			released.emit()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()


func _set_from_x(x: float) -> void:
	var pad: float = size.y * 0.5
	var new_value: float = clampf((x - pad) / maxf(size.x - pad * 2.0, 1.0), 0.0, 1.0)
	# Gruda nas pontas para chegar a 0 e a 100% com facilidade
	new_value = snappedf(new_value, 0.01)
	if not is_equal_approx(new_value, value):
		value = new_value
		value_changed.emit(value)


func _draw() -> void:
	var pad: float = size.y * 0.5
	var track_height: float = size.y * 0.3
	var track := Rect2(pad, (size.y - track_height) * 0.5, size.x - pad * 2.0, track_height)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(track_height * 0.5))
	box.bg_color = Color(Params.hud_panel_color, 0.9)
	draw_style_box(box, track)
	if value > 0.0:
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(int(track_height * 0.5))
		fill.bg_color = Params.ui_accent_color
		draw_style_box(fill, Rect2(track.position, Vector2(track.size.x * value, track.size.y)))
	var knob := Vector2(track.position.x + track.size.x * value, size.y * 0.5)
	draw_circle(knob, size.y * 0.42, Params.nucleus_outline_color)
	draw_circle(knob, size.y * 0.34, Color.WHITE if _dragging else Params.ui_text_color)
