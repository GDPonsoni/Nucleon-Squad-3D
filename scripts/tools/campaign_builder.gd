extends Node
## Gera a campanha: 5 capítulos de 9 fases (data/stages/p*_s*.tres), os planetas e
## data/campaign.tres. Rodado por build_campaign.gd:
##   godot --headless --path . -s res://scripts/tools/build_campaign.gd
## Atenção: sobrescreve os .tres das fases. Para mudar uma fase à mão, edite o .tres e não
## rode o gerador de novo (ou mude as regras aqui e gere tudo outra vez).
##
## Cada fase usa 4 "motivos" (padrões de onda reconhecíveis: cobra de drones, V de
## kamikazes, pinça, diagonal, arco de Miradores...) repetidos em ritmo regular: a cada
## volta o padrão vem do outro lado e um pouco maior. Inimigos aleatórios são só um
## preenchimento leve. A fase 5 tem um chefe intermediário e a 9, o chefe do capítulo.

const CHAPTERS: int = 5
const STAGES: int = 9
const MIDBOSS_STAGE: int = 4  # índice da fase 5
const BOSS_STAGE: int = 8  # índice da fase 9
const MOTIFS_PER_STAGE: int = 4
# Escala da dificuldade (d vai de 0 na 1-1 até ~4,4 na 5-9)
const GAP_BASE: float = 8.0  # segundos entre ondas na 1-1
const GAP_PER_DIFFICULTY: float = 0.85  # quanto o intervalo encurta por ponto de dificuldade
const COUNT_STEP: float = 1.3  # a cada tantos pontos de dificuldade, ondas com +1 membro
const PAIR_FROM: float = 1.6  # a partir dessa dificuldade, uma a cada 3 ondas vem em dupla
const PAIR_OFTEN_FROM: float = 3.6  # a partir dessa, uma a cada 2
# Orçamento de perigo: soma das notas de perigo dos motivos escolhidos para a fase
const DANGER_BASE: float = 5.5
const DANGER_PER_CHAPTER: float = 2.3
const DANGER_PER_STAGE: float = 0.75
const DANGER_MIDBOSS: float = 0.55  # fase do chefe intermediário: ondas mais leves
const DANGER_BOSS: float = 0.7  # fase do chefe: o chefe é o desafio principal
const HP_SCALE: PackedFloat32Array = [1.2, 1.3, 1.4, 1.5, 1.65]  # vida dos inimigos por capítulo
const FIRE_SCALE: PackedFloat32Array = [1.12, 1.16, 1.2, 1.25, 1.32]  # cadência de tiro por capítulo
const OLD_MOTIF_DECAY: float = 0.65  # peso dos motivos de capítulos anteriores, por capítulo de distância
const PLANET_KEYS: PackedStringArray = ["PLANET_1_NAME", "PLANET_2_NAME", "PLANET_3_NAME", "PLANET_4_NAME", "PLANET_5_NAME"]
const BACKGROUNDS: PackedColorArray = [
	Color(0.04, 0.04, 0.08), Color(0.08, 0.03, 0.04), Color(0.05, 0.02, 0.08), Color(0.01, 0.04, 0.05), Color(0.06, 0.035, 0.02),
]
const STARS: PackedColorArray = [
	Color(0.8, 0.85, 1.0), Color(1.0, 0.8, 0.7), Color(0.8, 0.7, 1.0), Color(0.6, 1.0, 0.9), Color(1.0, 0.85, 0.55),
]

var _e: Dictionary = {}  # id -> EnemyData
var _motifs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _current_stage: StageData


