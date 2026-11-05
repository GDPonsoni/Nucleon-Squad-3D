class_name Weapon
extends Node2D
## Base das armas: componente independente (dados em WeaponData) que fica num WeaponMount
## de qualquer portador (nave principal ou auxiliar) e dispara sozinho enquanto está ativo.

var data: WeaponData
var context: CombatContext
var level: int = 1
var stats: WeaponLevel  # valores do nível atual
var variant: int = 0  # WeaponMount.Variant: completa ou da nave auxiliar
var power: float = 1.0  # multiplicador de dano próprio (nave auxiliar)
var sound_db: float = 0.0  # ajuste de volume dos disparos (nave auxiliar soa mais baixo)
var muzzle_offset: float = Params.ship_size.y * 0.5  # distância do centro até a ponta


static func create(weapon_data: WeaponData, combat_context: CombatContext, start_level: int) -> Weapon:
	var weapon: Weapon
	match weapon_data.kind:
		WeaponData.Kind.BEAM:
			weapon = BeamWeapon.new()
		WeaponData.Kind.ORBIT:
			weapon = OrbitWeapon.new()
		WeaponData.Kind.HOMING:
			weapon = HomingWeapon.new()
		WeaponData.Kind.CHAIN:
			weapon = ChainWeapon.new()
		_:
			weapon = ProjectileWeapon.new()
	weapon.data = weapon_data
	weapon.context = combat_context
	weapon.set_level(start_level)
	return weapon


func set_level(number: int) -> void:
	level = clampi(number, 1, data.max_level())
	apply_stats(data.level(level))


## Troca os valores em uso (nível da arma ou versão da nave auxiliar).
func apply_stats(values: WeaponLevel) -> void:
	stats = values
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(active)


## Ponta da nave, em coordenadas globais.
func muzzle() -> Vector2:
	return global_position + Vector2(0.0, -muzzle_offset)


## Dano de cada acerto, já com a evolução do núcleo.
func damage() -> float:
	return stats.damage * context.boosts.damage * power


## Multiplicador de cadência da evolução do núcleo.
func rate() -> float:
	return context.boosts.fire_rate
