class_name Boss
extends Enemy
## Chefe do fim do capítulo: entra (descendo, surgindo do espaço ou despencando), balança de um
## lado para o outro e troca de padrão de ataque conforme a vida cai (BossData.phases). Os
## ataques únicos (signature) entram nas fases finais: investida, varredura e tropas.
## Não vem de pool: é criado pela partida e entra na colisão por CombatContext.boss.

signal phase_changed(index: int)

var boss_data: BossData
var spawn_wave: Callable  # (WaveData) -> void, para os ataques SUMMON
var spawn_troops: Callable  # (EnemyData, origem, quantidade, trajetória) -> void, para TROOPS
signal entered  # terminou a entrada (a partida mostra o nome e começa a luta)

var _phase: int = -1
var _timers := PackedFloat32Array()
var _bursts := PackedInt32Array()
var _ring_angles := PackedFloat32Array()
# Telegrafia por ataque: segundos restantes do aviso (< 0 = nenhum), duração, dados travados
var _attack_tele_left := PackedFloat32Array()
var _attack_tele_total := PackedFloat32Array()
var _locked: Array[Dictionary] = []  # {dirs: PackedVector2Array, ...} do disparo avisado
var _streamed := PackedByteArray()  # fluxo contínuo (intervalo menor que o aviso) já avisado
var _lasers: Array[Dictionary] = []  # {x, width, left, total, color} ligados agora
var _clock: float = 0.0
var _entering: bool = true
var _center_x: float = 0.0
var _hold_y: float = 0.0
var _entry_t: float = 0.0
var _drop_speed: float = 0.0
var _impact_left: float = 0.0  # onda de impacto ao terminar a entrada
var _charge: Dictionary = {}  # {target, back, speed, attack}
var _sweeps: Array[Dictionary] = []  # {angle, rate, left, width, color}


func _ready() -> void:
	# Diferente dos itens de pool, começa ativo após setup()
	pass


func setup(data: BossData, bullet_pool: NodePool, combat_context: CombatContext, wave_spawner: Callable) -> void:
	boss_data = _tuned(data)
	bullets = bullet_pool
	context = combat_context
	spawn_wave = wave_spawner
	hp = boss_data.max_hp
	radius = data.radius
	var rect: Rect2 = get_viewport_rect()
	_center_x = rect.get_center().x
	_hold_y = rect.position.y + rect.size.y * data.hold_y_ratio
	position = Vector2(_center_x, rect.position.y - radius)
	match data.entry:
		BossData.Entry.WARP:
			position = Vector2(_center_x, _hold_y)
			scale = Vector2.ONE * 0.05
			modulate.a = 0.0
		BossData.Entry.DROP:
			position = Vector2(_center_x, rect.position.y - radius * 3.0)
	queue_redraw()
	_set_active()


## Cópia do chefe com a dificuldade do balanceamento: vida, cadência por capítulo e uma fase
## final de fúria (cópia da última, com ataques mais rápidos). O recurso original não muda.
static func _tuned(data: BossData) -> BossData:
	var balance: BalanceData = Params.balance
	var tuned: BossData = data.duplicate()
	var mini: bool = String(data.id).begins_with("mini")
	tuned.max_hp = roundi(data.max_hp * (balance.miniboss_hp_multiplier if mini else balance.boss_hp_multiplier))
	var chapter: int = clampi(Session.planet_index, 0, balance.boss_interval_by_chapter.size() - 1)
	var interval_scale: float = balance.boss_interval_by_chapter[chapter] if not balance.boss_interval_by_chapter.is_empty() else 1.0
	var phases: Array[BossPhase] = []
	for i in data.phases.size():
		var phase: BossPhase = _with_signature(data, data.phases[i], i)
		phases.append(_scaled_phase(phase, interval_scale, 1.0, 1.0, phase.special_moment))
	if balance.boss_enrage_ratio > 0.0 and not data.phases.is_empty():
		var last: BossPhase = _with_signature(data, data.phases.back(), data.phases.size() - 1)
		if last.hp_ratio > balance.boss_enrage_ratio:
			var enrage := _scaled_phase(last, interval_scale * balance.boss_enrage_interval_scale,
					balance.boss_enrage_bullet_speed_scale, balance.boss_enrage_sway_scale, false)
			enrage.hp_ratio = balance.boss_enrage_ratio
			phases.append(enrage)
	tuned.phases = phases
	return tuned


