class_name ChainWeapon
extends Weapon
## Tesla: descargas elétricas. Cada descarga acerta o inimigo mais próximo à frente da
## nave e salta para o vizinho mais próximo, até chain_targets inimigos, perdendo um
## pouco de dano a cada salto. Sem inimigo à frente, não dispara.

var _cooldown: float = 0.0
var _bolts: Array[Dictionary] = []  # {points: PackedVector2Array (globais), age: float}


func _process(delta: float) -> void:
	# delta escalado: a cadência também desacelera na câmera lenta
	var charging: bool = _tick_spawn(delta)
	if charging:
		_cooldown = 0.0
	else:
		_cooldown -= delta
	if not charging and _cooldown <= 0.0:
		_cooldown += 1.0 / (stats.fire_rate * rate())
		_discharge()
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i]["age"] += delta
		if _bolts[i]["age"] >= Params.chain_bolt_seconds:
			_bolts.remove_at(i)
	queue_redraw()


func _discharge() -> void:
	var from: Vector2 = muzzle()
	var points := PackedVector2Array([from])
	var hit: Dictionary = {}
	var amount: float = damage()
	var current: Vector2 = from
	for k in stats.chain_targets:
		var target: Enemy = _next_target(current, stats.chain_range if k == 0 else stats.chain_jump, hit, k == 0 and not stats.chain_any_direction)
		if target == null:
			break
		hit[target] = true
		points.append(target.position)
		current = target.position
		target.take_damage(amount)
		amount *= stats.chain_falloff
	if points.size() > 1:
		_bolts.append({"points": points, "age": 0.0})
		Audio.shot(data.kind, sound_db)


## Inimigo mais próximo ainda não atingido; o primeiro precisa estar à frente da nave.
func _next_target(from: Vector2, reach: float, hit: Dictionary, ahead_only: bool) -> Enemy:
	var best: Enemy = null
	var best_distance: float = reach * reach
	for item in context.hostiles():
		var enemy := item as Enemy
		if not enemy.visible or hit.has(enemy) or not enemy.is_on_screen():
			continue
		if ahead_only and enemy.position.y > from.y:
			continue
		var distance: float = from.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _draw() -> void:
	_draw_charge()
	for bolt in _bolts:
		var fade: float = 1.0 - bolt["age"] / Params.chain_bolt_seconds
		var points: PackedVector2Array = bolt["points"]
		for i in points.size() - 1:
			_draw_bolt(to_local(points[i]), to_local(points[i + 1]), fade)


## Raio quebrado entre dois pontos: brilho largo na cor da arma e miolo branco.
func _draw_bolt(a: Vector2, b: Vector2, fade: float) -> void:
	var path := PackedVector2Array([a])
	var normal: Vector2 = (b - a).orthogonal().normalized()
	var pieces: int = Params.chain_bolt_segments
	for i in range(1, pieces):
		var t: float = float(i) / pieces
		path.append(a.lerp(b, t) + normal * randf_range(-1.0, 1.0) * Params.chain_bolt_jitter)
	path.append(b)
	draw_polyline(path, Color(data.color, 0.45 * fade), Params.chain_bolt_width * 2.2)
	draw_polyline(path, Color(Color.WHITE, fade), Params.chain_bolt_width)
