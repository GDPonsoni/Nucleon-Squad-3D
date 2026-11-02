class_name WeaponData
extends Resource
## Definição de uma arma: tipo, cor e um WeaponLevel por nível (1 a N).
## Valores em data/weapons/*.tres.

enum Kind { BEAM, SPREAD, HOMING, ORBIT }

@export var id: StringName
@export var kind: Kind = Kind.SPREAD
@export var color: Color = Color.WHITE
@export var levels: Array[WeaponLevel] = []


func max_level() -> int:
	return levels.size()


## Nível começa em 1.
func level(number: int) -> WeaponLevel:
	return levels[clampi(number, 1, max_level()) - 1]
