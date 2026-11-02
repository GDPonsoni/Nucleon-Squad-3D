extends Node2D
## Cena principal do Marco 0: monta os nós por código.

var touch_input: TouchInput
var player: Player
var bullet_pool: BulletPool
var gun: AutoGun


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)

	touch_input = TouchInput.new()
	touch_input.name = "TouchInput"
	add_child(touch_input)

	# Pool antes da nave para os projéteis ficarem atrás dela
	bullet_pool = BulletPool.new()
	bullet_pool.name = "BulletPool"
	add_child(bullet_pool)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.bind_input(touch_input)

	gun = AutoGun.new()
	gun.name = "AutoGun"
	add_child(gun)
	gun.setup(player, bullet_pool)
