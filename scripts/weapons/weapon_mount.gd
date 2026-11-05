class_name WeaponMount
extends Node2D
## Suporte de armas de um portador (nave principal ou auxiliar). Cada arma é um
## componente independente (Weapon + WeaponData); o portador só diz onde fica a ponta,
## a força e o volume. Hoje cada portador usa uma arma só (slot 0), mas a lista já
## aceita várias, para o modo com mais de uma arma por nave.

## Versão da arma: a completa (com níveis) ou a da nave auxiliar (simples e fraca).
enum Variant { MAIN, COMPANION }

var context: CombatContext
var variant: Variant = Variant.MAIN
var muzzle_offset: float = Params.ship_size.y * 0.5  # distância do centro até a ponta
var power: float = 1.0  # multiplicador de dano próprio (nave auxiliar)
var sound_db: float = 0.0  # ajuste de volume dos disparos

var _weapons: Array[Weapon] = []
var _active: bool = true


func setup(combat_context: CombatContext, weapon_variant: Variant = Variant.MAIN) -> void:
	context = combat_context
	variant = weapon_variant


## Anexa uma arma e devolve o componente criado.
func equip(data: WeaponData, level: int = 1) -> Weapon:
	var weapon: Weapon = Weapon.create(data, context, level)
	if variant == Variant.COMPANION:
		weapon.apply_stats(data.companion if data.companion != null else data.level(1))
	weapon.variant = variant
	weapon.power = power
	weapon.sound_db = sound_db
	weapon.muzzle_offset = muzzle_offset
	weapon.show_behind_parent = true
	add_child(weapon)
	weapon.set_active(_active)
	_weapons.append(weapon)
	return weapon


## Remove todas as armas.
func clear() -> void:
	for weapon in _weapons:
		weapon.queue_free()
	_weapons.clear()


func set_active(active: bool) -> void:
	_active = active
	for weapon in _weapons:
		weapon.set_active(active)


func is_active() -> bool:
	return _active


## Arma principal (slot 0) ou null.
func primary() -> Weapon:
	return _weapons[0] if not _weapons.is_empty() else null


func weapons() -> Array[Weapon]:
	return _weapons