## Fase com os ataques únicos do chefe somados (a partir de signature_from_phase).
static func _with_signature(data: BossData, phase: BossPhase, index: int) -> BossPhase:
	if data.signature.is_empty() or index < data.signature_from_phase:
		return phase
	var copy: BossPhase = phase.duplicate()
	var attacks: Array[BossAttack] = phase.attacks.duplicate()
	attacks.append_array(data.signature)
	copy.attacks = attacks
	return copy


static func _scaled_phase(phase: BossPhase, interval_scale: float, speed_scale: float, sway_scale: float, moment: bool) -> BossPhase:
	var copy: BossPhase = phase.duplicate()
	copy.special_moment = moment
	copy.sway_speed_scale = phase.sway_speed_scale * sway_scale
	var attacks: Array[BossAttack] = []
	for attack in phase.attacks:
		var changed: BossAttack = attack.duplicate()
		# Só ataques em intervalos (fluxos contínuos curtos mantêm o ritmo e o aviso)
		if attack.interval >= 1.0:
			changed.interval = attack.interval * interval_scale
		changed.bullet_speed = attack.bullet_speed * speed_scale
		attacks.append(changed)
	copy.attacks = attacks
	return copy


func is_entering() -> bool:
	return _entering


func health_ratio() -> float:
	return clampf(float(hp) / boss_data.max_hp, 0.0, 1.0)


func contact_damage() -> int:
	return boss_data.contact_damage


func points() -> int:
	return boss_data.score


func tint() -> Color:
	return boss_data.color


## Encostar no chefe tira hits da nave, mas não destrói o chefe.
func on_player_contact() -> void:
	pass


func _hit_sound() -> StringName:
	return &"boss_hit"


func take_damage(amount: float, source: int = SOURCE_NONE, from: Vector2 = Vector2.INF) -> void:
	# Invulnerável enquanto entra na tela
	if _entering:
		return
	var dealt: float = amount * context.boosts.boss_damage
	Haptics.boss_damage(dealt / maxf(boss_data.max_hp, 1.0))
	super(dealt, source, from)


func _damage_multiplier(_source: int) -> float:
	return 1.0


func _process(delta: float) -> void:
	_clock += delta
	_update_flash(delta)
	_impact_left = maxf(_impact_left - delta, 0.0)
	if _entering:
		_update_entry(delta)
		queue_redraw()
		return

	_update_phase()
	_update_lasers(delta)
	_update_sweeps(delta)
	var phase: BossPhase = boss_data.phases[_phase]
	if _charge.is_empty():
		_move(phase, delta)
	else:
		_update_charge(delta)
	for i in phase.attacks.size():
		_timers[i] -= delta
		var attack: BossAttack = phase.attacks[i]
		if _bursts[i] == attack.burst and _attack_tele_left[i] < 0.0 and _locked[i].is_empty() and _timers[i] <= attack.telegraph_seconds:
			_start_attack_telegraph(i, attack)
		if _attack_tele_left[i] >= 0.0:
			_attack_tele_left[i] = maxf(_timers[i], 0.0)
		if _timers[i] > 0.0:
			continue
		_attack(i, attack)
		_attack_tele_left[i] = -1.0
		# Rajada: os próximos disparos vêm logo em seguida (com a mira travada no aviso)
		if _bursts[i] > 1:
			_bursts[i] -= 1
			_timers[i] += attack.burst_gap
		else:
			_bursts[i] = attack.burst
			_timers[i] += attack.interval
			_locked[i] = {}
	queue_redraw()


