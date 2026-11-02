class_name TimeController
extends Node
## Câmera lenta: dedo solto -> time scale lento; tocar -> volta a 1.0.
## A transição usa tempo real (o delta do _process já vem escalado).

const NORMAL_TIME_SCALE: float = 1.0

var _target: float = NORMAL_TIME_SCALE
var _last_usec: int = 0


func _ready() -> void:
	_last_usec = Time.get_ticks_usec()


func bind_input(touch: TouchInput) -> void:
	touch.touch_started.connect(_on_touch_started)
	touch.touch_ended.connect(_on_touch_ended)
	# Começa sem dedo na tela: já em câmera lenta
	_target = NORMAL_TIME_SCALE if touch.is_touching() else Params.slow_time_scale
	Engine.time_scale = _target


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_delta: float = (now - _last_usec) / 1_000_000.0
	_last_usec = now
	var rate: float = (NORMAL_TIME_SCALE - Params.slow_time_scale) / Params.time_scale_smooth_seconds
	Engine.time_scale = move_toward(Engine.time_scale, _target, rate * real_delta)


func _exit_tree() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE


func _on_touch_started(_pos: Vector2) -> void:
	_target = NORMAL_TIME_SCALE


func _on_touch_ended() -> void:
	_target = Params.slow_time_scale
