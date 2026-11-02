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

var _context: CombatContext
var _touch_origin: Vector2
var _ship_origin: Vector2
var _target: Vector2
var _build: float = 1.0  # 0 = só o núcleo, 1 = corpo completo
var _build_tween: Tween
var _invulnerable_left: float = 0.0
var _blink_clock: float = 0.0


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


func _draw() -> void:
	if body != null and _build > 0.0:
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(point * Params.ship_size * _build)
		draw_colored_polygon(points, body.color)

	draw_circle(Vector2.ZERO, Params.nucleus_radius, Params.nucleus_color)
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
	return point.clamp(rect.position + half, rect.end - half)
