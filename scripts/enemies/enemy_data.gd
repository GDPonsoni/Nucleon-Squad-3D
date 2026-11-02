class_name EnemyData
extends Resource
## Definição de um tipo de inimigo. Valores em data/enemies/*.tres.

@export var id: StringName
@export var max_hp: int = 6
@export var speed: float = 220.0  # px/s para baixo
@export var radius: float = 48.0  # colisão e desenho
@export var sides: int = 6  # polígono do placeholder
@export var color: Color = Color(0.95, 0.2, 0.35)

@export_group("Tiro")
@export var fire_interval: float = 1.4
@export var first_shot_delay: float = 0.4  # após entrar na tela
@export var bullet_speed: float = 700.0
@export var bullet_radius: float = 14.0
@export var bullet_damage: int = 1
@export var bullet_color: Color = Color(1.0, 0.35, 0.75)
