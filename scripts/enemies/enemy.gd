class_name Enemy
extends PoolItem
## Inimigo reutilizável: movimento e padrão de tiro vêm do EnemyData.

## Destruído pelo jogador (não emite ao sair da tela).
signal killed(enemy: Enemy)

const SOURCE_NONE: int = -1  # dano sem arma (contato, ferramentas)
const SOURCE_SPECIAL: int = 100  # especiais (ignoram multiplicadores e a blindagem dos momentos de especial)

var data: EnemyData
var hp: float = 0.0
var radius: float = 0.0
var bullets: NodePool  # projéteis inimigos
var context: CombatContext  # para mirar na nave
## Blindado (momento de especial): o dano normal é reduzido até levar um especial.
var armored: bool = false
var elite: bool = false  # modo roguelike: maior, com muito mais vida e aura (solta baú)
var crushed: bool = false  # destruído ao encostar na nave: não se divide (rochas, fissão)

var _velocity: Vector2
var _age: float = 0.0
var _entered: bool = false  # já apareceu na tela (antes disso não sai por "sair da tela")
var _fire_cooldown: float = 0.0
var _ring_angle: float = 0.0
var _flash_left: float = 0.0
var _flash_color: Color = Color.WHITE  # branco = normal; dourado = fraco contra a arma; cinza = resistente
var _spin: float = 0.0  # rad/s do desenho (rochas)
var _rock_shape := PackedVector2Array()  # contorno irregular sorteado (rochas)
var _max_hp: float = 0.0
var _since_hit: float = 0.0  # para a regeneração
var _block_left: float = 0.0  # escudo acabou de bloquear (brilho)
var _shield_angle: float = PI * 0.5  # direção para onde o escudo aponta (global)
var _shield_left: float = 0.0  # vida do escudo
var last_blocked: bool = false  # o último acerto foi bloqueado pelo escudo (a área passa)
var _hover_left: float = -1.0  # HOVER: < 0 = ainda descendo até a altura de parada
# Telegrafia: direções travadas no começo do aviso (o tiro sai exatamente onde a linha mostrou)
var _tele_left: float = -1.0  # < 0 = sem aviso em curso
var _tele_total: float = 0.0
var _tele_dirs := PackedVector2Array()
# Movimento da onda (WaveData): balanço lateral, curva e velocidade
var _speed_scale: float = 1.0
var _fire_scale: float = 1.0  # cadência de tiro da fase (StageData.enemy_fire_scale)
var _sway_amplitude: float = 0.0
var _sway_omega: float = 0.0
var _sway_phase: float = 0.0
var _curve_rate: float = 0.0  # rad/s
var _curve_delay: float = 0.0
var _curve_left: float = 0.0


## extra_delay atrasa o comportamento por tempo (ex.: mergulhos em sequência numa onda).
func activate(enemy_data: EnemyData, pos: Vector2, velocity: Vector2, extra_delay: float = 0.0) -> void:
	data = enemy_data
	hp = data.max_hp
	_max_hp = hp
	_since_hit = 0.0
	_block_left = 0.0
	_shield_angle = PI * 0.5
	_shield_left = data.shield_hp
	last_blocked = false
	radius = data.radius
	position = pos
	_velocity = velocity
	_age = -extra_delay
	_entered = false
	_fire_cooldown = data.first_shot_delay
	_ring_angle = 0.0
	_flash_left = 0.0
	_hover_left = -1.0
	_tele_left = -1.0
	_tele_dirs.resize(0)
	crushed = false
	armored = false
	elite = false
	_speed_scale = 1.0
	_fire_scale = 1.0
	_sway_amplitude = 0.0
	if data.sway_amplitude > 0.0 and data.sway_period > 0.0:
		_sway_amplitude = data.sway_amplitude
		_sway_omega = TAU / data.sway_period
		_sway_phase = randf() * TAU
	_curve_left = 0.0
	rotation = 0.0
	_spin = deg_to_rad(data.spin_degrees) * (1.0 if randf() < 0.5 else -1.0)
	if data.look == EnemyData.Look.ROCK:
		_build_rock_shape()
	queue_redraw()
	_set_active()


