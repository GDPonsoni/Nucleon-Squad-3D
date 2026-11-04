class_name BodyData
extends Resource
## Corpo da nave: formato + arma. Valores em data/bodies/*.tres.

@export var id: StringName
@export var name_key: String  # tradução do nome (tela de esquadrão)
@export var description_key: String  # tradução da descrição curta
@export var color: Color = Color.WHITE
## Contorno em unidades (-0.5..0.5, ponta em y = -0.5), escalado por Params.ship_size.
@export var shape: PackedVector2Array = PackedVector2Array()
@export var weapon: WeaponData
## Capítulo cuja conclusão libera a nave (0 = disponível desde o início).
@export var unlock_chapter: int = 0