## Entrada: descendo, surgindo do espaço (cresce e aparece) ou despencando (acelera e freia).
func _update_entry(delta: float) -> void:
	match boss_data.entry:
		BossData.Entry.WARP:
			_entry_t = minf(_entry_t + delta / maxf(boss_data.entry_seconds, 0.1), 1.0)
			scale = Vector2.ONE * maxf(_ease_back(_entry_t), 0.05)
			modulate.a = minf(_entry_t * 2.0, 1.0)
			if _entry_t >= 1.0:
				_finish_entry()
		BossData.Entry.DROP:
			_drop_speed += Params.boss_drop_accel * delta
			position.y = minf(position.y + _drop_speed * delta, _hold_y)
			if position.y >= _hold_y:
				_finish_entry()
		_:
			position.y = move_toward(position.y, _hold_y, boss_data.entry_speed * delta)
			if position.y >= _hold_y:
				_finish_entry()


func _finish_entry() -> void:
	_entering = false
	_clock = 0.0
	scale = Vector2.ONE
	modulate.a = 1.0
	if boss_data.entry != BossData.Entry.DESCEND:
		_impact_left = Params.boss_impact_seconds
		Audio.play(&"bomb_global", -4.0)
		Haptics.play(&"explosao_grande")
	entered.emit()


## Passa um pouco do tamanho final e volta (surgimento com "estalo").
static func _ease_back(t: float) -> float:
	var c: float = 1.7
	var u: float = t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u


## Investida: vai até o alvo, solta o anel do impacto e volta para a altura de sempre.
func _update_charge(delta: float) -> void:
	var target: Vector2 = _charge["target"]
	position = position.move_toward(target, float(_charge["speed"]) * delta)
	if position.distance_to(target) > 1.0:
		return
	if not _charge["back"]:
		var attack: BossAttack = _charge["attack"]
		for i in attack.count:
			_shoot_bullet(Vector2.from_angle(TAU * i / maxf(attack.count, 1.0)), attack)
		_impact_left = Params.boss_impact_seconds
		Audio.play(&"boss_explode", -8.0, 1.6)
		Haptics.play(&"explosao_grande")
		_charge["back"] = true
		_charge["target"] = Vector2(position.x, _hold_y)
		_charge["speed"] = float(_charge["speed"]) * 0.5
	else:
		_charge = {}


func _update_sweeps(delta: float) -> void:
	for i in range(_sweeps.size() - 1, -1, -1):
		_sweeps[i]["angle"] += float(_sweeps[i]["rate"]) * delta
		_sweeps[i]["left"] -= delta
		if _sweeps[i]["left"] <= 0.0:
			_sweeps.remove_at(i)


func _move(phase: BossPhase, delta: float) -> void:
	var t: float = _clock * boss_data.sway_speed * phase.sway_speed_scale
	match phase.movement:
		BossPhase.Movement.SWAY:
			position.x = move_toward(position.x, _center_x + sin(t) * boss_data.sway_amplitude, phase.chase_speed * 2.0 * delta)
			position.y = move_toward(position.y, _hold_y, phase.chase_speed * delta)
		BossPhase.Movement.FIGURE8:
			var goal := Vector2(_center_x + sin(t) * boss_data.sway_amplitude, _hold_y + sin(t * 2.0) * boss_data.sway_amplitude * 0.3)
			position = position.move_toward(goal, phase.chase_speed * 2.0 * delta)
		BossPhase.Movement.CHASE:
			var player: Player = context.player
			var goal_x: float = player.position.x if player != null else _center_x
			var rect: Rect2 = get_viewport_rect()
			goal_x = clampf(goal_x, rect.position.x + radius, rect.end.x - radius)
			position.x = move_toward(position.x, goal_x, phase.chase_speed * delta)
			position.y = move_toward(position.y, _hold_y, phase.chase_speed * delta)


