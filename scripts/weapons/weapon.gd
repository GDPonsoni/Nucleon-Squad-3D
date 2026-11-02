class_name Weapon
extends Node2D
## Base das armas. Fica como filho da nave e dispara sozinha enquanto está ativa.

var data: WeaponData
var context: CombatContext


static func create(weapon_data: WeaponData, combat_context: CombatContext) -> Weapon:
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
	return weapon


func set_active(active: bool) -> void:
	visible = active
	set_process(active)


## Ponta da nave, em coordenadas globais.
func muzzle() -> Vector2:
	return global_position + Vector2(0.0, -Params.ship_size.y * 0.5)