## Contorno de rocha: polígono com raios sorteados (cada rocha é diferente).
func _build_rock_shape() -> void:
	var points: int = Params.rock_points
	_rock_shape.resize(points)
	for i in points:
		var r: float = radius * randf_range(Params.rock_roughness, 1.08)
		_rock_shape[i] = Vector2.from_angle(TAU * i / points + randf_range(-0.2, 0.2)) * r


## Pode ser escolhido como alvo (mísseis, Tesla, ricochete, mira)? Rochas não.
func is_target() -> bool:
	return data == null or data.targetable


## Movimento comum da onda (chamar depois de activate). member = posição na onda.
func set_motion(wave: WaveData, member: int) -> void:
	_speed_scale = wave.speed_scale
	_velocity *= wave.speed_scale
	if wave.sway_amplitude > 0.0 and wave.sway_period > 0.0:
		_sway_amplitude = wave.sway_amplitude
		_sway_omega = TAU / wave.sway_period
		_sway_phase = wave.sway_phase_step * member
	if not is_zero_approx(wave.curve_degrees) and wave.curve_seconds > 0.0:
		_curve_rate = deg_to_rad(wave.curve_degrees) / wave.curve_seconds
		_curve_delay = wave.curve_delay
		_curve_left = wave.curve_seconds


## Escalas da fase: vida e cadência de tiro dos inimigos (capítulos finais).
func apply_stage(stage: StageData) -> void:
	hp *= stage.enemy_hp_scale * Params.balance.enemy_hp_factor(Session.planet_index, Session.stage_index)
	_max_hp = hp
	_fire_scale = stage.enemy_fire_scale


## Vira elite: mais vida, maior e com aura. Chamar depois de activate e apply_stage.
func make_elite(hp_multiplier: float, size_multiplier: float) -> void:
	elite = true
	hp *= hp_multiplier
	_max_hp = hp
	radius *= size_multiplier
	queue_redraw()


func is_on_screen() -> bool:
	return get_viewport_rect().grow(-radius * 0.5).has_point(position)


func contact_damage() -> int:
	return data.contact_damage


func points() -> int:
	return data.score


func tint() -> Color:
	return data.color


## Encostou na nave: inimigos comuns são destruídos (o chefe sobrescreve).
func on_player_contact() -> void:
	crushed = true
	take_damage(hp)


## source = WeaponData.Kind da arma (ou SOURCE_SPECIAL / SOURCE_NONE); from = de onde veio o acerto.
func take_damage(amount: float, source: int = SOURCE_NONE, from: Vector2 = Vector2.INF) -> void:
	if not visible:
		return
	var mult: float = _damage_multiplier(source)
	if armored:
		if source == SOURCE_SPECIAL:
			armored = false
			if context != null:
				context.spark(position, Params.special_moment_color, radius / 30.0)
		else:
			mult *= Params.special_moment_armor
	last_blocked = _blocked_by_shield(from)
	if last_blocked:
		# O escudo absorve o acerto (com o multiplicador da arma) e pode quebrar
		_block_left = Params.shield_block_flash_seconds
		_since_hit = 0.0
		if data.shield_hp > 0.0:
			_shield_left -= amount * mult
		Audio.play(&"enemy_hit", -4.0, 1.8)
		queue_redraw()
		return
	amount *= mult
	hp -= amount
	_since_hit = 0.0
	_flash_left = Params.enemy_hit_flash_seconds
	_flash_color = Color.WHITE
	if mult >= Params.weakness_flash_threshold:
		_flash_color = Params.weakness_flash_color
	elif mult <= Params.resist_flash_threshold:
		_flash_color = Params.resist_flash_color
	queue_redraw()
	if context != null and context.damage_numbers != null:
		context.damage_numbers.report(self, amount, _flash_color)
	if hp <= 0:
		killed.emit(self)
		expire()
	else:
		Audio.play(_hit_sound())


