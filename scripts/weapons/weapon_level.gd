class_name WeaponLevel
extends Resource
## Valores de um nível de arma. Cada tipo usa só o seu grupo de campos.

@export var damage: int = 1

@export_group("Projéteis (Leque, Mísseis)")  # nos Mísseis, count = mísseis por onda
@export var fire_rate: float = 8.0  # disparos por segundo
@export var projectile_speed: float = 2000.0
@export var projectile_size: Vector2 = Vector2(10.0, 32.0)
@export var projectile_shape: Bullet.Shape = Bullet.Shape.RECT
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0  # abertura total do leque
@export var homing_turn_degrees: float = 0.0  # giro por segundo (0 = reto)
@export var projectile_lifetime: float = 0.0  # segundos (0 = até sair da tela)

@export_group("Mísseis em ondas")
@export var aim_seconds: float = 0.35  # a onda surge e mira antes de disparar
@export var wave_cooldown_seconds: float = 1.0  # pausa entre o disparo e a próxima onda
@export var launch_radius: float = 90.0  # raio do anel onde os mísseis surgem
@export var homing_turn_growth_degrees: float = 0.0  # aumento do giro por segundo ao perseguir

@export_group("Raio")  # um item por feixe nas três listas
@export var beam_offsets: PackedFloat32Array = [0.0]  # deslocamento lateral na ponta da nave
@export var beam_angles: PackedFloat32Array = [0.0]  # graus; 0 = para frente
@export var beam_widths: PackedFloat32Array = [30.0]
@export var beam_tick_seconds: float = 0.08  # aplica o dano a cada intervalo

@export_group("Órbita")
@export var orbit_count: int = 1
@export var orbit_radius: float = 170.0
@export var orbit_speed_degrees: float = 270.0
@export var orbit_size: float = 40.0
@export var orbit_hit_seconds: float = 0.15  # intervalo de dano no mesmo inimigo
@export var clears_projectiles: bool = false  # orbitais destroem tiros inimigos
