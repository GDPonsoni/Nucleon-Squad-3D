class_name WaveData
extends Resource
## Onda de inimigos em formação, num momento da fase (ou chamada por um chefe).
## Formações e movimentos fixos deixam as ondas reconhecíveis: o jogador aprende o padrão.

enum Formation {
	LINE,  ## fileira horizontal entrando pelo topo
	V,  ## V com a ponta na frente
	COLUMN,  ## um atrás do outro no mesmo x (use interval)
	SIDE,  ## entrando pela lateral, um após o outro (use interval)
	DIAGONAL,  ## escada: cada membro mais alto e mais para o lado (side = lado que lidera)
	GRID,  ## bloco de fileiras com columns membros cada
	PINCER,  ## duas colunas espelhadas (x_ratio e 1 - x_ratio), em pares (use interval)
	CIRCLE,  ## anel acima da tela, com spacing de raio
	SWARM,  ## bando solto: posições sorteadas numa nuvem de largura ~spacing x count / 4
	RISE,  ## fileira que entra por baixo da tela subindo
}
enum EntrySide { LEFT, RIGHT, BOTH }

@export var time_seconds: float = 10.0  # segundos desde o início da fase
@export var enemy: EnemyData
@export var formation: Formation = Formation.V
@export var count: int = 5
@export var spacing: float = 110.0  # distância entre membros (CIRCLE: raio do anel)
@export var interval: float = 0.0  # segundos entre membros (0 = todos juntos)
@export var x_ratio: float = 0.5  # centro da formação (0 = esquerda, 1 = direita)
@export var side: EntrySide = EntrySide.BOTH  # SIDE: de onde entram (BOTH alterna); DIAGONAL: quem lidera
@export var y_ratio: float = 0.25  # SIDE: altura de entrada (0 = topo, 1 = base)
@export var dive_stagger: float = 0.15  # atraso extra de mergulho por membro (kamikazes em sequência)
@export var columns: int = 3  # GRID: membros por fileira
## Momento de especial: os membros vêm blindados (dano normal reduzido) até levarem um especial.
@export var special_moment: bool = false

## Trajetória em passos (MoveStep) por cima do movimento do inimigo; vazia = o normal dele.
## Com passos que disparam, o inimigo só atira nesses passos (ataque sincronizado da onda).
@export var path: Array[MoveStep] = []
@export var mirror: bool = false  # espelha a trajetória (gira para o outro lado)

@export_group("Movimento da onda")  # vale para todos os membros, por cima do movimento do inimigo
@export var speed_scale: float = 1.0  # velocidade em relação à do inimigo
@export var sway_amplitude: float = 0.0  # px de balanço lateral enquanto anda (0 = reto); em fila vira "cobra"
@export var sway_period: float = 2.4  # segundos de um balanço completo
@export var sway_phase_step: float = 0.0  # rad entre membros (0 = balançam juntos)
@export var curve_degrees: float = 0.0  # giro total da direção (arcos); positivo = horário na tela
@export var curve_seconds: float = 1.5  # duração da curva
@export var curve_delay: float = 0.0  # segundos em linha reta antes de começar a curva
