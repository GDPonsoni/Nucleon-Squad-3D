class_name LevelUpMenu
extends Dialog
## Tela de subir de nível do modo roguelike: pausa o jogo e mostra as opções sorteadas
## (arma nova, subir uma arma ou quarks) e os espaços de arma. Sem X: é preciso escolher.

signal chosen(choice: RunChoice)

var progress: RunProgress
var choices: Array[RunChoice] = []
var first_pick: bool = false  # início da partida: "escolha sua arma"


static func open_choices(parent: Node, run_progress: RunProgress, options: Array[RunChoice], is_first: bool) -> LevelUpMenu:
	var dialog := LevelUpMenu.new()
	dialog.progress = run_progress
	dialog.choices = options
	dialog.first_pick = is_first
	dialog.title_key = "RUN_FIRST_PICK" if is_first else "RUN_LEVEL_UP"
	dialog.closable = false
	parent.add_child(dialog)
	return dialog


func _build_body() -> void:
	back_handler = func() -> void: pass  # Voltar não fecha: a escolha é obrigatória
	if not first_pick:
		var level := UiFactory.make_subtitle("")
		level.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		level.text = tr("RUN_LEVEL") % progress.level
		level.add_theme_color_override("font_color", Params.run_xp_color)
		body.add_child(level)
	body.add_child(RunLoadoutView.build(progress))
	for choice in choices:
		body.add_child(_card(choice))


func _card(choice: RunChoice) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, Params.run_card_height)
	card.pressed.connect(func() -> void:
		Audio.play(&"ui_confirm")
		chosen.emit(choice)
		close())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24.0
	row.offset_right = -24.0
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var icon := ShipIcon.new()
	icon.custom_minimum_size = Vector2.ONE * Params.run_card_icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.body = choice.body
	row.add_child(icon)
	if choice.kind == RunChoice.Kind.QUARKS:
		icon.visible = false
		var quark := Control.new()
		quark.custom_minimum_size = Vector2.ONE * Params.run_card_icon_size
		quark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quark.draw.connect(func() -> void:
			UiFactory.draw_quark_icon(quark, quark.size * 0.5, Params.run_card_icon_size * 0.3))
		row.add_child(quark)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title := Label.new()
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.add_theme_font_size_override("font_size", Params.run_card_font_size)
	var detail := Label.new()
	detail.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	detail.add_theme_font_size_override("font_size", Params.run_card_detail_font_size)
	match choice.kind:
		RunChoice.Kind.NEW_WEAPON:
			title.text = tr(choice.body.name_key)
			title.add_theme_color_override("font_color", choice.body.color)
			detail.text = tr("RUN_NEW_WEAPON")
		RunChoice.Kind.UPGRADE:
			title.text = tr(choice.body.name_key)
			title.add_theme_color_override("font_color", choice.body.color)
			detail.text = tr("RUN_WEAPON_LEVEL") % [choice.to_level - 1, choice.to_level]
		RunChoice.Kind.QUARKS:
			title.text = "+%d" % choice.quarks
			title.add_theme_color_override("font_color", Params.quark_color)
			detail.text = tr("RUN_QUARKS_REWARD")
	texts.add_child(title)
	texts.add_child(detail)
	return card