## A fase ativa é a última cujo hp_ratio ainda está acima da vida atual.
func _update_phase() -> void:
	var ratio: float = health_ratio()
	var index: int = 0
	for i in boss_data.phases.size():
		if ratio <= boss_data.phases[i].hp_ratio:
			index = i
	if index == _phase:
		return
	_phase = index
	armored = boss_data.phases[index].special_moment
	var attacks: Array[BossAttack] = boss_data.phases[index].attacks
	_timers.resize(attacks.size())
	_bursts.resize(attacks.size())
	_ring_angles.resize(attacks.size())
	_attack_tele_left.resize(attacks.size())
	_attack_tele_total.resize(attacks.size())
	_streamed.resize(attacks.size())
	_locked.resize(attacks.size())
	for i in attacks.size():
		_timers[i] = attacks[i].first_delay
		_bursts[i] = attacks[i].burst
		_ring_angles[i] = 0.0
		_attack_tele_left[i] = -1.0
		_streamed[i] = 0
		_locked[i] = {}
	phase_changed.emit(index)


## Aviso do ataque: trava a mira. Fluxo contínuo (intervalo menor que o aviso) só avisa no começo.
func _start_attack_telegraph(index: int, attack: BossAttack) -> void:
	var stream: bool = attack.interval < attack.telegraph_seconds and attack.burst <= 1
	if stream and _streamed[index] == 1:
		_locked[index] = {"stream": true}
		return
	_streamed[index] = 1 if stream else 0
	var seconds: float = maxf(_timers[index], 0.0)
	_attack_tele_total[index] = maxf(seconds, 0.01)
	_attack_tele_left[index] = seconds
	_locked[index] = _lock(index, attack)
	Audio.play(&"boss_warning", Params.telegraph_sound_db - 6.0, 1.3)


## Dados travados no aviso: direções, x do laser, brecha da cortina, pontos da chuva.
func _lock(index: int, attack: BossAttack) -> Dictionary:
	var rect: Rect2 = get_viewport_rect()
	match attack.pattern:
		BossAttack.Pattern.LASER:
			var player: Player = context.player
			var x: float = player.position.x if attack.aimed and player != null else position.x
			return {"x": clampf(x, rect.position.x + attack.laser_width * 0.5, rect.end.x - attack.laser_width * 0.5)}
		BossAttack.Pattern.CURTAIN:
			var margin: float = attack.gap_width * 0.5 + 40.0
			var gap: float = randf_range(rect.position.x + margin, rect.end.x - margin)
			var xs := PackedFloat32Array()
			for i in attack.count:
				var x: float = rect.position.x + (i + 0.5) * rect.size.x / attack.count
				if absf(x - gap) > attack.gap_width * 0.5:
					xs.append(x)
			return {"gap": gap, "xs": xs}
		BossAttack.Pattern.RAIN:
			var xs := PackedFloat32Array()
			for i in attack.count:
				xs.append(randf_range(rect.position.x + 60.0, rect.end.x - 60.0))
			return {"xs": xs}
		BossAttack.Pattern.CHARGE:
			var player: Player = context.player
			var x: float = player.position.x if player != null else position.x
			x = clampf(x, rect.position.x + radius, rect.end.x - radius)
			var y: float = rect.position.y + rect.size.y * Params.boss_charge_depth
			return {"x": x, "charge_y": y}
		BossAttack.Pattern.SWEEP:
			var player: Player = context.player
			var aim: float = PI * 0.5
			if attack.aimed and player != null:
				aim = (player.position - position).angle()
			var direction: float = 1.0 if randf() < 0.5 else -1.0
			return {"angle": aim - deg_to_rad(attack.sweep_degrees) * 0.5 * direction, "direction": direction}
	return {"dirs": _boss_attack_dirs(index, attack)}


