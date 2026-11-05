class_name Companion
extends Node2D
## Nave auxiliar: versão pequena de um corpo que acompanha a nave principal ao lado,
## sem levar dano, e dispara uma versão simples e fraca da arma dele (WeaponData.companion).
## Perto da borda da tela, troca de lado para não sair da tela.

var body: BodyData
var mount: WeaponMount

var level: int = 1
var always_active: bool = false  # demonstração (tela de inspeção): atira mesmo sem corpo na nave principal
var _player: Player
var _pulse_left: float = 0.0
var _side: float = -1.0  # -1 = à esquerda da nave, 1 = à direita
var _away: float = 0.0  # 0 = na formação, 1 = recolhida junto do núcleo (sem nave principal)
var _arrive_left: float = 0.0


func setup(data: BodyData, context: CombatContext) -> void:
	body = data
	_player = context.player
	mount = WeaponMount.new()
	mount.name = "WeaponMount"
	mount.show_behind_parent = true
	mount.setup(context, WeaponMount.Variant.COMPANION)
	mount.power = context.boosts.companion_damage
	mount.sound_db = Params.companion_sound_db
	mount.muzzle_offset = Params.ship_size.y * 0.5 * Params.companion_scale
	add_child(mount)
	mount.equip(data.weapon)
	position = _goal()


## Novo nível da versão auxiliar (power-up raro): troca os valores e pulsa.
func set_level(number: int) -> void:
	level = number
	mount.set_level(number)
	_pulse_left = Params.level_up_pulse_seconds


func _process(delta: float) -> void:
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	var rect: Rect2 = get_viewport_rect()
	# Histerese: só troca de lado bem perto da borda
	if _player.position.x < rect.position.x + Params.companion_side_margin:
		_side = 1.0
	elif _player.position.x > rect.end.x - Params.companion_side_margin:
		_side = -1.0
	# Sem corpo na nave principal (aguardando a escolha), a auxiliar recolhe e não atira
	var active: bool = always_active or _player.body != null
	var was_away: float = _away
	_away = move_toward(_away, 0.0 if active else 1.0, Params.companion_retreat_rate * delta)
	if was_away > 0.0 and _away <= 0.0:
		_arrive_left = Params.companion_arrive_pulse_seconds
	_arrive_left = maxf(_arrive_left - delta, 0.0)
	var weight: float = 1.0 - exp(-Params.companion_follow_rate * delta)
	position = position.lerp(_goal(), weight)
	if mount.is_active() != active:
		mount.set_active(active)
	modulate.a = lerpf(Params.companion_alpha, Params.companion_alpha * 0.4, _away)
	queue_redraw()


func _goal() -> Vector2:
	var formation := Vector2(Params.companion_offset.x * _side, Params.companion_offset.y)
	var retreat := Vector2(Params.companion_retreat_offset.x * _side, Params.companion_retreat_offset.y)
	return _player.position + formation.lerp(retreat, ease(_away, -1.8))


## Corpo pequeno com contorno escuro e sem núcleo: só a nave principal tem núcleo (e hitbox).
func _draw() -> void:
	var size: Vector2 = Params.ship_size * Params.companion_scale
	# Inclina durante o voo de saída/retorno e encolhe ao recolher
	var roll: float = sin(_away * PI) * Params.companion_roll * Params.anim_intensity * -_side
	draw_set_transform(Vector2.ZERO, roll, Vector2.ONE * lerpf(1.0, Params.companion_retreat_scale, _away))
	var points := PackedVector2Array()
	for point in body.shape:
		points.append(point * size)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, body.color)
	draw_polyline(outline, Params.nucleus_outline_color, 3.0)
	_draw_level(size)
	if _arrive_left > 0.0:
		var u: float = 1.0 - _arrive_left / Params.companion_arrive_pulse_seconds
		draw_arc(Vector2.ZERO, size.y * (0.5 + u * 0.9), 0.0, TAU, 32, Color(Params.companion_powerup_color, 1.0 - u), 4.0)
	if _pulse_left > 0.0:
		var t: float = 1.0 - _pulse_left / Params.level_up_pulse_seconds
		draw_arc(Vector2.ZERO, size.y * (0.5 + t * Params.level_up_pulse_growth), 0.0, TAU, 40,
			Color(Params.companion_powerup_color, 1.0 - t), Params.level_up_pulse_width * (1.0 - t * 0.5))


## Nível da auxiliar em pequenos segmentos embaixo dela (cheios até o nível atual).
func _draw_level(size: Vector2) -> void:
	var levels: int = body.weapon.companion_max_level()
	var pip: Vector2 = Params.companion_level_pip_size
	var gap: float = pip.y
	var total: float = levels * pip.x + (levels - 1) * gap
	var top: float = size.y * 0.5 + gap * 1.5
	for i in levels:
		var rect := Rect2(-total * 0.5 + i * (pip.x + gap), top, pip.x, pip.y)
		if i < level:
			draw_rect(rect, Params.companion_powerup_color)
		else:
			draw_rect(rect, Color(Params.hud_dead_color, 0.9), false, 2.0)