## Escudo frontal: bloqueia acertos que chegam pela frente (de baixo). Área e especiais passam (from = INF).
func _blocked_by_shield(from: Vector2) -> bool:
	if data == null or data.shield_arc_degrees <= 0.0 or from == Vector2.INF or not shield_up():
		return false
	var dir: Vector2 = from - position
	if dir.length_squared() < 1.0:
		return false
	return absf(dir.angle_to(Vector2.from_angle(_shield_angle))) <= deg_to_rad(data.shield_arc_degrees) * 0.5


func shield_up() -> bool:
	return data.shield_hp <= 0.0 or _shield_left > 0.0


## Multiplicador de dano por fonte (o chefe sobrescreve).
func _damage_multiplier(source: int) -> float:
	if source == SOURCE_SPECIAL or source < 0:
		return 1.0
	return data.multiplier_for(source)


## Som de quando leva um acerto sem morrer (o chefe usa outro).
func _hit_sound() -> StringName:
	return &"enemy_hit"


func _process(delta: float) -> void:
	_age += delta
	if data.movement == EnemyData.Movement.DIVE and _age >= data.dive_delay:
		_dive(delta)
	elif data.movement == EnemyData.Movement.HOVER:
		_hover(delta)
	if _curve_left > 0.0 and _age >= _curve_delay:
		var step: float = minf(delta, _curve_left)
		_velocity = _velocity.rotated(_curve_rate * step)
		_curve_left -= step
	var drift := Vector2.ZERO
	if _sway_amplitude > 0.0 and _age > 0.0:
		drift.x = _sway_amplitude * _sway_omega * cos(_sway_omega * _age + _sway_phase)
	position += (_velocity + drift) * delta
	if _spin != 0.0:
		rotation += _spin * delta

	var on_screen: bool = is_on_screen()
	_entered = _entered or on_screen
	if _entered and not get_viewport_rect().grow(radius * 2.0).has_point(position):
		expire()
		return

	if on_screen and data.fire_pattern != EnemyData.FirePattern.NONE:
		_fire_cooldown -= delta
		if _tele_left < 0.0 and _fire_cooldown <= data.telegraph_seconds:
			_start_telegraph(maxf(_fire_cooldown, 0.0))
		if _tele_left >= 0.0:
			_tele_left = _fire_cooldown
			queue_redraw()
		if _fire_cooldown <= 0.0:
			_fire_cooldown += data.fire_interval / _fire_scale
			_shoot()
			_tele_left = -1.0
			queue_redraw()
	elif data.movement == EnemyData.Movement.DIVE and _age < data.dive_delay and _age >= data.dive_delay - data.telegraph_seconds:
		queue_redraw()

	_update_flash(delta)
	_update_defense(delta)


## Regeneração (Colosso) e brilho do escudo depois de bloquear.
func _update_defense(delta: float) -> void:
	if _block_left > 0.0:
		_block_left -= delta
		queue_redraw()
	if data.shield_arc_degrees > 0.0 and data.shield_turn_degrees > 0.0 and context != null and context.player != null:
		var goal: float = (context.player.position - position).angle()
		_shield_angle = rotate_toward(_shield_angle, goal, deg_to_rad(data.shield_turn_degrees) * delta)
		queue_redraw()
	_since_hit += delta
	# Escudo quebrado volta inteiro depois de um tempo sem acertos
	if data.shield_hp > 0.0 and _shield_left <= 0.0 and _since_hit >= data.shield_regen_seconds:
		_shield_left = data.shield_hp
		queue_redraw()
	if data.regen_per_second <= 0.0:
		return
	if _since_hit >= data.regen_delay and hp < _max_hp:
		hp = minf(hp + data.regen_per_second * delta, _max_hp)
		queue_redraw()


func is_regenerating() -> bool:
	return data != null and data.regen_per_second > 0.0 and _since_hit >= data.regen_delay and hp < _max_hp


