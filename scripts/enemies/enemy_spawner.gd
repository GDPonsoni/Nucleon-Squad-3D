class_name EnemySpawner
extends Node
## Faz os inimigos da fase surgirem: aleatórios em intervalos (pelo topo ou pelas
## laterais) e ondas em formação em momentos definidos (StageData.waves).

## Acabou o tempo da fase: não surgem mais inimigos aleatórios nem ondas da fase.
signal finished

var _stage: StageData
var _enemies: NodePool
var _cooldown: float = 0.0
var _rock_cooldown: float = 0.0
var _elapsed: float = 0.0
var _finished: bool = false
var _duration: float = 1.0  # duração da fase já com stage_duration_scale
## Surgimentos agendados, em ordem de tempo: {time, data, pos, velocity, delay, wave, member}
var _pending: Array[Dictionary] = []


func setup(stage: StageData, enemies: NodePool) -> void:
	_stage = stage
	_enemies = enemies
	_duration = stage.duration_seconds * Params.balance.stage_duration_scale
	_cooldown = stage.start_delay
	_rock_cooldown = stage.start_delay + stage.rock_interval_min
	for wave in stage.waves:
		spawn_wave(wave, wave.time_seconds * Params.balance.stage_duration_scale)


## Recomeça a fase do zero (modos que repetem as ondas). Inimigos na tela continuam.
func restart(stage: StageData) -> void:
	_elapsed = 0.0
	_finished = false
	_pending.clear()
	setup(stage, _enemies)


## Segundos de jogo desde o início da fase.
func elapsed() -> float:
	return _elapsed


## 0 a 1 ao longo da duração da fase.
func progress() -> float:
	return clampf(_elapsed / _duration, 0.0, 1.0)


## Agenda uma onda em formação. Sem start_time, começa agora (ex.: chamada por chefe).
func spawn_wave(wave: WaveData, start_time: float = -1.0) -> void:
	var start: float = _elapsed if start_time < 0.0 else start_time
	var rect: Rect2 = get_viewport().get_visible_rect()
	var data: EnemyData = wave.enemy
	var center_x: float = rect.position.x + rect.size.x * wave.x_ratio
	var top: float = rect.position.y - data.radius
	# Com balanço lateral, a formação fica longe das bordas para não sair da tela
	var margin: float = data.radius + wave.sway_amplitude
	for i in wave.count:
		var pos: Vector2
		var velocity := Vector2(0.0, data.speed)
		var time: float = start + i * wave.interval
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
			WaveData.Formation.DIAGONAL:
				# O primeiro membro lidera embaixo; os outros sobem em escada para o lado
				var direction: float = -1.0 if wave.side == WaveData.EntrySide.RIGHT else 1.0
				var offset: float = (i - (wave.count - 1) * 0.5) * wave.spacing * direction
				pos = Vector2(center_x + offset, top - i * wave.spacing * 0.55)
			WaveData.Formation.GRID:
				var columns: int = maxi(wave.columns, 1)
				var col: int = i % columns
				var row: int = i / columns
				pos = Vector2(center_x + (col - (columns - 1) * 0.5) * wave.spacing, top - row * wave.spacing * 0.85)
			WaveData.Formation.PINCER:
				# Pares: um de cada lado ao mesmo tempo
				var mirrored: bool = i % 2 == 1
				var x: float = rect.position.x + rect.size.x * (1.0 - wave.x_ratio if mirrored else wave.x_ratio)
				pos = Vector2(x, top)
				time = start + (i / 2) * wave.interval
			WaveData.Formation.CIRCLE:
				var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / maxf(wave.count, 1.0))
				pos = Vector2(center_x, top - wave.spacing) + dir * wave.spacing
			WaveData.Formation.RISE:
				pos = Vector2(center_x + (i - (wave.count - 1) * 0.5) * wave.spacing, rect.end.y + data.radius)
				velocity = Vector2(0.0, -data.speed)
			WaveData.Formation.SWARM:
				var half: float = wave.spacing * wave.count * 0.25
				pos = Vector2(center_x + randf_range(-half, half), top - randf_range(0.0, half * 0.8))
		if wave.formation != WaveData.Formation.SIDE:
			pos.x = clampf(pos.x, rect.position.x + margin, rect.end.x - margin)
		_pending.append({
			"time": time, "data": data, "pos": pos,
			"velocity": velocity, "delay": i * wave.dive_stagger, "wave": wave, "member": i,
		})
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])


## Fissão: pedaços saem do ponto em leque para baixo (ex.: Fissor destruído).
func spawn_burst(data: EnemyData, pos: Vector2, count: int, spread_degrees: float) -> void:
	var spread: float = deg_to_rad(spread_degrees)
	for i in count:
		var enemy := _enemies.acquire() as Enemy
		if enemy == null:
			return
		var t: float = 0.0 if count == 1 else float(i) / (count - 1) - 0.5
		var dir := Vector2.from_angle(PI * 0.5 + spread * t)
		enemy.activate(data, pos + dir * data.radius, dir * data.speed)
		enemy.apply_stage(_stage)


func _process(delta: float) -> void:
	_elapsed += delta
	# Agendados continuam mesmo depois do fim (ondas chamadas pelo chefe)
	while not _pending.is_empty() and _pending[0]["time"] <= _elapsed:
		var entry: Dictionary = _pending.pop_front()
		var enemy := _enemies.acquire() as Enemy
		if enemy != null:
			enemy.activate(entry["data"], entry["pos"], entry["velocity"], entry["delay"])
			enemy.set_motion(entry["wave"], entry["member"])
			enemy.armored = (entry["wave"] as WaveData).special_moment
			enemy.apply_stage(_stage)

	if _finished:
		return
	if _elapsed >= _duration:
		_finished = true
		finished.emit()
		return
	_update_rocks(delta)
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += randf_range(_stage.spawn_interval_min, _stage.spawn_interval_max)
	_spawn_random()


## Rochas: caem do topo em intervalos sorteados, com deriva lateral e giro próprios.
func _update_rocks(delta: float) -> void:
	if _stage.rocks.is_empty() or _stage.rock_interval_max <= 0.0:
		return
	_rock_cooldown -= delta
	if _rock_cooldown > 0.0:
		return
	_rock_cooldown += randf_range(_stage.rock_interval_min, _stage.rock_interval_max)
	var rock := _enemies.acquire() as Enemy
	if rock == null:
		return
	var data: EnemyData = _pick_from(_stage.rocks, _stage.rock_weights)
	var rect: Rect2 = get_viewport().get_visible_rect()
	var x: float = randf_range(rect.position.x + data.radius, rect.end.x - data.radius)
	rock.activate(data, Vector2(x, rect.position.y - data.radius), Vector2(randf_range(-data.drift_x, data.drift_x), data.speed))
	rock.apply_stage(_stage)


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
	enemy.apply_stage(_stage)


## Sorteio ponderado por spawn_weights (sem pesos: todos iguais).
func _pick() -> EnemyData:
	return _pick_from(_stage.enemies, _stage.spawn_weights)


func _pick_from(list: Array[EnemyData], weights: PackedFloat32Array) -> EnemyData:
	if weights.size() != list.size():
		return list.pick_random()
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return list[i]
	return list.back()