func _ready() -> void:
	for id in ["drone", "aimer", "kamikaze", "tank", "spreader", "splitter", "hunter", "pulsar", "fissor"]:
		_e[id] = load("res://data/enemies/%s.tres" % id)
	_define_motifs()
	var planets: Array[PlanetData] = []
	for c in CHAPTERS:
		var stages: Array[StageData] = []
		for s in STAGES:
			var stage := _build_stage(c, s)
			var path := "res://data/stages/%s.tres" % stage.id
			_save(stage, path)
			stages.append(load(path) as StageData)
		var planet := PlanetData.new()
		planet.id = StringName("planet_%d" % (c + 1))
		planet.name_key = PLANET_KEYS[c]
		planet.background_color = BACKGROUNDS[c]
		planet.star_color = STARS[c]
		planet.stages = stages
		var planet_path := "res://data/planets/planet_%d.tres" % (c + 1)
		_save(planet, planet_path)
		planets.append(load(planet_path) as PlanetData)
	var campaign := CampaignData.new()
	campaign.planets = planets
	_save(campaign, "res://data/campaign.tres")
	print("campanha gerada: %d capítulos, %d fases" % [CHAPTERS, CHAPTERS * STAGES])
	get_tree().quit()


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(error)])


## Dificuldade de 0 (1-1) a ~4,4 (5-9): sobe ao longo do capítulo e recua um pouco no
## começo do seguinte (respiro depois do chefe).
func _difficulty(c: int, s: int) -> float:
	return c * 0.8 + s * 0.15


func _build_stage(c: int, s: int) -> StageData:
	_rng.seed = hash("p%d_s%d" % [c + 1, s + 1])
	var d: float = _difficulty(c, s)
	var stage := StageData.new()
	_current_stage = stage
	stage.id = StringName("p%d_s%d" % [c + 1, s + 1])
	stage.enemy_hp_scale = HP_SCALE[c]
	stage.enemy_fire_scale = FIRE_SCALE[c]
	stage.start_delay = 2.0
	if s == MIDBOSS_STAGE:
		stage.duration_seconds = 55.0 + 8.0 * c
		stage.boss = load("res://data/bosses/mini_%d.tres" % (c + 1))
	elif s == BOSS_STAGE:
		stage.duration_seconds = 80.0 + 10.0 * c
		stage.boss = load("res://data/bosses/boss_%d.tres" % (c + 1))
	else:
		stage.duration_seconds = 75.0 + 9.0 * s + 12.0 * c
	_set_filler(stage, c, s, d)
	stage.waves = _compose(c, s, d, stage.duration_seconds)
	return stage


func _log_stage(stage: StageData, chosen: Array[Dictionary]) -> void:
	var names := PackedStringArray()
	var total: float = 0.0
	for motif in chosen:
		names.append(motif["name"])
		total += motif["danger"]
	print("%s  %3ds  perigo %4.1f  %s" % [stage.id, int(stage.duration_seconds), total, ", ".join(names)])


## Preenchimento aleatório leve (só inimigos simples), bem mais raro que as ondas.
func _set_filler(stage: StageData, c: int, s: int, d: float) -> void:
	var enemies: Array[EnemyData] = [_e["drone"]]
	var weights := PackedFloat32Array([3.0])
	if c > 0 or s >= 1:
		enemies.append(_e["aimer"])
		weights.append(1.0 if c == 0 else 1.5)
	if c > 0 or s >= 2:
		enemies.append(_e["kamikaze"])
		weights.append(1.0 if c == 0 else 1.5)
	if c >= 3:
		enemies.append(_e["hunter"])
		weights.append(0.7)
	stage.enemies = enemies
	stage.spawn_weights = weights
	stage.spawn_interval_min = maxf(2.6 - 0.36 * d, 1.1)
	stage.spawn_interval_max = maxf(3.8 - 0.45 * d, 1.7)
	stage.spawn_margin_x = 90.0