func _boss_attack_dirs(index: int, attack: BossAttack) -> PackedVector2Array:
	var dirs := PackedVector2Array()
	match attack.pattern:
		BossAttack.Pattern.FAN, BossAttack.Pattern.BIG_SLOW, BossAttack.Pattern.MINES:
			var aim: float = PI * 0.5
			var player: Player = context.player
			if attack.aimed and player != null:
				aim = (player.position - position).angle()
			var spread: float = deg_to_rad(attack.spread_degrees)
			for i in attack.count:
				var t: float = 0.0 if attack.count == 1 else float(i) / (attack.count - 1) - 0.5
				dirs.append(Vector2.from_angle(aim + spread * t))
		BossAttack.Pattern.RING:
			for i in attack.count:
				dirs.append(Vector2.from_angle(_ring_angles[index] + TAU * i / attack.count))
	return dirs


func _attack(index: int, attack: BossAttack) -> void:
	var locked: Dictionary = _locked[index]
	if not (locked.has("dirs") or locked.has("x") or locked.has("xs") or locked.has("angle")):
		locked = _lock(index, attack)
	var top: float = get_viewport_rect().position.y + 10.0
	match attack.pattern:
		BossAttack.Pattern.FAN, BossAttack.Pattern.BIG_SLOW:
			for dir in locked["dirs"]:
				_shoot_bullet(dir, attack)
		BossAttack.Pattern.MINES:
			for dir in locked["dirs"]:
				var mine: Bullet = _shoot_bullet(dir, attack)
				if mine != null:
					mine.drag = attack.mine_drag
		BossAttack.Pattern.LASER:
			_lasers.append({"x": locked["x"], "width": attack.laser_width, "left": attack.laser_seconds,
				"total": attack.laser_seconds, "color": attack.bullet_color})
			Audio.play(&"shot_beam", 2.0, 0.6)
		BossAttack.Pattern.CURTAIN, BossAttack.Pattern.RAIN:
			for x in locked["xs"]:
				_spawn_bullet(Vector2(x, top), Vector2.DOWN, attack)
		BossAttack.Pattern.RING:
			for dir in _boss_attack_dirs(index, attack):
				_shoot_bullet(dir, attack)
			_ring_angles[index] += deg_to_rad(attack.turn_degrees)
		BossAttack.Pattern.SUMMON:
			if attack.wave != null and spawn_wave.is_valid():
				spawn_wave.call(attack.wave)
		BossAttack.Pattern.CHARGE:
			if _charge.is_empty():
				_charge = {"target": Vector2(locked["x"], locked["charge_y"]), "back": false,
					"speed": attack.charge_speed, "attack": attack}
				Audio.play(&"shot_missile", 2.0, 0.5)
		BossAttack.Pattern.SWEEP:
			var arc: float = deg_to_rad(attack.sweep_degrees)
			_sweeps.append({"angle": locked["angle"], "rate": arc / maxf(attack.laser_seconds, 0.1) * float(locked["direction"]),
				"left": attack.laser_seconds, "width": attack.laser_width, "color": attack.bullet_color})
			Audio.play(&"shot_beam", 2.0, 0.5)
		BossAttack.Pattern.TROOPS:
			if attack.troop != null and spawn_troops.is_valid():
				spawn_troops.call(attack.troop, position, attack.count, attack.troop_path)


func _shoot_bullet(direction: Vector2, attack: BossAttack) -> Bullet:
	return _spawn_bullet(position + direction * radius * 0.8, direction, attack)


func _spawn_bullet(origin: Vector2, direction: Vector2, attack: BossAttack) -> Bullet:
	var bullet := bullets.acquire() as Bullet
	if bullet == null:
		return null
	var size := Vector2.ONE * attack.bullet_radius * 2.0
	bullet.activate(origin, direction * attack.bullet_speed, 1, size, attack.bullet_color, Bullet.Shape.CIRCLE)
	if attack.split_time > 0.0:
		bullet.add_split(attack.split_time, attack.split_count, attack.split_speed, attack.split_radius, bullets)
	if attack.homing_time > 0.0:
		bullet.add_limited_homing(attack.homing_time, attack.homing_turn_degrees, _find_player)
	return bullet


func _update_lasers(delta: float) -> void:
	for i in range(_lasers.size() - 1, -1, -1):
		_lasers[i]["left"] -= delta
		if _lasers[i]["left"] <= 0.0:
			_lasers.remove_at(i)


