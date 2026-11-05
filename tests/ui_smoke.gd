extends Node
## Teste de fumaça: abre cada tela e a partida por alguns quadros e acusa erros de script.
## Uso: godot --headless --path . -s res://tests/ui_smoke_run.gd
## Erros de script aparecem como "SCRIPT ERROR" na saída; o teste só avisa se algo falhou ao carregar.

const SCENES: PackedStringArray = [
	"res://scenes/menu.tscn", "res://scenes/settings.tscn", "res://scenes/stage_select.tscn",
	"res://scenes/squad.tscn", "res://scenes/upgrades.tscn", "res://scenes/game.tscn",
]


func _ready() -> void:
	SaveGame.persistent = false
	SaveGame.unlock_everything = true
	var failures: int = 0
	var overflow: int = 0
	for path in SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			printerr("FALHOU ao carregar ", path)
			failures += 1
			continue
		# Cada tela também em inglês, para pegar textos quebrados
		for language in ["pt_BR", "en", "es"]:
			SaveGame.settings["language"] = language
			Audio.apply_settings()
			printerr("[smoke] %s %s" % [path, language])
			var scene: Node = packed.instantiate()
			get_tree().root.add_child(scene)
			# Espera em tempo real: as animações de entrada duram ~0,45 s
			await get_tree().create_timer(0.8, true, false, true).timeout
			overflow += _check_overflow(scene, "%s %s" % [path.get_file(), language])
			if scene.has_method("_finish_stage_clear"):
				var pause: PauseMenu = scene.get("pause_menu")
				pause.open()
				await get_tree().create_timer(0.8, true, false, true).timeout
				overflow += _check_overflow(pause, "pausa %s" % language)
				pause.call("_open_settings")
				await get_tree().create_timer(0.8, true, false, true).timeout
				overflow += _check_overflow(pause, "configurações na pausa %s" % language)
				pause.close()
				scene.call("_finish_stage_clear")
				await get_tree().create_timer(0.8, true, false, true).timeout
				overflow += _check_overflow(scene.get("results_menu"), "resultado %s" % language)
				get_tree().paused = false
			# Janela de ganhar quarks pelo selo do saldo
			for badge in scene.find_children("*", "QuarkBadge", true, false):
				if (badge as QuarkBadge).interactive:
					badge.emit_signal("pressed")
					await get_tree().create_timer(0.6, true, false, true).timeout
					for popup in scene.find_children("*", "AdOfferPopup", true, false):
						overflow += _check_overflow(popup, "ganhar quarks %s %s" % [path.get_file(), language])
						popup.queue_free()
			# Compra sem saldo: aviso e janela de anúncios
			if scene.has_method("_on_buy_pressed"):
				var saved_quarks: int = SaveGame.quarks
				SaveGame.quarks = 0
				scene.call("_select", Session.upgrade_tree.nodes[0])
				scene.call("_on_buy_pressed")
				await get_tree().create_timer(0.6, true, false, true).timeout
				var popups: Array[Node] = scene.find_children("*", "AdOfferPopup", true, false)
				if popups.is_empty():
					printerr("FALHOU: compra sem saldo não abriu a janela de anúncios")
					failures += 1
				for popup in popups:
					overflow += _check_overflow(popup, "sem saldo %s" % language)
					popup.queue_free()
				SaveGame.quarks = saved_quarks
			# Evolução: cada nó selecionado (requisitos e descrições longas)
			if scene.has_method("_select"):
				# Também com tudo bloqueado (textos de requisito, os mais longos)
				SaveGame.unlock_everything = false
				for node in Session.upgrade_tree.nodes:
					scene.call("_select", node)
					await get_tree().process_frame
					await get_tree().process_frame
					overflow += _check_overflow(scene, "upgrades %s %s" % [node.id, language])
				SaveGame.unlock_everything = true
			# Esquadrão: vaga da auxiliar e troca de lugar entre vagas
			if scene.has_method("_on_card_pressed"):
				failures += _check_squad_slots(scene, language)
				await get_tree().create_timer(0.5, true, false, true).timeout
				overflow += _check_overflow(scene, "squad trocas %s" % language)
				for body in scene.get("_roster"):
					scene.call("_open_inspect", body)
					var inspect: Dialog = scene.find_children("*", "ShipInspect", true, false)[0]
					for mode in [1, 0]:
						inspect.call("_set_mode", mode)
						await get_tree().create_timer(0.3, true, false, true).timeout
						overflow += _check_overflow(inspect, "inspeção %s %s" % [body.id, language])
					# Especial na demonstração (pega erros dos efeitos fora da partida)
					inspect.call("_on_special_pressed")
					await get_tree().create_timer(0.5, true, false, true).timeout
					inspect.call("_on_companion_pressed")
					inspect.call("_on_squad_pressed")
					inspect.close()
					await get_tree().process_frame
				# Nave bloqueada: só a nave e o aviso, sem demonstração
				SaveGame.unlock_everything = false
				for body in scene.get("_roster"):
					if not SaveGame.is_ship_unlocked(body):
						scene.call("_open_inspect", body)
						var locked: Dialog = scene.find_children("*", "ShipInspect", true, false)[0]
						await get_tree().create_timer(0.3, true, false, true).timeout
						if not locked.find_children("*", "WeaponDemo", true, false).is_empty():
							printerr("FALHOU: nave bloqueada mostra demonstração")
							failures += 1
						overflow += _check_overflow(locked, "inspeção bloqueada %s" % language)
						locked.close()
						await get_tree().process_frame
						break
				SaveGame.unlock_everything = true
			# Seletor: confere cada capítulo
			if scene.has_method("_show_chapter"):
				for c in Session.campaign.planets.size():
					scene.call("_show_chapter", c)
					await get_tree().create_timer(0.5, true, false, true).timeout
					overflow += _check_overflow(scene, "stage_select cap %d %s" % [c + 1, language])
			for view in scene.find_children("*", "UpgradeTreeView", true, false):
				overflow += _check_branch_titles(view, language)
			scene.queue_free()
			await get_tree().process_frame
	failures += await _check_ship_switch()
	failures += await _check_dialogs()
	failures += await _check_ad_reward_not_lost()
	# Painel de configurações: mexe em tudo
	var panel := SettingsPanel.new()
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	# Os botões mudam quando o painel se refaz (idioma): busca de novo a cada passo
	for i in 12:
		var buttons: Array[Node] = panel.find_children("*", "Button", true, false)
		(buttons[i % buttons.size()] as Button).pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	panel.queue_free()
	print("ui_smoke: %d telas, %d falhas de carga, %d elementos fora da tela" % [SCENES.size() * 3, failures, overflow])
	get_tree().quit(1 if failures + overflow > 0 else 0)


