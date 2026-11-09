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
var _spawn_left: float = 0.0  # animação de surgimento ao ativar


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
	var was_visible: bool = visible
	visible = active
	set_process(active)
	if active and not was_visible:
		play_spawn()


## Inicia a animação de surgimento (a arma já ligou, o ataque espera ela terminar).
func play_spawn() -> void:
	_spawn_left = Params.weapon_spawn_seconds
	_on_spawn()


## Gancho para armas que precisam preparar algo ao surgir.
func _on_spawn() -> void:
	pass


## 0 = acabou de ligar, 1 = pronta. Em tempo de jogo: acompanha a câmera lenta.
func spawn_progress() -> float:
	return 1.0 - clampf(_spawn_left / Params.weapon_spawn_seconds, 0.0, 1.0)


func is_spawning() -> bool:
	return _spawn_left > 0.0


## Avança o surgimento; devolve true enquanto ainda surge.
func _tick_spawn(delta: float) -> bool:
	if _spawn_left <= 0.0:
		return false
	_spawn_left = maxf(_spawn_left - delta, 0.0)
	queue_redraw()
	return _spawn_left > 0.0


## Clarão curto na ponta logo depois de atirar (left = segundos restantes).
func _draw_muzzle_flash(left: float) -> void:
	if left <= 0.0:
		return
	var t: float = left / Params.muzzle_flash_seconds
	var tip := Vector2(0.0, -muzzle_offset)
	var r: float = Params.ship_size.x * Params.muzzle_flash_scale * (0.6 + 0.4 * t) * minf(Params.anim_intensity, 1.5)
	draw_circle(tip, r, Color(data.color, 0.55 * t))
	draw_circle(tip, r * 0.5, Color(1.0, 1.0, 1.0, 0.9 * t))


## Carregamento na ponta: orbe que cresce e anel que converge.
func _draw_charge() -> void:
	if _spawn_left <= 0.0:
		return
	var t: float = spawn_progress()
	var k: float = minf(Params.anim_intensity, 1.5)
	var tip := Vector2(0.0, -muzzle_offset)
	var orb: float = Params.ship_size.x * Params.weapon_charge_orb_scale * t * k
	draw_circle(tip, orb, Color(data.color, 0.5))
	draw_circle(tip, orb * 0.5, Color(1.0, 1.0, 1.0, 0.9))
	draw_arc(tip, Params.ship_size.x * lerpf(0.9, 0.15, ease(t, 0.5)) * k, 0.0, TAU, 24, Color(data.color.lightened(0.4), (1.0 - t) * 0.9), 3.0)


## Ponta da nave, em coordenadas globais.
func muzzle() -> Vector2:
	return global_position + Vector2(0.0, -muzzle_offset)


## Dano de cada acerto, já com a evolução do núcleo.
func damage() -> float:
	return stats.damage * context.boosts.damage * power * data.damage_scale


## Câmera lenta voluntária: a arma segura o tiro (fica pronta para quando o jogo voltar).
func holding() -> bool:
	return context != null and context.weapons_hold


## Multiplicador de cadência da evolução do núcleo.
func rate() -> float:
	return context.boosts.fire_rate