## Linha do tempo: um motivo a cada intervalo, em ciclo; perto do fim, dois de uma vez.
func _compose(c: int, s: int, d: float, duration: float) -> Array[WaveData]:
	var chosen: Array[Dictionary] = _choose_motifs(c, s)
	_log_stage(_current_stage, chosen)
	var gap: float = GAP_BASE - GAP_PER_DIFFICULTY * d
	var bonus: int = int(d / COUNT_STEP)
	var waves: Array[WaveData] = []
	var t: float = 4.0
	var i: int = 0
	var climax_at: float = duration - 16.0
	var climax_done: bool = s == MIDBOSS_STAGE or duration < 70.0
	while t < duration - 6.0:
		var motif: Dictionary = chosen[i % chosen.size()]
		var cycle: int = i / chosen.size()
		var level: int = cycle + bonus
		var mirrored: bool = cycle % 2 == 1
		waves.append_array((motif["build"] as Callable).call(t, level, mirrored))
		# Duplas nos capítulos finais e o clímax: um motivo leve junto com o atual
		var pair_every: int = 2 if d >= PAIR_OFTEN_FROM else 3
		var pair: bool = d >= PAIR_FROM and i % pair_every == pair_every - 1 and s != MIDBOSS_STAGE
		if not climax_done and t >= climax_at:
			climax_done = true
			pair = true
		if pair:
			var partner: Dictionary = _light_partner(chosen, motif)
			waves.append_array((partner["build"] as Callable).call(t + 1.5, level, not mirrored))
		t += gap + (3.0 if motif["heavy"] else 0.0)
		i += 1
	return waves


## Escolhe os motivos da fase: o do inimigo novo do capítulo nas primeiras fases,
## pesados conforme o avanço e o resto entre os leves disponíveis.
func _choose_motifs(c: int, s: int) -> Array[Dictionary]:
	var count: int = 3 if s == MIDBOSS_STAGE else MOTIFS_PER_STAGE
	var heavy_budget: int = 0
	if c > 0 and s != MIDBOSS_STAGE:
		heavy_budget = 1
		if c >= 3 or (s != BOSS_STAGE and (s >= 5 or (c >= 2 and s >= 3))):
			heavy_budget = 2
		if c >= 4 and s >= 5 and s != BOSS_STAGE:
			heavy_budget = 3
	var available: Array[Dictionary] = []
	for motif in _motifs:
		if motif["chapter"] < c or (motif["chapter"] == c and motif["stage"] <= s):
			available.append(motif)
	var chosen: Array[Dictionary] = []
	# Inimigo mais novo do capítulo entra na fase em que aparece e nas duas seguintes
	if s <= 2:
		var newest: Dictionary = {}
		for motif in available:
			if motif["intro"] and motif["chapter"] == c and (newest.is_empty() or motif["stage"] > newest["stage"]):
				newest = motif
		if not newest.is_empty():
			chosen.append(newest)
			if newest["heavy"]:
				heavy_budget -= 1
	var budget: float = DANGER_BASE + DANGER_PER_CHAPTER * c + DANGER_PER_STAGE * s
	if s == MIDBOSS_STAGE:
		budget *= DANGER_MIDBOSS
	elif s == BOSS_STAGE:
		budget *= DANGER_BOSS
	while chosen.size() < count:
		var pool: Array[Dictionary] = []
		for motif in available:
			if motif in chosen:
				continue
			if motif["heavy"] and heavy_budget <= 0:
				continue
			pool.append(motif)
		if pool.is_empty():
			break
		# Perigo médio que falta por espaço: prefere motivos perto dele
		var spent: float = 0.0
		for motif in chosen:
			spent += motif["danger"]
		var desired: float = (budget - spent) / (count - chosen.size())
		var pick: Dictionary = _weighted_pick(pool, c, desired)
		chosen.append(pick)
		if pick["heavy"]:
			heavy_budget -= 1
	return chosen


func _weighted_pick(pool: Array[Dictionary], c: int, desired: float) -> Dictionary:
	var total: float = 0.0
	var weights := PackedFloat32Array()
	for motif in pool:
		# Motivos do capítulo atual aparecem mais (identidade do capítulo); os antigos, menos
		var age: int = c - int(motif["chapter"])
		var weight: float = motif["weight"] * (2.0 if age == 0 else pow(OLD_MOTIF_DECAY, age))
		weight *= exp(-absf(motif["danger"] - desired) / 0.8)
		weights.append(weight)
		total += weight
	var roll: float = _rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool.back()


