class_name TipDialog
extends Dialog
## Dica do tutorial numa janela (telas e fim de fase). O X e "Pular" fecham; "Não mostrar mais"
## desliga todas as dicas. A dica já foi marcada como vista ao abrir.

var tip: Dictionary = {}


static func open_tip(parent: Node, tip_data: Dictionary) -> TipDialog:
	var dialog := TipDialog.new()
	dialog.tip = tip_data
	dialog.title_key = "TIP_TITLE"
	parent.add_child(dialog)
	return dialog


func _build_body() -> void:
	var text := UiFactory.make_subtitle(String(tip["text_key"]))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var skip := UiFactory.make_primary_button("TIP_SKIP")
	skip.pressed.connect(close)
	body.add_child(skip)
	var never := UiFactory.make_button("TIP_DISABLE")
	never.pressed.connect(func() -> void:
		Tutorial.disable_tips()
		close())
	body.add_child(never)
