class_name TouchInput
extends Node
## Acompanha um único dedo (o primeiro que tocar) e emite sinais.
## No PC, o mouse chega como toque via emulate_touch_from_mouse.

signal touch_started(pos: Vector2)
signal touch_moved(pos: Vector2)
signal touch_ended

const NO_TOUCH: int = -1

var _index: int = NO_TOUCH


func is_touching() -> bool:
	return _index != NO_TOUCH


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _index == NO_TOUCH:
			_index = touch.index
			touch_started.emit(touch.position)
		elif not touch.pressed and touch.index == _index:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _index:
			touch_moved.emit(drag.position)


func _notification(what: int) -> void:
	# Perdeu o foco (notificação, troca de app): considera o dedo solto
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_touching():
		_release()


func _release() -> void:
	_index = NO_TOUCH
	touch_ended.emit()
