class_name Player
extends Node2D
## Nave: núcleo fixo + corpo trocável (formato e arma vêm de BodyData).
## Controle relativo: a nave segue o deslocamento do dedo desde o toque inicial.

var body: BodyData  # null = só o núcleo (corpo destruído, aguardando escolha)
var weapon: Weapon
var cracks: int = 0:  # rachaduras no núcleo, uma por corpo perdido
	set(value):
		cracks = value
		queue_redraw()
## Limite de baixo para a nave, em coordenadas de tela (topo da barra de troca).
var bottom_limit: float = INF

var _context: CombatContext
var _touch_origin: Vector2
var _ship_origin: Vector2
var _target: Vector2
var _build: float = 1.0  # 0 = só o núcleo, 1 = corpo completo
var _build_tween: Tween
var _invulnerable_left: float = 0.0
var _blink_clock: float = 0.0
var _level_pulse_left: float = 0.0
var _pulse_color: Color


func _ready() -> void:
	var rect: Rect2 = get_viewport_rect()
	position = Vector2(rect.get_center().x, rect.end.y - Params.ship_start_bottom_offset)
	_target = position


func setup(context: CombatContext) -> void:
	_context = context


func bind_input(touch: TouchInput) -> void:
	touch.touch_started.connect(_on_touch_started)
	touch.touch_moved.connect(_on_touch_moved)


## Monta um corpo novo: o corpo se reconstrói a partir do núcleo e a arma liga ao final.
func set_body(data: BodyData, weapon_level: int, invulnerable_seconds: float) -> void:
	clear_body()
	body = data
	weapon = Weapon.create(data.weapon, _context, weapon_level)
	weapon.show_behind_parent = true
	add_child(weapon)
	weapon.set_active(false)
	start_invulnerability(invulnerable_seconds)
	_build_tween = create_tween()
	_build_tween.tween_method(_set_build, 0.0, 1.0, Params.body_rebuild_seconds)
	_build_tween.finished.connect(weapon.set_active.bind(true))


## Fica só o núcleo (corpo destruído).
func clear_body() -> void:
	if _build_tween != null:
		_build_tween.kill()
	if weapon != null:
		weapon.queue_free()
		weapon = null
	body = null
	_set_build(0.0)


## Anel dourado que se expande ao subir o nível da arma.
func pulse_level_up() -> void:
	pulse(Params.powerup_color)


## Anel que se expande em volta da nave (nível, cura...).
func pulse(color: Color) -> void:
	_pulse_color = color
	_level_pulse_left = Params.level_up_pulse_seconds


func start_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func is_vulnerable() -> bool:
	return body != null and _build >= 1.0 and _invulnerable_left <= 0.0


func _process(delta: float) -> void:
	# delta já vem escalado pelo time scale: a nave reflete a câmera lenta
	position = position.move_toward(_target, Params.ship_speed * delta)

	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		_blink_clock += delta
		var lit: bool = fmod(_blink_clock * Params.invulnerability_blink_hz, 1.0) < 0.5
		self_modulate.a = 1.0 if lit or _invulnerable_left <= 0.0 else Params.invulnerability_alpha
	elif self_modulate.a < 1.0:
		self_modulate.a = 1.0

	_level_pulse_left = maxf(_level_pulse_left - delta, 0.0)
	# Halo do núcleo e pulso de nível são animados
	queue_redraw()


func _draw() -> void:
	if body != null and _build > 0.0:
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(point * Params.ship_size * _build)
		draw_colored_polygon(points, body.color)

	_draw_nucleus()

	if _level_pulse_left > 0.0:
		var t: float = 1.0 - _level_pulse_left / Params.level_up_pulse_seconds
		var radius: float = Params.ship_size.y * (0.4 + t * Params.level_up_pulse_growth)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(_pulse_color, 1.0 - t), Params.level_up_pulse_width * (1.0 - t * 0.5))


## Núcleo (que também é a hitbox): anel pulsando, borda escura e miolo claro.
## O anel fica mais forte na câmera lenta, quando o jogador planeja o desvio.
func _draw_nucleus() -> void:
	var radius: float = Params.nucleus_radius
	var slow: float = clampf((1.0 - Engine.time_scale) / (1.0 - Params.slow_time_scale), 0.0, 1.0)
	# Pulso em tempo real, para continuar vivo na câmera lenta
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * Params.nucleus_pulse_speed)
	var ring_alpha: float = lerpf(Params.nucleus_ring_alpha, Params.nucleus_ring_alpha_slow, slow) * (0.55 + 0.45 * pulse)
	var ring_radius: float = radius * lerpf(Params.nucleus_ring_scale, Params.nucleus_ring_scale * 1.15, pulse)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(Params.nucleus_color, ring_alpha), Params.nucleus_ring_width)
	draw_circle(Vector2.ZERO, radius + Params.nucleus_outline_width, Params.nucleus_outline_color)
	draw_circle(Vector2.ZERO, radius, Params.nucleus_color)
	for i in cracks:
		var dir := Vector2.from_angle(Params.crack_start_angle + i * Params.crack_angle_step)
		draw_line(dir * Params.nucleus_radius * 0.2, dir * Params.nucleus_radius, Params.background_color, 3.0)


func _set_build(value: float) -> void:
	_build = value
	queue_redraw()


func _on_touch_started(pos: Vector2) -> void:
	_touch_origin = pos
	_ship_origin = position
	_target = position


func _on_touch_moved(pos: Vector2) -> void:
	var raw: Vector2 = _ship_origin + (pos - _touch_origin) * Params.drag_sensitivity
	_target = _clamp_to_screen(raw)
	# Na borda, reancora para a nave responder assim que o dedo voltar
	_ship_origin += _target - raw


func _clamp_to_screen(point: Vector2) -> Vector2:
	var rect: Rect2 = get_viewport_rect()
	var half: Vector2 = Params.ship_size * 0.5
	var bottom: float = minf(rect.end.y, bottom_limit) - half.y
	return point.clamp(rect.position + half, Vector2(rect.end.x - half.x, bottom))
