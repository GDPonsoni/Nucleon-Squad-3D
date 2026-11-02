class_name ReviveOffer
extends CanvasLayer
## Oferta após perder a partida: continuar assistindo a um anúncio, por tempo limitado.
## Emite closed(true) se o jogador aceitar; closed(false) se recusar ou o tempo acabar.

signal closed(accepted: bool)

var _overlay: ColorRect
var _watch_button: Button
var _countdown: Label
var _time_left: float = 0.0
var _open: bool = false


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_overlay = UiFactory.make_overlay()
	_overlay.visible = false
	add_child(_overlay)

	var column := UiFactory.make_column()
	_overlay.add_child(UiFactory.make_centered(UiFactory.make_panel(column)))
	column.add_child(UiFactory.make_title("REVIVE_TITLE"))
	var info := UiFactory.make_subtitle("REVIVE_INFO")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = Params.button_min_size.x
	column.add_child(info)

	_countdown = UiFactory.make_title("")
	_countdown.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_countdown.add_theme_color_override("font_color", Params.powerup_color)
	column.add_child(_countdown)

	_watch_button = UiFactory.make_button("REVIVE_WATCH")
	_watch_button.pressed.connect(_close.bind(true))
	column.add_child(_watch_button)

	var skip_button := UiFactory.make_button("REVIVE_SKIP")
	skip_button.pressed.connect(_close.bind(false))
	column.add_child(skip_button)


func open() -> void:
	get_tree().paused = true
	_time_left = Params.revive_offer_seconds
	_open = true
	_overlay.visible = true
	_update_countdown()


func _process(delta: float) -> void:
	if not _open:
		return
	# Tempo real: o delta escala com a câmera lenta, que pode estar ativa ao perder
	_time_left -= delta / maxf(Engine.time_scale, 0.01)
	_update_countdown()
	if _time_left <= 0.0:
		_close(false)


func _update_countdown() -> void:
	_countdown.text = str(ceili(maxf(_time_left, 0.0)))


func _close(accepted: bool) -> void:
	if not _open:
		return
	_open = false
	_overlay.visible = false
	closed.emit(accepted)


func _notification(what: int) -> void:
	# Botão Voltar do Android recusa a oferta
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _open:
		_close(false)
