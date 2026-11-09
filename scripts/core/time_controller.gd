class_name TimeController
extends Node
## Câmera lenta: dedo solto -> time scale lento; tocar -> volta a 1.0.
## A transição usa tempo real (o delta do _process já vem escalado).
## Custo: a câmera lenta voluntária gasta energia (tempo real) e o dedo na tela recarrega.
## Sem energia, o jogo volta à velocidade normal até o próximo toque. A câmera lenta forçada
## (corpo destruído) e a do começo da fase (antes do primeiro toque) não gastam.

## Câmera lenta voluntária começou ou acabou (as armas seguram o tiro nela).
signal voluntary_slow_changed(slow: bool)

const NORMAL_TIME_SCALE: float = 1.0

## Corpo destruído: fica em câmera lenta até escolher outro, mesmo com o dedo na tela.
var forced_slow: bool = false:
	set(value):
		forced_slow = value
		var idle_slow: bool = not _touch.is_touching() and _has_energy()
		_target = Params.slow_time_scale if value or idle_slow else NORMAL_TIME_SCALE
		_update_voluntary()

## Fim de fase: velocidade normal travada, o dedo não muda mais a câmera lenta.
var locked_normal: bool = false

## Energia da câmera lenta, de 0 a 1.
var energy: float = 1.0

var _target: float = NORMAL_TIME_SCALE
var _last_usec: int = 0
var _touch: TouchInput
var _touched_once: bool = false
var _voluntary: bool = false


func _ready() -> void:
	_last_usec = Time.get_ticks_usec()


func bind_input(touch: TouchInput) -> void:
	_touch = touch
	touch.touch_started.connect(_on_touch_started)
	touch.touch_ended.connect(_on_touch_ended)
	# Começa sem dedo na tela: já em câmera lenta
	_target = NORMAL_TIME_SCALE if touch.is_touching() else Params.slow_time_scale
	Engine.time_scale = _target


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_delta: float = minf((now - _last_usec) / 1_000_000.0, Params.slowmo_max_frame_seconds)
	_last_usec = now
	_update_energy(real_delta)
	var rate: float = (NORMAL_TIME_SCALE - Params.slow_time_scale) / Params.time_scale_smooth_seconds
	Engine.time_scale = move_toward(Engine.time_scale, _target, rate * real_delta)


func _exit_tree() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE


func lock_normal() -> void:
	locked_normal = true
	_target = NORMAL_TIME_SCALE
	_update_voluntary()


## Câmera lenta escolhida pelo jogador (dedo solto), não a forçada nem a do início da fase.
func is_voluntary_slow() -> bool:
	return _voluntary


func _has_energy() -> bool:
	return energy >= Params.slowmo_min_energy


func _update_energy(real_delta: float) -> void:
	if locked_normal or forced_slow:
		return
	if _voluntary:
		energy = maxf(energy - real_delta / Params.slowmo_energy_seconds, 0.0)
		if energy <= 0.0:
			# Acabou: volta ao normal até o dedo tocar de novo
			Audio.play(&"slowmo_exit")
			_target = NORMAL_TIME_SCALE
			_update_voluntary()
	elif _touch != null and _touch.is_touching():
		energy = minf(energy + real_delta / Params.slowmo_recharge_seconds, 1.0)


func _update_voluntary() -> void:
	var slow: bool = _touched_once and not forced_slow and not locked_normal and _target < NORMAL_TIME_SCALE
	if slow != _voluntary:
		_voluntary = slow
		voluntary_slow_changed.emit(slow)


func _on_touch_started(_pos: Vector2) -> void:
	if locked_normal:
		return
	_touched_once = true
	if not forced_slow:
		if _target < NORMAL_TIME_SCALE:
			Audio.play(&"slowmo_exit")
		_target = NORMAL_TIME_SCALE
	_update_voluntary()


func _on_touch_ended() -> void:
	if locked_normal:
		return
	if not forced_slow and not _has_energy():
		return  # sem energia: segue na velocidade normal
	if _target >= NORMAL_TIME_SCALE:
		Audio.play(&"slowmo_enter")
	_target = Params.slow_time_scale
	_update_voluntary()
