class_name Storm
extends Node2D
## Especial da Tesla: tempestade elétrica. Em special_count descargas ao longo de
## special_duration, raios caem do alto em todos os inimigos visíveis da tela.

var _context: CombatContext
var _data: WeaponData
var _damage: float = 0.0
var _left: int = 0
var _cooldown: float = 0.0
var _flashes: Array[Dictionary] = []  # {from, to, age} em coordenadas da tela


func setup(context: CombatContext, data: WeaponData) -> void:
	_context = context
	_data = data
	_damage = SpecialAttack.damage_of(data, context)
	_left = data.special_count


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0 and _left > 0:
		_cooldown = _data.special_duration / _data.special_count
		_left -= 1
		_strike()
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["age"] += delta
		if _flashes[i]["age"] >= Params.storm_flash_seconds:
			_flashes.remove_at(i)
	queue_redraw()
	if _left <= 0 and _flashes.is_empty():
		queue_free()


func _strike() -> void:
	var top: float = get_viewport_rect().position.y
	for item in _context.hostiles().duplicate():
		var enemy := item as Enemy
		if not enemy.visible or not enemy.is_on_screen():
			continue
		var from := Vector2(enemy.position.x + randf_range(-120.0, 120.0), top)
		_flashes.append({"from": from, "to": enemy.position, "age": 0.0})
		enemy.take_damage(_damage)


func _draw() -> void:
	for flash in _flashes:
		var fade: float = 1.0 - flash["age"] / Params.storm_flash_seconds
		var a: Vector2 = flash["from"]
		var b: Vector2 = flash["to"]
		var path := PackedVector2Array([a])
		var normal: Vector2 = (b - a).orthogonal().normalized()
		for i in range(1, 8):
			path.append(a.lerp(b, i / 8.0) + normal * randf_range(-1.0, 1.0) * Params.chain_bolt_jitter * 2.0)
		path.append(b)
		draw_polyline(path, Color(_data.color, 0.5 * fade), Params.chain_bolt_width * 4.0)
		draw_polyline(path, Color(Color.WHITE, fade), Params.chain_bolt_width * 1.6)
		draw_circle(b, 40.0 * fade, Color(_data.color, 0.4 * fade))
