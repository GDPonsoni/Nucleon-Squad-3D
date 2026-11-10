extends SceneTree
## Tira fotos da partida em 3D para conferir o visual no PC (precisa de tela: sem --headless).
## Uso: godot --path . --resolution 540x1170 -s res://scripts/tools/shot_3d.gd -- \
##          --stages p1_s1 --at 6,14,22 --out /tmp/fotos [--boss-only] [--speed 4]
## Carrega o código real no primeiro quadro, quando os autoloads já existem.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var tool: Node = load("res://scripts/tools/shot_3d_runner.gd").new()
		tool.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(tool)
	return false
