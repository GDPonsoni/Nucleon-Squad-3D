class_name PagedView
extends Control
## Paginação lateral reutilizável. A página acompanha o dedo, a vizinha aparece durante o
## arrasto e, ao soltar, encaixa na página mais próxima ou na do sentido do gesto rápido.
## Só a página atual existe em repouso; as vizinhas são montadas ao começar o arrasto.
##
## Conflito com botões: o arrasto só começa depois de pager_slop px na horizontal. Ao começar,
## qualquer botão pressionado na página é cancelado (não dispara ao soltar). Toques e
## deslizes verticais passam intactos para a página (botões, rolagem).
## Gesto cancelável: voltar o dedo ao ponto inicial (ou ao meio) e soltar mantém a página.

## A página mudou (depois do encaixe).
signal page_changed(index: int)

enum State { IDLE, PRESSED, DRAGGING, SETTLING }

var current: int = 0
var count: int = 0

var _builder: Callable  # (index: int) -> Control
var _pages: Dictionary = {}  # índice -> página montada
var _offset: float = 0.0  # px: deslocamento de todas as páginas em relação ao repouso
var _state: State = State.IDLE
var _finger: int = -1
var _start := Vector2.ZERO
var _origin_offset: float = 0.0
var _velocity: float = 0.0  # px/s, suavizada
var _last_x: float = 0.0
var _last_usec: int = 0
var _tween: Tween


func setup(page_count: int, builder: Callable, start: int = 0) -> void:
	count = page_count
	_builder = builder
	current = clampi(start, 0, count - 1)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()


## Monta a página atual de novo (ex.: o progresso mudou).
func refresh() -> void:
	_free_pages()
	_offset = 0.0
	_ensure_page(current)
	_layout()


func current_page() -> Control:
	return _pages.get(current)


## Vai para a página (animado). Fora do intervalo, ignora.
func go_to(index: int) -> void:
	if index < 0 or index >= count or index == current or _state == State.DRAGGING:
		return
	_stop_tween()
	_ensure_page(index)
	_snap_to(index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _input(event: InputEvent) -> void:
	if count <= 1 or not is_visible_in_tree() or Dialog.is_open():
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_down(touch)
		elif touch.index == _finger:
			_on_up(touch.canceled)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _finger:
		_on_move(drag)


func _on_down(touch: InputEventScreenTouch) -> void:
	if _finger != -1 or not get_global_rect().has_point(touch.position):
		return
	_finger = touch.index
	_start = touch.position
	_last_x = touch.position.x
	_last_usec = Time.get_ticks_usec()
	_velocity = 0.0
	# Tocar durante o encaixe: segura a página onde ela está e continua dali
	if _state == State.SETTLING:
		_stop_tween()
		_origin_offset = _offset
		_begin_drag()
		return
	_origin_offset = _offset
	_state = State.PRESSED


func _on_move(drag: InputEventScreenDrag) -> void:
	var delta: Vector2 = drag.position - _start
	if _state == State.PRESSED:
		if absf(delta.x) < Params.pager_slop and absf(delta.y) < Params.pager_slop:
			return
		if absf(delta.x) > absf(delta.y) * Params.pager_horizontal_bias:
			_begin_drag()
		else:
			# Gesto vertical: a página trata (rolagem, botões); o pager desiste
			_finger = -1
			_state = State.IDLE
			return
	if _state != State.DRAGGING:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = maxf((now - _last_usec) / 1_000_000.0, 0.001)
	_velocity = lerpf(_velocity, (drag.position.x - _last_x) / dt, Params.pager_velocity_smoothing)
	_last_x = drag.position.x
	_last_usec = now
	_offset = _rubber(_origin_offset + delta.x)
	_layout()


func _on_up(canceled: bool) -> void:
	_finger = -1
	if _state == State.PRESSED:
		_state = State.IDLE
		return
	if _state != State.DRAGGING:
		return
	var target: int = current
	if not canceled:
		var width: float = maxf(size.x, 1.0)
		var direction: int = 0  # +1 = página seguinte (arrasto para a esquerda), -1 = anterior
		var fast: bool = absf(_velocity) > Params.pager_flick_velocity
		if fast:
			# Gesto rápido no sentido do arrasto muda de página; no sentido contrário, cancela
			if signf(_velocity) == signf(_offset) and absf(_offset) > Params.pager_flick_min_distance:
				direction = -1 if _velocity > 0.0 else 1
		elif absf(_offset) > width * Params.pager_snap_ratio:
			direction = -1 if _offset > 0.0 else 1
		target = clampi(current + direction, 0, count - 1)
	_snap_to(target)


## Dedo passou do limite: monta as vizinhas e cancela o que o dedo apertou na página.
func _begin_drag() -> void:
	_state = State.DRAGGING
	_ensure_page(current - 1)
	_ensure_page(current + 1)
	_cancel_pressed_buttons()
	_layout()


func _cancel_pressed_buttons() -> void:
	var page: Control = _pages.get(current)
	if page == null:
		return
	for node in page.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var mode: int = button.get_draw_mode()
		if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED:
			# Desativar limpa o estado de "pressionado" sem disparar o botão
			var was_disabled: bool = button.disabled
			button.disabled = true
			button.disabled = was_disabled


## Fora do intervalo de páginas o arrasto fica "elástico".
func _rubber(raw: float) -> float:
	var past_start: bool = current == 0 and raw > 0.0
	var past_end: bool = current == count - 1 and raw < 0.0
	return raw * Params.pager_edge_resistance if past_start or past_end else raw


func _snap_to(index: int) -> void:
	_state = State.SETTLING
	var width: float = size.x
	var goal: float = -(index - current) * width
	_stop_tween()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Gesto rápido termina mais depressa
	var seconds: float = Params.pager_snap_seconds
	if absf(_velocity) > Params.pager_flick_velocity:
		seconds *= Params.pager_flick_snap_scale
	_tween.tween_method(_set_offset, _offset, goal, seconds)
	_tween.tween_callback(_settled.bind(index))


func _set_offset(value: float) -> void:
	_offset = value
	_layout()


func _settled(index: int) -> void:
	var changed: bool = index != current
	current = index
	_offset = 0.0
	_state = State.IDLE
	_velocity = 0.0
	_prune()
	_layout()
	if changed:
		Haptics.play(&"tick")
		page_changed.emit(current)


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _ensure_page(index: int) -> void:
	if index < 0 or index >= count or _pages.has(index):
		return
	var page: Control = _builder.call(index)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.size = size
	add_child(page)
	_pages[index] = page


## Só a página atual fica montada em repouso.
func _prune() -> void:
	for index in _pages.keys():
		if index != current:
			(_pages[index] as Control).queue_free()
			_pages.erase(index)


func _free_pages() -> void:
	for page: Control in _pages.values():
		page.queue_free()
	_pages.clear()


func _layout() -> void:
	for index in _pages:
		var page := _pages[index] as Control
		page.size = size
		page.position = Vector2((index - current) * size.x + _offset, 0.0)
