class_name RunModeData
extends Resource
## Regras do modo roguelike (nome provisório): nave, vida, XP, escolhas e orbes.
## Valores em data/run/run_mode.tres.

@export var ship: BodyData  # nave branca com o ataque frontal fixo (não ocupa espaço de arma)
@export var duration_seconds: float = 1800.0  # meta da partida (30 min)
@export var max_hits: int = 5  # vida da nave (o Casco da evolução soma)
@export var weapon_slots: int = 3  # armas escolhidas que a nave carrega
@export var choices_per_level: int = 4  # opções sorteadas a cada nível

@export_group("XP")
@export var xp_per_point: float = 0.1  # XP por ponto de pontuação do inimigo destruído
@export var xp_first_level: float = 40.0  # XP para o 1º nível (~1 min só com o ataque frontal)
@export var xp_growth: float = 1.4  # cada nível pede isso vezes o anterior

@export_group("Recompensa sem arma para subir")
## Quando faltam armas para completar as opções (ou todas estão no máximo).
@export var quarks_per_extra_level: int = 15

@export_group("Orbes de XP")
@export var orb_fall_speed: float = 110.0  # px/s, caindo devagar
@export var orb_magnet_radius: float = 240.0  # a nave puxa os orbes dentro desse raio (Coleta aumenta)
@export var orb_pull_speed: float = 2200.0  # px/s máximos ao ser puxado
@export var orb_pull_accel: float = 6000.0  # px/s²
@export var orb_collect_radius: float = 70.0
@export var orb_big_value: float = 8.0  # a partir desse valor o orbe é desenhado maior

@export_group("Diretor de ondas")
## Ondas sorteadas pelo peso entre as ativas no minuto atual.
@export var waves: Array[RunWaveEntry] = []
@export var wave_gap_start: float = 2.4  # segundos entre ondas no começo
@export var wave_gap_end: float = 0.6  # ... e aos duration_seconds (interpolação linear)
@export var count_growth_per_minute: float = 0.08  # membros por onda: count x (1 + isso x minuto)
@export var surge_every: float = 60.0  # surto de ondas de horda
@export var surge_waves: int = 3
@export var surge_gap: float = 1.2
@export var first_wave_delay: float = 2.0

@export_group("Escala por tempo")
## Vida dos inimigos (sobre a do capítulo 1): início x crescimento ^ minuto.
@export var hp_start: float = 0.45
@export var hp_growth_per_minute: float = 1.15
## Cadência de tiro dos inimigos: interpolação linear do início ao fim.
@export var fire_scale_start: float = 0.85
@export var fire_scale_end: float = 1.6

@export_group("Elites")
@export var elite_enemies: Array[EnemyData] = []  # sorteados entre os que já apareceram por minuto
@export var elite_from_minute: PackedFloat32Array = []  # mesmo índice de elite_enemies
@export var elite_every: float = 40.0
@export var elite_first: float = 40.0
@export var elite_hp_multiplier: float = 14.0
@export var elite_size: float = 1.4
@export var elite_drops_chest: bool = false  # baú só dos chefes (com elites, as armas sobem rápido demais)
@export var elite_xp_multiplier: float = 6.0

@export_group("Chefes")
## Chefe i entra em boss_minutes[i] (fila: espera o anterior morrer). Vida x boss_hp_scale x
## boss_hp_growth ^ minuto. Durante a luta, as ondas ficam boss_wave_gap_scale x mais espaçadas.
@export var bosses: Array[BossData] = []
@export var boss_minutes: PackedFloat32Array = []
@export var boss_hp_scale: float = 0.5
@export var boss_hp_growth_per_minute: float = 1.05
@export var boss_wave_gap_scale: float = 3.0
@export var boss_xp: float = 80.0  # XP do orbe grande do chefe (x minuto / 5 + 1)
@export var boss_chest_every: int = 2  # baú a cada N chefes (2 = só os de capítulo, os pares)

@export_group("Itens")
@export var medkit_every: float = 75.0  # kit médico por tempo (segundos de jogo)
@export var elite_medkit_chance: float = 0.5
@export var boss_medkits: int = 2
