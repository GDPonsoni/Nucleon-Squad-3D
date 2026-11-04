class_name Companion
extends Node2D
## Nave auxiliar: versão pequena de um corpo que acompanha a nave principal ao lado,
## sem levar dano, e dispara uma versão simples e fraca da arma dele (WeaponData.companion).
## Perto da borda da tela, troca de lado para não sair da tela.

var body: BodyData
var weapon: Weapon

var _player: Player
var _side: float = -1.0  # -1 = à esquerda da nave, 1 = à direita


func setup(data: BodyData, context: CombatContext) -> void:
	body = data
	_player = context.player
	weapon = Weapon.create_companion(data.weapon, context)
	weapon.power = context.boosts.companion_damage
	weapon.sound_db = Params.companion_sound_db
	weapon.muzzle_offset = Params.ship_size.y * 0.5 * Params.companion_scale
	weapon.show_behind_parent = true
	add_child(weapon)
	position = _goal()


func _process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	# Histerese: só troca de lado bem perto da borda
	if _player.position.x < rect.position.x + Params.companion_side_margin:
		_side = 1.0
	elif _player.position.x > rect.end.x - Params.companion_side_margin:
		_side = -1.0
	var weight: float = 1.0 - exp(-Params.companion_follow_rate * delta)
	position = position.lerp(_goal(), weight)
	# Sem corpo na nave principal (aguardando a escolha), a auxiliar não atira
	var active: bool = _player.body != null
	if weapon.is_processing() != active:
		weapon.set_active(active)
	modulate.a = Params.companion_alpha if active else Params.companion_alpha * 0.4
	queue_redraw()


func _goal() -> Vector2:
	return _player.position + Vector2(Params.companion_offset.x * _side, Params.companion_offset.y)


## Corpo pequeno com contorno escuro e um núcleo pequeno, para não ser confundido com a nave.
func _draw() -> void:
	var size: Vector2 = Params.ship_size * Params.companion_scale
	var points := PackedVector2Array()
	for point in body.shape:
		points.append(point * size)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, body.color)
	draw_polyline(outline, Params.nucleus_outline_color, 3.0)
	draw_circle(Vector2.ZERO, Params.nucleus_radius * Params.companion_scale, Color(Params.nucleus_color, 0.85))
