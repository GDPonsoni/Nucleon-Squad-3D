extends SceneTree
## Ponto de entrada do teste de fumaça (ver ui_smoke.gd).

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		# Headless abre uma tela quadrada de 1920; usa a proporção do Galaxy S24 (em pé)
		root.size = Vector2i(1080, 2340)
		root.add_child(load("res://tests/ui_smoke.gd").new())
	return false
