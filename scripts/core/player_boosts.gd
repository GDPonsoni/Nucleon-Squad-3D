class_name PlayerBoosts
extends RefCounted
## Bônus da árvore de evolução do núcleo, calculados uma vez no início da partida.
## Os valores padrão são neutros (sem evolução): testes e ferramentas usam PlayerBoosts.new().

var damage: float = 1.0  # multiplica o dano de todas as armas e especiais
var fire_rate: float = 1.0  # multiplica a cadência (tiros, ondas de mísseis, ticks de raio e órbita)
var special_damage: float = 1.0  # multiplica o dano do especial (além de damage)
var special_charge: float = 1.0  # multiplica o tempo de recarga do especial (< 1 = mais rápido)
var boss_damage: float = 1.0  # multiplica o dano em chefes
var extra_hits: int = 0  # hits a mais em cada corpo
var extra_invulnerability: float = 0.0  # segundos a mais de invulnerabilidade após levar hit
var shields: int = 0  # hits absorvidos por fase, antes de tirar vida dos corpos
var medkit_kills_bonus: int = 0  # o medkit vem N inimigos antes
var powerup_kills_bonus: int = 0  # o power-up vem N inimigos antes
var pickup_radius: float = 1.0  # multiplica o alcance de coleta de itens
var start_level_bonus: int = 0  # níveis a mais nas armas ao começar a fase
var quarks: float = 1.0  # multiplica os quarks ganhos
var companion_damage: float = 1.0  # multiplica o dano da nave auxiliar
