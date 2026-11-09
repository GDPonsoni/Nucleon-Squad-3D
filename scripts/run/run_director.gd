class_name RunDirector
extends Node
## Diretor de ondas do modo roguelike: sorteia ondas (RunModeData.waves) num ritmo que
## acelera com o tempo, solta surtos de horda, elites e os chefes na hora marcada. Também
## atualiza a vida e a cadência dos inimigos (StageData da partida) conforme o minuto.
## Tudo em tempo de jogo (acompanha a câmera lenta).

signal elite_due(data: EnemyData)
signal boss_due(data: BossData, minute: float)

var mode: RunModeData
var stage: StageData  # da partida: o diretor muda enemy_hp_scale e enemy_fire_scale
var spawner: EnemySpawner
var boss_active: bool = false  # o jogo avisa: durante a luta, menos ondas e sem elites
var clock: float = 0.0
var _next_wave: float = 0.0
var _next_surge: float = 0.0
var _next_elite: float = 0.0
var _next_boss: int = 0
var _rng := RandomNumberGenerator.new()


func setup(run_mode: RunModeData, run_stage: StageData, enemy_spawner: EnemySpawner, seed_value: int) -> void:
	mode = run_mode
	stage = run_stage
	spawner = enemy_spawner
	_rng.seed = seed_value
	_next_wave = mode.first_wave_delay
	_next_surge = mode.surge_every
	_next_elite = mode.elite_first
	_update_scales()


func minute() -> float:
	return clock / 60.0


## Vida dos inimigos comuns no minuto atual (sobre a do capítulo 1).
func hp_scale() -> float:
	return mode.hp_start * pow(mode.hp_growth_per_minute, minute())


func boss_hp_factor() -> float:
	return mode.boss_hp_scale * pow(mode.boss_hp_growth_per_minute, minute())


func wave_gap() -> float:
	var t: float = clampf(clock / mode.duration_seconds, 0.0, 1.0)
	var gap: float = lerpf(mode.wave_gap_start, mode.wave_gap_end, t)
	return gap * (mode.boss_wave_gap_scale if boss_active else 1.0)


func _process(delta: float) -> void:
	clock += delta
	_update_scales()
	if clock >= _next_wave:
		_next_wave = clock + wave_gap()
		_spawn(_pick(false))
	if clock >= _next_surge:
		_next_surge += mode.surge_every
		if not boss_active:
			for i in mode.surge_waves:
				_spawn(_pick(true), i * mode.surge_gap)
	if clock >= _next_elite:
		_next_elite += mode.elite_every
		var elite: EnemyData = _pick_elite()
		if elite != null and not boss_active:
			elite_due.emit(elite)
	if _next_boss < mode.bosses.size() and _next_boss < mode.boss_minutes.size() \
			and not boss_active and minute() >= mode.boss_minutes[_next_boss]:
		boss_active = true
		boss_due.emit(mode.bosses[_next_boss], minute())
		_next_boss += 1


func _update_scales() -> void:
	stage.enemy_hp_scale = hp_scale()
	var t: float = clampf(clock / mode.duration_seconds, 0.0, 1.0)
	stage.enemy_fire_scale = lerpf(mode.fire_scale_start, mode.fire_scale_end, t)


## Onda ativa no minuto atual, pelo peso (horde = só as de horda, para os surtos).
func _pick(horde_only: bool) -> RunWaveEntry:
	var m: float = minute()
	var active: Array[RunWaveEntry] = []
	var total: float = 0.0
	for entry in mode.waves:
		if m < entry.from_minute or (entry.to_minute > 0.0 and m >= entry.to_minute):
			continue
		if horde_only and not entry.horde:
			continue
		active.append(entry)
		total += entry.weight
	if active.is_empty():
		return null
	var roll: float = _rng.randf() * total
	for entry in active:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return active[active.size() - 1]


func _pick_elite() -> EnemyData:
	var options: Array[EnemyData] = []
	for i in mode.elite_enemies.size():
		var from: float = mode.elite_from_minute[i] if i < mode.elite_from_minute.size() else 0.0
		if minute() >= from:
			options.append(mode.elite_enemies[i])
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]


## Monta a onda do modelo com o tamanho do minuto e agenda no spawner.
func _spawn(entry: RunWaveEntry, delay: float = 0.0) -> void:
	if entry == null:
		return
	var wave := WaveData.new()
	wave.enemy = entry.enemy
	wave.formation = entry.formation
	wave.count = mini(roundi(entry.count * (1.0 + mode.count_growth_per_minute * minute())), entry.max_count)
	wave.spacing = entry.spacing
	wave.interval = entry.interval
	wave.speed_scale = entry.speed_scale
	wave.sway_amplitude = entry.sway_amplitude
	wave.path = entry.path
	wave.mirror = entry.random_mirror and _rng.randf() < 0.5
	wave.x_ratio = entry.fixed_x if entry.fixed_x >= 0.0 else _rng.randf_range(0.25, 0.75)
	if entry.both_sides:
		wave.side = WaveData.EntrySide.BOTH
	else:
		wave.side = WaveData.EntrySide.LEFT if _rng.randf() < 0.5 else WaveData.EntrySide.RIGHT
	# Laterais entram em qualquer altura até um pouco abaixo do meio da tela
	wave.y_ratio = _rng.randf_range(0.1, 0.55)
	spawner.spawn_wave(wave, spawner.elapsed() + delay)
