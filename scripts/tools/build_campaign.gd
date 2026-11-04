extends SceneTree
## Ponto de entrada do gerador da campanha (ver campaign_builder.gd).
## Uso: godot --headless --path . -s res://scripts/tools/build_campaign.gd
## Os scripts do jogo usam os autoloads; por isso o gerador só é carregado no primeiro
## quadro, quando eles já existem.

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		root.add_child(load("res://scripts/tools/campaign_builder.gd").new())
	return false
