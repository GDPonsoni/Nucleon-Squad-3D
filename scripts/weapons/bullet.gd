class_name Bullet
extends Node2D
## Projétil reutilizável (vive no BulletPool). Sobe em linha reta.

signal expired(bullet: Bullet)


func activate(pos: Vector2) -> void:
	position = pos
	visible = true
	set_process(true)


func deactivate() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	position.y -= Params.bullet_speed * delta
	if position.y < get_viewport_rect().position.y - Params.bullet_size.y:
		expired.emit(self)


func _draw() -> void:
	draw_rect(Rect2(-Params.bullet_size * 0.5, Params.bullet_size), Params.bullet_color)