func _update_flash(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			queue_redraw()


## Acelera e vira na direção da nave; o desenho aponta para onde vai.
func _dive(delta: float) -> void:
	var speed: float = move_toward(_velocity.length(), data.dive_speed, data.dive_speed * delta * 2.0)
	var angle: float = _velocity.angle()
	var player: Player = context.player
	if player != null and player.body != null:
		angle = rotate_toward(angle, (player.position - position).angle(), deg_to_rad(data.dive_turn_degrees) * delta)
	_velocity = Vector2.from_angle(angle) * speed
	rotation = angle - PI * 0.5


## Desce até a altura de parada, fica parado um tempo e depois segue descendo.
func _hover(delta: float) -> void:
	if _hover_left < 0.0:
		var stop_y: float = get_viewport_rect().position.y + get_viewport_rect().size.y * data.hover_y_ratio
		if position.y >= stop_y:
			_hover_left = data.hover_seconds
			_velocity = Vector2.ZERO
	elif _hover_left > 0.0:
		_hover_left -= delta
		if _hover_left <= 0.0:
			_velocity = Vector2(0.0, data.speed * _speed_scale)


## Começa o aviso: trava as direções do próximo disparo.
func _start_telegraph(seconds: float) -> void:
	_tele_total = maxf(seconds, 0.01)
	_tele_left = seconds
	_tele_dirs = _attack_dirs()
	if data.telegraph_sound:
		Audio.play(&"boss_warning", Params.telegraph_sound_db, 1.5)


## Direções dos tiros do próximo disparo, conforme o padrão.
func _attack_dirs() -> PackedVector2Array:
	var dirs := PackedVector2Array()
	match data.fire_pattern:
		EnemyData.FirePattern.STRAIGHT:
			dirs.append(Vector2.DOWN)
		EnemyData.FirePattern.AIMED:
			var player: Player = context.player
			dirs.append(Vector2.DOWN if player == null else (player.position - position).normalized())
		EnemyData.FirePattern.FAN:
			var player: Player = context.player
			var aim: float = PI * 0.5 if player == null else (player.position - position).angle()
			var spread: float = deg_to_rad(data.fan_degrees)
			for i in data.fan_count:
				var t: float = 0.0 if data.fan_count == 1 else float(i) / (data.fan_count - 1) - 0.5
				dirs.append(Vector2.from_angle(aim + spread * t))
		EnemyData.FirePattern.RING:
			for i in data.ring_count:
				dirs.append(Vector2.from_angle(_ring_angle + TAU * i / data.ring_count))
	return dirs


func _shoot() -> void:
	var dirs: PackedVector2Array = _tele_dirs if not _tele_dirs.is_empty() else _attack_dirs()
	for dir in dirs:
		_fire(dir)
	_tele_dirs.resize(0)
	if data.fire_pattern == EnemyData.FirePattern.RING:
		_ring_angle += deg_to_rad(data.ring_turn_degrees)


func _fire(direction: Vector2) -> void:
	var bullet := bullets.acquire() as Bullet
	if bullet == null:
		return
	var size := Vector2.ONE * data.bullet_radius * 2.0
	bullet.activate(position + direction * radius, direction * data.bullet_speed,
		data.bullet_damage, size, data.bullet_color, Bullet.Shape.CIRCLE)
	if data.bullet_split_time > 0.0:
		bullet.add_split(data.bullet_split_time, data.bullet_split_count, data.bullet_split_speed, data.bullet_split_radius, bullets)
	if data.bullet_homing_time > 0.0:
		bullet.add_limited_homing(data.bullet_homing_time, data.bullet_homing_turn_degrees, _find_player)


## Alvo dos tiros perseguidores: a nave, se tiver corpo.
func _find_player(_from: Vector2) -> Node2D:
	var player: Player = context.player
	return player if player != null and player.body != null else null


func _draw() -> void:
	var color: Color = _flash_color if _flash_left > 0.0 else data.color
	if data.look == EnemyData.Look.ROCK:
		_draw_rock(color)
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in data.sides:
		# Vértice para baixo, apontando para o jogador
		var dir := Vector2.from_angle(PI * 0.5 + TAU * i / data.sides)
		outer.append(dir * radius)
		inner.append(dir * radius * 0.45)
	if elite:
		_draw_elite_aura()
	draw_colored_polygon(outer, color)
	draw_colored_polygon(inner, color.darkened(0.5))
	_draw_armor()
	_draw_defense()
	_draw_telegraph()


## Elite: aura girando e barra de vida embaixo.
func _draw_elite_aura() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.0)
	draw_circle(Vector2.ZERO, radius * (1.35 + 0.08 * pulse), Color(Params.elite_color, 0.18))
	var start: float = _age * 2.0 - rotation
	for i in 3:
		var a: float = start + TAU * i / 3.0
		draw_arc(Vector2.ZERO, radius * 1.3, a, a + TAU / 6.0, 12, Params.elite_color, 6.0)
	var ratio: float = clampf(hp / maxf(_max_hp, 1.0), 0.0, 1.0)
	var bar := Rect2(-radius, radius * 1.5, radius * 2.0, 8.0)
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Params.elite_color)
	draw_set_transform(Vector2.ZERO, 0.0)


