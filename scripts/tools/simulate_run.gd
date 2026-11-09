extends SceneTree
## Ponto de entrada da simulação do modo roguelike (ver run_simulator.gd para as opções).
## Uso: godot --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_run.gd -- --minutes 10

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		var runner: Node = load("res://scripts/tools/run_simulator.gd").new()
		runner.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(runner)
	return false
