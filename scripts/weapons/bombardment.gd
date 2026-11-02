class_name Bombardment
extends Node
## Especial da Artilharia: explosões espalhadas pela parte de cima da tela, uma após
## a outra. Cada uma é um anel curto que causa dano e apaga os tiros inimigos.

var _context: CombatContext
var _data: WeaponData
var _world: Node
var _left: int = 0
var _cooldown: float = 0.0


func setup(context: CombatContext, data: WeaponData, world: Node) -> void:
	_context = context
	_data = data
	_world = world
	_left = data.special_count


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = _data.special_duration / _data.special_count
	var rect: Rect2 = get_viewport().get_visible_rect()
	var target := Vector2(
		randf_range(rect.position.x + _data.special_radius * 0.5, rect.end.x - _data.special_radius * 0.5),
		randf_range(rect.position.y + rect.size.y * 0.08, rect.position.y + rect.size.y * Params.special_bombard_area))
	# Prefere cair em cima de inimigos quando há algum na tela
	var enemy: Enemy = _context.nearest_enemy(target)
	if enemy != null and randf() < Params.special_bombard_aim_chance:
		target = enemy.position
	var wave := Shockwave.new()
	wave.setup(_context, target, _data.special_radius, Params.special_bombard_blast_seconds, _data.special_damage, _data.color)
	_world.add_child(wave)
	_left -= 1
	if _left <= 0:
		queue_free()
