extends SceneTree
## Ponto de entrada da matriz inimigo x arma (ver counter_arena.gd).
## Uso: godot --headless --path . --fixed-fps 60 -s res://scripts/tools/counter_matrix.gd -- --levels 1,3,5
## Carrega a arena só no primeiro quadro, quando os autoloads já existem.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		var runner: Node = load("res://scripts/tools/counter_arena.gd").new()
		root.add_child(runner)
	return false
