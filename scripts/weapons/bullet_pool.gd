class_name BulletPool
extends Node2D
## Pool de projéteis: todos criados no início, nunca instanciados por tiro.

var _free: Array[Bullet] = []


func _ready() -> void:
	for i in Params.bullet_pool_size:
		var bullet := Bullet.new()
		add_child(bullet)
		bullet.deactivate()
		bullet.expired.connect(release)
		_free.append(bullet)


## Retorna false se o pool estiver esgotado (o tiro é descartado).
func spawn(pos: Vector2) -> bool:
	if _free.is_empty():
		return false
	_free.pop_back().activate(pos)
	return true


func release(bullet: Bullet) -> void:
	bullet.deactivate()
	_free.append(bullet)
