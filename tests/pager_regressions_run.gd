extends SceneTree
## Regressões da paginação lateral (PagedView) no seletor de fases.
## Uso: godot --headless --path . -s res://tests/pager_regressions_run.gd
var _started := false
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		root.add_child(load("res://tests/pager_regressions.gd").new())
	return false
