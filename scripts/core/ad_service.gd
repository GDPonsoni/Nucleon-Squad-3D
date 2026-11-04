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


## Altura reservada para o banner, em pixels da tela do jogo: banner_height_dp em dp
## (cabe o banner padrão de 50 dp e o adaptativo do AdMob, de até ~90 dp).
func banner_height(viewport_width: float) -> float:
	var screen_width: float = float(DisplayServer.screen_get_size().x)
	var dpi: float = float(DisplayServer.screen_get_dpi())
	if screen_width <= 0.0 or dpi <= 0.0 or OS.get_name() != "Android":
		dpi = Params.banner_fallback_dpi
		screen_width = viewport_width
	var px_per_dp: float = dpi / 160.0
	return Params.banner_height_dp * px_per_dp * viewport_width / screen_width


## Espaço do banner (simulado): retângulo marcando onde o banner real vai ficar.
## Com o SDK, troque por um nó que exibe o banner do AdMob na mesma área.
func make_banner_placeholder() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.border_color = Color(Params.ui_muted_text_color, 0.4)
	style.border_width_top = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiFactory.make_subtitle("BANNER_PLACEHOLDER")
	label.add_theme_font_size_override("font_size", Params.results_detail_font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


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
