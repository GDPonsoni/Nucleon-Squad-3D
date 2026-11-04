extends SceneTree
## Ponto de entrada do teste de fumaça (ver ui_smoke.gd).

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		root.add_child(load("res://tests/ui_smoke.gd").new())
	return false
