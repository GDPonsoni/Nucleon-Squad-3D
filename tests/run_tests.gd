extends SceneTree
## Roda os testes automáticos (tests/test_suite.gd).
## Uso: godot --headless --path . -s res://tests/run_tests.gd
## Os scripts do jogo usam os autoloads; por isso a suíte só é carregada no primeiro
## quadro, quando eles já existem. Sai com código 1 se algum teste falhar.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		# Headless abre uma tela quadrada de 1920; usa a proporção do Galaxy S24 (em pé)
		root.size = Vector2i(1080, 2340)
		var suite: Node = load("res://tests/test_suite.gd").new()
		root.add_child(suite)
	return false
