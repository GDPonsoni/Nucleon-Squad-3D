extends SceneTree
## Regressões dos chefes: cada chefe entra, vai para as fases finais e usa os ataques únicos.
## Uso: godot --headless --path . -s res://tests/boss_regressions_run.gd
var _started := false
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		root.add_child(load("res://tests/boss_regressions.gd").new())
	return false
