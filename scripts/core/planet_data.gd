class_name PlanetData
extends Resource
## Planeta (capítulo): nome, cores do fundo e fases. Valores em data/planets/*.tres.

@export var id: StringName
@export var name_key: String  # chave da tabela de tradução
@export var background_color: Color = Color(0.04, 0.04, 0.08)
@export var star_color: Color = Color(0.8, 0.85, 1.0)
@export var stages: Array[StageData] = []