## Perigos que não são tiros (laser ligado): o ponto (com raio r) está dentro de algum?
func hazard_hits(point: Vector2, r: float) -> bool:
	for laser in _lasers:
		if point.y > position.y and absf(point.x - float(laser["x"])) <= float(laser["width"]) * 0.5 + r:
			return true
	for sweep in _sweeps:
		var dir := Vector2.from_angle(float(sweep["angle"]))
		var rel: Vector2 = point - position
		if rel.dot(dir) > radius * 0.5 and absf(rel.cross(dir)) <= float(sweep["width"]) * 0.5 + r:
			return true
	return false


## Faixas de laser ligadas ou avisadas (x, largura), para o piloto automático do simulador.
func laser_bands() -> Array[Vector2]:
	var bands: Array[Vector2] = []
	for laser in _lasers:
		bands.append(Vector2(laser["x"], laser["width"]))
	if _phase >= 0:
		var attacks: Array[BossAttack] = boss_data.phases[_phase].attacks
		for i in mini(attacks.size(), _locked.size()):
			if attacks[i].pattern == BossAttack.Pattern.LASER and _locked[i].has("x"):
				bands.append(Vector2(_locked[i]["x"], attacks[i].laser_width))
	return bands


func _draw() -> void:
	var flash: bool = _flash_left > 0.0
	var color: Color = Color.WHITE if flash else boss_data.color
	var accent: Color = Color.WHITE if flash else boss_data.accent_color
	var fury: float = clampf(float(_phase) / maxf(boss_data.phases.size() - 1, 1.0), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_clock * (3.0 + fury * 6.0))
	_draw_entry_fx()
	# Aura
	draw_circle(Vector2.ZERO, radius * (1.35 + 0.06 * pulse), Color(color, 0.12 + 0.08 * fury))
	# Espinhos (giram devagar ao contrário das placas)
	for i in boss_data.spikes:
		var a: float = TAU * i / boss_data.spikes - _clock * 0.25
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * radius * 0.16
		draw_colored_polygon(PackedVector2Array([dir * radius * 0.8 + side, dir * radius * 1.38, dir * radius * 0.8 - side]), color.darkened(0.3))
	# Placas de blindagem em volta
	for i in boss_data.plates:
		var a0: float = TAU * i / boss_data.plates + _clock * (0.6 + fury)
		var a1: float = a0 + TAU / boss_data.plates * 0.62
		var plate := PackedVector2Array([
			Vector2.from_angle(a0) * radius * 0.92, Vector2.from_angle(a0) * radius * 1.18,
			Vector2.from_angle(a1) * radius * 1.18, Vector2.from_angle(a1) * radius * 0.92])
		draw_colored_polygon(plate, accent.darkened(0.35))
		draw_polyline(plate, accent, 3.0)
	# Casco
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in boss_data.sides:
		var angle: float = PI * 0.5 + TAU * i / boss_data.sides
		outer.append(Vector2.from_angle(angle) * radius)
		inner.append(Vector2.from_angle(angle + _clock * 0.8) * radius * 0.6)
	draw_colored_polygon(outer, color)
	draw_colored_polygon(inner, color.darkened(0.45))
	_draw_cracks()
	# Torretas que miram na nave
	var player: Player = context.player if context != null else null
	for i in boss_data.turrets:
		var spot := Vector2.from_angle(PI * 0.5 + TAU * (i + 0.5) / boss_data.turrets) * radius * 0.72
		var aim := Vector2.DOWN
		if player != null:
			aim = (to_local(player.global_position) - spot).normalized()
		draw_line(spot, spot + aim * radius * 0.3, accent.darkened(0.2), radius * 0.09)
		draw_circle(spot, radius * 0.12, accent)
	# Olho central: segue a nave e fica vermelho na fúria
	var eye_r: float = radius * 0.26
	draw_circle(Vector2.ZERO, eye_r * (1.15 + 0.1 * pulse), Color(accent, 0.5))
	draw_circle(Vector2.ZERO, eye_r, Color.WHITE)
	var look := Vector2.ZERO
	if player != null:
		look = to_local(player.global_position).normalized() * eye_r * 0.45
	draw_circle(look, eye_r * 0.45, Color(0.1, 0.05, 0.1).lerp(Color(0.9, 0.1, 0.15), fury))
	_draw_charge_telegraph()
	_draw_sweeps()
	_draw_lasers()
	_draw_armor()
	_draw_boss_telegraphs()


