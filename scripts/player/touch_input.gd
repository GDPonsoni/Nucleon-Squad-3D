class_name TouchInput
extends Node
## Acompanha um único dedo (o primeiro que tocar) e emite sinais.
## No PC, o mouse chega como toque via emulate_touch_from_mouse.
##
## Toques que começam numa área de toque curto (tap_filter, ex.: a barra de troca de nave)
## ficam pendentes: se o dedo sair logo e sem andar, viram um toque (tapped) e o jogo
## não percebe o dedo; se o dedo andar ou demorar, viram um arraste normal (touch_started).
## Assim, apoiar o polegar na barra para voltar a mover a nave não troca de nave sem querer.

signal touch_started(pos: Vector2)
signal touch_moved(pos: Vector2)
signal touch_ended
## Toque curto confirmado (pos = onde o dedo encostou).
signal tapped(pos: Vector2)
## Toque curto começou (pending = true) ou deixou de ser candidato (false).
signal tap_pending_changed(pos: Vector2, pending: bool)

const NO_TOUCH: int = -1

## (pos: Vector2) -> bool. true = um toque nessa posição pode ser um toque curto.
var tap_filter: Callable

var _index: int = NO_TOUCH
var _pending: bool = false
var _pending_start := Vector2.ZERO
var _pending_usec: int = 0


## Dedo na tela movendo a nave (toques curtos pendentes não contam).
func is_touching() -> bool:
	return _index != NO_TOUCH and not _pending


func _process(_delta: float) -> void:
	# Tempo real: na câmera lenta o limite do toque curto não se estende
	if _pending and (Time.get_ticks_usec() - _pending_usec) / 1_000_000.0 > Params.tap_max_seconds:
		_promote()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _index == NO_TOUCH:
			# Consulta o filtro antes de registrar o dedo: com o dedo registrado, a barra
			# de troca se considera "em jogo" e recusaria todo toque curto
			var tap: bool = tap_filter.is_valid() and tap_filter.call(touch.position)
			_index = touch.index
			if tap:
				_pending = true
				_pending_start = touch.position
				_pending_usec = Time.get_ticks_usec()
				tap_pending_changed.emit(_pending_start, true)
			else:
				touch_started.emit(touch.position)
		elif not touch.pressed and touch.index == _index:
			if _pending:
				_pending = false
				_index = NO_TOUCH
				tap_pending_changed.emit(_pending_start, false)
				tapped.emit(_pending_start)
			else:
				_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _index:
			return
		if _pending:
			if drag.position.distance_to(_pending_start) > Params.tap_move_tolerance:
				_promote()
				touch_moved.emit(drag.position)
		else:
			touch_moved.emit(drag.position)


func _notification(what: int) -> void:
	# Perdeu o foco ou o jogo pausou: considera o dedo solto (e cancela o toque curto)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		if _pending:
			_pending = false
			_index = NO_TOUCH
			tap_pending_changed.emit(_pending_start, false)
		elif is_touching():
			_release()


## O toque curto virou arraste: a partir de agora é um dedo normal na tela.
func _promote() -> void:
	_pending = false
	tap_pending_changed.emit(_pending_start, false)
	touch_started.emit(_pending_start)


func _release() -> void:
	_index = NO_TOUCH
	touch_ended.emit()
