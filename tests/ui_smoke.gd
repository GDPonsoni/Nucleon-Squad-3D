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
				await get_tree().process_frame
				overflow += _check_overflow(pause, "pausa %s" % language)
				pause.call("_open_settings")
				for i in 3:
					await get_tree().process_frame
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
			# Seletor: confere cada capítulo
			if scene.has_method("_show_chapter"):
				for c in Session.campaign.planets.size():
					scene.call("_show_chapter", c)
					await get_tree().create_timer(0.5, true, false, true).timeout
					overflow += _check_overflow(scene, "stage_select cap %d %s" % [c + 1, language])
			scene.queue_free()
			await get_tree().process_frame
	failures += await _check_ship_switch()
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
		var rect: Rect2 = control.get_global_rect()
		var height: float = get_viewport().get_visible_rect().size.y
		var scrolled: bool = _inside_scroll(control)
		if rect.position.x < -2.0 or rect.end.x > width + 2.0 or (not scrolled and (rect.position.y < -2.0 or rect.end.y > height + 2.0)):
			count += 1
			if count <= 4:
				printerr("FORA DA TELA [%s] %s (%s) x=%d..%d y=%d..%d" % [label, control.name, control.get_class(), rect.position.x, rect.end.x, rect.position.y, rect.end.y])
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
