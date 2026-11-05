class_name ReviveOffer
extends CanvasLayer
## Oferta após perder a partida: continuar assistindo a um anúncio, por tempo limitado.
## Emite closed(true) se o jogador aceitar; closed(false) se recusar (botão, X, Voltar) ou o tempo acabar.
## Fechar sem aceitar só gasta a chance de continuar; nenhuma recompensa fica pendente.

signal closed(accepted: bool)

var _dialog: Dialog
var _countdown: Label
var _time_left: float = 0.0
var _open: bool = false


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	get_tree().paused = true
	_time_left = Params.revive_offer_seconds
	_open = true
	_dialog = Dialog.open(self, "REVIVE_TITLE", true, 60)
	# X e Voltar recusam
	_dialog.closed.connect(_on_dialog_closed)
	_dialog.body.add_child(UiFactory.make_subtitle("REVIVE_INFO"))

	_countdown = UiFactory.make_title("")
	_countdown.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_countdown.add_theme_color_override("font_color", Params.powerup_color)
	_dialog.body.add_child(_countdown)

	var watch_button := UiFactory.make_button("REVIVE_WATCH")
	watch_button.pressed.connect(_close.bind(true))
	_dialog.body.add_child(watch_button)

	var skip_button := UiFactory.make_button("REVIVE_SKIP")
	skip_button.pressed.connect(_close.bind(false))
	_dialog.body.add_child(skip_button)
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
	if is_instance_valid(_dialog):
		_dialog.closed.disconnect(_on_dialog_closed)
		_dialog.close()
	closed.emit(accepted)


func _on_dialog_closed() -> void:
	_close(false)
