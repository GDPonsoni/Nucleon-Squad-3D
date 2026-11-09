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
@export var xp_first_level: float = 20.0  # XP para o 1º nível
@export var xp_growth: float = 1.22  # cada nível pede isso vezes o anterior

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

@export_group("Ondas (provisório)")
## Etapa (a): repete as ondas desta fase da campanha até existir o diretor de ondas do modo.
@export var placeholder_stage: StageData
