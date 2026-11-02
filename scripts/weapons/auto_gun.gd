class_name AutoGun
extends Node
## Tiro automático contínuo a partir da ponta da nave.

var _shooter: Node2D
var _pool: BulletPool
var _cooldown: float = 0.0


func setup(shooter: Node2D, pool: BulletPool) -> void:
	_shooter = shooter
	_pool = pool


func _process(delta: float) -> void:
	# delta escalado: a cadência também desacelera na câmera lenta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += 1.0 / Params.fire_rate
	_pool.spawn(_shooter.position + Vector2(0.0, -Params.ship_size.y * 0.5))
