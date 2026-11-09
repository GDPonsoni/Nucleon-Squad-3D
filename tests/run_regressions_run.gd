extends SceneTree
## Regressões do modo roguelike: escolha inicial, armas montadas, subir de nível e pausa.
## Uso: godot --headless --path . -s res://tests/run_regressions_run.gd
var _started := false
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		root.add_child(load("res://tests/run_regressions.gd").new())
	return false
