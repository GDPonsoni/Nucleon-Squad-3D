class_name WaveData
extends Resource
## Onda de inimigos em formação, num momento da fase (ou chamada por um chefe).

enum Formation {
	LINE,  ## fileira horizontal entrando pelo topo
	V,  ## V com a ponta na frente
	COLUMN,  ## um atrás do outro no mesmo x (use interval)
	SIDE,  ## entrando pela lateral, um após o outro (use interval)
}
enum EntrySide { LEFT, RIGHT, BOTH }

@export var time_seconds: float = 10.0  # segundos desde o início da fase
@export var enemy: EnemyData
@export var formation: Formation = Formation.V
@export var count: int = 5
@export var spacing: float = 110.0  # distância entre membros
@export var interval: float = 0.0  # segundos entre membros (0 = todos juntos)
@export var x_ratio: float = 0.5  # centro da formação (0 = esquerda, 1 = direita)
@export var side: EntrySide = EntrySide.BOTH  # SIDE: de onde entram (BOTH alterna)
@export var y_ratio: float = 0.25  # SIDE: altura de entrada (0 = topo, 1 = base)
@export var dive_stagger: float = 0.15  # atraso extra de mergulho por membro (kamikazes em sequência)
