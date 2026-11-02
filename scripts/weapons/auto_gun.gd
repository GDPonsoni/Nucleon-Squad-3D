class_name AutoGun
extends Node
## Tiro automático contínuo a partir da ponta da nave.

var _shooter: Node2D
var _pool: NodePool
var _cooldown: float = 0.0


func setup(shooter: Node2D, pool: NodePool) -> void:
	_shooter = shooter
	_pool = pool


func _process(delta: float) -> void:
	# delta escalado: a cadência também desacelera na câmera lenta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += 1.0 / Params.fire_rate
	var bullet := _pool.acquire() as Bullet
	if bullet != null:
		bullet.activate(_shooter.position + Vector2(0.0, -Params.ship_size.y * 0.5),
			Vector2(0.0, -Params.bullet_speed), 1, Params.bullet_size, Params.bullet_color, Bullet.Shape.RECT)
