class_name WeaponLevel
extends Resource
## Valores de um nível de arma. Cada tipo usa só o seu grupo de campos.

@export var damage: int = 1

@export_group("Projéteis (Leque, Mísseis)")
@export var fire_rate: float = 8.0  # disparos por segundo
@export var projectile_speed: float = 2000.0
@export var projectile_size: Vector2 = Vector2(10.0, 32.0)
@export var projectile_shape: Bullet.Shape = Bullet.Shape.RECT
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0  # abertura total do leque
@export var homing_turn_degrees: float = 0.0  # giro por segundo (0 = reto)
@export var projectile_lifetime: float = 0.0  # segundos (0 = até sair da tela)

@export_group("Raio")
@export var beam_count: int = 1
@export var beam_spacing: float = 50.0  # distância entre feixes
@export var beam_width: float = 30.0
@export var beam_tick_seconds: float = 0.08  # aplica o dano a cada intervalo

@export_group("Órbita")
@export var orbit_count: int = 1
@export var orbit_radius: float = 170.0
@export var orbit_speed_degrees: float = 270.0
@export var orbit_size: float = 40.0
@export var orbit_hit_seconds: float = 0.15  # intervalo de dano no mesmo inimigo
@export var clears_projectiles: bool = false  # orbitais destroem tiros inimigos
