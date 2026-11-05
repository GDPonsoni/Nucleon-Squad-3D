class_name WeaponData
extends Resource
## Definição de uma arma: tipo, cor e um WeaponLevel por nível (1 a N).
## Valores em data/weapons/*.tres.

enum Kind { BEAM, SPREAD, HOMING, ORBIT, PIERCE, BLAST, CHAIN, BOUNCE }

@export var id: StringName
@export var kind: Kind = Kind.SPREAD
@export var color: Color = Color.WHITE
@export var levels: Array[WeaponLevel] = []
## Versão simples e fraca usada pela nave auxiliar, com níveis próprios (power-up raro).
## Vazio = usa o nível 1 da arma.
@export var companion_levels: Array[WeaponLevel] = []

@export_group("Especial")  # cada tipo usa só parte dos campos
@export var special_charge_seconds: float = 20.0  # tempo (com o corpo ativo) para encher
@export var special_damage: int = 3
@export var special_duration: float = 1.0  # Raio: tempo do raio gigante; Leque/Órbita: expansão do anel; Tesla: duração da tempestade
@export var special_radius: float = 500.0  # alcance do anel que limpa os tiros
@export var special_width: float = 260.0  # Raio: largura do raio gigante
@export var special_count: int = 24  # Leque/Ricochete: projéteis; Mísseis: máximo de mísseis; Tesla: descargas


func max_level() -> int:
	return levels.size()


## Nível começa em 1.
func level(number: int) -> WeaponLevel:
	return levels[clampi(number, 1, max_level()) - 1]


func companion_max_level() -> int:
	return maxi(companion_levels.size(), 1)


## Nível da versão auxiliar (começa em 1).
func companion_level(number: int) -> WeaponLevel:
	if companion_levels.is_empty():
		return level(1)
	return companion_levels[clampi(number, 1, companion_levels.size()) - 1]
