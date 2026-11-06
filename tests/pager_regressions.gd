extends Node
## Ver pager_regressions_run.gd. Sai com código 1 se algum caso falhar.

var _failures: int = 0
var _scene: Node
var _pager: PagedView


func _ready() -> void:
	SaveGame.persistent = false
	SaveGame.unlock_everything = true
	Session.browsed_chapter = 1
	_scene = (load("res://scenes/stage_select.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_scene)
	await _wait(0.6)
	_pager = _scene.get("_pager")
	var width: float = _pager.size.x
	var y: float = 900.0  # sobre a arte do capítulo
	_expect(_pager.current == 1, "abre no capítulo salvo")

	# Arrasto curto e lento, solta: volta para a mesma página
	await _swipe(width * 0.5, y, -width * 0.2, 0.6)
	await _wait(0.5)
	_expect(_pager.current == 1, "arrasto curto e lento mantém a página")

	# Arrasto longo e lento para a esquerda: próxima página
	await _swipe(width * 0.8, y, -width * 0.6, 0.8)
	await _wait(0.5)
	_expect(_pager.current == 2, "arrasto longo avança (cap %d)" % _pager.current)

	# Gesto rápido e curto para a direita: página anterior
	await _swipe(width * 0.3, y, width * 0.18, 0.08)
	await _wait(0.5)
	_expect(_pager.current == 1, "gesto rápido recua (cap %d)" % _pager.current)

	# Ida e volta no mesmo gesto: cancelável
	await _send_touch(width * 0.5, y, true)
	for i in 6:
		await _send_drag(width * 0.5 - (i + 1) * 80.0, y)
	var mid: float = (_pager.get("_offset") as float)
	_expect(mid < -width * 0.2, "página acompanha o dedo (offset %.0f)" % mid)
	var neighbor: Control = (_pager.get("_pages") as Dictionary).get(2)
	_expect(neighbor != null and neighbor.position.x < width, "página seguinte aparece durante o arrasto")
	for i in 6:
		await _send_drag(width * 0.5 - (5 - i) * 80.0, y)
	await _send_touch(width * 0.5, y, false)
	await _wait(0.5)
	_expect(_pager.current == 1, "voltar o dedo e soltar cancela")

	# Arrasto começando em cima de um botão de fase não dispara a fase
	var button: Button = _find_stage_button()
	var started: bool = false
	if button != null:
		var at: Vector2 = button.get_global_rect().get_center()
		Session.stage_index = -7
		await _send_touch(at.x, at.y, true)
		for i in 8:
			await _send_drag(at.x - (i + 1) * 60.0, at.y)
		await _send_touch(at.x - 480.0, at.y, false)
		await _wait(0.5)
		started = Session.stage_index != -7
	_expect(not started, "arrastar de cima de um botão não o aciona")

	# Toque simples no botão continua funcionando e não mexe a página
	var page_before: int = _pager.current
	button = _find_stage_button()
	if button != null:
		var at2: Vector2 = button.get_global_rect().get_center()
		Session.stage_index = -7
		await _send_touch(at2.x, at2.y, true)
		await _send_touch(at2.x, at2.y, false)
		await _wait(0.3)
		_expect(Session.stage_index != -7, "toque simples no botão aciona a fase")
		_expect(_pager.current == page_before, "toque simples não muda de página")
	else:
		_expect(false, "botão de fase encontrado")
	print("pager_regressions: %d falhas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _find_stage_button() -> Button:
	var page: Control = _pager.current_page()
	for node in page.find_children("*", "Button", true, false):
		var b := node as Button
		if not b.disabled and b.get_global_rect().position.y > 1000.0 and b.get_global_rect().size.x > 100.0:
			return b
	return null


func _expect(ok: bool, label: String) -> void:
	if not ok:
		printerr("FALHOU: %s" % label)
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Dedo em (x0, y) anda dx em `seconds` (tempo real), em passos.
func _swipe(x0: float, y: float, dx: float, seconds: float) -> void:
	await _send_touch(x0, y, true)
	var steps: int = 10
	for i in steps:
		await _wait(seconds / steps)
		await _send_drag(x0 + dx * (i + 1) / steps, y)
	await _send_touch(x0 + dx, y, false)


func _send_touch(x: float, y: float, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(x, y)
	touch.pressed = pressed
	Input.parse_input_event(touch)
	await get_tree().process_frame


func _send_drag(x: float, y: float) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(x, y)
	Input.parse_input_event(drag)
	await get_tree().process_frame
