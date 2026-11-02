extends Node2D
## Cena principal do Marco 0: monta os nós por código.

var touch_input: TouchInput
var player: Player


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)

	touch_input = TouchInput.new()
	touch_input.name = "TouchInput"
	add_child(touch_input)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.bind_input(touch_input)