## Elementos visíveis que passam das laterais da tela (texto grande demais, por exemplo).
func _check_overflow(root: Node, label: String) -> int:
	var width: float = get_viewport().get_visible_rect().size.x
	var count: int = 0
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0:
			continue
		count += _check_text_fit(control, label)
		count += _check_inside_button(control, label)
		var rect: Rect2 = control.get_global_rect()
		var height: float = get_viewport().get_visible_rect().size.y
		var scrolled: bool = _inside_scroll(control)
		if rect.position.x < -2.0 or rect.end.x > width + 2.0 or (not scrolled and (rect.position.y < -2.0 or rect.end.y > height + 2.0)):
			count += 1
			if count <= 4:
				printerr("FORA DA TELA [%s] %s (%s) x=%d..%d y=%d..%d" % [label, control.name, control.get_class(), rect.position.x, rect.end.x, rect.position.y, rect.end.y])
	return count


## Texto que não cabe na própria caixa (vaza para os lados ou é cortado).
func _check_text_fit(control: Control, label: String) -> int:
	var text: String = ""
	var font: Font = control.get_theme_font("font")
	var font_size: int = 0
	var available: float = control.size.x
	if control is Button:
		var button := control as Button
		text = button.atr(button.text)
		font_size = button.get_theme_font_size("font_size")
		var box: StyleBox = button.get_theme_stylebox("normal")
		available -= box.get_minimum_size().x
		if button.autowrap_mode != TextServer.AUTOWRAP_OFF:
			var wrapped_button: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, available, font_size)
			if wrapped_button.y > control.size.y - box.get_minimum_size().y + 4.0:
				printerr("TEXTO CORTADO [%s] %s \"%s\"" % [label, control.name, text.left(40)])
				return 1
			return 0
	elif control is Label:
		var lbl := control as Label
		text = lbl.atr(lbl.text)
		font_size = lbl.get_theme_font_size("font_size")
		if lbl.autowrap_mode != TextServer.AUTOWRAP_OFF:
			# Quebra de linha: confere se a altura do texto cabe na caixa
			var wrapped: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, control.size.x, font_size)
			if wrapped.y > control.size.y + 4.0 and control.size.y > 0.0:
				printerr("TEXTO CORTADO [%s] %s \"%s\"" % [label, control.name, text.left(40)])
				return 1
			return 0
		if lbl.clip_text or lbl.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			return 0
	if text.is_empty() or font == null or text.contains("\n"):
		return 0
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Rótulos se ajustam ao texto; só importa a folga de botões (e o limite da tela, checado à parte)
	if width > available * 0.94 and (control is Button or width > available + 2.0):
		printerr("TEXTO APERTADO [%s] %s \"%s\" texto=%d caixa=%d" % [label, control.name, text.left(40), width, available])
		return 1
	return 0


