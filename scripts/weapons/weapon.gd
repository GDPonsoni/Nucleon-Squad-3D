class_name Weapon
extends Node2D
## Base das armas. Fica como filho da nave e dispara sozinha enquanto está ativa.

var data: WeaponData
var context: CombatContext
var level: int = 1
var stats: WeaponLevel  # valores do nível atual


static func create(weapon_data: WeaponData, combat_context: CombatContext, start_level: int) -> Weapon:
	var weapon: Weapon
	match weapon_data.kind:
		WeaponData.Kind.BEAM:
			weapon = BeamWeapon.new()
		WeaponData.Kind.ORBIT:
			weapon = OrbitWeapon.new()
		_:
			weapon = ProjectileWeapon.new()
	weapon.data = weapon_data
	weapon.context = combat_context
	weapon.set_level(start_level)
	return weapon


func set_level(number: int) -> void:
	level = clampi(number, 1, data.max_level())
	stats = data.level(level)
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(active)


## Ponta da nave, em coordenadas globais.
func muzzle() -> Vector2:
	return global_position + Vector2(0.0, -Params.ship_size.y * 0.5)
