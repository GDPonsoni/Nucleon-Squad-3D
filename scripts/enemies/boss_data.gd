class_name BossData
extends Resource
## Definição de um chefe: corpo, movimento e fases de ataque. Valores em data/bosses/*.tres.

@export var id: StringName
@export var name_key: String  # chave da tabela de tradução
@export var max_hp: int = 700
@export var score: int = 500
@export var contact_damage: int = 2
@export var radius: float = 120.0
@export var sides: int = 8
@export var color: Color = Color(0.95, 0.35, 0.3)

@export_group("Movimento")
@export var entry_speed: float = 160.0  # descendo até a posição
@export var hold_y_ratio: float = 0.2  # altura onde fica (0 = topo, 1 = base)
@export var sway_amplitude: float = 260.0  # balanço lateral (px)
@export var sway_speed: float = 0.6  # rad/s

@export_group("Ataques")
@export var phases: Array[BossPhase] = []  # em ordem de hp_ratio decrescente