## Blindagem do momento de especial: hexágono dourado pulsando em volta.
func _draw_armor() -> void:
	if not armored:
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * Params.special_moment_blink_hz)
	var points := PackedVector2Array()
	for i in 7:
		points.append(Vector2.from_angle(TAU * i / 6.0 - rotation) * radius * (1.25 + 0.08 * pulse))
	draw_polyline(points, Color(Params.special_moment_color, 0.55 + 0.45 * pulse), 6.0)


## Escudo frontal (arco embaixo) e anel verde enquanto regenera, com a vida que falta.
func _draw_defense() -> void:
	if data.shield_arc_degrees > 0.0 and shield_up():
		var half: float = deg_to_rad(data.shield_arc_degrees) * 0.5
		var base: float = _shield_angle - rotation
		var glow: float = clampf(_block_left / Params.shield_block_flash_seconds, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * 1.25, base - half, base + half, 24,
			Params.enemy_shield_color.lerp(Color.WHITE, glow), Params.enemy_shield_width * (1.0 + glow * 0.5))
	if data.regen_per_second > 0.0:
		var ratio: float = clampf(hp / maxf(_max_hp, 1.0), 0.0, 1.0)
		var regen: bool = is_regenerating()
		var c: Color = Params.regen_color if regen else Color(Params.regen_color, 0.35)
		draw_arc(Vector2.ZERO, radius * 1.12, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, c, 6.0 if regen else 4.0)


## Rocha: contorno irregular, borda escura e crateras.
func _draw_rock(color: Color) -> void:
	draw_colored_polygon(_rock_shape, color)
	var outline := _rock_shape.duplicate()
	outline.append(_rock_shape[0])
	draw_polyline(outline, color.darkened(0.45), 4.0)
	draw_circle(Vector2(radius * 0.25, -radius * 0.2), radius * 0.18, color.darkened(0.25))
	draw_circle(Vector2(-radius * 0.3, radius * 0.25), radius * 0.12, color.darkened(0.25))


## Aviso do próximo ataque (direções em coordenadas globais, desfeita a rotação do inimigo).
func _draw_telegraph() -> void:
	if data.movement == EnemyData.Movement.DIVE and _age < data.dive_delay and _age >= data.dive_delay - data.telegraph_seconds:
		var td: float = 1.0 - (data.dive_delay - _age) / maxf(data.telegraph_seconds, 0.01)
		var player: Player = context.player
		draw_circle(Vector2.ZERO, radius * 0.6, Color(Params.telegraph_dive_color, 0.5 * td))
		if player != null:
			var dir: Vector2 = (player.position - position).normalized().rotated(-rotation)
			Telegraph.draw_lines(self, Vector2.ZERO, PackedVector2Array([dir]), radius, Params.telegraph_dive_color, td)
	if _tele_left < 0.0:
		return
	var t: float = 1.0 - clampf(_tele_left / _tele_total, 0.0, 1.0)
	var dirs := PackedVector2Array()
	for dir in _tele_dirs:
		dirs.append(dir.rotated(-rotation))
	if data.fire_pattern == EnemyData.FirePattern.RING:
		Telegraph.draw_ring(self, Vector2.ZERO, radius, data.bullet_color, t)
		return
	if data.bullet_radius >= Params.telegraph_big_radius and not dirs.is_empty():
		Telegraph.draw_orb(self, dirs[0] * radius, data.bullet_radius, data.bullet_color, t)
	Telegraph.draw_lines(self, Vector2.ZERO, dirs, radius, data.bullet_color, t)
