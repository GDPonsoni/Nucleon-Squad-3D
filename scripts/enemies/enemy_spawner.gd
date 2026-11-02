class_name EnemySpawner
extends Node
## Faz os inimigos da fase surgirem: aleatórios em intervalos (pelo topo ou pelas
## laterais) e ondas em formação em momentos definidos (StageData.waves).

## Acabou o tempo da fase: não surgem mais inimigos aleatórios nem ondas da fase.
signal finished

var _stage: StageData
var _enemies: NodePool
var _cooldown: float = 0.0
var _elapsed: float = 0.0
var _finished: bool = false
## Surgimentos agendados, em ordem de tempo: {time, data, pos, velocity, delay}
var _pending: Array[Dictionary] = []


func setup(stage: StageData, enemies: NodePool) -> void:
	_stage = stage
	_enemies = enemies
	_cooldown = stage.start_delay
	for wave in stage.waves:
		spawn_wave(wave, wave.time_seconds)


## Segundos de jogo desde o início da fase.
func elapsed() -> float:
	return _elapsed


## 0 a 1 ao longo da duração da fase.
func progress() -> float:
	return clampf(_elapsed / _stage.duration_seconds, 0.0, 1.0)


## Agenda uma onda em formação. Sem start_time, começa agora (ex.: chamada por chefe).
func spawn_wave(wave: WaveData, start_time: float = -1.0) -> void:
	var start: float = _elapsed if start_time < 0.0 else start_time
	var rect: Rect2 = get_viewport().get_visible_rect()
	var data: EnemyData = wave.enemy
	var center_x: float = rect.position.x + rect.size.x * wave.x_ratio
	var top: float = rect.position.y - data.radius
	for i in wave.count:
		var pos: Vector2
		var velocity := Vector2(0.0, data.speed)
		match wave.formation:
			WaveData.Formation.LINE:
				pos = Vector2(center_x + (i - (wave.count - 1) * 0.5) * wave.spacing, top)
			WaveData.Formation.V:
				# 0 na ponta; depois alterna direita/esquerda, cada par mais atrás
				var rank: int = (i + 1) / 2
				var side: float = 1.0 if i % 2 == 1 else -1.0
				pos = Vector2(center_x + side * rank * wave.spacing, top - rank * wave.spacing * 0.6)
			WaveData.Formation.COLUMN:
				pos = Vector2(center_x, top)
			WaveData.Formation.SIDE:
				var from_left: bool = wave.side == WaveData.EntrySide.LEFT or (wave.side == WaveData.EntrySide.BOTH and i % 2 == 0)
				var y: float = rect.position.y + rect.size.y * wave.y_ratio
				pos = Vector2(rect.position.x - data.radius if from_left else rect.end.x + data.radius, y)
				velocity = Vector2((1.0 if from_left else -1.0) * data.speed, data.speed * data.cross_drift)
		if wave.formation != WaveData.Formation.SIDE:
			pos.x = clampf(pos.x, rect.position.x + data.radius, rect.end.x - data.radius)
		_pending.append({
			"time": start + i * wave.interval, "data": data, "pos": pos,
			"velocity": velocity, "delay": i * wave.dive_stagger,
		})
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])


func _process(delta: float) -> void:
	_elapsed += delta
	# Agendados continuam mesmo depois do fim (ondas chamadas pelo chefe)
	while not _pending.is_empty() and _pending[0]["time"] <= _elapsed:
		var entry: Dictionary = _pending.pop_front()
		var enemy := _enemies.acquire() as Enemy
		if enemy != null:
			enemy.activate(entry["data"], entry["pos"], entry["velocity"], entry["delay"])

	if _finished:
		return
	if _elapsed >= _stage.duration_seconds:
		_finished = true
		finished.emit()
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += randf_range(_stage.spawn_interval_min, _stage.spawn_interval_max)
	_spawn_random()


func _spawn_random() -> void:
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