## Rachaduras no casco conforme a vida cai.
func _draw_cracks() -> void:
	var damage: float = 1.0 - health_ratio()
	var count: int = int(damage * 6.0)
	for i in count:
		var a: float = TAU * i / 6.0 + 0.4
		var p0 := Vector2.from_angle(a) * radius * 0.35
		var p1 := Vector2.from_angle(a + 0.25) * radius * 0.65
		var p2 := Vector2.from_angle(a - 0.1) * radius * 0.95
		draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.05, 0.02, 0.05, 0.85), 4.0)


## Surgimento do espaço (anéis convergindo) e onda de impacto ao terminar a entrada.
func _draw_entry_fx() -> void:
	if _entering and boss_data.entry == BossData.Entry.WARP:
		var inv: float = 1.0 / maxf(scale.x, 0.05)
		for k in 3:
			var t: float = fmod(_entry_t * 1.5 + k / 3.0, 1.0)
			draw_arc(Vector2.ZERO, radius * lerpf(4.0, 1.0, t) * inv, 0.0, TAU, 48, Color(boss_data.accent_color, (1.0 - t) * 0.8), 6.0 * inv)
	if _impact_left > 0.0:
		var t: float = 1.0 - _impact_left / Params.boss_impact_seconds
		draw_arc(Vector2.ZERO, radius * lerpf(1.0, 4.5, t), 0.0, TAU, 64, Color(boss_data.accent_color, 1.0 - t), 10.0 * (1.0 - t) + 2.0)
		draw_circle(Vector2.ZERO, radius * 1.5, Color(1, 1, 1, 0.35 * (1.0 - t)))


## Investida avisada: faixa da largura do chefe até onde ele vai bater.
func _draw_charge_telegraph() -> void:
	if _phase < 0:
		return
	var attacks: Array[BossAttack] = boss_data.phases[_phase].attacks
	for i in mini(attacks.size(), _attack_tele_left.size()):
		if attacks[i].pattern != BossAttack.Pattern.CHARGE or _attack_tele_left[i] < 0.0 or not _locked[i].has("x"):
			continue
		var t: float = 1.0 - clampf(_attack_tele_left[i] / _attack_tele_total[i], 0.0, 1.0)
		var x: float = to_local(Vector2(_locked[i]["x"], 0.0)).x
		var bottom: float = to_local(Vector2(0.0, float(_locked[i]["charge_y"]) + radius)).y
		Telegraph.draw_band(self, x, radius * 2.0, 0.0, bottom, attacks[i].bullet_color, t)


func _draw_sweeps() -> void:
	for sweep in _sweeps:
		var w: float = sweep["width"]
		var length: float = 3000.0
		var c: Color = sweep["color"]
		draw_set_transform(Vector2.ZERO, float(sweep["angle"]))
		draw_rect(Rect2(radius * 0.5, -w * 0.5, length, w), Color(c, 0.45))
		draw_rect(Rect2(radius * 0.5, -w * 0.2, length, w * 0.4), Color(c.lightened(0.6), 0.95))
		draw_set_transform(Vector2.ZERO, 0.0)


