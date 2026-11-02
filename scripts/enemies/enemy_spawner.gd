class_name EnemySpawner
extends Node
## Faz os inimigos da fase surgirem em intervalos aleatórios: pelo topo ou,
## para quem atravessa a tela, por uma das laterais.

## Acabou o tempo da fase: não surgem mais inimigos.
signal finished

var _stage: StageData
var _enemies: NodePool
var _cooldown: float = 0.0
var _elapsed: float = 0.0
var _finished: bool = false


func setup(stage: StageData, enemies: NodePool) -> void:
	_stage = stage
	_enemies = enemies
	_cooldown = stage.start_delay


## Segundos de jogo desde o início da fase.
func elapsed() -> float:
	return _elapsed


## 0 a 1 ao longo da duração da fase.
func progress() -> float:
	return clampf(_elapsed / _stage.duration_seconds, 0.0, 1.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _stage.duration_seconds:
		if not _finished:
			_finished = true
			finished.emit()
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += randf_range(_stage.spawn_interval_min, _stage.spawn_interval_max)
	_spawn()


func _spawn() -> void:
	if _stage.enemies.is_empty():
		return
	var enemy := _enemies.acquire() as Enemy
	if enemy == null:
		return
	var data: EnemyData = _pick()
	var rect: Rect2 = get_viewport().get_visible_rect()
	if data.movement == EnemyData.Movement.CROSS:
		var side: float = 1.0 if randf() < 0.5 else -1.0  # 1 = entra pela esquerda
		var y: float = rect.position.y + rect.size.y * randf_range(Params.cross_band_top, Params.cross_band_bottom)
		var x: float = rect.position.x - data.radius if side > 0.0 else rect.end.x + data.radius
		enemy.activate(data, Vector2(x, y), Vector2(side * data.speed, data.speed * data.cross_drift))
	else:
		var x: float = randf_range(rect.position.x + _stage.spawn_margin_x, rect.end.x - _stage.spawn_margin_x)
		enemy.activate(data, Vector2(x, rect.position.y - data.radius), Vector2(0.0, data.speed))


## Sorteio ponderado por spawn_weights (sem pesos: todos iguais).
func _pick() -> EnemyData:
	var weights: PackedFloat32Array = _stage.spawn_weights
	if weights.size() != _stage.enemies.size():
		return _stage.enemies.pick_random()
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return _stage.enemies[i]
	return _stage.enemies.back()
