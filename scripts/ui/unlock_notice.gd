class_name UnlockNotice
extends Dialog
## Aviso curto de desbloqueio (nave, nave auxiliar, planeta): parabéns e o que mudou.
## notice: {"text": String já traduzido, "body": BodyData ou null}

var notice: Dictionary = {}


static func open_notice(parent: Node, data: Dictionary) -> UnlockNotice:
	var dialog := UnlockNotice.new()
	dialog.notice = data
	dialog.title_key = "UNLOCK_TITLE"
	parent.add_child(dialog)
	return dialog


func _build_body() -> void:
	var body_data: BodyData = notice.get("body")
	if body_data != null:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := ShipIcon.new()
		icon.custom_minimum_size = Vector2.ONE * Params.unlock_icon_size
		icon.body = body_data
		row.add_child(icon)
		body.add_child(row)
	var text := UiFactory.make_subtitle("")
	text.text = String(notice["text"])
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var ok := UiFactory.make_primary_button("UNLOCK_OK")
	ok.pressed.connect(close)
	body.add_child(ok)
