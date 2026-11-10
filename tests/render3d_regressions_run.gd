extends SceneTree
## Regressões da visão 3D: camada 2D no plano de jogo, vistas das entidades, projéteis,
## chefe, efeitos de chão e limpeza ao sair da partida.
## Uso: godot --headless --path . -s res://tests/render3d_regressions_run.gd
var _started := false
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		root.size = Vector2i(1080, 2340)
		root.add_child(load("res://tests/render3d_regressions.gd").new())
	return false