## Nomes dos ramos da árvore (desenhados por código): cada um tem que caber na sua coluna.
func _check_branch_titles(view: Control, label: String) -> int:
	var font: Font = view.get_theme_default_font()
	var count: int = 0
	for key: String in UpgradeTreeView.BRANCH_KEYS:
		var width: float = font.get_string_size(view.tr(key), HORIZONTAL_ALIGNMENT_LEFT, -1, Params.upgrade_branch_font_size).x
		if width > Params.upgrade_column_offset - 12.0:
			printerr("RAMO APERTADO [%s] %s texto=%d coluna=%d" % [label, view.tr(key), width, Params.upgrade_column_offset])
			count += 1
	return count


func _inside_scroll(control: Node) -> bool:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false



## Troca de nave na barra: toque curto num ícone troca; arrastar a partir dele não.
func _check_ship_switch() -> int:
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	for i in 10:
		await get_tree().process_frame
	var switcher: BodySwitcher = game.get("switcher")
	var state: MatchState = game.get("state")
	var icon: Vector2 = switcher.get("_positions")[1]
	await _touch(icon, true)
	await _touch(icon, false)
	var errors: int = 0
	if state.current != 1:
		printerr("FALHOU: toque curto no ícone não trocou de nave")
		errors += 1
	var other: Vector2 = switcher.get("_positions")[2]
	await _touch(other, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = other + Vector2(0.0, -200.0)
	Input.parse_input_event(drag)
	await get_tree().process_frame
	await _touch(drag.position, false)
	if state.current != 1:
		printerr("FALHOU: arrastar a partir do ícone trocou de nave")
		errors += 1
	game.queue_free()
	await get_tree().process_frame
	return errors


func _touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


## Diálogos: X >= 144 px, fecha pelo Voltar, texto dentro do painel e dentro da tela
## em 20:9 (Galaxy S24), 19,5:9 e 16:9, nos três idiomas.
func _check_dialogs() -> int:
	var failures: int = 0
	for size in [Vector2i(1080, 2400), Vector2i(1080, 2340), Vector2i(1080, 1920)]:
		get_tree().root.size = size
		for language in ["pt_BR", "en", "es"]:
			SaveGame.settings["language"] = language
			Audio.apply_settings()
			var host := Control.new()
			get_tree().root.add_child(host)
			var label := "diálogo %dx%d %s" % [size.x, size.y, language]
			# Ganhar quarks, com aviso longo
			var popup := AdOfferPopup.open_offer(host, "Quarks insuficientes: faltam 99999 quarks para esta evolução do núcleo")
			failures += await _check_dialog(popup, label + " ads", true)
			# Pausa e revive
			var revive := ReviveOffer.new()
			host.add_child(revive)
			revive.open()
			failures += await _check_dialog(revive.find_children("*", "Dialog", true, false)[0], label + " revive", true)
			get_tree().paused = false
			host.queue_free()
			await get_tree().process_frame
			# Pausa (e configurações por cima) e resultado, dentro da partida
			var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
			get_tree().root.add_child(game)
			await get_tree().create_timer(0.5, true, false, true).timeout
			var pause: PauseMenu = game.get("pause_menu")
			pause.open()
			failures += await _check_dialog(pause.find_children("*", "Dialog", true, false)[0], label + " pausa", true)
			if get_tree().paused:
				printerr("PAUSA NÃO RETOMOU PELO VOLTAR [%s]" % label)
				failures += 1
			pause.open()
			pause.call("_open_settings")
			failures += await _check_dialog(pause.get("_settings_dialog"), label + " config", true)
			pause.close()
			game.call("_finish_stage_clear")
			var results: ResultsMenu = game.get("results_menu")
			failures += await _check_dialog(results.find_children("*", "Dialog", true, false)[0], label + " resultado", false)
			get_tree().paused = false
			game.queue_free()
			await get_tree().process_frame
	get_tree().root.size = Vector2i(1080, 2340)
	return failures


func _check_dialog(dialog: Dialog, label: String, expect_close: bool) -> int:
	await get_tree().create_timer(0.6, true, false, true).timeout
	var failures: int = _check_overflow(dialog, label)
	var panel_rect: Rect2 = dialog.panel.get_global_rect()
	var view: Vector2 = get_viewport().get_visible_rect().size
	if panel_rect.end.y > view.y + 2.0 or panel_rect.position.y < -2.0:
		printerr("DIÁLOGO MAIS ALTO QUE A TELA [%s] %s" % [label, panel_rect])
		failures += 1
	for node in dialog.body.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and control.get_global_rect().end.x > panel_rect.end.x + 2.0:
			printerr("VAZA DO PAINEL [%s] %s" % [label, control.name])
			failures += 1
	if expect_close:
		var close_button := dialog.find_child("CloseButton", true, false) as Button
		if close_button == null or close_button.size.x < 144.0 or close_button.size.y < 144.0:
			printerr("SEM X (>= 144 px) [%s]" % label)
			failures += 1
		dialog.call("_on_back")
		await get_tree().create_timer(0.1, true, false, true).timeout
		if is_instance_valid(dialog) and not dialog.is_queued_for_deletion():
			printerr("NÃO FECHOU PELO VOLTAR [%s]" % label)
			failures += 1
	return failures


## Fechar durante o anúncio é bloqueado e a recompensa é concedida ao fim dele.
func _check_ad_reward_not_lost() -> int:
	SaveGame.settings["language"] = "pt_BR"
	var host := Control.new()
	get_tree().root.add_child(host)
	var popup := AdOfferPopup.open_offer(host)
	await get_tree().create_timer(0.3, true, false, true).timeout
	var before: int = SaveGame.quarks
	popup.get("_ad_button").pressed.emit()
	await get_tree().process_frame
	popup.request_close()
	var failures: int = 0
	if not is_instance_valid(popup) or popup.is_queued_for_deletion():
		printerr("FECHOU DURANTE O ANÚNCIO")
		failures += 1
	await get_tree().create_timer(Params.ad_simulated_seconds + 0.5, true, false, true).timeout
	if SaveGame.quarks <= before:
		printerr("ANÚNCIO NÃO CONCEDEU QUARKS")
		failures += 1
	if is_instance_valid(popup):
		popup.request_close()
		await get_tree().process_frame
		if is_instance_valid(popup) and not popup.is_queued_for_deletion():
			printerr("NÃO FECHOU DEPOIS DO ANÚNCIO")
			failures += 1
	host.queue_free()
	return failures


## Texto dentro de um botão/cartão tem que ficar dentro dele (ex.: descrição que passa da borda de baixo).
func _check_inside_button(control: Control, label: String) -> int:
	if not (control is Label):
		return 0
	var holder: Node = control.get_parent()
	while holder != null and not (holder is Button):
		holder = holder.get_parent()
	if holder == null or (holder as Button).text != "":
		return 0
	var inner: Rect2 = (holder as Button).get_global_rect().grow(2.0)
	var rect: Rect2 = control.get_global_rect()
	var lbl := control as Label
	# Altura real do texto (o rótulo pode ser menor que o texto quando o pai o espreme)
	var font: Font = lbl.get_theme_font("font")
	var text_h: float = font.get_multiline_string_size(lbl.atr(lbl.text), HORIZONTAL_ALIGNMENT_LEFT, maxf(rect.size.x, 1.0), lbl.get_theme_font_size("font_size")).y if lbl.autowrap_mode != TextServer.AUTOWRAP_OFF else rect.size.y
	if rect.position.x < inner.position.x or rect.end.x > inner.end.x or rect.position.y < inner.position.y or rect.position.y + maxf(text_h, rect.size.y) > inner.end.y:
		printerr("TEXTO FORA DO CARTÃO [%s] \"%s\"" % [label, lbl.text.left(40)])
		return 1
	return 0


func _check_squad_slots(scene: Node, language: String) -> int:
	var roster: Array = scene.get("_roster")
	var chosen: Array = scene.get("_chosen")
	var spares: Array = roster.filter(func(b: BodyData) -> bool: return not chosen.has(b))
	var first: BodyData = chosen[0]
	var ok: bool = true
	scene.call("_on_ship_pressed", spares[0])  # esquadrão cheio: vira auxiliar
	ok = ok and scene.get("_companion") == spares[0]
	scene.call("_on_ship_pressed", first)  # tira do esquadrão
	ok = ok and scene.get("_chosen")[0] == null and (scene.get("_save_button") as Button).disabled
	scene.call("_on_ship_pressed", spares[1])  # volta a encher a vaga 1
	ok = ok and scene.get("_chosen")[0] == spares[1] and not (scene.get("_save_button") as Button).disabled
	scene.call("_on_ship_pressed", spares[2])  # tudo cheio: recusa
	ok = ok and scene.get("_slot_of").call(spares[2]) == -2
	scene.call("_on_slot_pressed", -1)  # toque na vaga da auxiliar tira
	ok = ok and scene.get("_companion") == null
	if not ok:
		printerr("FALHOU: vagas do esquadrão [%s]" % language)
		return 1
	return 0
