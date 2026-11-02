extends Node2D
## Cena principal do Marco 0: monta os nós por código.

var player: Player


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)

	player = Player.new()
	player.name = "Player"
	add_child(player)
