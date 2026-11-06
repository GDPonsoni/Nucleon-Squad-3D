class_name Boss
extends Enemy
## Chefe do fim do capítulo: entra pelo topo, balança de um lado para o outro e
## troca de padrão de ataque conforme a vida cai (BossData.phases).
## Não vem de pool: é criado pela partida e entra na colisão por CombatContext.boss.

signal phase_changed(index: int)

var boss_data: BossData
var spawn_wave: Callable  # (WaveData) -> void, para os ataques SUMMON

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
	for phase in data.phases:
		phases.append(_scaled_phase(phase, interval_scale, 1.0, 1.0, phase.special_moment))
	if balance.boss_enrage_ratio > 0.0 and not data.phases.is_empty():
		var last: BossPhase = data.phases.back()
		if last.hp_ratio > balance.boss_enrage_ratio:
			var enrage := _scaled_phase(last, interval_scale * balance.boss_enrage_interval_scale,
					balance.boss_enrage_bullet_speed_scale, balance.boss_enrage_sway_scale, false)
			enrage.hp_ratio = balance.boss_enrage_ratio
			phases.append(enrage)
	tuned.phases = phases
	return tuned


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
	if _entering:
		position.y = move_toward(position.y, _hold_y, boss_data.entry_speed * delta)
		if position.y >= _hold_y:
			_entering = false
			_clock = 0.0
		queue_redraw()
		return

	_update_phase()
	_update_lasers(delta)
	var phase: BossPhase = boss_data.phases[_phase]
	_move(phase, delta)
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
	if not (locked.has("dirs") or locked.has("x") or locked.has("xs")):
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
	var color: Color = Color.WHITE if _flash_left > 0.0 else boss_data.color
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var spin: float = _clock * 0.8
	for i in boss_data.sides:
		var angle: float = PI * 0.5 + TAU * i / boss_data.sides
		outer.append(Vector2.from_angle(angle) * radius)
		inner.append(Vector2.from_angle(angle + spin) * radius * 0.55)
	draw_colored_polygon(outer, color)
	draw_colored_polygon(inner, color.darkened(0.45))
	# Núcleo do chefe pulsa mais rápido nas fases finais
	var pulse: float = 0.5 + 0.5 * sin(_clock * (4.0 + _phase * 3.0))
	draw_circle(Vector2.ZERO, radius * 0.22, color.lightened(0.3 + pulse * 0.4))
	_draw_lasers()
	_draw_armor()
	_draw_boss_telegraphs()


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
			BossAttack.Pattern.SUMMON:
				Telegraph.draw_ring(self, Vector2.ZERO, radius * 1.2, boss_data.color.lightened(0.4), t)
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
