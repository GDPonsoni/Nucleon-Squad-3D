extends Node
## Autoload: anúncios com recompensa. Ainda sem SDK: simula o anúncio com uma tela
## por alguns segundos e concede a recompensa. Para integrar o AdMob (Marco 3),
## troque o corpo de is_rewarded_available() e show_rewarded() pelas chamadas do plugin,
## mantendo o sinal rewarded_finished.

## Fim do anúncio: granted = o jogador assistiu até o fim e ganha a recompensa.
signal rewarded_finished(granted: bool)

var _busy: bool = false


func is_rewarded_available() -> bool:
	return not _busy


## Mostra o anúncio. Quem chamou deve aguardar rewarded_finished.
func show_rewarded() -> void:
	if _busy:
		return
	_busy = true
	var layer := CanvasLayer.new()
	layer.layer = 150  # acima de tudo, abaixo da transição de tela
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := UiFactory.make_overlay()
	overlay.color = Params.ad_placeholder_color
	layer.add_child(overlay)
	var column := UiFactory.make_column()
	overlay.add_child(UiFactory.make_centered(column))
	column.add_child(UiFactory.make_title("AD_PLACEHOLDER"))
	var info := UiFactory.make_subtitle("AD_PLACEHOLDER_INFO")
	column.add_child(info)
	add_child(layer)

	# Funciona com o jogo pausado e ignora a câmera lenta
	await get_tree().create_timer(Params.ad_simulated_seconds, true, false, true).timeout
	layer.queue_free()
	_busy = false
	rewarded_finished.emit(true)
