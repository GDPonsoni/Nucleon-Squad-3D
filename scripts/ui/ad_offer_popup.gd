class_name AdOfferPopup
extends CanvasLayer
## Janela "Ganhar quarks": saldo, botão para ver anúncio (até o limite do dia) e fechar.
## Abre ao tocar no saldo de quarks e quando falta saldo para uma compra (com aviso).
## Funciona com o jogo pausado.

signal closed
## Ganhou quarks com um anúncio (quem abriu pode atualizar a tela).
signal quarks_changed

var message: String = ""  # aviso opcional no topo (ex.: saldo insuficiente)

var _badge: QuarkBadge
var _ad_button: Button
var _info: Label


## Abre a janela por cima da tela atual.
static func open(parent: Node, warning: String = "") -> AdOfferPopup:
	var popup := AdOfferPopup.new()
	popup.message = warning
	parent.add_child(popup)
	return popup


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := UiFactory.make_overlay()
	add_child(overlay)
	var column := UiFactory.make_column()
	column.add_theme_constant_override("separation", Params.upgrade_spacing)
	var center := UiFactory.make_centered(UiFactory.make_panel(column))
	overlay.add_child(center)
	column.add_child(UiFactory.make_title("ADS_EARN_TITLE"))
	if not message.is_empty():
		var warning := Label.new()
		warning.text = message
		warning.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.custom_minimum_size.x = Params.ad_popup_width
		warning.add_theme_color_override("font_color", Params.hud_warning_color)
		warning.add_theme_font_size_override("font_size", Params.subtitle_font_size)
		column.add_child(warning)
	var hint := UiFactory.make_subtitle("ADS_EARN_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = Params.ad_popup_width
	column.add_child(hint)
	var badge_row := CenterContainer.new()
	column.add_child(badge_row)
	_badge = QuarkBadge.new()
	_badge.interactive = false
	badge_row.add_child(_badge)
	_ad_button = UiFactory.make_primary_button("")
	_ad_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ad_button.custom_minimum_size.x = Params.ad_popup_width
	_ad_button.pressed.connect(_on_ad_pressed)
	column.add_child(_ad_button)
	_info = UiFactory.make_subtitle("")
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_info)
	var close := UiFactory.make_button("MENU_BACK")
	close.custom_minimum_size.x = Params.ad_popup_width
	close.pressed.connect(_close)
	column.add_child(close)
	UiFactory.animate_in(center)
	_refresh()


func _refresh() -> void:
	var left: int = SaveGame.ads_left_today()
	_ad_button.text = tr("ADS_EARN_BUTTON") % SaveGame.ad_quark_reward()
	_ad_button.disabled = left <= 0 or not AdService.is_rewarded_available()
	_info.text = (tr("ADS_EARN_LEFT") % [left, Params.ad_quarks_daily_limit]) if left > 0 else tr("ADS_EARN_DONE")


func _on_ad_pressed() -> void:
	if SaveGame.ads_left_today() <= 0 or not AdService.is_rewarded_available():
		return
	_ad_button.disabled = true
	AdService.show_rewarded()
	var granted: bool = await AdService.rewarded_finished
	if granted:
		SaveGame.grant_ad_quarks()
		Audio.play(&"powerup_pickup")
		Audio.vibrate(Params.haptic_level_up_ms)
		_badge.set_amount(SaveGame.quarks, true)
		quarks_changed.emit()
	_refresh()


func _close() -> void:
	closed.emit()
	queue_free()


func _notification(what: int) -> void:
	# Botão Voltar do Android fecha a janela
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()
