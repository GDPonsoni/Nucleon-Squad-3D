extends Node2D
## Cena principal do Marco 0: monta os nós por código.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
