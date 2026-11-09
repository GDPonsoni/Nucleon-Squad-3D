class_name MoveStep
extends Resource
## Um passo da trajetória de uma onda (WaveData.path): por quanto tempo, quanto gira, com que
## velocidade, se persegue a nave e se dispara. Curva fechada = muito giro em pouco tempo;
## meia-volta = 180; laço = 360. Membros espelhados giram para o outro lado.

@export var seconds: float = 1.0
@export var turn_degrees: float = 0.0  # giro total no passo (positivo = horário na tela)
@export var speed_scale: float = 1.0  # velocidade no passo, relativa à da onda (0 = para)
@export var home_degrees: float = 0.0  # giro máximo por segundo em direção à nave (persegue)
@export var aim: bool = false  # no começo do passo, aponta para a nave
@export var fire: bool = false  # no começo do passo, dispara uma rajada (com o aviso do inimigo)
