extends SceneTree
## Regressões da partida: toques no botão de especial e alvos liberados (chefe morto).
## Uso: godot --headless --path . -s res://tests/match_regressions_run.gd
## Erros de script aparecem como "SCRIPT ERROR" na saída.
var _started := false
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		root.add_child(load("res://tests/match_regressions.gd").new())
	return false
