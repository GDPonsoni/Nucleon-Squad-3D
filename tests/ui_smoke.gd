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
	for path in SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			printerr("FALHOU ao carregar ", path)
			failures += 1
			continue
		# Cada tela também em inglês, para pegar textos quebrados
		for language in ["pt_BR", "en"]:
			SaveGame.settings["language"] = language
			Audio.apply_settings()
			printerr("[smoke] %s %s" % [path, language])
			var scene: Node = packed.instantiate()
			get_tree().root.add_child(scene)
			for i in 20:
				await get_tree().process_frame
			scene.queue_free()
			await get_tree().process_frame
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
	print("ui_smoke: %d telas, %d falhas de carga" % [SCENES.size() * 2, failures])
	get_tree().quit(1 if failures > 0 else 0)
