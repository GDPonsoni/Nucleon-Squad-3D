class_name AdOfferPopup
extends Dialog
## Janela "Ganhar quarks": saldo, botão para ver anúncio (até o limite do dia) e fechar (X / Voltar).
## Abre ao tocar no saldo de quarks e quando falta saldo para uma compra (com aviso).
## Não fecha enquanto o anúncio roda, para a recompensa não se perder.

## Ganhou quarks com um anúncio (quem abriu pode atualizar a tela).
signal quarks_changed

var message: String = ""  # aviso opcional no topo (ex.: saldo insuficiente)

var _badge: QuarkBadge
var _ad_button: Button
var _info: Label


## Abre a janela por cima da tela atual.
static func open_offer(parent: Node, warning: String = "") -> AdOfferPopup:
	var popup := AdOfferPopup.new()
	popup.message = warning
	popup.title_key = "ADS_EARN_TITLE"
	popup.dialog_layer = 120
	parent.add_child(popup)
	return popup


func _build_body() -> void:
	if not message.is_empty():
		var warning := Label.new()
		warning.text = message
		warning.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning.add_theme_color_override("font_color", Params.hud_warning_color)
		warning.add_theme_font_size_override("font_size", Params.subtitle_font_size)
		body.add_child(warning)
	body.add_child(UiFactory.make_subtitle("ADS_EARN_HINT"))
	var badge_row := CenterContainer.new()
	body.add_child(badge_row)
	_badge = QuarkBadge.new()
	_badge.interactive = false
	badge_row.add_child(_badge)
	_ad_button = UiFactory.make_primary_button("")
	_ad_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ad_button.pressed.connect(_on_ad_pressed)
	body.add_child(_ad_button)
	_info = UiFactory.make_subtitle("")
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.add_child(_info)
	_refresh()


func _refresh() -> void:
	var left: int = SaveGame.ads_left_today()
	_ad_button.text = tr("ADS_EARN_BUTTON") % SaveGame.ad_quark_reward()
	UiFactory.fit_button_text(_ad_button, content_width)
	_ad_button.disabled = left <= 0 or not AdService.is_rewarded_available()
	_info.text = (tr("ADS_EARN_LEFT") % [left, Params.ad_quarks_daily_limit]) if left > 0 else tr("ADS_EARN_DONE")


func _on_ad_pressed() -> void:
	if SaveGame.ads_left_today() <= 0 or not AdService.is_rewarded_available():
		return
	_ad_button.disabled = true
	# Fechar agora perderia a recompensa: X e Voltar ficam bloqueados até o anúncio acabar
	close_blocked = true
	AdService.show_rewarded()
	var granted: bool = await AdService.rewarded_finished
	if granted:
		SaveGame.grant_ad_quarks()
		Audio.play(&"powerup_pickup")
		Audio.vibrate(Params.haptic_level_up_ms)
		_badge.set_amount(SaveGame.quarks, true)
		quarks_changed.emit()
	close_blocked = false
	_refresh()