func _light_partner(chosen: Array[Dictionary], current: Dictionary) -> Dictionary:
	for motif in chosen:
		if motif != current and not motif["heavy"]:
			return motif
	return _motifs[0]


## Motivo: padrão de onda que se repete na fase. chapter/stage = quando passa a existir.
func _motif(name: String, chapter: int, stage: int, weight: float, danger: float, heavy: bool, intro: bool, build: Callable) -> void:
	_motifs.append({"name": name, "chapter": chapter, "stage": stage, "weight": weight, "danger": danger,
		"heavy": heavy, "build": build, "intro": intro})


func _wave(t: float, enemy: String, formation: WaveData.Formation, count: int, props: Dictionary = {}) -> WaveData:
	var wave := WaveData.new()
	wave.time_seconds = snappedf(t, 0.1)
	wave.enemy = _e[enemy]
	wave.formation = formation
	wave.count = count
	for key: String in props:
		wave.set(key, props[key])
	return wave


static func _side(mirrored: bool) -> WaveData.EntrySide:
	return WaveData.EntrySide.RIGHT if mirrored else WaveData.EntrySide.LEFT


static func _x(x: float, mirrored: bool) -> float:
	return 1.0 - x if mirrored else x


func _define_motifs() -> void:
	# --- Capítulo 1: drones, Miradores e kamikazes ---
	_motif("drone_line", 0, 0, 1.0, 1.0, false, false, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "drone", WaveData.Formation.LINE, mini(4 + l, 7), {"spacing": 165.0})])
	_motif("drone_snake", 0, 0, 1.4, 1.2, false, false, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "drone", WaveData.Formation.COLUMN, mini(5 + l, 8), {"x_ratio": _x(0.3, m), "interval": 0.42,
			"sway_amplitude": 150.0, "sway_period": 2.6})])
	_motif("drone_diagonal", 0, 0, 1.2, 1.1, false, false, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "drone", WaveData.Formation.DIAGONAL, mini(5 + l, 8), {"spacing": 125.0, "side": _side(m)})])
	_motif("drone_grid", 0, 0, 1.0, 1.5, false, false, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		var columns: int = 3 if l == 0 else 4
		return [_wave(t, "drone", WaveData.Formation.GRID, columns * 2, {"columns": columns, "spacing": 160.0, "speed_scale": 0.85})])
	_motif("drone_circle", 0, 3, 0.8, 1.5, false, false, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "drone", WaveData.Formation.CIRCLE, 8, {"spacing": 170.0, "speed_scale": 0.8})])
	_motif("aimer_side", 0, 1, 1.2, 2.0, false, true, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "aimer", WaveData.Formation.SIDE, mini(3 + l, 6), {"side": _side(m), "interval": 0.55, "y_ratio": 0.14})])
	_motif("aimer_arc", 0, 3, 1.0, 2.2, false, false, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "aimer", WaveData.Formation.COLUMN, mini(3 + l, 5), {"x_ratio": _x(0.12, m), "interval": 0.5,
			"curve_degrees": 100.0 if m else -100.0, "curve_seconds": 1.6, "curve_delay": 0.6})])
	_motif("kamikaze_v", 0, 2, 1.2, 2.2, false, true, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "kamikaze", WaveData.Formation.V, mini(5 + 2 * l, 9), {"spacing": 100.0, "dive_stagger": 0.15})])
	_motif("kamikaze_column", 0, 5, 0.8, 2.0, false, false, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "kamikaze", WaveData.Formation.COLUMN, mini(5 + l, 8), {"x_ratio": _x(0.35, m), "interval": 0.32})])
	# --- Capítulo 2: Tanques ---
	_motif("tank_solo", 1, 0, 1.0, 2.5, true, true, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "tank", WaveData.Formation.LINE, 1)])
	_motif("tank_escort", 1, 2, 1.0, 3.2, true, false, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "tank", WaveData.Formation.LINE, 1),
			_wave(t + 0.5, "drone", WaveData.Formation.COLUMN, 4, {"x_ratio": 0.14, "interval": 0.45}),
			_wave(t + 0.5, "drone", WaveData.Formation.COLUMN, 4, {"x_ratio": 0.86, "interval": 0.45})])
	_motif("tank_pair", 1, 6, 0.8, 4.2, true, false, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "tank", WaveData.Formation.LINE, 2, {"spacing": 460.0})])
	_motif("kamikaze_pincer", 1, 0, 1.2, 2.6, false, false, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "kamikaze", WaveData.Formation.PINCER, mini(6 + 2 * l, 10), {"x_ratio": 0.18, "interval": 0.4, "dive_stagger": 0.0})])
	_motif("aimer_crossfire", 1, 1, 1.0, 3.0, false, false, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "aimer", WaveData.Formation.SIDE, mini(4 + l, 7), {"side": WaveData.EntrySide.BOTH, "interval": 0.5, "y_ratio": 0.18})])
	_motif("drone_twin_snake", 1, 3, 1.0, 1.6, false, false, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "drone", WaveData.Formation.COLUMN, mini(4 + l, 7), {"x_ratio": 0.25, "interval": 0.45, "sway_amplitude": 120.0, "sway_period": 2.4}),
			_wave(t, "drone", WaveData.Formation.COLUMN, mini(4 + l, 7), {"x_ratio": 0.75, "interval": 0.45, "sway_amplitude": 120.0, "sway_period": 2.4})])
	# --- Capítulo 3: Atiradores ---
	_motif("spreader_pair", 2, 0, 1.0, 3.6, true, true, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "spreader", WaveData.Formation.LINE, 2, {"spacing": 540.0})])
	_motif("spreader_trio", 2, 4, 0.8, 4.6, true, false, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "spreader", WaveData.Formation.LINE, 3, {"spacing": 320.0})])
	_motif("drone_wave_line", 2, 1, 1.0, 1.6, false, false, func(t: float, l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "drone", WaveData.Formation.LINE, mini(5 + l, 7), {"spacing": 150.0, "sway_amplitude": 90.0,
			"sway_period": 2.2, "sway_phase_step": 0.6})])
	# --- Capítulo 4: Caçadores e Semeadores ---
	_motif("hunter_side", 3, 0, 1.2, 3.0, false, true, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "hunter", WaveData.Formation.SIDE, mini(3 + l, 5), {"side": _side(m), "interval": 0.6, "y_ratio": 0.16})])
	_motif("splitter_solo", 3, 1, 1.0, 3.0, true, true, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "splitter", WaveData.Formation.LINE, 1)])
	_motif("splitter_pair", 3, 5, 0.8, 4.6, true, false, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "splitter", WaveData.Formation.LINE, 2, {"spacing": 520.0})])
	_motif("hunter_arc", 3, 3, 0.8, 3.0, false, false, func(t: float, l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "hunter", WaveData.Formation.COLUMN, mini(3 + l, 4), {"x_ratio": _x(0.12, m), "interval": 0.6,
			"curve_degrees": 100.0 if m else -100.0, "curve_seconds": 1.6, "curve_delay": 0.6})])
	# --- Capítulo 5: Pulsares e Fissores ---
	_motif("fissor_line", 4, 0, 1.2, 3.2, true, true, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "fissor", WaveData.Formation.LINE, 3, {"spacing": 300.0})])
	_motif("pulsar_solo", 4, 1, 1.0, 3.6, true, true, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "pulsar", WaveData.Formation.LINE, 1)])
	_motif("pulsar_pair", 4, 5, 0.8, 5.2, true, false, func(t: float, _l: int, _m: bool) -> Array[WaveData]:
		return [_wave(t, "pulsar", WaveData.Formation.LINE, 2, {"spacing": 560.0})])
	_motif("fissor_diagonal", 4, 3, 1.0, 3.6, false, false, func(t: float, _l: int, m: bool) -> Array[WaveData]:
		return [_wave(t, "fissor", WaveData.Formation.DIAGONAL, 4, {"spacing": 170.0, "side": _side(m)})])
