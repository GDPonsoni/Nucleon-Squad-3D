extends SceneTree
## Ponto de entrada da simulação de fases (ver stage_simulator.gd para as opções).
## Uso: godot --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_stages.gd -- --stages p1_s1
## Os scripts do jogo usam os autoloads; por isso o simulador só é carregado no primeiro
## quadro, quando eles já existem.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		# Headless abre uma tela quadrada de 1920; usa a proporção do Galaxy S24 (em pé)
		root.size = Vector2i(1080, 2340)
		var runner: Node = load("res://scripts/tools/stage_simulator.gd").new()
		runner.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(runner)
	return false