func _draw_lasers() -> void:
	var bottom: float = to_local(Vector2(0.0, get_viewport_rect().end.y)).y
	for laser in _lasers:
		var x: float = to_local(Vector2(laser["x"], 0.0)).x
		var w: float = laser["width"]
		var fade: float = clampf(float(laser["left"]) / 0.12, 0.0, 1.0)
		var pulse: float = 0.85 + 0.15 * sin(_clock * 40.0)
		draw_rect(Rect2(x - w * 0.5, 0.0, w, bottom), Color(laser["color"], 0.45 * fade))
		draw_rect(Rect2(x - w * 0.22 * pulse, 0.0, w * 0.44 * pulse, bottom), Color(Color(laser["color"]).lightened(0.6), 0.95 * fade))


func _draw_boss_telegraphs() -> void:
	if _phase < 0:
		return
	var attacks: Array[BossAttack] = boss_data.phases[_phase].attacks
	for i in mini(attacks.size(), _attack_tele_left.size()):
		if _attack_tele_left[i] < 0.0:
			continue
		var attack: BossAttack = attacks[i]
		var t: float = 1.0 - clampf(_attack_tele_left[i] / _attack_tele_total[i], 0.0, 1.0)
		var dirs: PackedVector2Array = _locked[i].get("dirs", PackedVector2Array())
		match attack.pattern:
			BossAttack.Pattern.RING:
				Telegraph.draw_ring(self, Vector2.ZERO, radius, attack.bullet_color, t)
			BossAttack.Pattern.SUMMON, BossAttack.Pattern.TROOPS:
				Telegraph.draw_ring(self, Vector2.ZERO, radius * 1.2, boss_data.color.lightened(0.4), t)
			BossAttack.Pattern.CHARGE:
				pass  # faixa desenhada em _draw_charge_telegraph
			BossAttack.Pattern.SWEEP:
				if _locked[i].has("angle"):
					var start := PackedVector2Array([Vector2.from_angle(float(_locked[i]["angle"]))])
					Telegraph.draw_lines(self, Vector2.ZERO, start, radius * 0.8, attack.bullet_color, t)
					var arc: float = deg_to_rad(attack.sweep_degrees) * float(_locked[i]["direction"])
					var a0: float = float(_locked[i]["angle"])
					draw_arc(Vector2.ZERO, radius * 1.6, minf(a0, a0 + arc), maxf(a0, a0 + arc), 32, Color(attack.bullet_color, Telegraph.alpha(t)), 4.0)
			BossAttack.Pattern.LASER:
				if _locked[i].has("x"):
					var top_local: float = to_local(Vector2(0.0, get_viewport_rect().position.y)).y
					var bottom_local: float = to_local(Vector2(0.0, get_viewport_rect().end.y)).y
					Telegraph.draw_band(self, to_local(Vector2(_locked[i]["x"], 0.0)).x, attack.laser_width, maxf(top_local, 0.0), bottom_local, attack.bullet_color, t)
			BossAttack.Pattern.CURTAIN, BossAttack.Pattern.RAIN:
				var y: float = to_local(Vector2(0.0, get_viewport_rect().position.y + 60.0)).y
				var points := PackedVector2Array()
				for x in _locked[i].get("xs", PackedFloat32Array()):
					points.append(Vector2(to_local(Vector2(x, 0.0)).x, y))
				Telegraph.draw_markers(self, points, attack.bullet_radius * 1.4, attack.bullet_color, t)
				if _locked[i].has("gap"):
					# Brecha da cortina: faixa clara onde dá para passar
					var gx: float = to_local(Vector2(_locked[i]["gap"], 0.0)).x
					var bottom_local: float = to_local(Vector2(0.0, get_viewport_rect().end.y)).y
					draw_rect(Rect2(gx - attack.gap_width * 0.5, y, attack.gap_width, bottom_local - y), Color(Params.telegraph_gap_color, 0.12 + 0.18 * t))
			_:
				if attack.bullet_radius >= Params.telegraph_big_radius and not dirs.is_empty():
					Telegraph.draw_orb(self, dirs[0] * radius, attack.bullet_radius, attack.bullet_color, t)
				Telegraph.draw_lines(self, Vector2.ZERO, dirs, radius * 0.8, attack.bullet_color, t)
